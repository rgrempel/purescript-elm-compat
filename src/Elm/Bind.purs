
-- | Elm modules typically use `andThen` for what Purescript would call `bind`.
-- | We define the synomyn here generically so that we don't have to define the
-- | function multiple times. And, we can re-export it (as Elm code expects)
-- | without producing conflicts, since it's all the same function.

module Elm.Bind (andThen) where


import Prelude (class Bind, bind, flip)


-- | Given some computation, chain its result with another computation.
-- |
-- | Equivalent to Purescript's `bind`.
-- |
-- | The order of the arguments was flipped in Elm 0.18.
andThen :: ∀ m a b. (Bind m) => (a -> m b) -> m a -> m b
andThen = flip bind
