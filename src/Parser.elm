module Parser exposing (..)

import Dict exposing (..)

type alias UserCode = (ParseResult -> Operator)

type OperatorType =
      NextChar -- 1. `ch`
    | Match String -- 2. `match`
    | Regex String String -- 3. `re`
    | TextOf Operator -- 4. `text`
    | Maybe_ Operator -- 5. `maybe`
    | Some Operator -- 6. `some`
    | Any Operator  -- 7. `any`
    | And Operator -- 8. `and`
    | Not Operator -- 9. `not`
    | Sequence (List Operator) -- 10. `seqnc`
    | Choice (List Operator) -- 11. `choice`
    | Action Operator UserCode -- 12. `action`
    | PreExec UserCode -- 13. `pre`
    | NegPreExec UserCode -- 14. `xpre`
    | Label String Operator -- 15. `label`
    | Rule String Operator -- 16. `rule`
    | RuleReference String -- 17. `ref`
    | Alias String Operator -- 18. `as`

type alias Operator = OperatorType

type alias RuleName = String

-- type alias Chunk = ( Int, String )

type alias Parser = Rules

type ParseResult =
      Matched String
    | ExpectedString String
    | ExpectedRule RuleName
    | ExpectedOperator Operator
    | ExpectedEndOfInput String
    -- | ExpectedChunk Chunk
    -- | ExpectedChunks (List Chunk)
    | NoStartingRule
    | NotImplemented

-- type alias Context a = Dict String a
type alias Context v =
    { input: String
    , inputLength: Int
    , position: Int
    , rules: Rules
    , values: Values v
}

type alias OperatorResult v = (ParseResult, Context v)

type alias Rules = Dict String Operator
type alias Values v = Dict String v

parse : Parser -> String -> ParseResult
parse parser input =
    case getStartRule parser of
        Just startOperator ->
            execute startOperator (initContext input)
        Nothing -> NoStartingRule

-- RULES

noRules : Rules
noRules = Dict.empty

addRule : String -> Operator -> Rules -> Rules
addRule name op rules =
    rules |> Dict.insert name op

start : Operator -> Rules
start op =
    noRules |> addRule "start" op

-- OPERATORS

match : String -> Operator
match subject =
    Match subject

choice : List Operator -> Operator
choice operators =
    Choice operators

-- OPERATORS EXECUTION

execute : Operator -> Context v -> ParseResult
execute op ctx =
    case op of
        Match s -> Tuple.first (execMatch s ctx)
        _ -> NotImplemented

execMatch : String -> Context v -> OperatorResult v
execMatch str ctx =
    let
        ilen = ctx.inputLength -- length of the input string
        slen = String.length str -- length of the expectation string
    in
        if (ctx.position + slen) > ilen then
            ( ExpectedEndOfInput str, ctx )
        else
            if (String.startsWith str
                (ctx.input |> String.dropLeft ctx.position)) then
                ( Matched str
                , { ctx | position = ctx.position + slen }
                )
            else
                ( ExpectedString str, ctx )

-- UTILS

noValues : Values v
noValues = Dict.empty

initContext : String -> Context v
initContext input =
    { input = input
    , inputLength = String.length input
    , position = 0
    , rules = noRules
    , values = noValues
    }

getStartRule : Parser -> Maybe Operator
getStartRule parser =
    Dict.get "start" parser

isNotParsed : ParseResult -> Bool
isNotParsed result =
    case result of
        Matched _ -> False
        _ -> True

isParsedAs : String -> ParseResult -> Bool
isParsedAs subject result =
    case result of
        Matched s -> (s == subject)
        _ -> False
