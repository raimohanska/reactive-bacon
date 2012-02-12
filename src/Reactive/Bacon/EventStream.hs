module Reactive.Bacon.EventStream where

import Reactive.Bacon.Core
import Reactive.Bacon.PushCollection
import Control.Monad
import Data.Maybe
import Data.IORef
import Control.Concurrent.STM

instance Functor EventStream where
  fmap f = sinkMap mappedSink 
           where mappedSink sink event = sink (fmap f event)

mapE :: EventSource s => (a -> b) -> s a -> IO (EventStream b)
mapE f = return . (fmap f) . obs

scanE :: EventSource s => (b -> a -> b) -> b -> s a -> IO (EventStream b)
scanE f seed src = do acc <- newTVarIO seed
                      wrap $ sinkMap (scanSink acc) src
  where scanSink acc sink End = sink End >> return NoMore 
        scanSink acc sink (Next x) = do y <- update acc x
                                        sink (Next y)
        update acc x = atomically $ do accVal <- readTVar acc
                                       let next = f accVal x
                                       writeTVar acc next
                                       return next

filterE :: EventSource s => (a -> Bool) -> s a -> IO (EventStream a)
filterE f = return . sinkMap filteredSink 
  where filteredSink sink End = sink End
        filteredSink sink (Next x) | f x  = sink (Next x)
                                   | otherwise = return More

takeWhileE :: EventSource s => (a -> Bool) -> s a -> IO (EventStream a)
takeWhileE f src = do stopFlag <- newIORef False
                      wrap $ sinkMap (guardedSink stopFlag) src
                    where guardedSink stopFlag sink x = do stop <- readIORef stopFlag
                                                           if stop 
                                                              then return NoMore
                                                              else limitedSink stopFlag sink x
                          limitedSink stopFlag sink End = sink End >> return NoMore 
                          limitedSink stopFlag sink (Next x) | f x = sink (Next x)
                                                             | otherwise = writeIORef stopFlag True >> sink End >> return NoMore

takeE :: EventSource s => Num n => Ord n => n -> s a -> IO (EventStream a)
takeE n src = scanE numbered (Nothing, 0) src >>= takeWhileE atMostN >>= mapE (fromJust . fst)
  where numbered (_, i) x = (Just x, i + 1) 
        atMostN (_, i) | i <= n      = True
                       | otherwise   = False 

sinkMap :: EventSource s => (EventSink b -> EventSink a) -> s a -> EventStream b
sinkMap sinkMapper src = EventStream $ subscribe'
  where subscribe' sink = subscribe (toEventStream src) $ sinkMapper sink

(===>) :: EventSource s => s a -> (Event a -> IO()) -> IO()
(===>) src f = void $ subscribe (toEventStream src) $ toEventObserver f

