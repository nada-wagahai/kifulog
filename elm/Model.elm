module Model exposing (Game, Model, Step, initStep)

import Browser.Navigation as Nav
import Kifu.Board as KB
import Route exposing (Route)


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


type alias Game =
    { players : List String
    }


type alias Model =
    { count : Int
    , key : Nav.Key
    , route : Route
    , board : KB.Model
    , step : Step
    , game : Maybe Game
    }
