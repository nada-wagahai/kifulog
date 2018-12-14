module Route exposing (Route(..), toRoute)

import Url
import Url.Parser as Parser exposing ((</>), Parser)


type Route
    = Index
    | Kifu String
    | Scene String Int
    | NotFound


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Index Parser.top
        , Parser.map Kifu (Parser.s "kifu" </> Parser.string)
        , Parser.map Scene (Parser.s "kifu" </> Parser.string </> Parser.int)
        ]


toRoute : Url.Url -> Route
toRoute url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)
