module Reactive.Bacon.Monadic where

import Data.IORef
import Reactive.Bacon

instance Monad Observable where
  return x = getObservable [x]
  (>>=) xs binder = Observable $ \(Observer sink) -> do
      sinkRef <- newIORef sink
      disposeRef <- newIORef Nothing
      dispose <- subscribe xs $ Observer $ mainEventSink (sinkRef, disposeRef)
      writeIORef disposeRef (Just dispose)
      return dispose
    where mainEventSink state eventA = do
            case eventA of
              End    -> childEventSink state End >> return NoMore
              Next x -> do
                disposeChild <- subscribe (binder x) $ Observer $ childEventSink state
                -- TODO disposeChild is never called
                return $ More $ mainEventSink state -- TODO what if client has unsubscribed or returned NoMore
          childEventSink s@(sinkRef, disposeRef) = \eventB -> do
                          case eventB of
                              End    -> return NoMore
                              Next y -> do
                                sink <- readIORef sinkRef
                                result <- sink (Next y)
                                case result of
                                    NoMore    -> disposeMain s >> return NoMore
                                    More sink -> writeIORef sinkRef sink >> return (More $ childEventSink s)
          disposeMain (_, disposeRef) = do
              maybeDispose <- readIORef disposeRef
              case maybeDispose of
                  Nothing -> return () -- TODO should dispose later tjsp
                  Just dispose -> dispose
