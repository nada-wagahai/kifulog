module View exposing (view)

import Browser
import Element as Elm exposing (Attribute, Element)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Event
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes as HtmlAttr
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
        [ Elm.link linkStyles { url = url_, label = Elm.text "棋譜一覧" }

        -- [ Elm.el (Event.onClick (Msg.LinkClicked <| Browser.External "../..") :: linkStyles) <| Elm.text "棋譜一覧"
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
                    let
                        notPromoted =
                            not c.putted
                                && not (List.member c.piece [ KB.GYOKU, KB.KIN, KB.RYU, KB.UMA, KB.NARI_GIN, KB.NARI_KEI, KB.NARI_KYOU, KB.TO ])
                                && ((step.player == KB.FIRST && c.pos.y <= 3)
                                        || (step.player == KB.SECOND && c.pos.y >= 7)
                                   )
                    in
                    KB.posToString c.pos
                        ++ KB.pieceText c.piece
                        ++ (if c.promoted then
                                "成"

                            else if notPromoted then
                                "不成"

                            else
                                ""
                           )
                        ++ prevPos step.prev
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
    Elm.column
        [ Elm.width (Elm.px 140)
        , Elm.height (Elm.px 300)
        , Border.width 1
        , Elm.scrollbarY
        , Elm.htmlAttribute <| HtmlAttr.id "steps-view"
        ]
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

                    attrs =
                        Font.size 15
                            :: Elm.paddingXY 7 5
                            :: Elm.width Elm.fill
                            :: Event.onClick (Msg.LinkClicked <| Browser.Internal url_)
                            :: (if step.seq == seq then
                                    [ Background.color (Elm.rgb255 199 209 205) ]

                                else
                                    []
                               )
                in
                Elm.el attrs <|
                    Elm.text <|
                        String.fromInt step.seq
                            ++ ": "
                            ++ symbol step
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


ifLogin : Model -> Element msg -> Element msg
ifLogin model elm =
    Maybe.withDefault Elm.none <| Maybe.map (\_ -> elm) model.login


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
                            ifLogin model <|
                                if c.owned then
                                    Input.button linkStyles
                                        { onPress = Just <| Msg.ApiRequest (Msg.KifuDeleteComment c.id)
                                        , label =
                                            Elm.el
                                                [ Elm.htmlAttribute (HtmlAttr.style "font-size" "small") ]
                                            <|
                                                Elm.text "削除"
                                        }

                                else
                                    Elm.none
                  }
                ]
            }
        , ifLogin model <|
            Elm.column [ Elm.width Elm.fill, Elm.spacing 10 ]
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
        ]


sameSteps : Model -> Element Msg
sameSteps model =
    let
        myself s =
            (s.kifuId == model.game.kifu.kifuId)
                && (model.game.step.seq == s.seq || model.game.step.seq + 1 == s.seq || model.game.step.seq == s.seq + 1)

        steps =
            List.filter (not << myself) model.game.sameSteps

        stepLink step =
            let
                ( fs, ss ) =
                    List.partition (\p -> p.order == KB.FIRST) step.players
            in
            Elm.link [ Elm.htmlAttribute <| HtmlAttr.class "list_star" ]
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
            [ Elm.htmlAttribute (HtmlAttr.readonly True)
            , Elm.htmlAttribute (HtmlAttr.style "font-size" "small")
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

        Route.Index ->
            Elm.column [ Elm.spacing 20 ]
                [ Elm.row []
                    [ Elm.table [ Elm.spacing 5 ]
                        { data = model.index.entries
                        , columns =
                            [ { header = Elm.none
                              , width = Elm.shrink
                              , view =
                                    \kifu ->
                                        let
                                            ( fs, ss ) =
                                                List.partition (\p -> p.order == KB.FIRST) kifu.players
                                        in
                                        Elm.link [ Elm.htmlAttribute <| HtmlAttr.class "list_star" ]
                                            { url = "kifu/" ++ kifu.kifuId ++ "/0"
                                            , label =
                                                Elm.text (playersToStr fs ++ " - " ++ playersToStr ss)
                                            }
                              }
                            , { header = Elm.none
                              , width = Elm.shrink
                              , view = \kifu -> Elm.text <| posixToStr kifu.timestamp.start model.timeZone
                              }
                            ]
                        }

                    -- , ifLogin model <|
                    --     Elm.column []
                    --         [ Elm.text "最近のコメント"
                    --         ]
                    ]
                , Elm.row [ Elm.spacing 15 ]
                    [ case model.login of
                        Nothing ->
                            Elm.el (Event.onClick (Msg.LinkClicked <| Browser.External "login") :: linkStyles) <| Elm.text "login"

                        Just _ ->
                            Elm.el (Event.onClick (Msg.LinkClicked <| Browser.External "logout") :: linkStyles) <| Elm.text "logout"
                    , Elm.el (Event.onClick (Msg.LinkClicked <| Browser.External "admin") :: linkStyles) <| Elm.text "admin"
                    ]
                ]

        _ ->
            Elm.text "NotFound"


body : Model -> Html Msg
body model =
    Elm.layout [] <|
        Elm.column [ Elm.padding 20, Elm.spacing 15 ]
            [ header model
            , content model
            ]


view : Model -> Browser.Document Msg
view model =
    { title = "棋譜ログ"
    , body = [ body model ]
    }
