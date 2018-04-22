
-- | Right now, this library is pretty sparse. For example, there is no public API
-- | for processes to communicate with each other. This is a really important
-- | ability, but it is also something that is extraordinarily easy to get wrong!

module Elm.Process
  ( Id
  , spawn
  , sleep
  , kill
  , send
  ) where


import Control.Monad.Aff (forkAff, delay, killFiber, apathize)
import Control.Monad.Aff.AVar (killVar, makeEmptyVar, putVar)
import Control.Monad.Aff.Class (liftAff)
import Control.Monad.Eff.Exception (error)
import Control.Monad.Except.Trans (ExceptT(..), runExceptT)
import Control.Monad.Trans.Class (lift)
import Data.Either (Either(..))
import Data.Newtype (unwrap)
import Data.Time.Duration (Milliseconds(..), toDuration)
import Elm.Platform (Process(..), ProcessId, Task)
import Prelude (Unit, bind, discard, pure, ($), (<$>), (<<<))


-- This is repeated here to avoid a circular dependency
type Time = Number


-- | A light-weight process that runs concurrently. You can use `spawn` to
-- | get a bunch of different tasks running in different processes. The Elm runtime
-- | will interleave their progress. So if a task is taking too long, we will pause
-- | it at an `andThen` and switch over to other stuff.
-- |
-- | **Note:** We make a distinction between *concurrency* which means interleaving
-- | different sequences and *parallelism* which means running different
-- | sequences at the exact same time. For example, a
-- | [time-sharing system](https://en.wikipedia.org/wiki/Time-sharing) is definitely
-- | concurrent, but not necessarily parallel. So even though JS runs within a
-- | single OS-level thread, Elm can still run things concurrently.
-- |
-- | Note that in Purescript, the Id takes an `e` parameter representing effects.
type Id =
    ProcessId


-- | Run a task in its own light-weight process. In the following example,
-- | `task1` and `task2` will be interleaved. If `task1` makes a long HTTP request
-- | or is just taking a long time, we can hop over to `task2` and do some work
-- | there.
-- |
-- |     spawn task1
-- |       |> Task.andThen (\_ -> spawn task2)
-- |
-- | **Note:** This creates a relatively restricted kind of `Process` because it
-- | cannot receive any messages. More flexibility for user-defined processes will
-- | come in a later release!
spawn :: ∀ x y a. Task x a -> Task y Id
spawn task = do
    mailbox <- liftAff makeEmptyVar
    fiber <- (lift <<< liftAff <<< forkAff <<< apathize <<< unwrap <<< runExceptT) task
    pure $ Process { mailbox, fiber }


-- | Block progress on the current process for a given amount of time. The
-- | JavaScript equivalent of this is [`setTimeout`][setTimeout] which lets you
-- | delay work until later.
-- |
-- | [setTimeout]: https://developer.mozilla.org/en-US/docs/Web/API/WindowTimers/setTimeout
sleep :: ∀ x. Time -> Task x Unit
sleep time =
    ExceptT $ liftAff $ Right <$> delay (toDuration $ Milliseconds time)


-- | Sometimes you `spawn` a process, but later decide it would be a waste to
-- | have it keep running and doing stuff. The `kill` function will force a process
-- | to bail on whatever task it is running. So if there is an HTTP request in
-- | flight, it will also abort the request.
kill :: ∀ y. Id -> Task y Unit
kill (Process {mailbox, fiber}) =
    -- We have to specify an specific error ...
    let
        err =
            error "Elm.Process.kill"
    in do
        -- I should figure out how to make `liftAff` lift something straight
        -- into `Task`. Also, I should probably set things up so that the AVar
        -- is automatically killed when the fiber exits.
        lift $ liftAff $ killVar err mailbox
        lift $ liftAff $ killFiber err fiber


-- | A task that will send a message to a process that can receive messages.
-- |
-- | This is not exposed in Elm, though something like it is used internally.
send :: ∀ x msg. Process msg -> msg -> Task x Unit
send (Process {mailbox}) msg =
    lift $ liftAff $ putVar msg mailbox
