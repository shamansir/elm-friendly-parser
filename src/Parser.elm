module Parser exposing
    ( Parser, init, start, startWith, parse
    -- , Position, ParseResult(..), FailureReason(..), Expectation(..), Sample(..)
    , withRules, setStartRule, getStartRule, getRule --, noRules, RuleName, Rules, RulesList
    -- , ActionResult(..), PrefixActionResult(..), UserCode, UserPrefixCode
    -- , InputType(..)
    -- , Adapter
    -- , Operator(..), State
    )

import Dict exposing (..)

import Operator exposing
    ( Operator
    , Context
    , execute
    , Rules
    , RuleName
    , Grammar
    , Rules
    , noRules
    , getCurrentChar
    , toResult
    , failByEndOfInput
    )
import State as State exposing
    ( State
    , Position
    , findPosition
    )
import ParseResult exposing
    ( ParseResult(..)
    , FailureReason(..)
    , Expectation(..)
    , Sample(..)
    )
import Match exposing (Adapter, Token)

type alias Parser o =
    String -> ParseResult o
    -- { grammar: Grammar o
    -- , startRule: String
    -- , adapter: Maybe (Adapter o)
    -- }

default : Parser o
default =
    (\input ->
        parseWith input noRules "start" Nothing)

parseWith : String -> Grammar o -> String -> Maybe (Adapter o) -> ParseResult o
parseWith input grammar startRule maybeAdapter =
    let
        state = (State.init input)
        context =
            { adapter = maybeAdapter
            , grammar = grammar
            , state = state
            }
    in
        case getStartRule context of
            Just startOperator ->
                -- TODO: extractParseResult (execCall parser.startRule context)
                let
                    ( opResult, lastState ) = (execute startOperator context)
                in
                    case toResult opResult of
                        Ok success ->
                            if lastState.position == (String.length input) then
                                Matched success
                            else
                                let
                                    ( reason, position ) = lastState |> failByEndOfInput
                                in
                                    Failed reason position
                        Err reason -> Failed reason (findPosition lastState)
            Nothing -> Failed NoStartRule (0, 0)

-- FIXME: change ParseResult to some type which returns Matched | Failed (FailureReason, Position)
--        may be change ParseResult to `OpParseResult or OpSuccess = OpMatched | OpFailed` and keep --        it private.
--        Fix the docs in the intro then.
parse : String -> Parser o -> ParseResult o
parse input parser =
    parser input

withRules : Rules o -> Parser o -> Parser o
withRules rules parser =
    { parser | grammar = Dict.fromList rules }
    -- , startRule = case List.head rules of
    --     Just ( name, _ ) -> name
    --     Nothing -> "start"

start : Operator o -> Parser o
start op =
    init |> startWith op

startWith : Operator o -> Parser o -> Parser o
startWith op parser =
    parser |> addRule "start" op

addStartRule : Operator o -> Parser o -> Parser o
addStartRule = startWith

getStartRule : Context o -> Maybe (Operator o)
getStartRule context =
    Dict.get context.startRule context.grammar

setStartRule : RuleName -> Parser o -> Parser o
setStartRule name parser =
    { parser | startRule = name }

addRule : RuleName -> Operator o -> Parser o -> Parser o
addRule name op parser =
    { parser | grammar = parser.grammar |> Dict.insert name op }

getRule : RuleName -> Parser o -> Maybe (Operator o)
getRule name parser =
    Dict.get name parser.grammar

-- UTILS

-- extractParseResult : OperatorResult o -> ParseResult o
-- extractParseResult opResult =
--     Tuple.first opResult

-- extractContext : OperatorResult o -> Context o
-- extractContext opResult =
--     Tuple.second opResult

-- opResultToMaybe : OperatorResult o -> ( Maybe o, Context o )
-- opResultToMaybe ( parseResult, ctx ) =
--     ( parseResultToMaybe parseResult, ctx )

parseResultToMaybe : ParseResult o -> Maybe (Token o)
parseResultToMaybe result =
    case result of
        Matched v -> Just v
        Failed _ _ -> Nothing

parseResultToResult : ParseResult o -> Result (FailureReason o) (Token o)
parseResultToResult result =
    case result of
        Matched v -> Ok v
        Failed f _ -> Err f
