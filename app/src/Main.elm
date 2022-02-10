module Main exposing (..)

import Browser exposing (Document, UrlRequest(..))
import Browser.Navigation as Nav
import Url exposing (Url)
import Url.Parser exposing (Parser)
import Html as H exposing (Html)
import Html.Attributes as HA
import Search
import Analyze
import Explore

type alias Model =
    { page : Page
    , nav_key : Nav.Key
    }

type Page
    = Home
    | Search Search.Model
    | Analyze
    | Explore Explore.Model
    | NotFound

type Msg
    = SearchMsg Search.Msg
    | AnalyzeMsg Analyze.Msg
    | ExploreMsg Explore.Msg
    | ClickedUrl UrlRequest
    | ChangedUrl Url

main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = ClickedUrl
        , onUrlChange = ChangedUrl
        }

init : () -> Url -> Nav.Key -> ( Model, Cmd Msg)
init _ url nav_key =
    select_page { nav_key = nav_key, page = NotFound } url

view : Model -> Document Msg
view model =
    { title = "Error Explorer"
    , body =
        [ view_navigation_bar model
        , view_page model.page
        ]
    }

view_navigation_bar : Model -> Html Msg
view_navigation_bar model =
    H.ul
        [ HA.class "navbar" ]
        [ H.li [] [ H.a [ HA.href "/" ] [ H.text "Home" ] ]
        , H.li [] [ H.a [ HA.href "/search" ] [ H.text "Search" ] ]
        , H.li [] [ H.a [ HA.href "/analyze" ] [ H.text "Analyze" ] ]
        , H.li [] [ H.a [ HA.href "/explore" ] [ H.text "Explore" ] ]
        ]

view_page : Page -> Html Msg
view_page page =
    case page of
        Home -> H.text "TODO!"
        Search search_model -> Search.view search_model |> H.map SearchMsg
        Analyze -> Analyze.view |> H.map AnalyzeMsg
        Explore explore_model -> Explore.view explore_model |> H.map ExploreMsg
        NotFound -> H.text "404: Page not found"

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( SearchMsg search_msg, Search search_model ) ->
            Search.update search_msg search_model
                |> map_search_update model
        ( ExploreMsg explore_msg, Explore explore_model ) ->
            Explore.update explore_msg explore_model
                |> map_explore_update model
        ( ClickedUrl url_request, _ ) ->
            case url_request of
                Internal url -> select_page model url
                External url ->
                    ( model, Nav.load url )
        _ -> ( model, Cmd.none )
                
select_page : Model -> Url -> ( Model, Cmd Msg )
select_page model url =
    let ( new_model, cmd ) =
            Url.Parser.parse (page_parser model) url
                |> Maybe.withDefault ( { model | page = NotFound }, Cmd.none)
    in 
        ( new_model, Cmd.batch [ cmd, Nav.pushUrl model.nav_key (Url.toString url) ] )

page_parser : Model -> Parser ( ( Model, Cmd Msg ) -> a ) a
page_parser model =
    Url.Parser.oneOf
        [ Url.Parser.map ( { model | page = Home }, Cmd.none ) (Url.Parser.top)
        , Url.Parser.map (map_search_update model Search.init) (Url.Parser.s "search")
        , Url.Parser.map ( { model | page = Analyze }, Cmd.none ) (Url.Parser.s "analyze")
        , Url.Parser.map (map_explore_update model Explore.init) (Url.Parser.s "explore")
        ]

map_search_update : Model -> ( Search.Model, Cmd Search.Msg ) -> ( Model, Cmd Msg )
map_search_update model ( search_model, search_msg ) =
    ( { model | page = Search search_model }, Cmd.map SearchMsg search_msg )

map_explore_update : Model -> ( Explore.Model, Cmd Explore.Msg ) -> ( Model, Cmd Msg )
map_explore_update model ( explore_model, explore_msg ) =
    ( { model | page = Explore explore_model }, Cmd.map ExploreMsg explore_msg )

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
