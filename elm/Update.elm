module Update exposing (KifuRequest(..), Msg(..), update)

import Browser
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Dict
import Http
import Json.Decode as D
import Json.Encode as E
import Kifu.Board as KB
import Model exposing (Comment, Model, SameStep, Step)
import Route
import Task
import Time
import Update.Decoder as Decoder
import Url


type KifuRequest
    = KifuScene String Int
    | KifuGame String Int
    | KifuPostComment String String
    | KifuDeleteComment String


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | KifuMsg KB.Msg
    | StepsScrollResult (Result Dom.Error ())
    | ApiRequest KifuRequest
    | ApiResponse KifuRequest (Result Http.Error String)
    | SetZone ( Time.Zone, Time.ZoneName )
    | CommentInput String
    | NopMsg


mkScene : List KB.Piece -> Step -> KB.Scene
mkScene pieces step =
    { pieces = pieces
    , pos = Maybe.map (\c -> c.pos) step.curr
    , prev = step.prev
    }


get : Int -> List a -> Maybe a
get i =
    List.head << List.drop i


updateScene : Model -> (Step -> KB.Scene) -> List Comment -> List SameStep -> Int -> ( Model, Cmd Msg )
updateScene model sceneF comments steps seq =
    let
        game =
            model.game

        step =
            if seq == 0 then
                Model.initStep

            else
                Maybe.withDefault Model.initStep (get (seq - 1) game.kifu.steps)
    in
    update
        (KifuMsg <| KB.UpdateScene <| sceneF step)
        { model
            | game =
                { game
                    | step = step
                    , comments = comments
                    , sameSteps = steps
                }
        }


apiRequest : Model -> KifuRequest -> ( Model, Cmd Msg )
apiRequest model req =
    case req of
        KifuScene boardId seq ->
            case Dict.get boardId model.game.boardCache of
                Nothing ->
                    ( model
                    , Http.get
                        { url = "/api/board/" ++ boardId
                        , expect = Http.expectString (ApiResponse req)
                        }
                    )

                Just ( board, comments, steps ) ->
                    updateScene model (always board.scene) comments steps seq

        KifuGame kifuId seq ->
            if model.game.kifu.kifuId == kifuId then
                ( model, Cmd.none )

            else
                ( model
                , Http.get
                    { url = "/api/kifu/" ++ kifuId
                    , expect = Http.expectString (ApiResponse req)
                    }
                )

        KifuPostComment boardId comment ->
            let
                game =
                    model.game

                body =
                    E.object
                        [ ( "comment", E.string comment )
                        , ( "kifu_id", E.string game.kifu.kifuId )
                        , ( "seq", E.int game.step.seq )
                        ]
            in
            ( { model
                | game =
                    { game
                        | commentInput = ""
                        , boardCache = Dict.remove boardId game.boardCache
                    }
              }
            , Http.post
                { url = "/api/board/" ++ boardId ++ "/comment"
                , body = Http.jsonBody body
                , expect = Http.expectString (ApiResponse req)
                }
            )

        KifuDeleteComment commentId ->
            let
                game =
                    model.game
            in
            ( { model
                | game =
                    { game
                        | boardCache = Dict.remove game.step.boardId game.boardCache
                    }
              }
            , Http.post
                { url = "/api/comment/" ++ commentId ++ "/delete"
                , body = Http.emptyBody
                , expect = Http.expectString (ApiResponse req)
                }
            )


apiResponse : Model -> KifuRequest -> Result Http.Error String -> ( Model, Cmd Msg )
apiResponse model res result =
    case result of
        Ok text ->
            case res of
                KifuScene _ seq ->
                    case D.decodeString Decoder.board text of
                        Ok ( pieces, comments, steps ) ->
                            updateScene model (mkScene pieces) comments steps seq

                        Err err ->
                            ( model, Cmd.none )

                KifuGame kifuId seq ->
                    case D.decodeString (Decoder.kifu kifuId) text of
                        Ok kifu ->
                            case get seq kifu.boardIds of
                                Nothing ->
                                    ( model, Cmd.none )

                                Just boardId ->
                                    let
                                        game =
                                            model.game

                                        steps =
                                            List.map
                                                (\step ->
                                                    case get step.seq kifu.boardIds of
                                                        Nothing ->
                                                            step

                                                        Just bid ->
                                                            { step | boardId = bid }
                                                )
                                                kifu.steps
                                    in
                                    update (ApiRequest (KifuScene boardId seq))
                                        { model
                                            | game =
                                                { game
                                                    | kifu = { kifu | steps = steps }
                                                    , boardCache = Dict.empty
                                                }
                                        }

                        Err err ->
                            ( model, Cmd.none )

                KifuPostComment _ _ ->
                    update (LinkClicked (Browser.Internal model.url)) model

                KifuDeleteComment _ ->
                    update (LinkClicked (Browser.Internal model.url)) model

        Err err ->
            ( model, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( { model | url = url }
            , Nav.pushUrl model.key (Url.toString url)
            )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            let
                m =
                    { model | route = Route.toRoute url }
            in
            case m.route of
                Route.Kifu kifuId seq ->
                    let
                        boardId =
                            Maybe.withDefault "" <| get seq model.game.kifu.boardIds
                    in
                    if m.game.kifu.kifuId == kifuId then
                        update (ApiRequest <| KifuScene boardId seq) m

                    else
                        update (ApiRequest <| KifuGame kifuId seq) m

                Route.KifuTop kifuId ->
                    update (LinkClicked (Browser.Internal { url | path = url.path ++ "/0" })) model

                _ ->
                    ( m, Cmd.none )

        KifuMsg kifuMsg ->
            let
                game =
                    model.game

                ( kModel_, kMsg ) =
                    KB.update kifuMsg game.kModel

                game_ =
                    case get game.step.seq game.kifu.boardIds of
                        Nothing ->
                            { game | kModel = kModel_ }

                        Just boardId ->
                            { game
                                | kModel = kModel_
                                , boardCache =
                                    Dict.insert
                                        boardId
                                        ( kModel_, game.comments, game.sameSteps )
                                        game.boardCache
                            }

                y =
                    toFloat (game_.step.seq - 1) * 25
            in
            ( { model | game = game_ }
            , Cmd.batch
                [ Cmd.map KifuMsg kMsg
                , Task.attempt StepsScrollResult (Dom.setViewportOf "steps-view" 0 y)
                ]
            )

        StepsScrollResult result ->
            ( model, Cmd.none )

        ApiRequest req ->
            apiRequest model req

        ApiResponse res result ->
            apiResponse model res result

        SetZone zone ->
            ( { model | timeZone = zone }, Cmd.none )

        CommentInput text ->
            let
                game =
                    model.game
            in
            ( { model | game = { game | commentInput = text } }, Cmd.none )

        _ ->
            ( model, Cmd.none )
