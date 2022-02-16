module Explore exposing (..)

import Html as H exposing (Html)
import Html.Events.Extra.Mouse as Mouse
import TypedSvg as S
import TypedSvg.Core as SC exposing (Svg)
import TypedSvg.Attributes as SA
import TypedSvg.Events as SE
import TypedSvg.Types exposing (Paint(..), Length(..))
import Color exposing (Color)
import Http
import Json.Decode as Decode exposing (Decoder)
import Force exposing (Entity, entity)
import Time
import Browser.Events
import Array
import Search exposing (viewErrorMessage)

w : Float
w = 900

h : Float
h = 250

type Msg
    = GotGraph (Result Http.Error Graph)
    | Tick Time.Posix
    | ClickedNode Int
    | DragStart Int ( Float, Float )
    | DragAt ( Float, Float )
    | DragEnd ( Float, Float )

type Model
    = Loading
    | Exploring
        { entities : List (Entity Int { value: ErrorMessage })
        , simulation : Force.State Int
        , selection : Selection
        , drag : Maybe Drag
        }

type alias Selection = Maybe Int

type alias Drag =
    { start : ( Float, Float )
    , current : ( Float, Float )
    , index : Int
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
        Exploring { entities, selection } ->
            H.div []
                [ viewGraph entities selection
                , viewMessage entities selection
                ]
            

viewGraph : List (Entity Int { value: ErrorMessage }) -> Selection -> Html Msg
viewGraph entities selection =
    S.svg
        [ SA.viewBox 0 0 w h ]
        [ S.g
            [ SA.class [ "nodes" ] ]
            (List.map (viewEntity selection) entities)
        ]

viewEntity : Selection -> Entity Int { value: ErrorMessage } -> Svg Msg
viewEntity selection entity =
    let index = entity.id
        color = String.toInt entity.value.code |> Maybe.withDefault -1 |> nodeColor 
        selected = selection |> Maybe.map (\sIndex -> sIndex == index ) |> Maybe.withDefault False
        strokeColor = if selected then Color.black else Color.rgba 0 0 0 0
    in
        S.circle
            [ SA.r (Px 5)
            , SA.fill (Paint <| color)
            , SA.stroke (Paint <| strokeColor)
            , SA.strokeWidth (Px 2)
            , SA.cx (Px entity.x)
            , SA.cy (Px entity.y)
            , SE.onClick (ClickedNode index)
            , SE.onMouseDown (DragStart index (entity.x, entity.y))
            ]
            [ S.title [] [ SC.text entity.value.code ] ]

viewMessage : List (Entity Int { value: ErrorMessage }) -> Selection -> Html Msg
viewMessage entities selection =
    case selection of
        Just id ->
            H.div []
                (List.map (\entity -> if entity.id == id then viewErrorMessage entity.value else H.text "") entities)
        Nothing ->
            H.text ""

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
        (Tick _, Exploring ({ entities, simulation, drag } as e)) ->
            let ( newState, newEntities ) = Force.tick simulation <| entities
            in
                case drag of
                    Just { current, index } ->
                        ( Exploring
                            { e
                            | entities = List.map (updateNode index current) newEntities
                            , simulation = newState
                            }
                        , Cmd.none
                        )
                    Nothing ->
                        ( Exploring { e | entities = newEntities, simulation = newState }, Cmd.none )
        (ClickedNode id, Exploring e) -> ( Exploring { e | selection = Just id }, Cmd.none )
        (DragStart id xy, Exploring e) -> ( Exploring { e | drag = Just { start = xy, current = xy, index = id } }, Cmd.none )
        (DragAt ( x, y ), Exploring ({ drag } as e)) ->
            case drag of
                Just { start, index } ->
                    ( Exploring
                        { e
                        | drag = Just { start = start, current = ( x, y ), index = index }
                        , entities = List.map (updateNode index ( x, y )) e.entities
                        , simulation = Force.reheat e.simulation
                        }
                    , Cmd.none
                    )
                Nothing ->
                    ( model, Cmd.none )
        (DragEnd _, Exploring e) -> ( Exploring { e | drag = Nothing }, Cmd.none )
        _ -> ( model, Cmd.none )

updateNode : Int -> (Float, Float) -> Entity Int { value: ErrorMessage } -> Entity Int { value: ErrorMessage }
updateNode index ( x, y ) entity =
    if entity.id == index then { entity | x = x, y = y } else entity

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
        Exploring { entities = entities, simulation = simulation, selection = Nothing, drag = Nothing }

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
    Sub.batch
        [ Browser.Events.onMouseMove (Decode.map (.offsetPos >> adjustCoordinates >> DragAt) Mouse.eventDecoder)
        , Browser.Events.onMouseUp (Decode.map (.offsetPos >> adjustCoordinates >> DragEnd) Mouse.eventDecoder)
        , Browser.Events.onAnimationFrame Tick
        ]
 
adjustCoordinates : ( Float, Float ) -> ( Float, Float )
adjustCoordinates ( x, y ) =
    ( x / 2 - 10, y / 2 )