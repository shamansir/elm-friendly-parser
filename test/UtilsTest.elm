module UtilsTest exposing (suite)

import Test exposing (..)
import Expect

import Utils exposing (..)

suite : Test
suite =
    describe "utils"
        [ testReduce
        , testIterateMap
        , testIterateOr
        , testIterateAnd
        , testIterateMapAnd
        , testIterateWhileAnd
        ]

testReduce : Test
testReduce =
    describe "reduce"
        [ test "should iterate through a list while function returns something" <|
            (\() ->
                Expect.equal
                    3
                    (reduce -1 [ 0, 1, 2, 3 ]
                        (\n _ -> Just n))
            )
        , test "should stop when function returns `Nothing`" <|
            (\() ->
                Expect.equal
                    1
                    (reduce -1 [ 0, 1, 2, 3 ]
                        (\n _ -> if n < 2 then Just n else Nothing))
            )
        , test "should return initial value when first element returned nothing" <|
            (\() ->
                Expect.equal
                    -1
                    (reduce -1 [ 0, 1, 2, 3 ] (\_ _ -> Nothing) )
            )
        , test "should be able to join items" <|
            (\() ->
                Expect.equal
                    5
                    (reduce -1 [ 0, 1, 2, 3 ]
                        (\n prevN -> Just (n + prevN)))
            )
        , test "should provide access to previous items" <|
            (\() ->
                Expect.equal
                    [ 1, 2, 3, 4 ]
                    (reduce  [] [ 0, 1, 2, 3 ]
                        (\n prev -> Just (prev ++ [ n + 1 ])))
            )
        , test "should work with strings" <|
            (\() ->
                Expect.equal
                    "3/2/1/0/"
                    (reduce "" [ 0, 1, 2, 3 ]
                        (\n prev -> Just (toString n ++ "/" ++ prev)))
            )
        ]

testIterateMap : Test
testIterateMap =
    describe "iterateMap"
        [ test "should be able to get all elements while function returns something" <|
            (\() ->
                Expect.equal
                    [ 0, 1, 2, 3 ]
                    (iterateMap (\n -> Just n) [ 0, 1, 2, 3 ])
            )
        , test "should apply what mapping function returns" <|
            (\() ->
                Expect.equal
                    [ 10, 11, 12, 13 ]
                    (iterateMap (\n -> Just (n + 10)) [ 0, 1, 2, 3 ])
            )
        , test "should stop when mapping function returns `Nothing`" <|
            (\() ->
                Expect.equal
                    [ 0, 1 ]
                    (iterateMap
                        (\n -> if (n < 2) then Just n else Nothing )
                        [ 0, 1, 2, 3 ])
            )
        , test "should return empty array when function returned `Nothing` for the first element" <|
            (\() ->
                Expect.equal
                    [ ]
                    (iterateMap
                        (\n -> if (n < 0) then Just n else Nothing )
                        [ 0, -1, -2, -3 ])
            )
        , test "should apply mapping function despite being stopped by `Nothing`" <|
            (\() ->
                Expect.equal
                    [ -10, -9, -8 ]
                    (iterateMap
                        (\n -> if (n < 3) then Just (n - 10) else Nothing )
                        [ 0, 1, 2, 3 ])
            )
        ]

testIterateOr : Test
testIterateOr =
    describe "iterateOr"
        [ test "should get first element for which function returns something" <|
            (\() ->
                Expect.equal
                    (Just 0)
                    (iterateOr (\n -> Just n)
                        [ 0, 1, 2, 3 ])
            )
        , test "should get first element for which function returns something, p.II" <|
            (\() ->
                Expect.equal
                    (Just 2)
                    (iterateOr (\n -> if (n > 1) then Just n else Nothing)
                        [ 0, 1, 2, 3 ])
            )
        , test "should apply what mapping function returns" <|
            (\() ->
                Expect.equal
                    (Just 12)
                    (iterateOr (\n -> if (n > 1) then Just (n + 10) else Nothing)
                        [ 0, 1, 2, 3 ])
            )
        , test "should return `Nothing` when function returned `Nothing` for all the elements" <|
            (\() ->
                Expect.equal
                    Nothing
                    (iterateOr
                        (\n -> if (n > 10) then Just n else Nothing )
                        [ 0, 1, 2, 3 ])
            )
        ]

