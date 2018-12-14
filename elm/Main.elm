module Main exposing (Flags, init, main, subscriptions)

import Browser
import Browser.Navigation as Nav
import Kifu.Board as KB
import Model exposing (Model)
import Route
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
    Update.update (Update.UrlChanged url)
        { count = 0
        , key = key
        , route = Route.toRoute url
        , board = KB.init
        , step = Model.initStep
        , game = Nothing
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
