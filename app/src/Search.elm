module Search exposing (Msg, Model, view, update, init)

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


view : Model -> Html Msg
view model =
    H.div
        []
        [ view_search_box
        , view_search_result model.search_result
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
        [ HA.class "error-message-row"  ]
        [ "error[E" ++ code ++ "]: " ++ message |> H.text ]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateQuery query -> ( { model | query = query, search_result = Loading }, getSearchResult query )
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
        ( Decode.field "code" Decode.string )
        ( Decode.field "message" Decode.string )

init : ( Model, Cmd Msg )
init = ( { query = "", search_result = Loading } , getSearchResult "" )