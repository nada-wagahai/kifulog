module Main exposing (Flags, Model, Msg(..), init, main, subscriptions, update, view)

import Browser
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Element as Elm exposing (Attribute, Element)
import Element.Events as Event
import Html as Tag exposing (Attribute, Html)
import Html.Attributes as Attr
import Html.Lazy as Lazy
import Http
import Json.Decode as D
import Kifu
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
    ()


type alias Model =
    { count : Int
    , key : Nav.Key
    , route : Route
    , kifu : Kifu.Model
    }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    update (UrlChanged url) <| Model 0 key (toRoute url) Kifu.init



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | KifuMsg Kifu.Msg
    | ApiRequest KifuRequest
    | ApiResponse KifuRequest (Result Http.Error String)
    | NopMsg


piece : Kifu.PieceType -> ( Int, Int ) -> Kifu.Player -> Kifu.Piece
piece t ( x, y ) o =
    Kifu.Piece t { x = x, y = y } o


pos : D.Decoder ( Int, Int )
pos =
    D.map2 Tuple.pair (D.field "x" D.int) (D.field "y" D.int)


decoder : D.Decoder (List Kifu.Piece)
decoder =
    D.field "pieces" <|
        D.list <|
            D.map3 piece
                (D.map Kifu.pieceFromString <|
                    D.field "type" D.string
                )
                (D.field "pos" pos)
                (D.map Kifu.playerFromString <|
                    D.map (Maybe.withDefault "FIRST") <|
                        D.maybe <|
                            D.field "order" D.string
                )


type KifuRequest
    = KifuScene String Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( model
            , Nav.pushUrl model.key (Url.toString url)
            )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            let
                route =
                    toRoute url

                m =
                    { model | route = route }
            in
            case route of
                Step kifuId step ->
                    update (ApiRequest <| KifuScene kifuId step) m

                _ ->
                    ( m, Cmd.none )

        KifuMsg kifuMsg ->
            let
                ( kModel, kMsg ) =
                    Kifu.update kifuMsg model.kifu
            in
            ( { model | kifu = kModel }, Cmd.none )

        ApiRequest req ->
            case req of
                KifuScene id step ->
                    ( model
                    , Http.get
                        { url = "/api/kifu/" ++ id ++ "/" ++ String.fromInt step
                        , expect = Http.expectString (ApiResponse req)
                        }
                    )

        ApiResponse res result ->
            case res of
                KifuScene _ _ ->
                    case result of
                        Ok text ->
                            case D.decodeString decoder text of
                                Ok pieces ->
                                    update (KifuMsg <| Kifu.Scene pieces) model

                                Err err ->
                                    let
                                        _ =
                                            Debug.log "json" err
                                    in
                                    ( model, Cmd.none )

                        Err err ->
                            let
                                _ =
                                    Debug.log "err" err
                            in
                            ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )



-- VIEW


header : Model -> Element Msg
header model =
    Elm.row []
        --[ Elm.link [] { url = "../..", label = Elm.text "棋譜一覧" }
        [ Elm.el [ Event.onClick (LinkClicked <| Browser.External "../..") ] <| Elm.text "棋譜一覧"
        ]


board : Model -> String -> Int -> Element Msg
board model kifuId step =
    Elm.column [ Elm.spacing 10 ]
        [ Kifu.viewElm model.kifu KifuMsg
        , Elm.row [ Elm.width Elm.fill ]
            [ Elm.link []
                { url = String.fromInt (step - 1)
                , label = Elm.text "前"
                }
            , Elm.link [ Elm.alignRight ]
                { url = String.fromInt (step + 1)
                , label = Elm.text "次"
                }
            ]
        , Elm.link [] { url = ".", label = Elm.text "戻る" }
        ]


content : Model -> Element Msg
content model =
    case model.route of
        Step kifuId step ->
            board model kifuId step

        Kifu kifuId ->
            board model kifuId 0

        _ ->
            Elm.text "NotFound"


body : Model -> Html Msg
body model =
    Elm.layout [] <|
        Elm.column []
            [ header model
            , Elm.el [] <| content model
            ]


view : Model -> Browser.Document Msg
view model =
    { title = "棋譜ログ"
    , body = [ body model ]
    }


viewLink : List (Attribute Msg) -> String -> Html Msg
viewLink attrs path =
    Tag.li [] [ Tag.a (Attr.href path :: attrs) [ Tag.text path ] ]



-- ROUTE


type Route
    = Index
    | Kifu String
    | Step String Int
    | NotFound


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Index Parser.top
        , Parser.map Kifu (Parser.s "kifu" </> Parser.string)
        , Parser.map Step (Parser.s "kifu" </> Parser.string </> Parser.int)
        ]


toRoute : Url.Url -> Route
toRoute url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)
