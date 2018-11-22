port module Main exposing (Flags, Model, Msg(..), init, main, subscriptions, update, view)

import Browser
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Html as Tag exposing (Attribute, Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Lazy as Lazy
import Http
import Json.Decode as D
import Kifu.View as Kifu
import Task
import Url
import Url.Parser as Parser exposing ((</>), Parser)


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Flags =
    { path : String
    }


type alias Model =
    { count : Int
    , key : Nav.Key
    , route : Route
    , kifu : Kifu.Model
    }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( Model 0 key (toRoute url) Kifu.init
    , Nav.pushUrl key (Url.toString url)
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- UPDATE


type Msg
    = Test Int
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | KifuMsg Kifu.Msg
    | HttpRes (Result Http.Error String)
    | RequestScene String
    | NopMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Test step ->
            ( model, Cmd.none )

        LinkClicked (Browser.Internal url) ->
            ( { model | route = toRoute url }
            , Nav.pushUrl model.key (Url.toString url)
            )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            case model.route of
                Script ->
                    ( model
                    , Cmd.batch
                        [ loadKifu "/test.kifu"
                        ]
                    )

                _ ->
                    ( model, Cmd.none )

        KifuMsg kifuMsg ->
            let
                ( kModel, kMsg ) =
                    Kifu.update kifuMsg model.kifu
            in
            ( { model | kifu = kModel }, Cmd.none )

        RequestScene url ->
            ( model
            , Http.get
                { url = url
                , expect = Http.expectString HttpRes
                }
            )

        HttpRes result ->
            case result of
                Ok text ->
                    let
                        decoder =
                            D.list <|
                                D.map4 Kifu.Piece
                                    (D.field "type" D.string)
                                    (D.field "x" D.int)
                                    (D.field "y" D.int)
                                    (D.field "player" D.string)
                    in
                    case D.decodeString decoder text of
                        Ok pieces ->
                            update (KifuMsg <| Kifu.Scene pieces) model

                        Err _ ->
                            ( model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )


port loadKifu : String -> Cmd msg


port test : Int -> Cmd msg



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "test"
    , body =
        [ Tag.ul []
            [ viewLink [] "/"
            , Tag.div [ Attr.id "board" ] []
            , Tag.button [ Events.onClick (Test 3) ] [ Tag.text "aaaa" ]
            , Tag.button [ Events.onClick (RequestScene "http://localhost:8080/aaa.kifu") ] [ Tag.text "request" ]
            ]
        , Kifu.view model.kifu KifuMsg
        ]
    }


viewLink : List (Attribute Msg) -> String -> Html Msg
viewLink attrs path =
    Tag.li [] [ Tag.a (Attr.href path :: attrs) [ Tag.text path ] ]



-- ROUTE


type Route
    = Home
    | Counter
    | Kifu String
    | Step String Int
    | Script


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Home Parser.top
        , Parser.map Counter (Parser.s "counter")
        , Parser.map Kifu (Parser.s "kifu" </> Parser.string)
        , Parser.map Step (Parser.s "kifu" </> Parser.string </> Parser.int)
        , Parser.map Script (Parser.s "script")
        ]


toRoute : Url.Url -> Route
toRoute url =
    Maybe.withDefault Home (Parser.parse routeParser url)
