module Analyze exposing (Msg, Model, init, view, update)

import Chart as C
import Chart.Attributes as CA
import Html as H exposing (Html)
import Html.Attributes as HA
import Http
import Json.Decode as Decode exposing (Decoder)

type Msg
    = GotFrequencies (Result Http.Error (List Frequency))
    | GotLengths (Result Http.Error (List Float))

type alias Frequency = { code : String, count : Float }

type Model
    = Loading PartialData
    | Analyzing Data

type alias PartialData =
    { frequencies : Maybe ( List Frequency )
    , lengths : Maybe ( List Float )
    }

type alias Data =
    { frequencies : List Frequency
    , lengths : List Float
    }    

init : ( Model, Cmd Msg )
init =
    ( Loading initPartial, Cmd.batch [ getFrequencies, getLengths] )

initPartial : PartialData
initPartial = PartialData Nothing Nothing

getFrequencies : Cmd Msg
getFrequencies =
    Http.get
        { url = "api/frequency"
        , expect = Http.expectJson GotFrequencies frequencyDecoder
        }

frequencyDecoder : Decoder (List Frequency)
frequencyDecoder =
    Decode.list
        <| Decode.map2 Frequency
            ( Decode.field "code" Decode.string )
            ( Decode.field "count" Decode.float )

getLengths : Cmd Msg
getLengths =
    Http.get
        { url = "api/length"
        , expect = Http.expectJson GotLengths lengthDecoder
        }

lengthDecoder : Decoder (List Float)
lengthDecoder =
    Decode.list Decode.float

view : Model -> Html Msg
view model =
    case model of
        Loading _ -> viewLoading
        Analyzing data -> viewData data

viewLoading : Html Msg
viewLoading =
    H.text "Loading"

viewData : Data -> Html Msg
viewData data =
    H.div []
        [ viewFrequencies data.frequencies
        , viewLengths data.lengths
        ]

viewFrequencies : List Frequency -> Html Msg
viewFrequencies frequencies =
    H.div
        [ HA.style "margin" "50px" ]
        [ H.text "Error Code Frequency"
        , H.div
            [ HA.style "height" "300px"
            , HA.style "width" "300px"
            , HA.style "position" "relative"
            , HA.style "display" "block"
            , HA.style "left" "50px"
            ]
            [ C.chart
                [ CA.height 300
                , CA.width 300
                ]
                [ C.binLabels (.code >> (\code -> "E" ++ code)) [ CA.moveDown 20 ]
                , C.yLabels [ CA.withGrid ]
                , C.bars
                    []
                    [ C.bar .count [] ]
                    frequencies
                ]
            ]
        ]

viewLengths : List Float -> Html Msg
viewLengths lengths =
    H.div
        [ HA.style "margin" "50px" ]
        [ H.text "Error Message Length"
        , H.div
            [ HA.style "height" "300px"
            , HA.style "width" "300px"
            , HA.style "position" "relative"
            , HA.style "display" "block"
            , HA.style "left" "50px"
            ]
            [ C.chart
                [ CA.height 300
                , CA.width 300
                ]
                [ C.yLabels [ CA.withGrid ]
                , C.bars
                    [ CA.margin 0 ]
                    [ C.bar identity [] ]
                    (lengths |> List.sort)
                ]
            ]
        ]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    thenNothing <|
        case msg of
            GotFrequencies (Ok frequencies) ->
                let partial = downgradeData model
                    newPartial = { partial | frequencies = Just frequencies }
                in
                    case upgradePartialData newPartial of
                        Just data -> Analyzing data
                        Nothing -> Loading newPartial
            GotFrequencies (Err _) -> Loading initPartial
            GotLengths (Ok lengths) ->
                let partial = downgradeData model
                    newPartial = { partial | lengths = Just lengths }
                in
                    case upgradePartialData newPartial of
                        Just data -> Analyzing data
                        Nothing -> Loading newPartial
            GotLengths (Err _) -> Loading initPartial
    
thenNothing : Model -> ( Model, Cmd Msg )
thenNothing model = ( model, Cmd.none )

downgradeData : Model -> PartialData
downgradeData model =
    case model of
        Loading partial -> partial
        Analyzing data -> PartialData (Just data.frequencies) (Just data.lengths)

upgradePartialData : PartialData -> Maybe Data
upgradePartialData partialData =
    case ( partialData.frequencies, partialData.lengths ) of
        ( Just frequencies, Just lengths ) -> Just (Data frequencies lengths)
        _ -> Nothing