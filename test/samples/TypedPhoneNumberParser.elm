module Samples.TypedPhoneNumberParser exposing (..)

import Parser exposing (..)
import Operator exposing (..)
import Action exposing (..)
import Match
import ParseResult exposing (..)

type PhoneNumberPart =
    Unknown
  | Prefix String Int
  | Operator Int
  | Local (Int, Int, Int)
  | PhoneNumber
    { prefix: (String, Int)
    , operator: Int
    , local: (Int, Int, Int)
    }

type ReturnType = PhoneNumberPart

rules : Rules ReturnType
rules =
    [ ( "phoneNumber"
      , action
        (seqnc
            [ maybe (call "prefix")
            , maybe (call "operator")
            , (call "local")
            ]
        )
        (\val _ -> extractPhoneNumber val)
      )
    , ( "prefix"
      , action
        ( seqnc
            [ match "+"
            , some (re "[0-9]")
            ]
        )
        (\val _ -> extractPrefix val)
      )
    , ( "operator"
      , action
        (seqnc
            [ choice [ match "(", match "[" ]
            , some (re "[0-9]")
            , choice [ match "]", match ")" ]
            ]
        )
        (\val _ -> extractOperator val)
      )
    , ( "local"
      , action
        ( seqnc
            [ some (re "[0-9]")
            , match "-"
            , some (re "[0-9]")
            , match "-"
            , some (re "[0-9]")
            ]
        )
        (\val _ -> extractLocal val)
      )
    ]

init : Parser PhoneNumberPart
init =
       Parser.init adapter
    |> Parser.withRules rules
    |> Parser.setStartRule "phoneNumber"

adapter : Match.Token PhoneNumberPart -> PhoneNumberPart
adapter result =
    case result of
        _ -> Unknown
        Match.My v -> v

isAString : Match.Token PhoneNumberPart -> Bool
isAString test =
    case test of
        Match.Lexem _ -> True
        _ -> False

digitsToInt : List PhoneNumberPart -> Maybe Int
digitsToInt probablyDigits =
    let
        collapse =
            (\val prev ->
                case prev of
                    Just prevDigits ->
                        case val of
                            Match.Lexem a ->
                                Just (prevDigits ++ a)
                            _ -> Nothing
                    Nothing -> Nothing)
    in
        case List.foldl collapse (Just "") probablyDigits of
            Just digitsString -> String.toInt digitsString |> Result.toMaybe
            Nothing -> Nothing

extractPrefix : Match.Token PhoneNumberPart -> ActionResult PhoneNumberPart
extractPrefix source =
  case source of
    AList vals ->
      if List.length vals == 2 then
        case vals of
          (AString symbol)::(AList maybeDigits)::_ ->
            case digitsToInt maybeDigits of
                Just value -> Pass (Prefix symbol value)
                Nothing -> Fail
          _ -> Fail
      else Fail
    _ -> Fail

extractOperator : Match.Token PhoneNumberPart -> ActionResult PhoneNumberPart
extractOperator source =
    case source of
        AList vals ->
            if List.length vals == 3 then
                case vals of
                    _::(AList maybeDigits)::_ ->
                        case digitsToInt maybeDigits of
                            Just value -> Pass (Operator value)
                            Nothing -> Fail
                    _ -> Fail
            else Fail
        _ -> Fail

extractLocal : Match.Token PhoneNumberPart -> ActionResult PhoneNumberPart
extractLocal source =
    case source of
        AList vals ->
            if List.length vals == 5 then
                case vals of
                    (AList maybeDigits1)::_::(AList maybeDigits2)::_::(AList maybeDigits3)::_ ->
                        case ( digitsToInt maybeDigits1
                             , digitsToInt maybeDigits2
                             , digitsToInt maybeDigits3
                             ) of
                            ( Just digits1
                            , Just digits2
                            , Just digits3
                            ) -> Pass (Local (digits1, digits2, digits3))
                            _ -> Fail
                    _ -> Fail
            else Fail
        _ -> Fail

extractPhoneNumber : Match.Token PhoneNumberPart -> ActionResult PhoneNumberPart
extractPhoneNumber source =
    case source of
        AList vals ->
            if List.length vals == 3 then
                case vals of
                    (Prefix symbol number)
                  ::(Operator operatorNumber)
                  ::(Local (local1, local2, local3))
                  ::_ ->
                        Pass
                            (PhoneNumber
                                { prefix = ( symbol, number )
                                , operator = operatorNumber
                                , local = ( local1, local2, local3 )
                                }
                            )
                    _ -> Fail
            else Fail
        _ -> Fail

