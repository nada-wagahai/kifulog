module Update exposing (Msg(..), update)

import Browser
import Browser.Navigation as Nav
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


apiRequest : Model -> KifuRequest -> ( Model, Cmd Msg )
apiRequest model req =
    case req of
        KifuScene kifuId seq ->
            ( model
            , Http.get
                { url = "/api/kifu/" ++ kifuId ++ "/" ++ String.fromInt seq
                , expect = Http.expectString (ApiResponse req)
                }
            )

        KifuGame kifuId seq ->
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


apiResponse : Model -> KifuRequest -> Result Http.Error String -> ( Model, Cmd Msg )
apiResponse model res result =
    case res of
        KifuScene _ seq ->
            case result of
                Ok text ->
                    case D.decodeString (Decoder.pieces "pieces") text of
                        Ok pieces ->
                            Maybe.withDefault ( model, Cmd.none ) <|
                                Maybe.map
                                    (\( game, kifuModel, _ ) ->
                                        let
                                            step =
                                                if seq == 0 then
                                                    Model.initStep

                                                else
                                                    Maybe.withDefault Model.initStep (get (seq - 1) game.steps)
                                        in
                                        update
                                            (KifuMsg <| KB.UpdateScene <| mkScene pieces step)
                                            { model | game = Just ( game, kifuModel, step ) }
                                    )
                                    model.game

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

        KifuGame kifuId seq ->
            case result of
                Ok text ->
                    case D.decodeString Decoder.game text of
                        Ok game ->
                            let
                                model_ =
                                    Maybe.withDefault model <|
                                        Maybe.map
                                            (\( _, kModel, step ) ->
                                                { model | game = Just ( game, kModel, step ) }
                                            )
                                            model.game
                            in
                            update (ApiRequest (KifuScene kifuId seq)) model_

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
                    case m.game of
                        Nothing ->
                            update (ApiRequest <| KifuGame kifuId seq) m

                        Just _ ->
                            update (ApiRequest <| KifuScene kifuId seq) m

                Route.KifuTop kifuId ->
                    update (LinkClicked (Browser.Internal { url | path = url.path ++ "/0" })) model

                _ ->
                    ( m, Cmd.none )

        KifuMsg kifuMsg ->
            Maybe.withDefault ( model, Cmd.none ) <|
                Maybe.map
                    (\( game, kModel, step ) ->
                        let
                            ( kModel_, kMsg ) =
                                KB.update kifuMsg kModel
                        in
                        ( { model | game = Just ( game, kModel_, step ) }, Cmd.map KifuMsg kMsg )
                    )
                    model.game

        ApiRequest req ->
            apiRequest model req

        ApiResponse res result ->
            apiResponse model res result

        SetZone zone ->
            ( { model | timeZone = zone }, Cmd.none )

        _ ->
            ( model, Cmd.none )
