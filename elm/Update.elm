module Update exposing (Msg(..), update)

import Browser
import Browser.Navigation as Nav
import Dict
import Http
import Json.Decode as D
import Kifu.Board as KB
import Model exposing (Model, Step)
import Route
import Time
import Update.Decoder as Decoder
import Url


type KifuRequest
    = KifuScene String Int
    | KifuGame String Int
    | KifuComment String


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | KifuMsg KB.Msg
    | ApiRequest KifuRequest
    | ApiResponse KifuRequest (Result Http.Error String)
    | SetZone ( Time.Zone, Time.ZoneName )
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


updateScene : Model -> (Step -> KB.Scene) -> Int -> ( Model, Cmd Msg )
updateScene model sceneF seq =
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
        { model | game = { game | step = step } }


apiRequest : Model -> KifuRequest -> ( Model, Cmd Msg )
apiRequest model req =
    case req of
        KifuScene boardId seq ->
            case Dict.get seq model.game.boardCache of
                Nothing ->
                    ( model
                    , Http.get
                        { url = "/api/board/" ++ boardId
                        , expect = Http.expectString (ApiResponse req)
                        }
                    )

                Just b ->
                    updateScene model (always b.scene) seq

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

        KifuComment boardId ->
            ( model
            , Http.get
                { url = "/api/comments/" ++ boardId
                , expect = Http.expectString (ApiResponse req)
                }
            )


apiResponse : Model -> KifuRequest -> Result Http.Error String -> ( Model, Cmd Msg )
apiResponse model res result =
    case result of
        Ok text ->
            case res of
                KifuScene _ seq ->
                    case D.decodeString (Decoder.pieces "pieces") text of
                        Ok pieces ->
                            updateScene model (mkScene pieces) seq

                        Err err ->
                            let
                                a_ =
                                    Debug.log "kifu json" err
                            in
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
                                    in
                                    update (ApiRequest (KifuScene boardId seq))
                                        { model
                                            | game =
                                                { game
                                                    | kifu = kifu
                                                    , boardCache = Dict.empty
                                                }
                                        }

                        Err err ->
                            let
                                a_ =
                                    Debug.log "game json" err
                            in
                            ( model, Cmd.none )

                KifuComment boardId ->
                    case D.decodeString (D.field "comments" Decoder.comments) text of
                        Ok comments ->
                            let
                                game =
                                    model.game
                            in
                            ( { model
                                | game = { game | comments = comments }
                              }
                            , Cmd.none
                            )

                        Err err ->
                            let
                                a_ =
                                    Debug.log "comment json" err
                            in
                            ( model, Cmd.none )

        Err err ->
            let
                _ =
                    Debug.log "http err" err
            in
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
            in
            ( { model
                | game =
                    { game
                        | kModel = kModel_
                        , boardCache = Dict.insert game.step.seq kModel_ game.boardCache
                    }
              }
            , Cmd.map KifuMsg kMsg
            )

        ApiRequest req ->
            apiRequest model req

        ApiResponse res result ->
            apiResponse model res result

        SetZone zone ->
            ( { model | timeZone = zone }, Cmd.none )

        _ ->
            ( model, Cmd.none )
