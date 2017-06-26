module Core.Operator exposing
    ( ch, match, choice, seqnc, maybe, text, any, some, and, not
    , action, pre, xpre, label, call, re, redesc
    )

import Dict exposing (Dict)
import Regex exposing (..)

import Core.State exposing (State)
import Core.Adapter exposing (Adapter)
import Core.Action exposing
    ( ActionResult(..)
    , PrefixActionResult(..)
    , UserCode
    , UserPrefixCode
    )
import Core.Result exposing
    ( Expectation(..)
    , FailureReason(..)
    , Sample(..)
    , Position
    )
import Core.Adapter exposing (InputType(..))

type alias RuleName = String
type alias Rules o = Dict RuleName (Operator o)
type alias Grammar o = List ( RuleName, Operator o )

type StepResult o = Matched o | Failed (FailureReason o)

type alias Context o = ( Adapter o, Grammar o, State o )

type alias OperatorResult o = ( StepResult o, Context o )

type Operator o =
      NextChar -- 1. `ch`
    | Match String -- 2. `match`
    | Regex String (Maybe String) -- 3. `re`, `redesc`
    | TextOf (Operator o) -- 4. `text`
    | Maybe_ (Operator o) -- 5. `maybe`
    | Some (Operator o) -- 6. `some`
    | Any (Operator o)  -- 7. `any`
    | And (Operator o) -- 8. `and`
    | Not (Operator o) -- 9. `not`
    | Sequence (List (Operator o)) -- 10. `seqnc`
    | Choice (List (Operator o)) -- 11. `choice`
    | Action (Operator o) (UserCode o) -- 12. `action`
    | PreExec (UserPrefixCode o) -- 13. `pre`
    | NegPreExec (UserPrefixCode o) -- 14. `xpre`
    | Label String (Operator o) -- 15. `label`
    -- | Rule RuleName (Operator o) -- 16. `rule`
    | Call RuleName -- 17. `call` a.k.a `ref`
    -- | Alias String (Operator o) -- 18. `as`
    | CallAs RuleName RuleName

match : String -> Operator o
match subject =
    Match subject

ch : Operator o
ch =
    NextChar

re : String -> Operator o
re regex_ =
    Regex regex_ Nothing

redesc : String -> String -> Operator o
redesc regex_ description =
    Regex regex_ (Just description)

seqnc : List (Operator o) -> Operator o
seqnc operators =
    Sequence operators

choice : List (Operator o) -> Operator o
choice operators =
    Choice operators


maybe : Operator o -> Operator o
maybe operator =
    Maybe_ operator

any : Operator o -> Operator o
any operator =
    Any operator

some : Operator o -> Operator o
some operator =
    Some operator

and : Operator o -> Operator o
and operator =
    And operator

not : Operator o -> Operator o
not operator =
    Not operator

-- FIXME: make `call` accept the rule from the RulesList
call : RuleName -> Operator o
call ruleName =
    Call ruleName

-- FIXME: actions should have access to a position, check the examples.
action : Operator o -> UserCode o -> Operator o
action operator userCode =
    Action operator userCode

pre : UserPrefixCode o -> Operator o
pre userCode =
    PreExec userCode


xpre : UserPrefixCode o -> Operator o
xpre userCode =
    NegPreExec userCode

text : Operator o -> Operator o
text operator =
    TextOf operator

-- FIXME: check the examples
label : String -> Operator o -> Operator o
label name operator =
    Label name operator

-- OPERATORS EXECUTION

execute : Operator o -> Context o -> OperatorResult o
execute op ctx =
    ctx |> case op of
        NextChar -> execNextChar -- `ch`
        Match str -> execMatch str -- `match`
        Sequence ops -> execSequence ops -- `seqnc`
        Choice ops -> execChoice ops -- `choice`
        Maybe_ op -> execMaybe op -- `maybe`
        TextOf op -> execTextOf op -- `text`
        Some op -> execSome op -- `some`
        Any op -> execAny op -- `any`
        And op -> execAnd op -- `and`
        Not op -> execNot op -- `not`
        Action op uc -> execAction op uc -- `action`
        PreExec uc -> execPre uc -- `pre`
        NegPreExec uc -> execNegPre uc -- `xpre`
        Label n op -> execLabel n op -- `label`
        Call n -> execCall n -- `call` a.k.a. `ref`
        CallAs n1 n2 -> execCallAs n1 n2
        Regex re desc -> execRegex re desc

