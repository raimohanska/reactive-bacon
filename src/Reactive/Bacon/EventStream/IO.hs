module Reactive.Bacon.EventStream.IO where

import Reactive.Bacon.Core
import Reactive.Bacon.EventStream.Monadic
import Reactive.Bacon.EventStream
import Reactive.Bacon.PushCollection
import Data.IORef
import Control.Concurrent(forkIO)
import Control.Monad

-- | startProcess is a function whose params are "event sink" and "stop sign"
fromStoppableProcess :: ((Event a -> IO ()) -> IO Bool -> IO ()) -> IO (EventStream a, IO ())
fromStoppableProcess startProcess = do
  pc <- newPushCollection
  stopSignal <- newIORef False
  let getStopState = (readIORef stopSignal)
  startProcess (guardedPush pc getStopState) getStopState
  return (toEventStream pc, (writeIORef stopSignal True))
  where guardedPush pc getStopState event = do stop <- getStopState
                                               unless stop $ pushEvent pc event

fromNonStoppableProcess :: ((Event a -> IO ()) -> IO ()) -> IO (EventStream a)
fromNonStoppableProcess startProcess = do
  pc <- newPushCollection
  startProcess (pushEvent pc)
  return $ toEventStream pc

fromIO :: IO a -> IO (EventStream a)
fromIO action = fromNonStoppableProcess $ \sink -> void $ forkIO $ action >>= sink . Next >> sink End
