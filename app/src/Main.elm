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
    , navKey : Nav.Key
    }

type Page
    = Home
    | Search Search.Model
    | Analyze Analyze.Model
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
init _ url navKey =
    selectPage { navKey = navKey, page = NotFound } url

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

subscriptions : Model -> Sub Msg
subscriptions model =
    case model.page of
        Explore e -> Explore.subscriptions e |> Sub.map ExploreMsg 
        _ -> Sub.none
