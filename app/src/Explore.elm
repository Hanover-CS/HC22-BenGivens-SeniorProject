module Explore exposing (..)

import Html as H exposing (Html)
import Http
import Json.Decode as Decode exposing (Decoder)

type Msg =
    GotGraph (Result Http.Error Graph)

type Model
    = Loading
    | Value { graph: Graph }

type alias Graph =
    { nodes: List Node
    , edges: List Edge
    }

type alias Node =
    { id: Int
    , message: ErrorMessage
    }

type alias ErrorMessage =
    { code: String
    , message: String
    }

type alias Edge =
    { a_id: Int
    , b_id: Int
    , distance: Int
    }

init : ( Model, Cmd Msg )
init =
    ( Loading, getGraph )

view : Model -> Html Msg
view model =
    case model of
        Loading -> H.text "Loading..."
        Value { graph } ->
            case List.head graph.nodes of
                Just node -> node.message.message |> H.text
                Nothing -> H.text "Didn't really load"

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotGraph (Ok graph) ->
            ( Value { graph = graph }, Cmd.none )
        GotGraph (Err e) ->
            ( model, Cmd.none )

getGraph : Cmd Msg
getGraph =
    Http.get
        { url = "api/force_graph"
        , expect = Http.expectJson GotGraph graphDecoder
        }

graphDecoder : Decoder Graph
graphDecoder =
    Decode.map2 Graph
        ( Decode.field "nodes" (Decode.list nodeDecoder) )
        ( Decode.field "edges" (Decode.list edgeDecoder) )

nodeDecoder : Decoder Node
nodeDecoder =
    Decode.map2 Node
        ( Decode.field "id" Decode.int )
        ( Decode.field "message" errorMessageDecoder )

errorMessageDecoder : Decoder ErrorMessage
errorMessageDecoder =
    Decode.map2 ErrorMessage
        ( Decode.field "code" Decode.string )
        ( Decode.field "message" Decode.string )

edgeDecoder : Decoder Edge
edgeDecoder =
    Decode.map3 Edge
        ( Decode.field "a_id" Decode.int )
        ( Decode.field "b_id" Decode.int )
        ( Decode.field "distance" Decode.int )