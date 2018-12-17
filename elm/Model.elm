module Model exposing (Kifu, Model, Player, Step, Timestamp, initKifu, initStep)

import Browser.Navigation as Nav
import Kifu.Board as KB
import Route exposing (Route)
import Time
import Url


type alias Step =
    { seq : Int
    , curr :
        Maybe
            { pos : KB.Pos
            , piece : KB.PieceType
            }
    , player : KB.Player
    , prev : Maybe KB.Pos
    , finished : Bool
    , notes : List String
    }


initStep : Step
initStep =
    Step 0 Nothing KB.FIRST Nothing False []


type alias Player =
    { order : KB.Player
    , name : String
    }


type alias Timestamp =
    { start : Time.Posix
    , end : Time.Posix
    }


initTimestamp : Timestamp
initTimestamp =
    Timestamp (Time.millisToPosix 0) (Time.millisToPosix 0)


type alias Kifu =
    { players : List Player
    , timestamp : Timestamp
    , handicap : String
    , gameName : String
    , steps : List Step
    }


initKifu : Kifu
initKifu =
    Kifu [] initTimestamp "" "" []


type alias Model =
    { count : Int
    , key : Nav.Key
    , url : Url.Url
    , route : Route
    , game : Maybe ( Kifu, KB.Model, Step )
    , timeZone : ( Time.Zone, Time.ZoneName )
    }
