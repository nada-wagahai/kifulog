module Model exposing (Game, Model, Player, Step, Timestamp, initStep)

import Browser.Navigation as Nav
import Kifu.Board as KB
import Route exposing (Route)
import Time


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


type alias Player =
    { order : KB.Player
    , name : String
    }


type alias Timestamp =
    { start : Time.Posix
    , end : Time.Posix
    }


type alias Game =
    { players : List Player
    , timestamp : Timestamp
    , handicap : String
    , gameName : String
    , steps : List Step
    }


type alias Model =
    { count : Int
    , key : Nav.Key
    , route : Route
    , board : KB.Model
    , step : Step
    , game : Maybe Game
    , timeZone : ( Time.Zone, Time.ZoneName )
    }
