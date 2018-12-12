module Kifu exposing
    ( Model
    , Msg(..)
    , Piece
    , PieceType(..)
    , Player(..)
    , Pos
    , Scene
    , init
    , pieceFromString
    , playerFromString
    , update
    , view
    , viewElm
    )

import Dict exposing (Dict)
import Element as Elm exposing (Attribute, Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html exposing (Html)
import Html.Attributes as Attr


init : Model
init =
    { scene =
        { pieces = []
        , pos = Nothing
        , prev = Nothing
        }
    }


type alias Model =
    { scene : Scene
    }


type alias Scene =
    { pieces : List Piece
    , pos : Maybe Pos
    , prev : Maybe Pos
    }


type Msg
    = UpdateScene Scene


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateScene scene ->
            ( { model | scene = scene }
            , Cmd.none
            )


type PieceType
    = NULL
    | GYOKU
    | HISHA
    | RYU
    | KAKU
    | UMA
    | KIN
    | GIN
    | NARI_GIN
    | KEI
    | NARI_KEI
    | KYOU
    | NARI_KYOU
    | FU
    | TO


pieceFromString : String -> PieceType
pieceFromString str =
    case str of
        "GYOKU" ->
            GYOKU

        "HISHA" ->
            HISHA

        "RYU" ->
            RYU

        "KAKU" ->
            KAKU

        "UMA" ->
            UMA

        "KIN" ->
            KIN

        "GIN" ->
            GIN

        "NARI_GIN" ->
            NARI_GIN

        "KEI" ->
            KEI

        "NARI_KEI" ->
            NARI_KEI

        "KYOU" ->
            KYOU

        "NARI_KYOU" ->
            NARI_KYOU

        "FU" ->
            FU

        "TO" ->
            TO

        _ ->
            NULL


pieceText : PieceType -> String
pieceText type_ =
    case type_ of
        GYOKU ->
            "玉"

        HISHA ->
            "飛"

        RYU ->
            "竜"

        KAKU ->
            "角"

        UMA ->
            "馬"

        KIN ->
            "金"

        GIN ->
            "銀"

        NARI_GIN ->
            "全"

        KEI ->
            "桂"

        NARI_KEI ->
            "圭"

        KYOU ->
            "香"

        NARI_KYOU ->
            "杏"

        FU ->
            "步"

        TO ->
            "と"

        NULL ->
            ""


type Player
    = FIRST
    | SECOND


playerFromString : String -> Player
playerFromString str =
    case str of
        "SECOND" ->
            SECOND

        _ ->
            FIRST


type alias Pos =
    { x : Int
    , y : Int
    }


type alias Piece =
    { type_ : PieceType
    , pos : Maybe Pos
    , player : Player
    }


pieceMap : List Piece -> Dict ( Int, Int ) Piece
pieceMap list =
    Dict.fromList <|
        List.filterMap
            (\p -> Maybe.map (\pos -> ( ( pos.x, pos.y ), p )) p.pos)
            list


view : Model -> (Msg -> msg) -> Html msg
view model toMsg =
    Html.map toMsg <| Elm.layout [] <| board model.scene


viewElm : Model -> (Msg -> msg) -> Element msg
viewElm model toMsg =
    Elm.map toMsg <| board model.scene


writingModeVirticalRl : Attribute msg
writingModeVirticalRl =
    Elm.htmlAttribute <| Attr.style "writing-mode" "vertical-rl"


capturedAttrs : Player -> List (Attribute msg)
capturedAttrs player =
    let
        attrs =
            [ writingModeVirticalRl, Elm.paddingXY 5 15 ]
    in
    if player == FIRST then
        Elm.alignBottom :: attrs

    else
        Elm.rotate pi :: Elm.alignTop :: attrs


board : Scene -> Element Msg
board scene =
    let
        fontSize =
            Font.size 12

        headRow =
            Elm.el [ Elm.width (Elm.px 32) ] << Elm.el [ Elm.centerX, fontSize ]

        headColumn =
            Elm.el [ Elm.height (Elm.px 32) ] << Elm.el [ Elm.centerY, fontSize ]

        ( capturedFirst, capturedSecond ) =
            List.partition (\p -> p.player == FIRST) <|
                List.filter (\p -> p.pos == Nothing) scene.pieces
    in
    Elm.row []
        [ Elm.el (capturedAttrs SECOND) <|
            Elm.text <|
                String.join "" <|
                    "☖持駒: "
                        :: List.map (\p -> pieceText p.type_) capturedSecond
        , Elm.column []
            [ Elm.row [] <|
                List.map (headRow << Elm.text << String.fromInt) <|
                    List.reverse <|
                        List.range 1 9
            , Elm.row []
                [ field scene.pieces scene.pos scene.prev
                , Elm.column [] <|
                    List.map (headColumn << Elm.text << String.fromList << List.singleton) <|
                        String.toList "一二三四五六七八九"
                ]
            ]
        , Elm.el (capturedAttrs FIRST) <|
            Elm.text <|
                String.join "" <|
                    "☗持駒: "
                        :: List.map (\p -> pieceText p.type_) capturedFirst
        ]


alt : Maybe a -> Maybe a -> Maybe a
alt ma mb =
    case ma of
        Just _ ->
            ma

        Nothing ->
            mb


field : List Piece -> Maybe Pos -> Maybe Pos -> Element msg
field pieces curr prev =
    let
        pMap =
            pieceMap pieces

        defPiece =
            Piece NULL Nothing FIRST

        p x y =
            Maybe.withDefault defPiece <| Dict.get ( x, y ) pMap
    in
    Elm.el [ Border.width 2 ] <|
        Elm.row [] <|
            List.map
                (\x ->
                    Elm.column [] <|
                        List.map
                            (\y ->
                                let
                                    piece =
                                        p x y

                                    bgcolor : Maybe Pos -> Elm.Color -> Maybe Elm.Color
                                    bgcolor mpos color =
                                        Maybe.andThen
                                            (\pos ->
                                                if x == pos.x && y == pos.y then
                                                    Just color

                                                else
                                                    Nothing
                                            )
                                            mpos

                                    currColor =
                                        Elm.rgb255 199 209 205

                                    prevColor =
                                        Elm.rgb255 215 225 221

                                    defColor =
                                        Elm.rgb 1 1 1

                                    bg : Maybe Pos -> Maybe Pos -> Attribute msg
                                    bg mpos mprev =
                                        Background.color <|
                                            Maybe.withDefault defColor <|
                                                alt (bgcolor mpos currColor) (bgcolor mprev prevColor)
                                in
                                Elm.el (bg curr prev :: pieceAttrs piece.player) <|
                                    Elm.el
                                        [ Elm.centerX
                                        , Elm.centerY
                                        ]
                                    <|
                                        Elm.text <|
                                            pieceText piece.type_
                            )
                        <|
                            List.range 1 9
                )
            <|
                List.reverse <|
                    List.range 1 9


pieceAttrs : Player -> List (Attribute msg)
pieceAttrs player =
    let
        attrs =
            [ Border.width 1
            , Elm.width (Elm.px 32)
            , Elm.height (Elm.px 32)
            ]
    in
    case player of
        SECOND ->
            Elm.rotate pi :: attrs

        _ ->
            attrs
