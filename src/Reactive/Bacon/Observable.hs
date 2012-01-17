module Reactive.Bacon.Observable where

import Reactive.Bacon.Core
import Reactive.Bacon.PushCollection
import Control.Monad

toEventObserver :: (Event a -> IO()) -> Observer a
toEventObserver next = Observer sink
  where sink event = next event >> return (More sink)

toObserver :: (a -> IO()) -> Observer a
toObserver next = Observer sink
  where sink (Next x) = next x >> return (More sink)
        sink End = return NoMore

-- |Returns new Observable with a single, persistent connection to the wrapped observable
-- Also returns Disposable for disconnecting from the source
publishE :: Source s => s a -> IO (Observable a, Disposable)
publishE src = do
  pushCollection <- newPushCollection
  dispose <- subscribe (obs src) $ toEventObserver $ (pushEvent pushCollection)
  return (obs pushCollection, dispose)


(===>) :: Source s => s a -> (Event a -> IO()) -> IO()
(===>) src f = void $ subscribe (toObservable src) $ toEventObserver f

(==>) :: Source s => s a -> (a -> IO()) -> IO()
(==>) src f = void $ subscribe (toObservable src) $ toObserver f

(|=>) :: Source s => s a -> (a -> IO()) -> IO Disposable
(|=>) src f = subscribe (toObservable src) $ toObserver f



