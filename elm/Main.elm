module Main exposing (Flags, Model, Msg(..), init, main, subscriptions, update, view)

import Browser
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Element as Elm exposing (Attribute, Element)
import Element.Events as Event
import Element.Input as Input
import Html as Tag exposing (Attribute, Html)
import Html.Attributes as Attr
import Html.Lazy as Lazy
import Http
import Json.Decode as D
import Kifu.Board as KB
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


type alias Step =
    { curr :
        Maybe
            { pos : KB.Pos
            , piece : KB.PieceType
            }
    , player : KB.Player
    , prev : Maybe KB.Pos
    , finished : Bool
    }


initStep : Step
initStep =
    Step Nothing KB.FIRST Nothing False


type alias Model =
    { count : Int
    , key : Nav.Key
    , route : Route
    , board : KB.Model
    , step : Step
    }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    update (UrlChanged url)
        { count = 0
        , key = key
        , route = toRoute url
        , board = KB.init
        , step = initStep
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | KifuMsg KB.Msg
    | ApiRequest KifuRequest
    | ApiResponse KifuRequest (Result Http.Error String)
    | NopMsg


fieldMaybe : String -> D.Decoder a -> D.Decoder (Maybe a)
fieldMaybe label =
    D.maybe << D.field label


fieldDefault : String -> a -> D.Decoder a -> D.Decoder a
fieldDefault label a =
    D.map (Maybe.withDefault a) << fieldMaybe label


posDecoder : String -> D.Decoder (Maybe KB.Pos)
posDecoder label =
    let
        f x y =
            if x == 0 || y == 0 then
                Nothing

            else
                Just { x = x, y = y }
    in
    D.map (Maybe.andThen identity)
        << fieldMaybe label
    <|
        D.map2 f (D.field "x" D.int) (D.field "y" D.int)


decoder : D.Decoder ( KB.Scene, Step )
decoder =
    D.map2
        (\ps step ->
            ( { pieces = ps
              , pos = Maybe.map (\c -> c.pos) step.curr
              , prev = step.prev
              }
            , step
            )
        )
        (D.field "pieces" <|
            D.list <|
                D.map3 KB.Piece
                    (D.map KB.pieceFromString <| D.field "type" D.string)
                    (posDecoder "pos")
                    (D.map KB.playerFromString <| fieldDefault "order" "FIRST" D.string)
        )
        (fieldDefault "step" initStep <|
            D.map4 Step
                (D.map2 (\pi -> Maybe.map (\pos -> { pos = pos, piece = pi }))
                    (D.map KB.pieceFromString <| fieldDefault "piece" "NULL" D.string)
                    (posDecoder "pos")
                )
                (D.map KB.playerFromString <| fieldDefault "player" "FIRST" D.string)
                (posDecoder "prev")
                (fieldDefault "finished" False D.bool)
        )


type KifuRequest
    = KifuScene String Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( model
            , Nav.pushUrl model.key (Url.toString <| Debug.log "url" url)
            )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load <| Debug.log "href" href )

        UrlChanged url ->
            let
                route =
                    toRoute url

                m =
                    { model | route = route }
            in
            case route of
                Scene kifuId seq ->
                    update (ApiRequest <| KifuScene kifuId seq) m

                Kifu kifuId ->
                    update (ApiRequest <| KifuScene kifuId 0) m

                _ ->
                    ( m, Cmd.none )

        KifuMsg kifuMsg ->
            let
                ( kModel, kMsg ) =
                    KB.update kifuMsg model.board
            in
            ( { model | board = kModel }, Cmd.none )

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
                                Ok ( scene, step ) ->
                                    update
                                        (KifuMsg <| KB.UpdateScene scene)
                                        { model | step = step }

                                Err err ->
                                    let
                                        a_ =
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


playersView : Model -> Element Msg
playersView model =
    Elm.el [] <| Elm.text "players"


stepView : Step -> Int -> Element msg
stepView step seq =
    Elm.el [] <|
        Elm.text <|
            String.fromInt seq
                ++ "手 "
                ++ KB.playerToSymbol step.player
                ++ Maybe.withDefault
                    (if step.finished then
                        "投了"

                     else
                        ""
                    )
                    (Maybe.map
                        (\c ->
                            KB.posToString c.pos
                                ++ KB.pieceText c.piece
                                ++ " まで"
                        )
                        step.curr
                    )


boardView : Model -> String -> Int -> Element Msg
boardView model kifuId seq =
    Elm.column [ Elm.spacing 10 ]
        [ playersView model
        , KB.viewElm model.board KifuMsg
        , stepView model.step seq
        , Elm.row [ Elm.width Elm.fill ] <|
            List.concat
                [ if seq == 0 then
                    []

                  else
                    [ Elm.link []
                        { url = String.fromInt (seq - 1)
                        , label = Elm.text "前"
                        }
                    ]
                , if model.step.finished then
                    []

                  else
                    [ Elm.link [ Elm.alignRight ]
                        { url = String.fromInt (seq + 1)
                        , label = Elm.text "次"
                        }
                    ]
                ]
        ]


content : Model -> Element Msg
content model =
    case model.route of
        Scene kifuId seq ->
            boardView model kifuId seq

        Kifu kifuId ->
            boardView model kifuId 0

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
    | Scene String Int
    | NotFound


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Index Parser.top
        , Parser.map Kifu (Parser.s "kifu" </> Parser.string)
        , Parser.map Scene (Parser.s "kifu" </> Parser.string </> Parser.int)
        ]


toRoute : Url.Url -> Route
toRoute url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)
