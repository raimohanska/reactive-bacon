module Reactive.Bacon.EventStream.IO where

import Reactive.Bacon.Core
import Reactive.Bacon.EventStream.Monadic
import Reactive.Bacon.EventStream
import Reactive.Bacon.PushStream
import Data.IORef
import Control.Concurrent(forkIO)
import Control.Monad

-- | startProcess is a function whose params are "event sink" and "stop sign"
fromStoppableProcess :: ((Event a -> IO ()) -> IO Bool -> IO ()) -> IO (EventStream a, IO ())
fromStoppableProcess startProcess = do
  (stream, pushEvent) <- newPushStream
  stopSignal <- newIORef False
  let getStopState = (readIORef stopSignal)
  startProcess (guardedPush pushEvent getStopState) getStopState
  return (stream, (writeIORef stopSignal True))
  where guardedPush pushEvent getStopState event = do stop <- getStopState
                                                      unless stop $ pushEvent event

fromNonStoppableProcess :: ((Event a -> IO ()) -> IO ()) -> IO (EventStream a)
fromNonStoppableProcess startProcess = do
  (stream, pushEvent) <- newPushStream
  startProcess (pushEvent)
  return stream

fromIO :: IO a -> IO (EventStream a)
fromIO action = fromNonStoppableProcess $ \sink -> void $ forkIO $ action >>= sink . Next >> sink End
