import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, custom)
import Http
import Json.Decode as JD
import Url
import Url.Parser as UP exposing ((</>))
import Attributes exposing (..)

-- MAIN

main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }

-- Routes

type Route
    = Home
    | Detail Int
    | Unknown String

routeParser : UP.Parser (Route -> a) a
routeParser =
    UP.oneOf
        [ UP.map Home    UP.top
        , UP.map Detail  (UP.s "rezepte" </> UP.int)
        ]

routeFromUrl : Url.Url -> Route
routeFromUrl url =
    case UP.parse routeParser url of
        Nothing ->
            Unknown (Url.toString url)
        Just route ->
            route

-- Rezepte

type Status a = Initial | Loading | Success a | Failure

type alias RezeptKopf =
    { api_link : String
    , ui_link : String
    , rezept_id : Int
    , bezeichnung : String
    , tags : List String
    }

type alias RezeptZutat =
    { rezept_zutat_id : Int
    , zutat : String
    , menge : Float
    , mengeneinheit : String
    , bemerkung : String
    }

type alias RezeptTeil =
    { rezept_teil_id : Int
    , bezeichnung : String
    , zutaten : List RezeptZutat
    }

type alias RezeptDetails =
    { api_link : String
    , ui_link : String
    , rezept_id : Int
    , bezeichnung : String
    , anleitung : String
    , tags : List String
    , rezept_teile : List RezeptTeil
    }

-- Model

type alias Model =
    { key : Nav.Key
    , current_route : Route
    , navbarBurgerExpanded : Bool
    , rezeptListe : Status (List RezeptKopf)
    , rezept : Status RezeptDetails
    }

init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    changeUrl url (Model key Home False Initial Initial)

-- UPDATE

type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotRezeptListe (Result Http.Error (List RezeptKopf))
    | GotRezeptDetails (Result Http.Error RezeptDetails)
    | ToggleBurgerMenu

changeRoute : Route -> Model -> ( Model, Cmd Msg )
changeRoute route model =
    let
        cmd = case route of
            Home ->
                getRezeptListe
            Detail key ->
                getRezeptDetails key
            Unknown _ ->
                Cmd.none
    in
        ( { model | current_route = route }, cmd )

changeUrl : Url.Url -> Model -> ( Model, Cmd Msg )
changeUrl url model =
    changeRoute (routeFromUrl url) model

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )
                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            changeUrl url model

        GotRezeptListe result ->
            case result of
                Ok rezeptListe ->
                    ({ model | rezeptListe = Success rezeptListe }, Cmd.none)
                Err _ ->
                    ({ model | rezeptListe = Failure }, Cmd.none)

        GotRezeptDetails result ->
            case result of
                Ok rezept ->
                    ({ model | rezept = Success rezept }, Cmd.none)
                Err _ ->
                    ({ model | rezept = Failure }, Cmd.none)

        ToggleBurgerMenu ->
            ({ model | navbarBurgerExpanded = not model.navbarBurgerExpanded }, Cmd.none)

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none

-- VIEW

view : Model -> Browser.Document Msg
view model =
    case model.current_route of
        Home ->
            { title = "Rezepte"
            , body =
                [ viewNavbar model
                , viewRezeptListe model.rezeptListe
                ]
            }
        Detail key ->
            { title = "Rezept " ++ (String.fromInt key)
            , body =
                [ viewNavbar model
                , viewRezeptDetails model.rezept
                ]
            }
        Unknown msg ->
            { title = "Fehler!"
            , body =
                [ viewNavbar model
                , text ("Hoppala: " ++ msg)
                ]
            }

onClickSimply : Msg -> Attribute Msg
onClickSimply msg =
    custom "click" (JD.map alwaysStopAndPreventDefault (JD.succeed msg))

alwaysStopAndPreventDefault : Msg -> { message : Msg, stopPropagation : Bool, preventDefault : Bool }
alwaysStopAndPreventDefault msg =
      { message = msg, stopPropagation = True, preventDefault = True }

viewNavbar : Model -> Html Msg
viewNavbar model =
    let
        isActive = case model.navbarBurgerExpanded of
            True -> " is-active"
            False -> ""
    in
        nav [ class "navbar is-fixed-top is-info", role "navigation", ariaLabel "main navigation"]
            [ div [class "navbar-brand"]
                  [ a [ href "/", class "navbar-item" ] [ text "Home" ]
                  , a [ role "button"
                      , class ("navbar-burger burger" ++ isActive)
                      , ariaLabel "menu"
                      , ariaExpanded "false"
                      , href "#"
                      , onClick ToggleBurgerMenu
                      ]
                      [ span [ ariaHidden "true" ] []
                      , span [ ariaHidden "true" ] []
                      , span [ ariaHidden "true" ] []
                      ]
                  ]
            , div [ class ("navbar-menu" ++ isActive) ]
                  [ div [ class "navbar-end" ]
                        [ div [ class "navbar-item" ]
                              [ div [ class "buttons" ]
                                    [ button [ class "button" ] [ text "Neu" ]
                                    ]
                              ]
                        ]
                  ]
            ]

