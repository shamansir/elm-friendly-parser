port module Main exposing (..)

import Test.Runner.Node exposing (run, TestProgram)
import Json.Encode exposing (Value)
import Test exposing (..)

import UtilsTest exposing (suite)
import ParserTest exposing (suite)
import BasicParserTest exposing (suite)
import CustomParserTest exposing (suite)


allSuites : Test
allSuites =
    describe "Elm Friendly Parser"
        [ UtilsTest.suite
        , ParserTest.suite
        , BasicParserTest.suite
        , CustomParserTest.suite
        ]


main : TestProgram
main =
    run emit allSuites


port emit : ( String, Value ) -> Cmd msg
