module Attributes exposing (..)

import Html exposing (Attribute)
import Html.Attributes exposing (attribute)

role : String -> Attribute msg
role name =
    attribute "role" name

ariaLabel : String -> Attribute msg
ariaLabel name =
    attribute "aria-label" name
