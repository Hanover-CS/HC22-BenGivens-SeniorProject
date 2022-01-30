module Main exposing (..)

import Browser exposing (Document, UrlRequest(..))
import Browser.Navigation as Nav
import Url exposing (Url)
import Url.Parser exposing (Parser)
import Html as H exposing (Html)
import Html.Attributes as HA
import Search

type alias Model =
    { page : Page
    , nav_key : Nav.Key
    }

type Page
    = Home
    | Search Search.Model
    | Explore
    | Analyze
    | NotFound

type Msg
    = SearchMsg Search.Msg
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
        Explore -> H.text "TODO!"
        Analyze -> H.text "TODO!"
        NotFound -> H.text "404: Page not found"

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( SearchMsg search_msg, Search search_model ) ->
            Search.update search_msg search_model
                |> map_search_update model
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
        [ Url.Parser.map ( { model | page = Home }, Nav.pushUrl model.nav_key "/" ) (Url.Parser.top)
        , Url.Parser.map (map_search_update model Search.init) (Url.Parser.s "search")
        ]

map_search_update : Model -> ( Search.Model, Cmd Search.Msg ) -> ( Model, Cmd Msg )
map_search_update model ( search_model, search_msg ) =
    ( { model | page = Search search_model }, Cmd.map SearchMsg search_msg )

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
