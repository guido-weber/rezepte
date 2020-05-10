module Main exposing (..)

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

neuerRezeptTeil : RezeptTeil
neuerRezeptTeil =
    (RezeptTeil -1 "Zutaten" [ (RezeptZutat -1 "" 0 "" "") ])

neueRezeptDetails : RezeptDetails
neueRezeptDetails =
    RezeptDetails "" "" -1 "" "" [] [ neuerRezeptTeil ]

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
        new_model = { model | currentRoute = route }
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
    , currentRoute : Route
    }

init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    changeUrl url (Model key Initial)

-- UPDATE

type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotRezeptListe (Result Http.Error (List RezeptKopf))
    | GotRezeptDetails (Result Http.Error RezeptDetails)
    | InputBezeichnung String
    | InputAnleitung String
    | AddRezeptTeil
    | InputTeilBezeichnung Int String
    | InputZutat Int Int String
    | InputMengeneinheit Int Int String
    | InputMenge Int Int String
    | InputBemerkung Int Int String
    | SubmitRezeptNeu RezeptDetails
    | SubmitRezeptNeuDone RezeptDetails (Result Http.Error String)
    | CancelRezeptNeu

addRezeptTeil : Model -> ( Model, Cmd Msg )
addRezeptTeil model =
    case model.currentRoute of
        AddNew (AddNewEntering details) ->
            let
                neu = (List.append details.rezept_teile [ neuerRezeptTeil ])
            in
                ( { model | currentRoute = AddNew (AddNewEntering {details | rezept_teile = neu}) }
                , Cmd.none
                )
        _ ->
            (model, Cmd.none)

replaceTeil : RezeptDetails -> Int -> (RezeptTeil -> RezeptTeil) -> RezeptDetails
replaceTeil details idx fct =
    let
        neu = (List.indexedMap
                (\n -> \t -> if n == idx then (fct t) else t)
                details.rezept_teile)
    in
        {details | rezept_teile = neu}

inputTeilBezeichnung : Model -> Int -> String -> ( Model, Cmd Msg )
inputTeilBezeichnung model teilIdx s =
    case model.currentRoute of
        AddNew (AddNewEntering details) ->
            let
                neu = replaceTeil details teilIdx (\t -> { t | bezeichnung = s })
            in
                ( { model | currentRoute = AddNew (AddNewEntering neu) }
                , Cmd.none
                )
        _ ->
            (model, Cmd.none)

replaceZutat : RezeptTeil -> Int -> (RezeptZutat -> RezeptZutat) -> RezeptTeil
replaceZutat teil idx fct =
    let
        replaced = (List.indexedMap
                (\n -> \z -> if n == idx then (fct z) else z)
                teil.zutaten)
        neu = if (List.length teil.zutaten) == (idx + 1)
            then (List.append replaced [ (RezeptZutat -1 "" 0 "" "") ])
            else replaced
    in
        {teil | zutaten = neu}