execNextChar : Context o -> OperatorResult o
execNextChar ctx =
    let
        ( _, state ) = ctx
    in
        if (state.position >= state.inputLength) then
            ctx |> failedBy ExpectedAnything GotEndOfInput
        else
            ctx |> advanceBy 1 |> matched (getNextChar ctx)

execMatch : String -> Context o -> OperatorResult o
execMatch expectation ctx =
    let
        ( _, state ) = ctx
        inputLength = state.inputLength
        expectationLength = String.length expectation
    in
        if (state.position + expectationLength) > inputLength then
            ctx |> failedBy (ExpectedValue expectation) GotEndOfInput
        else
            if (String.startsWith expectation
                (state.input |> String.dropLeft state.position)) then
                ctx |> advanceBy expectationLength |> matched expectation
            else
                ctx |> failedCC (ExpectedValue expectation)

execSequence : List (Operator o) -> Context o -> OperatorResult o
execSequence ops ctx =
    case ops of
        [] -> ctx |> failedBy ExpectedAnything GotEndOfInput
        (firstOp::restOps) ->
            let
                applied = chain
                    (\prevResult lastCtx reducedVal ->
                        let
                            ( opsLeft, maybeFailed, matches, _ ) = reducedVal
                        in
                            case ( prevResult, opsLeft ) of
                                ( Matched v, [] ) ->
                                    StopWith ( [], Nothing, matches ++ [ v ], lastCtx )
                                ( Matched v, nextOp::restOps ) ->
                                    Next ( nextOp, ( restOps, Nothing, matches ++ [ v ], lastCtx ) )
                                ( Failed failure, _ ) ->
                                    StopWith ( [], Just failure, matches, lastCtx )
                    )
                    firstOp ( restOps, Nothing, [], ctx ) ctx
            in
                case applied of
                    ( _, Nothing, matches, lastCtx ) ->
                        lastCtx |> matchedList matches
                    ( _, Just reason, failures, lastCtx ) ->
                        ctx |> loadPosition lastCtx |> failed reason

execChoice : List (Operator o) -> Context o -> OperatorResult o
execChoice ops ctx =
    case ops of
        [] -> ctx |> failedBy ExpectedAnything GotEndOfInput
        (firstOp::restOps) ->
            let
                applied = chain
                    (\prevResult lastCtx reducedVal ->
                        let
                            ( opsLeft, maybeMatched, failures ) = reducedVal
                        in
                            case ( prevResult, opsLeft ) of
                                ( Matched v, _ ) ->
                                    StopWith ( [], Just (v, lastCtx), failures )
                                ( Failed failure, [] ) ->
                                    case maybeMatched of
                                        Just v -> StopWith ( [], maybeMatched, failures )
                                        Nothing -> StopWith ( [], Nothing, failures ++ [ prevResult ] )
                                ( Failed failure, nextOp::restOps ) ->
                                    Next ( nextOp, ( restOps, Nothing, failures ++ [ prevResult ] ) )
                    )
                    firstOp ( restOps, Nothing, [] ) ctx
            in
                case applied of
                    ( _, Just ( success, lastCtx ), _ ) -> lastCtx |> matchedWith success
                        -- ctx |> loadPosition lastCtx |> matchedWith success
                    ( _, Nothing, failures ) ->
                        ctx |> failedNestedCC (keepOnlyFailures failures)

execSome : Operator o -> Context o -> OperatorResult o
execSome op ctx =
    let
        applied = chain
                  (\prevResult lastCtx reducedVal ->
                      case prevResult of
                          Matched v ->
                            case reducedVal of
                                ( prevMatches, _, _ ) ->
                                    Next ( op, ( prevMatches ++ [ v ], Just lastCtx, Nothing ) )
                          Failed f ->
                            case reducedVal of
                                ( [], _, _ ) -> StopWith ( [], Nothing, Just f )
                                _ -> Stop
                  )
                  op ( [], Nothing, Nothing ) ctx
    in
        case applied of
            ( allMatches, Just lastCtx, Nothing ) -> lastCtx |> matchedList allMatches
            ( _, _, Just failure ) -> ctx |> failed failure
            _ -> ctx |> failedBy ExpectedAnything GotEndOfInput

execAny : Operator o -> Context o -> OperatorResult o
execAny op ctx =
    let
        someResult = (execSome op ctx)
    in
        case someResult of
            ( Matched _, _ ) -> someResult
            ( Failed _, _ ) -> ctx |> matchedList []

