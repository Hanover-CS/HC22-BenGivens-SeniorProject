module Explore exposing (..)

import Html as H exposing (Html)
import TypedSvg as S
import TypedSvg.Core as SC exposing (Svg)
import TypedSvg.Attributes as SA
import TypedSvg.Types exposing (Paint(..), Length(..))
import Color exposing (Color)
import Http
import Json.Decode as Decode exposing (Decoder)
import Force exposing (Entity, entity)
import Time
import Browser.Events
import Array

w : Float
w = 900

h : Float
h = 504

type Msg
    = GotGraph (Result Http.Error Graph)
    | Tick Time.Posix

type Model
    = Loading
    | Exploring
        { entities: List (Entity Int { value: ErrorMessage })
        , simulation: Force.State Int
        }

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
    { aId: Int
    , bId: Int
    , distance: Float
    }

init : ( Model, Cmd Msg )
init =
    ( Loading, getGraph )

view : Model -> Html Msg
view model =
    case model of
        Loading -> H.text "Loading..."
        Exploring { entities } ->
            S.svg [ SA.viewBox 0 0 w h ]
                [ S.g
                    [ SA.class [ "nodes" ] ]
                    (List.map viewEntity entities)
                ]

viewEntity : Entity Int { value: ErrorMessage } -> Svg Msg
viewEntity entity =
    S.circle
        [ SA.r (Px 2.5)
        , SA.fill (Paint <| nodeColor <| Maybe.withDefault -1 <| String.toInt entity.value.code)
        , SA.stroke (Paint <| Color.rgba 0 0 0 0)
        , SA.strokeWidth (Px 7)
        , SA.cx (Px entity.x)
        , SA.cy (Px entity.y)
        ]
        [ S.title [] [ SC.text entity.value.code ] ]

nodeColor : Int -> Color
nodeColor errorCode =
    let colors =
            Array.fromList
                [ Color.blue
                , Color.red
                , Color.orange
                , Color.green
                , Color.purple
                , Color.lightBlue
                , Color.lightGreen
                , Color.lightRed
                , Color.darkGreen
                , Color.darkPurple
                , Color.darkCharcoal
                ]
    in Array.get (errorCode |> modBy (Array.length colors)) colors |> Maybe.withDefault Color.black

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case (msg, model) of
        (GotGraph (Ok graph), Loading) ->
            ( initializeExploring graph, Cmd.none )
        (GotGraph (Err e), Loading) ->
            ( model, Cmd.none )
        (Tick _, Exploring { entities, simulation }) ->
            let ( newState, newEntities ) = Force.tick simulation <| entities
            in
                ( Exploring { entities = newEntities, simulation = newState }, Cmd.none )
        _ -> ( model, Cmd.none )

initializeExploring : Graph -> Model
initializeExploring graph =
    let
        entities = List.map (\node -> entity node.id node.message) graph.nodes

        edgeToLink { aId, bId, distance } =
            { source = aId 
            , target = bId
            , distance = distance
            , strength = Nothing
            }

        links = List.map edgeToLink graph.edges

        simulation =
            Force.simulation
                [ Force.customLinks 1 links
                , Force.manyBody <| List.map .id graph.nodes
                , Force.center (w / 2) (h / 2)
                ]
    in
        Exploring { entities = entities, simulation = simulation }

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
        ( Decode.field "distance" Decode.float )

subscriptions : Model -> Sub Msg
subscriptions model =
    Browser.Events.onAnimationFrame Tick