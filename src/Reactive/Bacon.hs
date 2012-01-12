{-# LANGUAGE TupleSections #-}
module Reactive.Bacon where

import Control.Monad
import Control.Concurrent.STM
import Control.Concurrent.STM.TVar
import Data.IORef
import Prelude hiding (map, filter)

data Observable a = Observable { subscribe :: (Observer a -> IO Disposable) }

data Observer a = Observer { consume :: (Event a -> IO (HandleResult)) }

data HandleResult = More | NoMore

data Event a = Next a | End | Error String

type Disposable = IO ()

class Source s where
  getObservable :: s a -> Observable a

instance Functor Observable where
  fmap = map

instance Functor Event where
  fmap f (Next a)  = Next (f a)
  fmap _ End       = End
  fmap _ (Error e) = Error e 

{-
instance Monad Observable where
  return a = observableList [a]
  (>>=) = selectMany

instance MonadPlus Observable where
  mzero = observableList []
  mplus = merge 
-}

toObservable :: (Observer a -> IO Disposable) -> Observable a
toObservable subscribe = Observable subscribe

toObserver :: (a -> IO()) -> Observer a
toObserver next = Observer defaultHandler
  where defaultHandler (Next x) = next x >> return More
        defaultHandler End = return NoMore
        defaultHandler (Error e) = fail e

observableList :: [a] -> Observable a
observableList list = toObservable subscribe 
  where subscribe observer = feed observer list >> return (return ())
        feed observer (x:xs) = do result <- consume observer $ Next x
                                  case result of
                                      More -> feed observer xs
                                      NoMore   -> return ()
        feed observer _      = consume observer End >> return ()

map :: (a -> b) -> Observable a -> Observable b
map f = filteredBy mapper
  where mapper sink x = sink (Next (f x)) 

filter :: (a -> Bool) -> Observable a -> Observable a
filter f = filteredBy filter'
  where filter' sink x | f x       = sink (Next x)
                       | otherwise = return More

filteredBy :: ((Event b -> IO (HandleResult)) -> a -> IO (HandleResult)) -> Observable a -> Observable b
filteredBy filter src = Observable $ subscribe' 
  where subscribe' (Observer consume) = subscribe src $ Observer (mapped consume)
        mapped consume (Next x)  = filter consume x
        mapped consume (End)     = consume End
        mapped consume (Error s) = consume (Error s)
