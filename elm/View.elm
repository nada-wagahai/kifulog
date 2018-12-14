module View exposing (view)

import Browser
import Element as Elm exposing (Attribute, Element)
import Element.Events as Event
import Element.Input as Input
import Html as Tag exposing (Attribute, Html)
import Html.Attributes as Attr
import Kifu.Board as KB
import Model exposing (Game, Model, Player, Step, Timestamp)
import Route
import Time
import Update as Msg exposing (Msg)


header : Model -> Element Msg
header model =
    Elm.row []
        --[ Elm.link [] { url = "../..", label = Elm.text "棋譜一覧" }
        [ Elm.el [ Event.onClick (Msg.LinkClicked <| Browser.External "../..") ] <| Elm.text "棋譜一覧"
        ]


playersView : List Player -> Element Msg
playersView players =
    let
        ( firsts, seconds ) =
            List.partition (\p -> p.order == KB.FIRST) players
    in
    Elm.column []
        [ Elm.text <| "☗先手: " ++ String.join ", " (List.map (\p -> p.name) firsts)
        , Elm.text <| "☖後手: " ++ String.join ", " (List.map (\p -> p.name) seconds)
        ]


stepView : Step -> Int -> Element msg
stepView step seq =
    Elm.el [] <|
        Elm.text <|
            if seq == 0 then
                "開始前"

            else
                String.fromInt seq
                    ++ "手 "
                    ++ KB.playerToSymbol step.player
                    ++ Maybe.withDefault
                        (if step.finished then
                            "投了"

                         else
                            ""
                        )
                        (Maybe.map
                            (\c ->
                                KB.posToString c.pos
                                    ++ KB.pieceText c.piece
                                    ++ " まで"
                            )
                            step.curr
                        )


monthNumber : Time.Month -> Int
monthNumber month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12


zoneStr : Time.ZoneName -> String
zoneStr zone =
    case zone of
        Time.Name str ->
            "(" ++ str ++ ")"

        Time.Offset min ->
            (if min < 0 then
                ""

             else
                "+"
            )
                ++ String.fromFloat
            <|
                toFloat min
                    / 60


posixToStr : Time.Posix -> ( Time.Zone, Time.ZoneName ) -> String
posixToStr t ( tz, zname ) =
    String.join " "
        [ String.join "/"
            [ String.fromInt <| Time.toYear tz t
            , String.fromInt <| monthNumber <| Time.toMonth tz t
            , String.fromInt <| Time.toDay tz t
            ]
        , String.join ":"
            [ String.fromInt <| Time.toHour tz t
            , String.fromInt <| Time.toMinute tz t
            , String.fromInt <| Time.toSecond tz t
            ]
        , zoneStr zname
        ]


timestampView : Timestamp -> ( Time.Zone, Time.ZoneName ) -> Element Msg
timestampView t tz =
    Elm.column []
        [ Elm.text <| "開始時刻: " ++ posixToStr t.start tz
        ]


gameInfo : ( Time.Zone, Time.ZoneName ) -> Game -> Element Msg
gameInfo tz game =
    Elm.column []
        [ timestampView game.timestamp tz
        , playersView game.players
        , Elm.text <| "手割合: " ++ game.handicap
        , Elm.text <| "棋戦: " ++ game.gameName
        ]


boardView : Model -> String -> Int -> Element Msg
boardView model kifuId seq =
    Elm.column [ Elm.spacing 10 ]
        [ Maybe.withDefault Elm.none <| Maybe.map (gameInfo model.timeZone) model.game
        , KB.viewElm model.board Msg.KifuMsg
        , stepView model.step seq
        , Elm.row [ Elm.width Elm.fill ] <|
            List.concat
                [ if seq == 0 then
                    []

                  else
                    [ Elm.link []
                        { url = String.fromInt (seq - 1)
                        , label = Elm.text "前"
                        }
                    ]
                , if model.step.finished then
                    []

                  else
                    [ Elm.link [ Elm.alignRight ]
                        { url = String.fromInt (seq + 1)
                        , label = Elm.text "次"
                        }
                    ]
                ]
        ]


content : Model -> Element Msg
content model =
    case model.route of
        Route.Scene kifuId seq ->
            boardView model kifuId seq

        Route.Kifu kifuId ->
            boardView model kifuId 0

        _ ->
            Elm.text "NotFound"


body : Model -> Html Msg
body model =
    Elm.layout [] <|
        Elm.column []
            [ header model
            , Elm.el [] <| content model
            ]


view : Model -> Browser.Document Msg
view model =
    { title = "棋譜ログ"
    , body = [ body model ]
    }


viewLink : List (Attribute Msg) -> String -> Html Msg
viewLink attrs path =
    Tag.li [] [ Tag.a (Attr.href path :: attrs) [ Tag.text path ] ]
