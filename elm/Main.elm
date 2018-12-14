module Main exposing (Flags, main)

import Browser
import Browser.Navigation as Nav
import Kifu.Board as KB
import Model exposing (Model)
import Route
import Task
import Time
import Update exposing (Msg)
import Url
import View


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = Update.update
        , subscriptions = subscriptions
        , view = View.view
        , onUrlChange = Update.UrlChanged
        , onUrlRequest = Update.LinkClicked
        }


type alias Flags =
    ()


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        ( m1, c1 ) =
            Update.update (Update.UrlChanged url)
                { count = 0
                , key = key
                , route = Route.toRoute url
                , board = KB.init
                , step = Model.initStep
                , game = Nothing
                , timeZone = ( Time.utc, Time.Name "UTC" )
                }
    in
    ( m1
    , Cmd.batch
        [ Task.perform Update.SetZone <| Task.map2 Tuple.pair Time.here Time.getZoneName
        , c1
        ]
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
