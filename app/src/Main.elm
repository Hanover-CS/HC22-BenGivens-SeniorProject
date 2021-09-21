module Main exposing (..)

import Browser exposing (Document)
import Html exposing (text)

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

view model =
    { title = "Error Explorer"
    , body = [ text "Hello from Elm!" ]
    }

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( (), Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none