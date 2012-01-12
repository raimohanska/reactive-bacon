module Reactive.Bacon where

import Control.Monad
import Prelude hiding (map, filter)

data Observable a = Observable { subscribe :: (Observer a -> IO Disposable) }

data Observer a = Observer { consume :: (Event a -> IO (HandleResult)) }

data HandleResult = More | NoMore

data Event a = Next a | End | Error String

type Disposable = IO ()

class Source s where
  getObservable :: s a -> Observable a

instance Source Observable where
  getObservable = id

instance Source [] where
  getObservable = observableList

instance Functor Observable where
  fmap = map

instance Functor Event where
  fmap f (Next a)  = Next (f a)
  fmap _ End       = End
  fmap _ (Error e) = Error e 

toObservable :: (Observer a -> IO Disposable) -> Observable a
toObservable subscribe = Observable subscribe

toObserver :: (a -> IO()) -> Observer a
toObserver next = Observer defaultHandler
  where defaultHandler (Next x) = next x >> return More
        defaultHandler End = return NoMore
        defaultHandler (Error e) = fail e

observableList list = Observable subscribe 
  where subscribe observer = feed observer list >> return (return ())
        feed observer (x:xs) = do result <- consume observer $ Next x
                                  case result of
                                      More -> feed observer xs
                                      NoMore   -> return ()
        feed observer _      = consume observer End >> return ()

map :: Source s => (a -> b) -> s a -> Observable b
map f = filteredBy mapper
  where mapper sink x = sink (Next (f x)) 

filter :: Source s => (a -> Bool) -> s a -> Observable a
filter f = filteredBy filter'
  where filter' sink x | f x       = sink (Next x)
                       | otherwise = return More

filteredBy :: Source s => ((Event b -> IO (HandleResult)) -> a -> IO (HandleResult)) -> s a -> Observable b
filteredBy filter src = Observable $ subscribe' 
  where subscribe' (Observer consume) = subscribe (getObservable src) $ Observer (mapped consume)
        mapped consume (Next x)  = filter consume x
        mapped consume (End)     = consume End
        mapped consume (Error s) = consume (Error s)

takeWhile :: Source s => (a -> Bool) -> s a -> Observable a
takeWhile f = filteredBy takeWhile'
  where takeWhile' sink x | f x       = sink (Next x)
                          | otherwise = return NoMore

(==>) :: Source s => s a -> (a -> IO()) -> IO()
(==>) src f = void $ subscribe (getObservable src) $ toObserver f

(@?) :: Source s => s a -> (a -> Bool) -> Observable a
(@?) src f = filter f (getObservable src)