testIterateAnd : Test
testIterateAnd =
    describe "iterateAnd"
        [ test "should return last successful element when function passes for all of them" <|
            (\() ->
                Expect.equal
                    (Just 3)
                    (iterateAnd (\n -> Just n)
                        [ 0, 1, 2, 3 ])
            )
        , test "should return `Nothing` when function not passes for one of the elements" <|
            (\() ->
                Expect.equal
                    Nothing
                    (iterateAnd (\n -> if (n > 0) then Just n else Nothing)
                        [ 0, 1, 2, 3 ])
            )
        , test "should apply what mapping function returns" <|
            (\() ->
                Expect.equal
                    (Just 13)
                    (iterateAnd (\n -> if (n > 1) then Just (n + 10) else Just (n - 10))
                        [ 0, 1, 2, 3 ])
            )
        , test "should return `Nothing` when function returned `Nothing` for all the elements" <|
            (\() ->
                Expect.equal
                    Nothing
                    (iterateAnd
                        (\n -> if (n > 10) then Just n else Nothing )
                        [ 0, 1, 2, 3 ])
            )
        ]

testIterateMapAnd : Test
testIterateMapAnd =
    describe "iterateMapAnd"
        [ test "should return all values when function passes for all the elements" <|
            (\() ->
                Expect.equal
                    (Just [ 0, 1, 2, 3 ])
                    (iterateMapAnd (\n -> Just n)
                        [ 0, 1, 2, 3 ])
            )
        , test "should return `Nothing` when function not passes for one of the elements" <|
            (\() ->
                Expect.equal
                    Nothing
                    (iterateMapAnd (\n -> if (n > 0) then Just n else Nothing)
                        [ 0, 1, 2, 3 ])
            )
        , test "should return `Nothing` when function not passes for one of the elements, p. II" <|
            (\() ->
                Expect.equal
                    Nothing
                    (iterateMapAnd (\n -> if (n < 3) then Just n else Nothing)
                        [ 0, 1, 2, 3 ])
            )
        , test "should apply what mapping function returns" <|
            (\() ->
                Expect.equal
                    (Just [ -10, -9, 12, 13 ])
                    (iterateMapAnd (\n -> if (n > 1) then Just (n + 10) else Just (n - 10))
                        [ 0, 1, 2, 3 ])
            )
        , test "should return `Nothing` when function returned `Nothing` for all the elements" <|
            (\() ->
                Expect.equal
                    Nothing
                    (iterateMapAnd
                        (\n -> if (n > 10) then Just n else Nothing )
                        [ 0, 1, 2, 3 ])
            )
        ]

testIterateWhileAnd : Test
testIterateWhileAnd =
    describe "iterateWhileAnd"
        [ test "should return last successful element when function passes for all of them" <|
            (\() ->
                Expect.equal
                    (Just 3)
                    (iterateWhileAnd (\n -> Just n)
                        [ 0, 1, 2, 3 ])
            )
        , test "should return `Nothing` when success chain in not bound to the start of the list" <|
            (\() ->
                Expect.equal
                    Nothing
                    (iterateWhileAnd (\n -> if (n > 0) then Just n else Nothing)
                        [ 0, 1, 2, 3 ])
            )
        , test "should return last element from the continuous chain of successes" <|
            (\() ->
                Expect.equal
                    (Just 2)
                    (iterateWhileAnd (\n -> if (n < 3) then Just n else Nothing)
                        [ 0, 1, 2, 3 ])
            )
        , test "should apply what mapping function returns" <|
            (\() ->
                Expect.equal
                    (Just 12)
                    (iterateWhileAnd (\n -> if (n < 3) then Just (n + 10) else Nothing)
                        [ 0, 1, 2, 3 ])
            )
        , test "should apply what mapping function returns, p. II" <|
            (\() ->
                Expect.equal
                    (Just 13)
                    (iterateWhileAnd (\n -> if (n > 1) then Just (n + 10) else Just (n - 10))
                        [ 0, 1, 2, 3 ])
            )
        , test "should return `Nothing` when function returned `Nothing` for all the elements" <|
            (\() ->
                Expect.equal
                    Nothing
                    (iterateWhileAnd
                        (\n -> if (n > 10) then Just n else Nothing )
                        [ 0, 1, 2, 3 ])
            )
        ]
