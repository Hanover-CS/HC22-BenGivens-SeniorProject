module Main exposing (..)

import Browser exposing (Document)
import Chart as C
import Chart.Attributes as CA
import Html as H
import Html.Attributes as HA

type alias Model = ()
type alias Msg = ()

main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

init : () -> ( Model, Cmd Msg )
init _ = ( (), Cmd.none )


type alias Data = { x : String, y : Float }

data : List Data
data =
    [ { x = "E0277", y = 16 }
    , { x = "E0308", y = 10 }
    , { x = "E0599", y = 39 }
    , { x = "E0609", y = 3 }
    ]

view model =
    { title = "Error Explorer"
    , body =
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
            , C.bars []
                [ C.bar .y [] ]
                data
            ]]
        ]
    }

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( (), Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none