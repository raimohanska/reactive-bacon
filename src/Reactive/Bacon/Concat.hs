module Reactive.Bacon.Concat where

import Reactive.Bacon.Core

import Data.IORef


concatE :: Source s1 => Source s2 => s1 a -> s2 a -> Observable a
concatE xs ys = Observable $ \(Observer sink) -> do
    disposeRef <- newIORef Nothing
    subscribe (obs xs) (Observer $ concat' disposeRef sink) >>= writeIORef disposeRef . Just
    return $ maybeDispose disposeRef
  where concat' disposeRef sink End   = do
          subscribe (obs ys) (Observer sink) >>= writeIORef disposeRef . Just
          return NoMore
        concat' disposeRef sink event = sink event >>= return . mapResult (More . concat' disposeRef)
        maybeDispose disposeRef = do
          dispose <- readIORef disposeRef
          case dispose of
            Nothing -> return () -- TODO: later?
            Just d -> d

repeatE :: Source s1 => s1 a -> Observable a
repeatE xs = concatE xs (repeatE xs)

startWithE :: Source s1 => a -> s1 a -> Observable a
startWithE x xs = [x] <++> xs

(<++>) :: Source s1 => Source s2 => s1 a -> s2 a -> Observable a
(<++>) = concatE

(<:>) :: Source s1 => a -> s1 a -> Observable a
(<:>) = startWithE
