module Match exposing
    ( Token(..)
    , Adapter
    )

-- FIXME: there should be an option of UserType contained in this type,
-- this could allow us to get rid of Adapters and stuff
type Token o =
      Lexem String
    | Tokens (List (Token o))
    | InRule String Token -- FIXME: RuleName
    | Custom o

type alias Adapter o = (Token o -> o)
