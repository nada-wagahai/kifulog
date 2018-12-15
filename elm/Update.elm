module Update exposing (Msg(..), update)

import Browser
import Browser.Navigation as Nav
import Http
import Json.Decode as D
import Kifu.Board as KB
import Model exposing (Game, Model, Step)
import Route
import Time
import Url


type KifuRequest
    = KifuScene String Int
    | KifuGame String


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | KifuMsg KB.Msg
    | ApiRequest KifuRequest
    | ApiResponse KifuRequest (Result Http.Error String)
    | SetZone ( Time.Zone, Time.ZoneName )
    | NopMsg


fieldMaybe : String -> D.Decoder a -> D.Decoder (Maybe a)
fieldMaybe label =
    D.maybe << D.field label


fieldDefault : String -> a -> D.Decoder a -> D.Decoder a
fieldDefault label a =
    D.map (Maybe.withDefault a) << fieldMaybe label


playerDecoder : String -> D.Decoder KB.Player
playerDecoder label =
    D.map KB.playerFromString <| fieldDefault label "FIRST" D.string


gameDecoder : D.Decoder Game
gameDecoder =
    D.map5 Game
        (D.field "players" <|
            D.list <|
                D.map2 Model.Player
                    (playerDecoder "order")
                    (D.field "name" D.string)
        )
        (D.map2 Model.Timestamp
            (D.map (\i -> Time.millisToPosix <| i * 1000) <| D.field "startTs" D.int)
            (D.map (\i -> Time.millisToPosix <| i * 1000) <| D.field "endTs" D.int)
        )
        (D.field "handicap" D.string)
        (D.field "gameName" D.string)
        (D.field "steps" <| D.list stepDecoder)


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


stepDecoder : D.Decoder Step
stepDecoder =
    D.map5 Step
        (D.field "seq" D.int)
        (D.map2 (\pi -> Maybe.map (\pos -> { pos = pos, piece = pi }))
            (D.map KB.pieceFromString <| fieldDefault "piece" "NULL" D.string)
            (posDecoder "pos")
        )
        (playerDecoder "player")
        (posDecoder "prev")
        (fieldDefault "finished" False D.bool)


sceneDecoder : D.Decoder ( KB.Scene, Step )
sceneDecoder =
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
                    (playerDecoder "order")
        )
        (fieldDefault "step" Model.initStep stepDecoder)


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
                        ( m1, c1 ) =
                            update (ApiRequest <| KifuGame kifuId) m

                        ( m2, c2 ) =
                            update (ApiRequest <| KifuScene kifuId seq) m1
                    in
                    ( m2, Cmd.batch [ c1, c2 ] )

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
                KifuScene kifuId seq ->
                    ( model
                    , Http.get
                        { url = "/api/kifu/" ++ kifuId ++ "/" ++ String.fromInt seq
                        , expect = Http.expectString (ApiResponse req)
                        }
                    )

                KifuGame kifuId ->
                    case model.game of
                        Nothing ->
                            ( model
                            , Http.get
                                { url = "/api/kifu/" ++ kifuId
                                , expect = Http.expectString (ApiResponse req)
                                }
                            )

                        Just _ ->
                            ( model, Cmd.none )

        ApiResponse res result ->
            case res of
                KifuScene _ _ ->
                    case result of
                        Ok text ->
                            case D.decodeString sceneDecoder text of
                                Ok ( scene, step ) ->
                                    update
                                        (KifuMsg <| KB.UpdateScene scene)
                                        { model | step = step }

                                Err err ->
                                    let
                                        a_ =
                                            Debug.log "kifu json" err
                                    in
                                    ( model, Cmd.none )

                        Err err ->
                            let
                                _ =
                                    Debug.log "kifu err" err
                            in
                            ( model, Cmd.none )

                KifuGame _ ->
                    case result of
                        Ok text ->
                            case D.decodeString gameDecoder text of
                                Ok game ->
                                    update NopMsg { model | game = Just game }

                                Err err ->
                                    let
                                        a_ =
                                            Debug.log "game json" err
                                    in
                                    ( model, Cmd.none )

                        Err err ->
                            let
                                _ =
                                    Debug.log "game err" err
                            in
                            ( model, Cmd.none )

        SetZone zone ->
            ( { model | timeZone = zone }, Cmd.none )

        _ ->
            ( model, Cmd.none )
