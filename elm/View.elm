module View exposing (view)

import Browser
import Element as Elm exposing (Attribute, Element)
import Element.Events as Event
import Element.Input as Input
import Html exposing (Attribute, Html)
import Html.Attributes as Attr
import Html.Events as HtmlEvent
import Kifu.Board as KB
import Model exposing (Game, Model, Player, Step, Timestamp)
import Route
import Time
import Update as Msg exposing (Msg)
import Url


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


symbol : Step -> String
symbol step =
    KB.playerToSymbol step.player
        ++ Maybe.withDefault
            (if step.finished then
                "投了"

             else
                ""
            )
            (Maybe.map (\c -> KB.posToString c.pos ++ KB.pieceText c.piece) step.curr)


stepView : Step -> Element msg
stepView step =
    Elm.el [] <|
        Elm.text <|
            if step.seq == 0 then
                "開始前"

            else
                String.fromInt step.seq
                    ++ "手 "
                    ++ symbol step
                    ++ (if step.finished then
                            ""

                        else
                            " まで"
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
                ++ String.fromFloat (toFloat min / 60)


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


stepsView : Model -> Int -> Game -> Element Msg
stepsView model seq game =
    Elm.html <|
        Html.select [ Attr.size 13, Attr.style "align-self" "fix-start", Attr.style "width" "96px" ] <|
            List.map
                (\step ->
                    let
                        url =
                            model.url

                        url_ =
                            { url
                                | path =
                                    url.path
                                        ++ "/../"
                                        ++ String.fromInt step.seq
                            }
                    in
                    Html.option
                        [ Attr.selected (seq == step.seq)
                        , Attr.style "font-size" "larger"
                        , HtmlEvent.onClick <| Msg.LinkClicked <| Browser.Internal url_
                        ]
                        [ Html.text <| String.fromInt step.seq ++ ": " ++ symbol step ]
                )
                game.steps


controlView : Model -> Step -> Int -> Element Msg
controlView model step seq =
    Elm.row [ Elm.width Elm.fill ] <|
        List.concat
            [ if seq == 0 then
                []

              else
                [ Elm.link []
                    { url = String.fromInt (seq - 1)
                    , label = Elm.text "前"
                    }
                ]
            , if step.finished then
                []

              else
                [ Elm.link [ Elm.alignRight ]
                    { url = String.fromInt (seq + 1)
                    , label = Elm.text "次"
                    }
                ]
            ]


linkView : Model -> Element Msg
linkView model =
    Elm.text ""


boardView : Model -> String -> Int -> Element Msg
boardView model kifuId seq =
    let
        ( game, kModel, step ) =
            Maybe.withDefault ( Model.initGame, KB.init, Model.initStep ) model.game
    in
    Elm.column [ Elm.spacing 10 ]
        [ gameInfo model.timeZone game
        , Elm.row []
            [ KB.viewElm kModel Msg.KifuMsg
            , stepsView model seq game
            ]
        , stepView step
        , Input.multiline
            [ Elm.htmlAttribute (Attr.readonly True)
            , Elm.htmlAttribute (Attr.style "font-size" "small")
            , Elm.height (Elm.px 100)
            ]
            { onChange = always Msg.NopMsg
            , text = String.join "\n" step.notes
            , placeholder = Nothing
            , label = Input.labelHidden "notes"
            , spellcheck = False
            }
        , controlView model step seq
        , linkView model
        ]


content : Model -> Element Msg
content model =
    case model.route of
        Route.Kifu kifuId seq ->
            boardView model kifuId seq

        _ ->
            Elm.text "NotFound"


body : Model -> Html Msg
body model =
    Elm.layout [] <|
        Elm.column []
            [ header model
            , content model
            ]


view : Model -> Browser.Document Msg
view model =
    { title = "棋譜ログ"
    , body = [ body model ]
    }


viewLink : List (Attribute Msg) -> String -> Html Msg
viewLink attrs path =
    Html.li [] [ Html.a (Attr.href path :: attrs) [ Html.text path ] ]
