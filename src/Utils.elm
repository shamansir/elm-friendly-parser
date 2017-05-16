module Utils exposing (..)

import Tuple exposing (first)
import List exposing (foldl)

reduce : b -> List a -> (a -> b -> Maybe b) -> b
reduce init src reducer =
  Tuple.first
    (List.foldl
      (\curVal (prevVal, prevContinue) ->
        case prevContinue of
          True -> case (reducer curVal prevVal) of
            Just v -> (v, True)
            Nothing -> (prevVal, False)
          False -> (prevVal, False))
      (init, True)
      src)

iterateMap : (a -> Maybe b) -> List a -> List b
iterateMap f src =
  reduce [] src
    (\cur prev ->
      case (f cur) of
        Just v -> Just ( prev ++ [ v ] )
        Nothing -> Nothing
    )

iterateOr : (a -> Maybe b) -> List a -> Maybe b
iterateOr f src =
  reduce Nothing src
    (\cur hasValue ->
      case hasValue of
        Just v -> Just hasValue
        Nothing -> case (f cur) of
          Just v -> Just ( Just v )
          Nothing -> Just Nothing
    )

iterateWhileAnd : (a -> Maybe b) -> List a -> Maybe b
iterateWhileAnd f src =
  Nothing

iterateAnd : (a -> Maybe b) -> List a -> Maybe b
iterateAnd f src =
  Nothing

iterateMapAnd : (a -> Maybe b) -> List a -> Maybe (List b)
iterateMapAnd f src =
  Nothing
