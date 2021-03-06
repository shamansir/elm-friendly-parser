module State exposing
    ( Values
    , State
    , init
    , Position
    , findPosition
    )

import Dict exposing (Dict)
import Match exposing (Token)

type alias Values o = Dict String (Token o)

type alias Position = ( Int, Int ) -- FIXME : Known ( Int, Int ) | Unknown | EndOfInput

noValues : Values v
noValues = Dict.empty

-- FIXME: it should be possible to get ( Line, Position ),
-- and also Previous Position in state
type alias State o =
    { input: String
    , inputLength: Int
    , position: Int
    , values: Values o
    }

init : String -> State o
init input =
    { input = input
    , inputLength = String.length input
    , position = 0
    , values = noValues
    }

findPosition : State o -> Position
findPosition state =
    let
        input = state.input
        allLines = String.lines input
        linesCount = List.length allLines
        curPosition = (state.position - (linesCount - 1)) -- '\n' count as separate symbols
    in
        .cursor
            (List.foldl
                (\line { cursor, prevCursor, sum } ->
                    if (sum < curPosition) then
                        case cursor of
                            ( lineIndex, charIndex ) ->
                                let
                                    strlen = (String.length line)
                                in
                                    if (sum + strlen) > curPosition then
                                        { cursor = ( lineIndex, curPosition - sum )
                                        , prevCursor = cursor
                                        , sum = sum + strlen
                                        }
                                    else
                                        { cursor =
                                            if (lineIndex < linesCount - 1)
                                                then ( lineIndex + 1, 0 )
                                                else ( lineIndex, strlen )
                                        , prevCursor = cursor
                                        , sum = sum + strlen
                                        }
                    else
                        { cursor = prevCursor
                        , prevCursor = prevCursor
                        , sum = sum
                        }
                )
                { cursor = (0, 0)
                , prevCursor = (0, 0)
                , sum = 0
                }
                (String.lines input))
