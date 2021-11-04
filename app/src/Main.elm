module Main exposing (..)

import Browser exposing (Document)
import Chart as C
import Chart.Attributes as CA
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import Http
import Json.Decode as Decode exposing (Decoder)

type alias ErrorMessage =
    { code : String
    , message : String
    }

type SearchResult
    = Loading
    | Value (List ErrorMessage)
    | SearchError

type alias Model =
    { query : String
    , search_result : SearchResult
    }

type Msg
    = UpdateQuery String
    | GotSearchResult (Result Http.Error (List ErrorMessage))

main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

init : () -> ( Model, Cmd Msg )
init _ = ( { query = "", search_result = Loading } , getSearchResult "" )

type alias Data = { x : String, y : Float }

data : List Data
data =
    [ { x = "E0277", y = 16 }
    , { x = "E0308", y = 10 }
    , { x = "E0599", y = 39 }
    , { x = "E0609", y = 3 }
    ]

view : Model -> Document Msg
view model =
    { title = "Error Explorer"
    , body =
        [ view_search model.search_result
        ]
    }
view_graph : Html Msg
view_graph =
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

view_search : SearchResult -> Html Msg
view_search result =
    H.div
        []
        [ view_search_box
        , view_search_result result
        ]
    
view_search_box : Html Msg
view_search_box =
    H.input
        [ HA.type_ "text"
        , HE.onInput UpdateQuery
        ]
        []

view_search_result : SearchResult -> Html Msg
view_search_result result =
    case result of
        Loading -> H.text "Loading..."
        Value messages -> H.table [] (List.map view_error_message messages)
        SearchError -> H.text "Error loading results..."
        
view_error_message : ErrorMessage -> Html Msg
view_error_message { message, code } =
    H.tr
        [ HA.style "white-space" "pre-wrap"
        , HA.style "font-family" "\"Lucida Console\""
        ]
        [ "error[E" ++ code ++ "]: " ++ message |> H.text ]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateQuery query -> ( { model | query = query, search_result = Loading }, getSearchResult query)
        GotSearchResult (Ok result) -> ( { model | search_result = Value result }, Cmd.none )
        GotSearchResult (Err _) -> ( { model | search_result = SearchError }, Cmd.none )

getSearchResult : String -> Cmd Msg
getSearchResult query =
    Http.get
        { url = "api/search/" ++ query
        , expect = Http.expectJson GotSearchResult (Decode.list errorMessageDecoder)
        }

errorMessageDecoder : Decoder ErrorMessage
errorMessageDecoder =
    Decode.map2 ErrorMessage
        (Decode.field "code" Decode.string)
        (Decode.field "message" Decode.string)

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none