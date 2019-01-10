import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, custom)
import Http
import Json.Decode as JD
import Json.Encode as JE
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

-- Rezepte

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

neueRezeptDetails : RezeptDetails
neueRezeptDetails =
    RezeptDetails "" "" -1 "" "" [] [(RezeptTeil -1 "Zutaten" [])]

-- Routes & URLs

routeParser : UP.Parser (Route -> a) a
routeParser =
    UP.oneOf
        [ UP.map (Liste ListLoading) UP.top
        , UP.map (\i -> Detail (DetailLoading i)) (UP.s "rezepte" </> UP.int)
        , UP.map (AddNew (AddNewEntering neueRezeptDetails)) (UP.s "rezepte" </> UP.s "neu")
        ]

routeFromUrl : Url.Url -> Route
routeFromUrl url =
    case UP.parse routeParser url of
        Nothing ->
            Unknown (Url.toString url)
        Just route ->
            route

changeRoute : Route -> Model -> ( Model, Cmd Msg )
changeRoute route model =
    let
        new_model = { model | currentRoute = route, navbarBurgerExpanded = False }
    in
        case route of
            Liste _ ->
                (new_model, getRezeptListe)
            Detail (DetailLoading key) ->
                (new_model, getRezeptDetails key)
            _ ->
                (new_model, Cmd.none)

changeUrl : Url.Url -> Model -> ( Model, Cmd Msg )
changeUrl url model =
    changeRoute (routeFromUrl url) model

-- Model

type ListRoute
    = ListLoading
    | ListLoaded (List RezeptKopf)
    | ListError String

type DetailRoute
    = DetailLoading Int
    | DetailOK RezeptDetails
    | DetailError String

type AddNewRoute
    = AddNewEntering RezeptDetails
    | AddNewSubmitted RezeptDetails
    | AddNewError RezeptDetails String

type Route
    = Initial
    | Liste ListRoute
    | Detail DetailRoute
    | AddNew AddNewRoute
    | Unknown String

type alias Model =
    { key : Nav.Key
    , navbarBurgerExpanded : Bool
    , currentRoute : Route
    }

init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    changeUrl url (Model key False Initial)

-- UPDATE

type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotRezeptListe (Result Http.Error (List RezeptKopf))
    | GotRezeptDetails (Result Http.Error RezeptDetails)
    | ToggleBurgerMenu
    | InputBezeichnung String
    | InputAnleitung String
    | SubmitRezeptNeu RezeptDetails
    | SubmitRezeptNeuDone (Result Http.Error String)
    | CancelRezeptNeu

submitRezeptNeu : RezeptDetails -> Model -> ( Model, Cmd Msg )
submitRezeptNeu rd model =
    let
        json = JE.object
            [ ( "Bezeichnung", JE.string rd.bezeichnung )
            , ( "Anleitung", JE.string rd.anleitung )
            ]
    in
        ( {model | currentRoute = AddNew (AddNewSubmitted rd)}
        , Http.request
            { method = "POST"
            , headers = []
            , url = "/api/rezepte"
            , body = Http.jsonBody json
            , expect = Http.expectJson SubmitRezeptNeuDone JD.string
            , timeout = Nothing
            , tracker = Nothing
        } )

formatError : Http.Error -> String
formatError error =
    case error of
        Http.BadUrl s -> "Bad URL: " ++ s
        Http.Timeout -> "Timeout"
        Http.NetworkError -> "Network Error"
        Http.BadStatus status -> "Bad Status: " ++ (String.fromInt status)
        Http.BadBody s -> "Bad Body: " ++ s

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
                    ({ model | currentRoute = Liste (ListLoaded rezeptListe) }, Cmd.none)
                Err s ->
                    ({ model | currentRoute = Liste (ListError (formatError s)) }, Cmd.none)

        GotRezeptDetails result ->
            case result of
                Ok rezept ->
                    ({ model | currentRoute = Detail (DetailOK rezept) }, Cmd.none)
                Err s ->
                    ({ model | currentRoute = Detail (DetailError (formatError s)) }, Cmd.none)

        ToggleBurgerMenu ->
            ({ model | navbarBurgerExpanded = not model.navbarBurgerExpanded }, Cmd.none)

        InputBezeichnung s ->
            case model.currentRoute of
                AddNew (AddNewEntering details) ->
                    ( { model | currentRoute = AddNew (AddNewEntering {details | bezeichnung = s}) }, Cmd.none)
                _ ->
                    (model, Cmd.none)

        InputAnleitung s ->
            case model.currentRoute of
                AddNew (AddNewEntering details) ->
                    ( { model | currentRoute = AddNew (AddNewEntering {details | anleitung = s}) }, Cmd.none)
                _ ->
                    (model, Cmd.none)

        SubmitRezeptNeu rd ->
            submitRezeptNeu rd model

        SubmitRezeptNeuDone result ->
            case result of
                Ok url ->
                    (model, Nav.replaceUrl model.key url)
                Err _ ->
                    (model, Cmd.none)

        CancelRezeptNeu ->
            (model, Nav.back model.key 1)

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none

