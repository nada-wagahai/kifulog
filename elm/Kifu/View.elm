module Kifu.View exposing (Model, Msg(..), Piece, init, update, view)

import Dict exposing (Dict)
import Html as Tag exposing (Attribute, Html)
import Html.Attributes as Attr
import List



-- MODEL


pieceText : String -> String
pieceText type_ =
    case type_ of
        "GYOKU" ->
            "玉"

        "HISHA" ->
            "飛"

        "RYU" ->
            "竜"

        "KAKU" ->
            "角"

        "UMA" ->
            "馬"

        "KIN" ->
            "金"

        "GIN" ->
            "銀"

        "NARI_GIN" ->
            "全"

        "KEI" ->
            "桂"

        "NARI_KEI" ->
            "圭"

        "KYOU" ->
            "香"

        "NARI_KYOU" ->
            "杏"

        "FU" ->
            "步"

        "TO" ->
            "と"

        _ ->
            ""


pieceMap : List Piece -> Dict ( Int, Int ) Piece
pieceMap list =
    Dict.fromList <|
        List.map (\p -> ( ( p.x, p.y ), p )) list


type alias Piece =
    { type_ : String
    , x : Int
    , y : Int
    , player : String
    }


type alias Model =
    { pieces : List Piece
    }


init : Model
init =
    Model []



-- UPDATE


type Msg
    = Scene (List Piece)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Scene pieces ->
            ( { model | pieces = pieces }, Cmd.none )



-- VIEW


playerClass : String -> String
playerClass pl =
    case pl of
        "SECOND" ->
            "second"

        _ ->
            "first"


pos : (List (Attribute Msg) -> List (Html Msg) -> Html Msg) -> Piece -> Html Msg
pos tag piece =
    let
        attrs =
            [ Attr.class <| playerClass piece.player ]
    in
    tag attrs [ Tag.text <| pieceText piece.type_ ]


view : Model -> (Msg -> msg) -> Html msg
view model f =
    let
        pMap =
            pieceMap model.pieces

        defPiece =
            Piece "NULL" 0 0 "FIRST"

        p x y =
            Maybe.withDefault defPiece <| Dict.get ( x, y ) pMap
    in
    Tag.map f <|
        Tag.div [ Attr.id "kifu--board" ]
            [ Tag.div []
                [ Tag.text "☖持駒"
                , Tag.table [ Attr.class "label-x" ]
                    [ Tag.tr [] <|
                        List.reverse <|
                            List.map
                                (Tag.td []
                                    << List.singleton
                                    << Tag.text
                                    << String.fromInt
                                )
                            <|
                                List.range 1 9
                    ]
                , Tag.div []
                    [ Tag.table [ Attr.class "board" ] <|
                        List.map
                            (\y ->
                                Tag.tr [] <|
                                    List.map
                                        (\x ->
                                            pos Tag.td <| p x y
                                        )
                                    <|
                                        List.reverse <|
                                            List.range 1 9
                            )
                        <|
                            List.range 1 9
                    , Tag.table [ Attr.class "label-y" ] <|
                        List.map
                            (Tag.tr []
                                << List.singleton
                                << Tag.td []
                                << List.singleton
                                << Tag.text
                                << String.fromList
                                << List.singleton
                            )
                        <|
                            String.toList "一二三四五六七八九"
                    ]
                , Tag.text "☗持駒"
                , Tag.div []
                    [ Tag.div [ Attr.class "prev_step" ]
                        [ Tag.a [ Attr.href "" ] [ Tag.text "前" ] ]
                    , Tag.div [ Attr.class "nest_step" ]
                        [ Tag.a [ Attr.href "" ] [ Tag.text "次" ] ]
                    ]
                ]
            ]