execMaybe : Operator o -> Context o -> OperatorResult o
execMaybe op ctx =
    let
        result = execute op ctx
    in
        case result of
            ( Matched s, newCtx ) -> matchedWith s newCtx
            ( Failed _, _ ) -> matched "" ctx

execTextOf : Operator o -> Context o -> OperatorResult o
execTextOf op ctx =
    let
        ( _, state ) = ctx
        prevPos = state.position
        result = execute op ctx
    in
        case result of
            ( Matched s, newCtx ) ->
                let
                    ( _, newState ) = newCtx
                in
                    newCtx |> matched
                        (newState.input |> String.slice prevPos newState.position)
            failure -> failure

execAnd : Operator o -> Context o -> OperatorResult o
execAnd op ctx =
    let
        ( result, newCtx ) = (execute op ctx)
    in
        case result of
            Matched v -> matched "" ctx
            failure -> ( failure, newCtx )

execNot : Operator o -> Context o -> OperatorResult o
execNot op ctx =
    let
        ( result, newCtx ) = (execute op ctx)
    in
        case result of
            Matched _ -> ctx |> failedCC ExpectedEndOfInput
            failure -> matched "" ctx

execAction : Operator o -> UserCode o -> Context o -> OperatorResult o
execAction op userCode ctx =
    let
        ( result, newCtx ) = (execute op ctx)
        ( _, newState ) = newCtx
         -- we forget all the data left inside the "closure" and take only the new position
        resultingCtx = ctx |> loadPosition newCtx
    in
        case result of
            Matched v ->
                case (userCode v newState) of
                    Pass userV -> resultingCtx |> matchedWith userV
                    PassThrough -> resultingCtx |> matchedWith v
                    Fail -> resultingCtx |> failedCC ExpectedAnything
            Failed _ -> ( result, resultingCtx )

execPre : UserPrefixCode o -> Context o -> OperatorResult o
execPre userCode ctx =
    let
        ( _, state ) = ctx
        result = (userCode state)
    in
        case result of
            Continue -> ctx |> matched ""
            Halt -> ctx |> failedCC ExpectedEndOfInput

execNegPre : UserPrefixCode o -> Context o -> OperatorResult o
execNegPre userCode ctx =
    let
        ( _, state ) = ctx
        result = (userCode state)
    in
        case result of
            Continue -> ctx |> failedCC ExpectedEndOfInput
            Halt -> ctx |> matched ""

execLabel : String -> Operator o -> Context o -> OperatorResult o
execLabel name op ctx =
    let
        ( result, newCtx ) = (execute op ctx)
        updatedCtx =
            case result of
                Matched v ->
                    let
                        ( parser, newState ) = newCtx
                        updatedState =
                            { newState | values = newState.values |> Dict.insert name v }
                    in
                        ( parser, updatedState )
                Failed _ -> newCtx
    in
        ( result, updatedCtx )

execCall : RuleName -> Context o -> OperatorResult o
execCall ruleName ctx =
    execCallAs ruleName ruleName ctx

execCallAs : RuleName -> RuleName -> Context o -> OperatorResult o
execCallAs ruleAlias realRuleName ctx =
    let
        ( parser, _ ) = ctx
    in
        case (getRule realRuleName parser) of
            Just op -> (execute op ctx) |> addRuleToResult ruleAlias
            Nothing -> ctx |> failedBy (ExpectedRuleDefinition realRuleName) (gotChar ctx)

-- execDefineRule : RuleName -> Operator o -> Context o -> OperatorResult o
-- execDefineRule ruleName op ctx =
--     matched "" { ctx | rules = ctx.rules |> addRule_ ruleName op }

execRegex : String -> Maybe String -> Context o -> OperatorResult o
execRegex regex maybeDesc ctx =
    -- FIXME: cache all regular expressions with Regex.Regex instances
    let
        ( _, state ) = ctx
        regexInstance = Regex.regex regex
        matches = Regex.find (Regex.AtMost 1) regexInstance
                    (String.slice state.position state.inputLength state.input)
        -- FIXME: add `^` to the start, so Regex with try matching from the start,
        --        which should be faster
        firstMatch = List.head matches
        description = case maybeDesc of
                        Just d -> d
                        Nothing -> regex
    in
        case firstMatch of
            Just match ->
                if match.index == 0 then
                    ctx
                        |> advanceBy (String.length match.match)
                        |> matched match.match
                else
                    ctx |> failedRE description
            Nothing -> ctx |> failedRE description

-- UTILS

matchedWith : o -> Context o -> OperatorResult o
matchedWith output ctx =
    ( Matched output, ctx )

