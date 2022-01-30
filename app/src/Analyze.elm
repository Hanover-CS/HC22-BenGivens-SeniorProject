module Analyze exposing (view)

import Chart as C
import Chart.Attributes as CA
import Html as H exposing (Html)
import Html.Attributes as HA

type alias Msg = ()
type alias Data = { x : String, y : Float }

data : List Data
data =
    [ { x = "E0277", y = 16 }
    , { x = "E0308", y = 10 }
    , { x = "E0599", y = 39 }
    , { x = "E0609", y = 3 }
    ]

view : Html Msg
view =
    H.div
        []
        [ H.text "Error Code Summary"
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
                [ C.binLabels .x [ CA.moveDown 20 ]
                , C.yLabels [ CA.withGrid ]
                , C.bars
                    []
                    [ C.bar .y [] ]
                    data
                ]
            ]
        ]