inputZutat : Model -> Int -> Int -> (RezeptZutat -> RezeptZutat) -> ( Model, Cmd Msg )
inputZutat model teilIdx zutatIdx fct =
    case model.currentRoute of
        AddNew (AddNewEntering details) ->
            let
                neu = replaceTeil details teilIdx (\t -> replaceZutat t zutatIdx fct)
            in
                ( { model | currentRoute = AddNew (AddNewEntering neu) }
                , Cmd.none
                )
        _ ->
            (model, Cmd.none)

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

        AddRezeptTeil ->
            addRezeptTeil model

        InputTeilBezeichnung teilIdx s ->
            inputTeilBezeichnung model teilIdx s

        InputZutat teilIdx zutatIdx s ->
            inputZutat model teilIdx zutatIdx (\z -> { z | zutat = s })

        InputMengeneinheit teilIdx zutatIdx s ->
            inputZutat model teilIdx zutatIdx (\z -> { z | mengeneinheit = s })

        InputBemerkung teilIdx zutatIdx s ->
            inputZutat model teilIdx zutatIdx (\z -> { z | bemerkung = s })

        InputMenge teilIdx zutatIdx s ->
            case (String.toFloat s) of
                Just f ->
                    inputZutat model teilIdx zutatIdx (\z -> { z | menge = f })
                Nothing ->
                    (model, Cmd.none)

        SubmitRezeptNeu rd ->
            submitRezeptNeu rd model

        SubmitRezeptNeuDone rd result ->
            case result of
                Ok url ->
                    (model, Nav.replaceUrl model.key url)
                Err s ->
                    ({ model | currentRoute = AddNew (AddNewError rd (formatError s)) }, Cmd.none)

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
        showNewButton = case model.currentRoute of
            AddNew _ -> False
            _ -> True
    in
        nav [ class "navbar is-fixed-top is-info", role "navigation", ariaLabel "main navigation"]
            [ div [class "navbar-brand"]
                  [ a [ href "/", class "navbar-item" ] [ text "Home" ]
                  , div [ class "buttons" ]
                        (if showNewButton then
                            [ a [ href "/rezepte/neu", class "button" ] [ text "Neu" ] ]
                        else
                            [])
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
    let
        menge = if zutat.menge == 0 then "" else String.fromFloat zutat.menge
        first = String.trim (String.concat (List.intersperse " " [menge, zutat.mengeneinheit, zutat.zutat]))
        all = if String.isEmpty zutat.bemerkung
            then first
            else (String.concat (List.intersperse ", " [first, zutat.bemerkung]))
    in
        li []
            [ text all ]

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
                [ div [ class "content", style "white-space" "pre-line" ]
                    [ text rezept.anleitung ]
                ]
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

viewRezeptZutatForm : Int -> Int -> RezeptZutat -> Html Msg
viewRezeptZutatForm teilIdx idx zutat =
    div [ class "field is-horizontal"]
        [ div [ class "field-body" ]
            [ div [ class "field" ]
                [ p [ class "control" ]
                    [ input
                        [ id ("zutat-" ++ (String.fromInt teilIdx) ++ "-" ++ (String.fromInt idx))
                        , class "input is-small"
                        , type_ "text"
                        , size 12
                        , value zutat.zutat
                        , placeholder "Zutat"
                        , onInput (InputZutat teilIdx idx)
                        ]
                        []
                    ]
                ]
            , div [ class "field" ]
                [ p [ class "control" ]
                    [ input
                        [ id ("menge-" ++ (String.fromInt teilIdx) ++ "-" ++ (String.fromInt idx))
                        , class "input is-small"
                        , type_ "text"
                        , size 6
                        , value (String.fromFloat zutat.menge)
                        , placeholder "Menge"
                        , onInput (InputMenge teilIdx idx)
                        ]
                        []
                    ]
                ]
            , div [ class "field" ]
                [ p [ class "control" ]
                    [ input
                        [ id ("mengeneinheit-" ++ (String.fromInt teilIdx) ++ "-" ++ (String.fromInt idx))
                        , class "input is-small"
                        , type_ "text"
                        , size 8
                        , value zutat.mengeneinheit
                        , placeholder "Mengeneinheit"
                        , onInput (InputMengeneinheit teilIdx idx)
                        ]
                        []
                    ]
                ]
            , div [ class "field is-expanded" ]
                [ p [ class "control" ]
                    [ input
                        [ id ("bemerkung-" ++ (String.fromInt teilIdx) ++ "-" ++ (String.fromInt idx))
                        , class "input is-small"
                        , type_ "text"
                        , value zutat.bemerkung
                        , placeholder "Bemerkung"
                        , tabindex -1
                        , onInput (InputBemerkung teilIdx idx)
                        ]
                        []
                    ]
                ]
            ]
        ]

viewRezeptTeilForm : Int -> RezeptTeil -> Html Msg
viewRezeptTeilForm idx teil =
    div [ class "box content" ]
        ( div [ class "field"]
            [ div [ class "control is-expandend" ]
                [ input
                    [ id ("bezeichnung_" ++ (String.fromInt idx))
                    , class "input"
                    , type_ "text"
                    , value teil.bezeichnung
                    , placeholder "Bezeichnung"
                    , onInput (InputTeilBezeichnung idx)
                    ]
                    []
                ]
            ]
        :: (List.indexedMap (viewRezeptZutatForm idx) teil.zutaten)
        )

rezeptValid : RezeptDetails -> Bool
rezeptValid rd =
    ( not (String.isEmpty rd.bezeichnung)
    && (List.all rezeptTeilValid rd.rezept_teile)
    )

rezeptTeilValid : RezeptTeil -> Bool
rezeptTeilValid teil =
    not (String.isEmpty teil.bezeichnung)

viewRezeptForm : RezeptDetails -> Html Msg
viewRezeptForm rd =
    div [ class "section" ]
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
        , div [ class "columns" ]
            [ div [ class "column" ]
                ( [ label [ class "label" ] [ text "Rezeptteile" ] ]
                ++ (List.indexedMap viewRezeptTeilForm rd.rezept_teile)
                ++ [ button [ class "button", onClick AddRezeptTeil ]
                        [ span [ class "icon" ]
                            [ i [ class "far fa-plus-square"] [] ]
                            , span [] [ text "Rezeptteil neu" ]
                        ]
                    ]
                )
            , div [ class "column is-two-thirds" ]
                [ div [ class "field" ]
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
                ]
            ]
        , div [ class "field is-grouped" ]
            [ div [ class "control" ]
                [ button
                    [ class "button is-primary"
                    , type_ "button"
                    , disabled (not (rezeptValid rd))
                    , onClick (SubmitRezeptNeu rd)
                    ]
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

submitRezeptNeu : RezeptDetails -> Model -> ( Model, Cmd Msg )
submitRezeptNeu rd model =
    ( { model | currentRoute = AddNew (AddNewSubmitted rd) }
    , Http.request
        { method = "POST"
        , headers = []
        , url = "/api/rezepte"
        , body = Http.jsonBody (rezeptDetailsEncoder rd)
        , expect = Http.expectJson (SubmitRezeptNeuDone rd) JD.string
        , timeout = Nothing
        , tracker = Nothing
    } )

rezeptDetailsEncoder : RezeptDetails -> JE.Value
rezeptDetailsEncoder rd =
    JE.object
        [ ( "Bezeichnung", JE.string rd.bezeichnung )
        , ( "Anleitung", JE.string rd.anleitung )
        , ( "RezeptTeile", JE.list rezeptTeilEncoder rd.rezept_teile )
        ]

rezeptTeilEncoder : RezeptTeil -> JE.Value
rezeptTeilEncoder teil =
    JE.object
        [ ( "Bezeichnung", JE.string teil.bezeichnung )
        , ( "Zutaten", JE.list rezeptZutatEncoder teil.zutaten )
        ]

rezeptZutatEncoder : RezeptZutat -> JE.Value
rezeptZutatEncoder zutat =
    JE.object
        [ ( "Zutat", JE.string zutat.zutat )
        , ( "Menge", JE.float zutat.menge )
        , ( "Mengeneinheit", JE.string zutat.mengeneinheit )
        , ( "Bemerkung", JE.string zutat.bemerkung )
        ]
