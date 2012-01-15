module Reactive.Bacon.IO where

import Reactive.Bacon
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
          s $ Next result
          s $ End
          return ()
    return $ writeIORef sinkRef Nothing

monadicIO :: Source s => s a -> (a -> IO b) -> Observable b
monadicIO xs binder = (obs xs) >>= fromIO . binder
