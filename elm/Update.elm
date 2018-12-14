module Update exposing (Msg(..), update)

import Browser
import Browser.Navigation as Nav
import Http
import Json.Decode as D
import Kifu.Board as KB
import Model exposing (Model, Step)
import Route
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
        (fieldDefault "step" Model.initStep <|
            D.map4 Step
                (D.map2 (\pi -> Maybe.map (\pos -> { pos = pos, piece = pi }))
                    (D.map KB.pieceFromString <| fieldDefault "piece" "NULL" D.string)
                    (posDecoder "pos")
                )
                (D.map KB.playerFromString <| fieldDefault "player" "FIRST" D.string)
                (posDecoder "prev")
                (fieldDefault "finished" False D.bool)
        )


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
                m =
                    { model | route = Route.toRoute url }
            in
            case m.route of
                Route.Scene kifuId seq ->
                    let
                        ( m1, c1 ) =
                            update (ApiRequest <| KifuGame kifuId) m

                        ( m2, c2 ) =
                            update (ApiRequest <| KifuScene kifuId seq) m1
                    in
                    ( m2, Cmd.batch [ c1, c2 ] )

                Route.Kifu kifuId ->
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
                KifuScene kifuId step ->
                    ( model
                    , Http.get
                        { url = "/api/kifu/" ++ kifuId ++ "/" ++ String.fromInt step
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

                KifuGame _ ->
                    ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )
