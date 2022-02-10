module Analyze exposing (Msg, Model, init, view, update)

import Chart as C
import Chart.Attributes as CA
import Html as H exposing (Html)
import Html.Attributes as HA
import Http
import Json.Decode as Decode exposing (Decoder)

type Msg
    = GotFrequency (Result Http.Error (List Frequency))
type alias Frequency = { code : String, count : Float }

type Model
    = Loading
    | Analyzing (List Frequency)    

init : ( Model, Cmd Msg )
init =
    ( Loading, getFrequency )

getFrequency : Cmd Msg
getFrequency =
    Http.get
        { url = "api/frequency"
        , expect = Http.expectJson GotFrequency frequencyDecoder
        }

frequencyDecoder : Decoder (List Frequency)
frequencyDecoder =
    Decode.list
        <| Decode.map2 Frequency
            ( Decode.field "code" Decode.string )
            ( Decode.field "count" Decode.float )

view : Model -> Html Msg
view model =
    case model of
        Loading -> viewLoading
        Analyzing data -> viewFrequency data

viewLoading : Html Msg
viewLoading =
    H.text "Loading"

viewFrequency : List Frequency -> Html Msg
viewFrequency data =
    H.div
        []
        [ H.text "Error Code Frequency"
        , H.div
            [ HA.style "height" "300px"
            , HA.style "width" "300px"
            , HA.style "position" "absolute"
            , HA.style "left" "50px"
            ]
            [ C.chart
                [ CA.height 300
                , CA.width 300
                ]
                [ C.binLabels .code [ CA.moveDown 20 ]
                , C.yLabels [ CA.withGrid ]
                , C.bars
                    []
                    [ C.bar .count [] ]
                    data
                ]
            ]
        ]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotFrequency (Ok frequency) -> ( Analyzing frequency, Cmd.none)
        GotFrequency (Err _) -> ( Loading, Cmd.none )
    