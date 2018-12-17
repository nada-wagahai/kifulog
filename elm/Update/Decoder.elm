module Update.Decoder exposing
    ( comments
    , kifu
    , pieces
    )

import Json.Decode as D
import Kifu.Board as KB
import Model exposing (Comment, Kifu, Step)
import Time


fieldMaybe : String -> D.Decoder a -> D.Decoder (Maybe a)
fieldMaybe label =
    D.maybe << D.field label


fieldDefault : String -> a -> D.Decoder a -> D.Decoder a
fieldDefault label a =
    D.map (Maybe.withDefault a) << fieldMaybe label


player : String -> D.Decoder KB.Player
player label =
    D.map KB.playerFromString <| fieldDefault label "FIRST" D.string


kifu : String -> D.Decoder Kifu
kifu kifuId =
    D.map6 (Kifu kifuId)
        (D.field "players" <|
            D.list <|
                D.map2 Model.Player
                    (player "order")
                    (D.field "name" D.string)
        )
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
    D.map6 Step
        (D.field "seq" D.int)
        (D.map2 (\pi -> Maybe.map (\p -> { pos = p, piece = pi }))
            (D.map KB.pieceFromString <| fieldDefault "piece" "NULL" D.string)
            (pos "pos")
        )
        (player "player")
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
                (player "order")


comments : D.Decoder (List Comment)
comments =
    D.list <|
        D.map3 Comment
            (D.field "id" D.string)
            (D.field "ownerId" D.string)
            (D.field "text" D.string)