viewRezeptTag : String -> Html Msg
viewRezeptTag tag =
    span [ class "tag is-primary" ] [ text tag ]

viewRezeptElement : RezeptKopf -> Html Msg
viewRezeptElement rezept =
    div [ class "card rezept-element" ]
        [ header [ class "card-header" ]
            [ a [ href rezept.ui_link, class "card-header-title has-text-link" ]
                [ text rezept.bezeichnung ] ]
        , div [ class "card-content" ]
            [ div [ class "tags" ] (List.map viewRezeptTag rezept.tags) ]
        ]

viewRezeptListe : Status (List RezeptKopf) -> Html Msg
viewRezeptListe rezeptListeStatus =
    case rezeptListeStatus of
        Initial ->
            text "Initial"
        Loading ->
            text "Wait ..."
        Success rezeptListe ->
            section [class "section"]
                [ div [ class "container is-widescreen rezept-liste" ]
                    (List.map viewRezeptElement rezeptListe) ]
        Failure ->
            text "Oops!"

viewRezeptZutat : RezeptZutat -> Html Msg
viewRezeptZutat zutat =
    li []
        [ text (String.fromFloat zutat.menge)
        , text " "
        , text zutat.mengeneinheit
        , text " "
        , text zutat.zutat
        ]

viewRezeptTeil : RezeptTeil -> Html Msg
viewRezeptTeil teil =
    div [ class "box content" ]
        [ h4 [ class "title is-4" ] [ text teil.bezeichnung ]
        , ul [] (List.map viewRezeptZutat teil.zutaten)
        ]

viewRezeptDetails : Status RezeptDetails -> Html Msg
viewRezeptDetails rezeptDetailsStatus =
    case rezeptDetailsStatus of
        Initial ->
            text "Initial"
        Loading ->
            text "Wait ..."
        Success rezept ->
            section [class "section"]
                [ h1 [ class "title" ] [ text rezept.bezeichnung ]
                , div [ class "tags" ] (List.map viewRezeptTag rezept.tags)
                , div [ class "columns" ]
                    [ div [ class "column" ]
                        (List.map viewRezeptTeil rezept.rezept_teile)
                    , div [ class "column is-two-thirds" ]
                        [ div [ class "content" ] [ text rezept.anleitung ] ]
                    ]
                ]
        Failure ->
            text "Oops!"

-- HTTP

getRezeptListe : Cmd Msg
getRezeptListe =
    Http.get
        { url = "/api/rezepte"
        , expect = Http.expectJson GotRezeptListe rezeptListeDecoder
        }

rezeptKopfDecoder : JD.Decoder RezeptKopf
rezeptKopfDecoder =
    JD.map5 RezeptKopf
        (JD.field "APILink" JD.string)
        (JD.field "UILink" JD.string)
        (JD.field "RezeptID" JD.int)
        (JD.field "Bezeichnung" JD.string)
        (JD.field "Tags" (JD.list JD.string))

rezeptListeDecoder : JD.Decoder (List RezeptKopf)
rezeptListeDecoder =
    JD.list rezeptKopfDecoder

getRezeptDetails : Int -> Cmd Msg
getRezeptDetails key =
    Http.get
        { url = "/api/rezepte/" ++ (String.fromInt key)
        , expect = Http.expectJson GotRezeptDetails rezeptDetailsDecoder
        }

rezeptZutatDecoder : JD.Decoder RezeptZutat
rezeptZutatDecoder =
    JD.map5 RezeptZutat
        (JD.field "RezeptZutatID" JD.int)
        (JD.field "Zutat" JD.string)
        (JD.field "Menge" JD.float)
        (JD.field "Mengeneinheit" JD.string)
        (JD.field "Bemerkung" JD.string)

rezeptTeilDecoder : JD.Decoder RezeptTeil
rezeptTeilDecoder =
    JD.map3 RezeptTeil
        (JD.field "RezeptTeilID" JD.int)
        (JD.field "Bezeichnung" JD.string)
        (JD.field "Zutaten" (JD.list rezeptZutatDecoder))

rezeptDetailsDecoder : JD.Decoder RezeptDetails
rezeptDetailsDecoder =
    JD.map7 RezeptDetails
        (JD.field "APILink" JD.string)
        (JD.field "UILink" JD.string)
        (JD.field "RezeptID" JD.int)
        (JD.field "Bezeichnung" JD.string)
        (JD.field "Anleitung" JD.string)
        (JD.field "Tags" (JD.list JD.string))
        (JD.field "RezeptTeile" (JD.list rezeptTeilDecoder))
