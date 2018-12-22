module View exposing (view)

import Browser
import Element as Elm exposing (Attribute, Element)
import Element.Border as Border
import Element.Events as Event
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as HtmlEvent
import Kifu.Board as KB
import Model exposing (Kifu, Model, Player, Step, Timestamp)
import Route
import Time
import Update as Msg exposing (Msg)
import Url


linkStyles : List (Attribute msg)
linkStyles =
    [ Elm.padding 2, Border.width 1, Border.rounded 3 ]


header : Model -> Element Msg
header model =
    let
        url =
            model.url

        url_ =
            Url.toString { url | path = url.path ++ "/../../.." }
    in
    Elm.row [ Elm.padding 5 ]
        -- [ Elm.link linkStyles { url = url_, label = Elm.text "棋譜一覧" }
        [ Elm.el (Event.onClick (Msg.LinkClicked <| Browser.External "../..") :: linkStyles) <| Elm.text "棋譜一覧"
        ]


playersToStr : List Player -> String
playersToStr players =
    String.join ", " (List.map (\p -> p.name) players)


playersView : List Player -> Element Msg
playersView players =
    let
        ( firsts, seconds ) =
            List.partition (\p -> p.order == KB.FIRST) players
    in
    Elm.column []
        [ Elm.text <| "☗先手: " ++ playersToStr firsts
        , Elm.text <| "☖後手: " ++ playersToStr seconds
        ]


prevPos : Maybe KB.Pos -> String
prevPos prev =
    case prev of
        Nothing ->
            "打"

        Just p ->
            "(" ++ String.fromInt p.x ++ String.fromInt p.y ++ ")"


symbol : Step -> String
symbol step =
    KB.playerToSymbol step.player
        ++ Maybe.withDefault
            (if step.finished then
                "投了"

             else
                ""
            )
            (Maybe.map
                (\c ->
                    KB.posToString c.pos ++ KB.pieceText c.piece ++ prevPos step.prev
                )
                step.curr
            )


stepView : Step -> Element msg
stepView step =
    Elm.column []
        [ Elm.text <|
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
        ]


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


gameInfo : ( Time.Zone, Time.ZoneName ) -> Kifu -> Element Msg
gameInfo tz game =
    Elm.column [ Elm.padding 2, Elm.spacing 5 ]
        [ timestampView game.timestamp tz
        , playersView game.players
        , Elm.text <| "手割合: " ++ game.handicap
        , Elm.text <| "棋戦: " ++ game.gameName
        ]


stepsView : Model -> Int -> Kifu -> Element Msg
stepsView model seq game =
    Elm.el [] <|
        Elm.html <|
            Html.select
                [ Attr.size 13, Attr.style "align-self" "fix-start", Attr.style "width" "128px" ]
            <|
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


controlView : Model -> Element Msg
controlView model =
    Elm.row [ Elm.width Elm.fill ] <|
        List.concat
            [ if model.game.step.seq == 0 then
                []

              else
                [ Elm.link [ Elm.padding 2, Border.width 1, Border.rounded 3 ]
                    { url = String.fromInt (model.game.step.seq - 1)
                    , label = Elm.text "←前"
                    }
                ]
            , if model.game.step.finished then
                []

              else
                [ Elm.link [ Elm.alignRight, Elm.padding 2, Border.width 1, Border.rounded 3 ]
                    { url = String.fromInt (model.game.step.seq + 1)
                    , label = Elm.text "次→"
                    }
                ]
            ]


commentsView : Model -> Element Msg
commentsView model =
    Elm.column [ Elm.spacing 20 ] <|
        [ Elm.table [ Elm.spacing 10, Elm.width <| Elm.px 600 ]
            { data = model.game.comments
            , columns =
                [ { header = Elm.none
                  , width = Elm.maximum 50 Elm.shrink
                  , view = \c -> Elm.paragraph [] [ Elm.text c.name ]
                  }
                , { header = Elm.none
                  , width = Elm.fill
                  , view = \c -> Elm.paragraph [] [ Elm.text c.text ]
                  }
                , { header = Elm.none
                  , width = Elm.shrink
                  , view =
                        \c ->
                            case model.login of
                                Nothing ->
                                    Elm.none

                                Just s ->
                                    if c.owned then
                                        Input.button linkStyles
                                            { onPress = Just <| Msg.ApiRequest (Msg.KifuDeleteComment c.id)
                                            , label =
                                                Elm.el
                                                    [ Elm.htmlAttribute (Attr.style "font-size" "small") ]
                                                <|
                                                    Elm.text "削除"
                                            }

                                    else
                                        Elm.none
                  }
                ]
            }
        , Elm.column [ Elm.width Elm.fill, Elm.spacing 10 ] <|
            Maybe.withDefault [] <|
                Maybe.map
                    (\s ->
                        [ Input.text []
                            { onChange = Msg.CommentInput
                            , text = model.game.commentInput
                            , placeholder = Nothing
                            , label = Input.labelHidden "comment"
                            }
                        , Input.button linkStyles
                            { onPress =
                                Just <|
                                    Msg.ApiRequest <|
                                        Msg.KifuPostComment model.game.step.boardId model.game.commentInput
                            , label = Elm.text "post comment"
                            }
                        ]
                    )
                    model.login
        ]


sameSteps : Model -> Element Msg
sameSteps model =
    let
        myself s =
            s.kifuId /= model.game.kifu.kifuId || s.seq /= model.game.step.seq

        steps =
            List.filter myself model.game.sameSteps

        stepLink step =
            let
                ( fs, ss ) =
                    List.partition (\p -> p.order == KB.FIRST) step.players
            in
            Elm.link [ Elm.htmlAttribute <| Attr.class "same_step" ]
                { url = "../" ++ step.kifuId ++ "/" ++ String.fromInt step.seq
                , label = Elm.text (playersToStr fs ++ " - " ++ playersToStr ss)
                }
    in
    Elm.column [ Elm.paddingXY 10 30, Elm.spacing 5, Elm.alignTop ] <|
        Elm.el [ Elm.paddingXY 0 5 ] (Elm.text "同一局面")
            :: (if List.isEmpty steps then
                    [ Elm.text "なし" ]

                else
                    [ Elm.table [ Elm.spacingXY 10 5 ]
                        { data = steps
                        , columns =
                            [ { header = Elm.none
                              , width = Elm.shrink
                              , view = stepLink
                              }
                            , { header = Elm.none
                              , width = Elm.shrink
                              , view = \step -> Elm.text <| String.fromInt step.seq ++ "手"
                              }
                            , { header = Elm.none
                              , width = Elm.shrink
                              , view = \step -> Elm.text <| posixToStr step.start model.timeZone
                              }
                            ]
                        }
                    ]
               )


boardView : Model -> Element Msg
boardView model =
    Elm.column [ Elm.spacing 10 ]
        [ gameInfo model.timeZone model.game.kifu
        , Elm.row [ Elm.padding 5, Elm.spacing 15 ]
            [ KB.viewElm model.game.kModel Msg.KifuMsg
            , stepsView model model.game.step.seq model.game.kifu
            ]
        , stepView model.game.step
        , Input.multiline
            [ Elm.htmlAttribute (Attr.readonly True)
            , Elm.htmlAttribute (Attr.style "font-size" "small")
            , Elm.height (Elm.px 100)
            ]
            { onChange = always Msg.NopMsg
            , text = String.join "\n" model.game.step.notes
            , placeholder = Just <| Input.placeholder [] (Elm.text "棋譜コメント")
            , label = Input.labelHidden "notes"
            , spellcheck = False
            }
        , controlView model
        ]


content : Model -> Element Msg
content model =
    case model.route of
        Route.Kifu kifuId seq ->
            Elm.column [ Elm.spacing 20 ]
                [ Elm.row []
                    [ boardView model
                    , sameSteps model
                    ]
                , commentsView model
                ]

        _ ->
            Elm.text "NotFound"


body : Model -> Html Msg
body model =
    Elm.layout [] <|
        Elm.column [ Elm.padding 20 ]
            [ header model
            , content model
            ]


view : Model -> Browser.Document Msg
view model =
    { title = "棋譜ログ"
    , body = [ body model ]
    }


viewLink : List (Html.Attribute Msg) -> String -> Html Msg
viewLink attrs path =
    Html.li [] [ Html.a (Attr.href path :: attrs) [ Html.text path ] ]
