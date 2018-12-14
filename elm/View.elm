module View exposing (view)

import Browser
import Element as Elm exposing (Attribute, Element)
import Element.Events as Event
import Element.Input as Input
import Html as Tag exposing (Attribute, Html)
import Html.Attributes as Attr
import Kifu.Board as KB
import Model exposing (Model, Step)
import Route
import Update as Msg exposing (Msg)


header : Model -> Element Msg
header model =
    Elm.row []
        --[ Elm.link [] { url = "../..", label = Elm.text "棋譜一覧" }
        [ Elm.el [ Event.onClick (Msg.LinkClicked <| Browser.External "../..") ] <| Elm.text "棋譜一覧"
        ]


playersView : Model -> Element Msg
playersView model =
    Elm.el [] <| Elm.text "players"


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


boardView : Model -> String -> Int -> Element Msg
boardView model kifuId seq =
    Elm.column [ Elm.spacing 10 ]
        [ playersView model
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
