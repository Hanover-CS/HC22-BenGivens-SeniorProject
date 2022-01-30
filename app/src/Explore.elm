module Explore exposing (..)

import Html as H exposing (Html)

type alias Msg = ()

type alias Model = ()

view : Model -> Html Msg
view model = H.text ""

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )