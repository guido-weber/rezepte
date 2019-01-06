module Attributes exposing (..)

import Html exposing (Attribute)
import Html.Attributes exposing (attribute)

role : String -> Attribute msg
role name =
    attribute "role" name

ariaLabel : String -> Attribute msg
ariaLabel name =
    attribute "aria-label" name

ariaHidden : String -> Attribute msg
ariaHidden name =
    attribute "aria-hidden" name

ariaExpanded : String -> Attribute msg
ariaExpanded name =
    attribute "aria-expanded" name