-- VIEW

view : Model -> Browser.Document Msg
view model =
    case model.currentRoute of
        Initial ->
            { title = "Rezepte"
            , body =
                [ viewNavbar model
                ]
            }
        Liste listRoute ->
            { title = "Rezepte"
            , body =
                [ viewNavbar model
                , viewRezeptListe listRoute
                ]
            }
        Detail (DetailLoading i) ->
            { title = "Lade Rezept " ++ (String.fromInt i)
            , body =
                [ viewNavbar model
                , text "Wait ..."
                ]
            }
        Detail (DetailOK rezeptDetails) ->
            { title = rezeptDetails.bezeichnung
            , body =
                [ viewNavbar model
                , viewRezeptDetails rezeptDetails
                ]
            }
        Detail (DetailError msg) ->
            { title = "Fehler!"
            , body =
                [ viewNavbar model
                , text msg
                ]
            }
        AddNew addNewRoute ->
            { title = "Neu"
            , body =
                [ viewNavbar model
                , viewRezeptNeu addNewRoute
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
        showNewButton = case model.currentRoute of
            AddNew _ -> False
            _ -> True
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
                            (if showNewButton then
                                [ div [ class "buttons" ]
                                    [ a [ href "/rezepte/neu", class "button" ] [ text "Neu" ]
                                    ]
                                ]
                            else
                                [])
                        ]
                  ]
            ]

viewRezeptTag : String -> Html Msg
viewRezeptTag tag =
    span [ class "tag is-primary" ] [ text tag ]

viewRezeptElement : RezeptKopf -> Html Msg
viewRezeptElement rezept =
    div [ class "card rezept-element" ]
        [ div [ class "card-header" ]
            [ a [ href rezept.ui_link, class "card-header-title has-text-link" ]
                [ text rezept.bezeichnung ] ]
        , div [ class "card-content" ]
            [ div [ class "tags" ] (List.map viewRezeptTag rezept.tags) ]
        ]

viewRezeptListe : ListRoute -> Html Msg
viewRezeptListe listeRoute =
    case listeRoute of
        ListLoading ->
            text "Wait ..."
        ListLoaded rezeptListe ->
            section [class "section"]
                [ div [ class "container is-widescreen rezept-liste" ]
                    (List.map viewRezeptElement rezeptListe) ]
        ListError msg ->
            text ("Oops: " ++ msg)

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

viewRezeptDetails : RezeptDetails -> Html Msg
viewRezeptDetails rezept =
    section [ class "section" ]
        [ h1 [ class "title" ] [ text rezept.bezeichnung ]
        , div [ class "tags" ] (List.map viewRezeptTag rezept.tags)
        , div [ class "columns" ]
            [ div [ class "column" ]
                (List.map viewRezeptTeil rezept.rezept_teile)
            , div [ class "column is-two-thirds" ]
                [ div [ class "content" ] [ text rezept.anleitung ] ]
            ]
        ]

viewRezeptNeu : AddNewRoute -> Html Msg
viewRezeptNeu addNewRoute =
    case addNewRoute of
        AddNewEntering rd ->
            viewRezeptForm rd
        AddNewSubmitted rd ->
            viewRezeptForm rd
        AddNewError rd _ ->
            viewRezeptForm rd

viewRezeptForm : RezeptDetails -> Html Msg
viewRezeptForm rd =
    Html.form [ class "section" ]
        [ div [ class "field" ]
            [ label [ class "label", for "bezeichnung" ] [ text "Bezeichnung" ]
            , div [ class "control" ]
                [ input
                    [ id "bezeichnung"
                    , class "input"
                    , type_ "text"
                    , value rd.bezeichnung
                    , placeholder "Rezeptbezeichnung"
                    , onInput InputBezeichnung
                    ]
                    []
                ]
            ]
        , div [ class "field" ]
            [ label [ class "label", for "anleitung" ] [ text "Anleitung" ]
            , div [ class "control" ]
                [ textarea
                    [ id "anleitung"
                    , class "textarea"
                    , value rd.anleitung
                    , placeholder "Anleitung"
                    , attribute "rows" "5"
                    , onInput InputAnleitung
                    ]
                    []
                ]
            ]
        , div [ class "field is-grouped" ]
            [ div [ class "control" ]
                [ button [ class "button is-primary", type_ "button", onClick (SubmitRezeptNeu rd) ]
                    [ text "Speichern" ] ]
            , div [ class "control" ]
                [ button [ class "button is-danger", type_ "button", onClick CancelRezeptNeu ]
                    [ text "Abbrechen" ] ]
            ]
        ]

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
