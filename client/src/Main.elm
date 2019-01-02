import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode exposing (Decoder, field, int, string, list, map3)
import Url

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

-- MODEL

type alias Receipe =
    { id: Int
    , name: String
    , instructions: String
    }

type alias ReceipeList = List Receipe

type Receipes = Loading | Success ReceipeList | Failure

type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , receipes: Receipes
    }

init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( Model key url Loading, getReceipeList )

-- UPDATE

type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotReceipeList (Result Http.Error ReceipeList)

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
            ( { model | url = url }
            , Cmd.none
            )

        GotReceipeList result ->
            case result of
                Ok receipes ->
                    ({ model | receipes = Success receipes }, Cmd.none)

                Err _ ->
                    ({ model | receipes = Failure }, Cmd.none)

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none

-- VIEW

view : Model -> Browser.Document Msg
view model =
    { title = "URL Interceptor"
    , body =
        [ text "The current URL is: "
        , b [] [ text (Url.toString model.url) ]
        , viewReceipes model.receipes
        ]
    }

viewReceipe : Receipe -> Html msg
viewReceipe receipe =
    div [class "receipe"]
        [ a [ href ("/rezepte/" ++ (String.fromInt receipe.id)) ] [ text receipe.name ]
        , p [] [ text receipe.instructions ]
        ]

viewReceipes : Receipes -> Html Msg
viewReceipes receipes =
    case receipes of
        Loading ->
            text "Wait ..."

        Success receipeList ->
            div [class "receipe-list"]
                (List.map viewReceipe receipeList)

        Failure ->
            text "Oops!"


-- HTTP

getReceipeList : Cmd Msg
getReceipeList =
    Http.get
        { url = "/api/rezepte"
        , expect = Http.expectJson GotReceipeList receipeListDecoder
        }

receipeDecoder : Decoder Receipe
receipeDecoder =
    map3 Receipe
        (field "RezeptID" int)
        (field "Bezeichnung" string)
        (field "Anleitung" string)

receipeListDecoder : Decoder ReceipeList
receipeListDecoder =
    list receipeDecoder
