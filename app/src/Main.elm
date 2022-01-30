module Main exposing (..)

import Browser exposing (Document)
import Html as H
import Search

type Model = SearchModel Search.Model
type Msg = SearchMsg Search.Msg

main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

view : Model -> Document Msg
view model =
    { title = "Error Explorer"
    , body =
        [ case model of
            SearchModel search_model -> Search.view search_model |> H.map SearchMsg
        ]
    }

init : () -> ( Model, Cmd Msg)
init _ =
    map_search_update Search.init

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( SearchMsg search_msg, SearchModel search_model ) ->
            Search.update search_msg search_model
                |> map_search_update

map_search_update : ( Search.Model, Cmd Search.Msg ) -> ( Model, Cmd Msg )
map_search_update ( search_model, search_msg ) =
    ( SearchModel search_model, Cmd.map SearchMsg search_msg )

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none