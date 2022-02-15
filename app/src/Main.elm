module Main exposing (..)

{-| The Main module contains the main function which serves
    as the entry point for the client. It responsible for
    handling page navigation and delegating to the other modules.
-}

import Browser exposing (Document, UrlRequest(..))
import Browser.Navigation as Nav
import Url exposing (Url)
import Url.Parser exposing (Parser)
import Html as H exposing (Html)
import Html.Attributes as HA
import Search
import Analyze
import Explore

{-| The Model type represents the current state of the application. The main
    module uses this to know which page to render.
-}
type alias Model =
    { page : Page
    , navKey : Nav.Key
    }

type Page
    = Home
    | Search Search.Model
    | Analyze Analyze.Model
    | Explore Explore.Model
    | NotFound

{-| The Msg type represents messages to the update function describing how
    you want the model to change or how the application should access the
    outside world. The main module mostly handles correctly dispatching
    each page's Msg's and navigation events from the outside world.
-}
type Msg
    = SearchMsg Search.Msg
    | AnalyzeMsg Analyze.Msg
    | ExploreMsg Explore.Msg
    | ClickedUrl UrlRequest
    | ChangedUrl Url

{-| Elm programs follow The Elm Architecture (TEA). It is composed of
    two types (Model and Msg) and four functions (init, view, update,
    and subscriptions). Like Haskell, Elm requires that all functions
    are pure (have no side effects). TEA provides a way of building
    web applications in a reasonable way with that restriction.
-}
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

{-| The init function gives the initial state of the application. In
    this case the page defaults to NotFound and looks up the appropriate
    page based on the URL.
-}
init : () -> Url -> Nav.Key -> ( Model, Cmd Msg)
init _ url navKey =
    selectPage { navKey = navKey, page = NotFound } url

{-| The view function renders the model which is purely data as Html.
    The main purpose of the Main module is to delegate to the view
    functions of the other modules when that page is selected.
-}
view : Model -> Document Msg
view model =
    { title = "Error Explorer"
    , body =
        [ viewNavigationBar model
        , viewPage model.page
        ]
    }

viewNavigationBar : Model -> Html Msg
viewNavigationBar model =
    H.ul
        [ HA.class "navbar" ]
        [ H.li [] [ H.a [ HA.href "/" ] [ H.text "Home" ] ]
        , H.li [] [ H.a [ HA.href "/search" ] [ H.text "Search" ] ]
        , H.li [] [ H.a [ HA.href "/analyze" ] [ H.text "Analyze" ] ]
        , H.li [] [ H.a [ HA.href "/explore" ] [ H.text "Explore" ] ]
        ]

viewPage : Page -> Html Msg
viewPage page =
    case page of
        Home -> H.text "TODO!"
        Search searchModel -> Search.view searchModel |> H.map SearchMsg
        Analyze analyzeModel -> Analyze.view analyzeModel |> H.map AnalyzeMsg
        Explore exploreModel -> Explore.view exploreModel |> H.map ExploreMsg
        NotFound -> H.text "404: Page not found"

{-| The update function processes messages and returns what
    the new model should be, as well as any Cmd's. Cmd's are
    how Elm represents interacting with the outside (impure) world
    (e.g. HTTP requests or randomness).
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( SearchMsg searchMsg, Search searchModel ) ->
            Search.update searchMsg searchModel
                |> mapSearchUpdate model
        ( ExploreMsg exploreMsg, Explore exploreModel ) ->
            Explore.update exploreMsg exploreModel
                |> mapExploreUpdate model
        ( AnalyzeMsg analyzeMsg, Analyze analyzeModel ) ->
            Analyze.update analyzeMsg analyzeModel
                |> mapAnalyzeUpdate model
        ( ClickedUrl urlRequest, _ ) ->
            case urlRequest of
                Internal url -> selectPage model url
                External url ->
                    ( model, Nav.load url )
        _ -> ( model, Cmd.none )
                
selectPage : Model -> Url -> ( Model, Cmd Msg )
selectPage model url =
    let ( newModel, cmd ) =
            Url.Parser.parse (pageParser model) url
                |> Maybe.withDefault ( { model | page = NotFound }, Cmd.none)
    in 
        ( newModel, Cmd.batch [ cmd, Nav.pushUrl model.navKey (Url.toString url) ] )

pageParser : Model -> Parser ( ( Model, Cmd Msg ) -> a ) a
pageParser model =
    Url.Parser.oneOf
        [ Url.Parser.map ( { model | page = Home }, Cmd.none ) (Url.Parser.top)
        , Url.Parser.map (mapSearchUpdate model Search.init) (Url.Parser.s "search")
        , Url.Parser.map (mapAnalyzeUpdate model Analyze.init) (Url.Parser.s "analyze")
        , Url.Parser.map (mapExploreUpdate model Explore.init) (Url.Parser.s "explore")
        ]

mapSearchUpdate : Model -> ( Search.Model, Cmd Search.Msg ) -> ( Model, Cmd Msg )
mapSearchUpdate model ( searchModel, searchMsg ) =
    ( { model | page = Search searchModel }, Cmd.map SearchMsg searchMsg )

mapAnalyzeUpdate : Model -> ( Analyze.Model, Cmd Analyze.Msg ) -> ( Model, Cmd Msg )
mapAnalyzeUpdate model ( analyzeModel, analyzeMsg ) =
    ( { model | page = Analyze analyzeModel }, Cmd.map AnalyzeMsg analyzeMsg )

mapExploreUpdate : Model -> ( Explore.Model, Cmd Explore.Msg ) -> ( Model, Cmd Msg )
mapExploreUpdate model ( exploreModel, exploreMsg ) =
    ( { model | page = Explore exploreModel }, Cmd.map ExploreMsg exploreMsg )

{-| Subscriptions are how you request that the outside world
    send messages to the update function when an event happens.
    In this case, only the explore page uses this feature.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    case model.page of
        Explore e -> Explore.subscriptions e |> Sub.map ExploreMsg 
        _ -> Sub.none
