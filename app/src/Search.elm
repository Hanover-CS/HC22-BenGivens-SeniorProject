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

type SortMode
    = Relevance
    | Length

type alias Model =
    { query : String
    , sortMode : SortMode
    , searchResult : SearchResult
    }

type Msg
    = UpdateQuery String
    | UpdateSortMode (Maybe SortMode)
    | GotSearchResult (Result Http.Error (List ErrorMessage))

view : Model -> Html Msg
view model =
    H.div
        []
        [ viewSearchBox
        , viewSortModeBox
        , viewSearchResult model.searchResult model.sortMode
        ]
    
viewSearchBox : Html Msg
viewSearchBox =
    H.input
        [ HA.type_ "text"
        , HE.onInput UpdateQuery
        ]
        []

viewSortModeBox : Html Msg
viewSortModeBox =
    H.select
        [ HE.onInput (parseSortMode >> UpdateSortMode) ]
        [ H.option [ HA.value "Relevance" ] [ H.text "Relevance" ]
        , H.option [ HA.value "Length" ] [ H.text "Length" ]
        ]

parseSortMode : String -> Maybe SortMode
parseSortMode mode =
    case mode of
        "Relevance" -> Just Relevance
        "Length" -> Just Length
        _ -> Nothing

viewSearchResult : SearchResult -> SortMode -> Html Msg
viewSearchResult result sortMode =
    case result of
        Loading -> H.text "Loading..."
        Value messages -> H.table [] (messages |> sort sortMode |> List.map viewErrorMessage )
        SearchError -> H.text "Error loading results..."
        
sort : SortMode -> List ErrorMessage -> List ErrorMessage
sort sortMode messages =
    case sortMode of
        Relevance -> messages
        Length -> List.sortBy (.message >> String.words >> String.concat >> String.length) messages
    
viewErrorMessage : ErrorMessage -> Html Msg
viewErrorMessage { message, code } =
    H.tr
        [ HA.class "error-message-row"  ]
        [ "error[E" ++ code ++ "]: " ++ message |> H.text ]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateQuery query -> ( { model | query = query, searchResult = Loading }, getSearchResult query )
        UpdateSortMode (Just mode) -> ( { model | sortMode = mode }, Cmd.none )
        UpdateSortMode Nothing -> ( { model | sortMode = Relevance }, Cmd.none )
        GotSearchResult (Ok result) -> ( { model | searchResult = Value result }, Cmd.none )
        GotSearchResult (Err _) -> ( { model | searchResult = SearchError }, Cmd.none )

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
init = ( { query = "", searchResult = Loading, sortMode = Relevance } , getSearchResult "" )