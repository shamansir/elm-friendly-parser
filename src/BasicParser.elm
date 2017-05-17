module BasicParser exposing (..)

import Parser exposing (..)

import List exposing (..)
import String exposing (..)

type ReturnType = RString String | RList (List ReturnType)

type alias BasicParser = Parser.Parser ReturnType

type alias ParseResult = Parser.ParseResult ReturnType

start : Operator -> BasicParser
start op =
    Parser.start op adapter

withRules : Parser.Rules -> BasicParser
withRules rules =
    Parser.withRules rules adapter

adapter : InputType ReturnType -> ReturnType
adapter input =
    case input of
        Parser.AString str -> RString str
        Parser.AList list -> RList list

toString : ReturnType -> String
toString value =
    case value of
        RString str -> str
        RList list -> String.join "," (List.map toString list)
