import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as JD
import Url
import Url.Parser as UP exposing ((</>))

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
    }

type alias RezeptDetails =
        { api_link : String
        , ui_link : String
        , rezept_id : Int
        , bezeichnung : String
        , anleitung : String
        }

-- Model

type alias Model =
    { key : Nav.Key
    , current_route : Route
    , rezeptListe : Status (List RezeptKopf)
    , rezept : Status RezeptDetails
    }

init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    changeUrl url (Model key Home Initial Initial)

-- UPDATE

type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotRezeptListe (Result Http.Error (List RezeptKopf))
    | GotRezeptDetails (Result Http.Error RezeptDetails)

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
                [ viewRezeptListe model.rezeptListe
                ]
            }
        Detail key ->
            { title = "Rezept " ++ (String.fromInt key)
            , body =
                [ viewRezeptDetails model.rezept
                ]
            }
        Unknown msg ->
            { title = "Fehler!"
            , body =
                [ text ("Hoppala: " ++ msg)
                ]
            }

viewRezeptElement : RezeptKopf -> Html msg
viewRezeptElement rezept =
    div [class "rezept-element"]
        [ a [ href rezept.ui_link ] [ text rezept.bezeichnung ]
        ]

viewRezeptListe : Status (List RezeptKopf) -> Html Msg
viewRezeptListe rezeptListeStatus =
    case rezeptListeStatus of
        Initial ->
            text "Initial"
        Loading ->
            text "Wait ..."
        Success rezeptListe ->
            div [class "rezept-liste"]
                (List.map viewRezeptElement rezeptListe)
        Failure ->
            text "Oops!"

viewRezeptDetails : Status RezeptDetails -> Html Msg
viewRezeptDetails rezeptDetailsStatus =
    case rezeptDetailsStatus of
        Initial ->
            text "Initial"
        Loading ->
            text "Wait ..."
        Success rezept ->
            div [class "rezept-details"]
                [ h3 [] [ text rezept.bezeichnung ]
                , p [] [ text rezept.anleitung ]
                , a [ href "/" ] [ text "Home" ]
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
    JD.map4 RezeptKopf
        (JD.field "APILink" JD.string)
        (JD.field "UILink" JD.string)
        (JD.field "RezeptID" JD.int)
        (JD.field "Bezeichnung" JD.string)

rezeptListeDecoder : JD.Decoder (List RezeptKopf)
rezeptListeDecoder =
    JD.list rezeptKopfDecoder

getRezeptDetails : Int -> Cmd Msg
getRezeptDetails key =
    Http.get
        { url = "/api/rezepte/" ++ (String.fromInt key)
        , expect = Http.expectJson GotRezeptDetails rezeptDetailsDecoder
        }

rezeptDetailsDecoder : JD.Decoder RezeptDetails
rezeptDetailsDecoder =
    JD.map5 RezeptDetails
        (JD.field "APILink" JD.string)
        (JD.field "UILink" JD.string)
        (JD.field "RezeptID" JD.int)
        (JD.field "Bezeichnung" JD.string)
        (JD.field "Anleitung" JD.string)
