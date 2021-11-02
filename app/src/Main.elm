module Main exposing (..)

import Browser exposing (Document)
import Chart as C
import Chart.Attributes as CA
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import Http

type SearchResult
    = Loading
    | Value String
    | SearchError

type alias Model =
    { query : String
    , search_result : SearchResult
    }

type Msg
    = UpdateQuery String
    | GotSearchResult (Result Http.Error String)

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
        Value messages -> H.text messages
        SearchError -> H.text "Error loading results..."
        


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateQuery query -> ( { model | query = query, search_result = Loading }, getSearchResult query)
        GotSearchResult (Ok result) -> ( { model | search_result = Value result }, Cmd.none )
        GotSearchResult _ -> ( { model | search_result = SearchError }, Cmd.none )

getSearchResult : String -> Cmd Msg
getSearchResult query =
    Http.get
        { url = "api/search/" ++ query
        , expect = Http.expectString GotSearchResult
        }

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none