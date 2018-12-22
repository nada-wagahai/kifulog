module Model exposing
    ( Comment
    , Game
    , Kifu
    , Model
    , Player
    , SameStep
    , Step
    , Timestamp
    , initGame
    , initStep
    )

import Browser.Navigation as Nav
import Dict exposing (Dict)
import Kifu.Board as KB
import Route exposing (Route)
import Time
import Url


type alias Step =
    { seq : Int
    , boardId : String
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
    Step 0 "" Nothing KB.FIRST Nothing False []


type alias Player =
    { order : KB.Player
    , name : String
    }


type alias SameStep =
    { kifuId : String
    , seq : Int
    , players : List Player
    , start : Time.Posix
    }


type alias Timestamp =
    { start : Time.Posix
    , end : Time.Posix
    }


initTimestamp : Timestamp
initTimestamp =
    Timestamp (Time.millisToPosix 0) (Time.millisToPosix 0)


type alias Kifu =
    { kifuId : String
    , players : List Player
    , timestamp : Timestamp
    , handicap : String
    , gameName : String
    , steps : List Step
    , boardIds : List String
    }


initKifu : Kifu
initKifu =
    Kifu "" [] initTimestamp "" "" [] []


type alias Comment =
    { id : String
    , name : String
    , text : String
    , owned : Bool
    }


type alias Game =
    { kifu : Kifu
    , kModel : KB.Model
    , step : Step
    , comments : List Comment
    , sameSteps : List SameStep
    , boardCache : Dict String ( KB.Model, List Comment, List SameStep )
    , commentInput : String
    }


initGame : Game
initGame =
    { kifu = initKifu
    , kModel = KB.init
    , step = initStep
    , comments = []
    , sameSteps = []
    , boardCache = Dict.empty
    , commentInput = ""
    }


type alias Model =
    { count : Int
    , key : Nav.Key
    , url : Url.Url
    , route : Route
    , game : Game
    , timeZone : ( Time.Zone, Time.ZoneName )
    , login : Maybe { accountId : String }
    }
