module Samples.ArithmeticsParser exposing (parser)

import Operator exposing (..)
import Parser exposing (..)
import User exposing (..)

import Regex

type alias ReturnType = Float

-- Expression
--   = head:Term tail:(_ ("+" / "-") _ Term)* {
--       return tail.reduce(function(result, element) {
--         if (element[1] === "+") { return result + element[3]; }
--         if (element[1] === "-") { return result - element[3]; }
--       }, head);
--     }

-- Term
--   = head:Factor tail:(_ ("*" / "/") _ Factor)* {
--       return tail.reduce(function(result, element) {
--         if (element[1] === "*") { return result * element[3]; }
--         if (element[1] === "/") { return result / element[3]; }
--       }, head);
--     }

-- Factor
--   = "(" _ expr:Expression _ ")" { return expr; }
--   / Integer

-- Integer "integer"
--   = [0-9]+ { return parseInt(text(), 10); }

-- _ "whitespace"
--   = [ \t\n\r]*

rules : RulesList ReturnType
rules =
    [ ( "Expression",
        seqnc
            [ label "head" (call "Term")
            , label "tail"
                (any (seqnc
                    [ call "whitespace"
                    , choice [ match "+", match "-" ]
                    , call "whitespace"
                    , call "Term"
                    ]
                ) )
            ]
      )
    , ( "Term",
        seqnc
            [ label "head" (call "Factor")
            , label "tail"
                (any (seqnc
                    [ call "whitespace"
                    , choice [ match "*", match "/" ]
                    , call "whitespace"
                    , call "Factor"
                    ]
                ) )
            ])
    , ( "Factor",
        choice
            [ seqnc
                [ match "("
                , call "whitespace"
                , label "expr" (call "Expression")
                ]
            , call "Integer"
            ]
       )
    , ( "Integer",
        some (re (Regex.regex "[0-9]") "nums")
      )
    , ( "whitespace",
        any (re (Regex.regex "[\t\n\r]") "tabs")
      )
    ]

parser : Parser ReturnType
parser = Parser.withListedRules rules adapter

adapter : InputType ReturnType -> ReturnType
adapter input =
    42.0
    -- case input of
    --     User.AValue str -> String.length str
    --     User.AList list -> List.length list
    --     User.ARule name value -> String.length name