matched : String -> Context o -> OperatorResult o
matched val ctx =
    let
        ( parser, _ ) = ctx
    in
        matchedWith (parser.adapt (AValue val)) ctx

matchedList : List o -> Context o -> OperatorResult o
matchedList val ctx =
    let
        ( parser, _ ) = ctx
    in
        matchedWith (parser.adapt (AList val)) ctx

matchedRule : RuleName -> o -> Context o -> OperatorResult o
matchedRule ruleName value ctx =
    let
        ( parser, _ ) = ctx
    in
        matchedWith (parser.adapt (ARule ruleName value)) ctx

-- matchedFlatList : List o -> Context o -> OperatorResult o
-- matchedFlatList val ctx =
--     matchedWith (ctx.flatten (AList val)) ctx

failed : FailureReason o -> Context o -> OperatorResult o
failed reason ctx =
    ( Failed reason, ctx )

failedBy : Expectation -> Sample -> Context o -> OperatorResult o
failedBy expectation sample ctx =
    ctx |> failed (ByExpectation ( expectation, sample ))

-- fail with current character
failedCC : Expectation -> Context o -> OperatorResult o
failedCC expectation ctx =
    ctx |> failedBy expectation (gotChar ctx)

failedNested : List (FailureReason o) -> Sample -> Context o -> OperatorResult o
failedNested failures sample ctx =
    ctx |> failed (FollowingNestedOperator ( failures, sample ))

failedNestedCC : List (FailureReason o) -> Context o -> OperatorResult o
failedNestedCC failures ctx =
    ctx |> failedNested failures (gotChar ctx)

failedRE : String -> Context o -> OperatorResult o
failedRE desc ctx =
    ctx |> failedCC (ExpectedRegexMatch desc)

notImplemented : Context o -> OperatorResult o
notImplemented ctx =
    ctx |> failed SomethingWasNotImplemented

-- failWith : Expectation -> Sample -> ParseResult
-- failWith expectation sample =
--     ExpectationFailure ( expectation, sample )

advanceBy : Int -> Context o -> Context o
advanceBy count ctx =
    let
        ( parser, state ) = ctx
    in
        ( parser
        , { state | position = state.position + count }
        )

getNextSubstring : Context o -> Int -> Int -> String
getNextSubstring ctx shift count =
    let
        ( _, state ) = ctx
    in
        String.slice (state.position + shift) (state.position + shift + count) state.input

getNextChar : Context o -> String
getNextChar ctx =
    getNextSubstring ctx 1 1

getCurrentChar : Context o -> String
getCurrentChar ctx =
    getNextSubstring ctx 0 1

gotChar : Context o -> Sample
gotChar ctx =
    GotValue (getCurrentChar ctx)

addRuleToResult : RuleName -> OperatorResult o -> OperatorResult o
addRuleToResult ruleName ( result, ctx ) =
    case result of
        Matched v -> ctx |> matchedRule ruleName v
        Failed failure -> ( Failed (FollowingRule ruleName failure), ctx )

-- HELPERS

getRule : RuleName -> Grammar o -> Maybe (Operator o)
getRule name grammar =
    Dict.get name grammar

loadPosition : Context o -> Context o -> Context o
loadPosition ( _, loadFrom ) ( parser, addTo ) =
    ( parser, { addTo | position = loadFrom.position } )

type Step o v = Next ( Operator o, v ) | StopWith v | Stop

chain :
    -- (StepResult o -> Context o -> v -> ChainStep (Operator o, v))
       (StepResult o -> Context o -> v -> Step o v)
    -> Operator o
    -> v
    -> Context o
    -> v
chain stepFn initialOp initialVal initialCtx =
    let
        unfold = (\op ctx val ->
                    let
                        ( mayBeMatched, nextCtx ) = ( execute op ctx )
                    in
                        case (stepFn mayBeMatched nextCtx val) of
                            Next (nextOp, nextVal) ->
                                (unfold nextOp nextCtx nextVal)
                            StopWith lastVal -> lastVal
                            Stop -> val

                    )
    in
        unfold initialOp initialCtx initialVal

keepOnlyMatches : List (StepResult o) -> List o
keepOnlyMatches parseResults =
    List.filterMap
        (\result ->
            case result of
                Matched v -> Just v
                Failed _ -> Nothing)
        parseResults

keepOnlyFailures : List (StepResult o) -> List (FailureReason o)
keepOnlyFailures parseResults =
    List.filterMap
        (\result ->
            case result of
                Matched _ -> Nothing
                Failed failure -> Just failure)
        parseResults