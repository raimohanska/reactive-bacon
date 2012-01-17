module Reactive.Bacon.IO where

import Reactive.Bacon.Core
import Reactive.Bacon.Monadic
import Data.IORef
import Control.Concurrent(forkIO)

fromIO :: IO a -> Observable a
fromIO action = Observable $ \(Observer sink) -> do
    sinkRef <- newIORef $ Just sink
    forkIO $ do
      result <- action
      sink <- readIORef sinkRef
      case sink of
        Nothing -> return ()
        Just s -> do
          s2 <- (s $ Next result) >>= return . toSink
          s2 $ End
          return ()
    return $ writeIORef sinkRef Nothing
