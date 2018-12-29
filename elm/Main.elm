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
    Maybe
        { accountId : String
        }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        ( m1, c1 ) =
            Update.update (Update.UrlChanged url)
                { count = 0
                , key = key
                , url = url
                , route = Route.toRoute url
                , index = { entries = [], recentComments = [] }
                , game = Model.initGame
                , timeZone = ( Time.utc, Time.Name "UTC" )
                , login = flags
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
