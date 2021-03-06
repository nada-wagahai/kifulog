module Update.Decoder exposing
    ( board
    , comments
    , index
    , kifu
    , pieces
    )

import Json.Decode as D
import Kifu.Board as KB
import Model exposing (Comment, Index, Kifu, Player, SameStep, Step)
import Time


fieldMaybe : String -> D.Decoder a -> D.Decoder (Maybe a)
fieldMaybe label =
    D.maybe << D.field label


fieldDefault : String -> a -> D.Decoder a -> D.Decoder a
fieldDefault label a =
    D.map (Maybe.withDefault a) << fieldMaybe label


order : String -> D.Decoder KB.Player
order label =
    D.map KB.playerFromString <| fieldDefault label "FIRST" D.string


players : D.Decoder (List Player)
players =
    D.list <|
        D.map2 Model.Player
            (order "order")
            (D.field "name" D.string)


kifu : String -> D.Decoder Kifu
kifu kifuId =
    D.map6 (Kifu kifuId)
        (D.field "players" players)
        (D.map2 Model.Timestamp
            (D.map (\i -> Time.millisToPosix <| i * 1000) <| D.field "startTs" D.int)
            (D.map (\i -> Time.millisToPosix <| i * 1000) <| D.field "endTs" D.int)
        )
        (D.field "handicap" D.string)
        (D.field "gameName" D.string)
        (D.field "steps" <| D.list step)
        (D.field "boardIds" <| D.list D.string)


pos : String -> D.Decoder (Maybe KB.Pos)
pos label =
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


step : D.Decoder Step
step =
    D.map7 Step
        (D.field "seq" D.int)
        -- boardId dummy
        (D.succeed "")
        (D.map4 (\pi pr pt -> Maybe.map (\p -> { pos = p, piece = pi, promoted = pr, putted = pt }))
            (D.map KB.pieceFromString <| fieldDefault "piece" "NULL" D.string)
            (fieldDefault "promoted" False D.bool)
            (fieldDefault "putted" False D.bool)
            (pos "pos")
        )
        (order "player")
        (pos "prev")
        (fieldDefault "finished" False D.bool)
        (D.field "notes" <| D.list D.string)


pieces : String -> D.Decoder (List KB.Piece)
pieces label =
    D.field label <|
        D.list <|
            D.map3 KB.Piece
                (D.map KB.pieceFromString <| D.field "type" D.string)
                (pos "pos")
                (order "order")


comments : D.Decoder (List Comment)
comments =
    D.list <|
        D.map4 Comment
            (D.field "id" D.string)
            (D.field "name" D.string)
            (D.field "text" D.string)
            (fieldDefault "owned" False D.bool)


sameSteps : D.Decoder (List SameStep)
sameSteps =
    D.list <|
        D.map5 SameStep
            (D.field "kifuId" D.string)
            (D.field "seq" D.int)
            (fieldDefault "finished" False D.bool)
            (D.field "players" players)
            (D.map (\i -> Time.millisToPosix <| i * 1000) <| D.field "startTs" D.int)


board : D.Decoder ( List KB.Piece, List Comment, List SameStep )
board =
    D.map3 (\a b c -> ( a, b, c ))
        (D.field "board" <| pieces "pieces")
        (D.field "comments" comments)
        (D.field "steps" sameSteps)


index : D.Decoder Index
index =
    D.map2 Index
        (D.field "entries" <|
            D.list <|
                D.map2 (\id k -> { k | kifuId = id })
                    (D.field "id" D.string)
                    (D.field "kifu" (kifu ""))
        )
        (D.field "recentComments" comments)
