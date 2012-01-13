module Reactive.Bacon where

import Control.Monad
import Prelude hiding (map, filter)

data Observable a = Observable { subscribe :: (Observer a -> IO Disposable) }

data Observer a = Observer { consume :: Sink a }

type Sink a = (Event a -> IO (HandleResult a))

data HandleResult a = More (Sink a) | NoMore

data Event a = Next a | End

type Disposable = IO ()

class Source s where
  getObservable :: s a -> Observable a

instance Source Observable where
  getObservable = id

instance Source [] where
  getObservable = observableList

instance Functor Observable where
  fmap = mapE

instance Functor Event where
  fmap f (Next a)  = Next (f a)
  fmap _ End       = End

toObserver :: (a -> IO()) -> Observer a
toObserver next = Observer defaultHandler
  where defaultHandler (Next x) = next x >> return (More defaultHandler)
        defaultHandler End = return NoMore

observableList list = Observable subscribe 
  where subscribe (Observer sink) = feed sink list >> return (return ())
        feed sink (x:xs) = do result <- sink $ Next x
                              case result of
                                 More o2 -> feed o2 xs
                                 NoMore  -> return ()
        feed sink _      = sink End >> return ()

mapE :: Source s => (a -> b) -> s a -> Observable b
mapE f = sinkMap mappedSink 
  where mappedSink sink event = sink (fmap f event) >>= return . convertResult
        convertResult = mapResult (More . mappedSink)

filterE :: Source s => (a -> Bool) -> s a -> Observable a
filterE f = sinkMap filteredSink 
  where filteredSink sink End = sink End
        filteredSink sink (Next x) | f x  = sink (Next x) >>= return . convertResult
                                   | otherwise = return $ More (filteredSink sink)
        convertResult = mapResult (More . filteredSink)

takeWhileE :: Source s => (a -> Bool) -> s a -> Observable a
takeWhileE f = sinkMap limitedSink
  where limitedSink sink End = sink End
        limitedSink sink (Next x) | f x  = sink (Next x) >>= return . convertResult
                                  | otherwise = return NoMore
        convertResult = mapResult (More . limitedSink)

takeE :: Source s => Int -> s a -> Observable a
takeE 0 _   = getObservable []
takeE n src = sinkMap (limitedSink n) src
  where limitedSink n sink End = sink End
        limitedSink n sink (Next x) = sink (Next x) >>= return . (convertResult n)
        convertResult 1 = \_ -> NoMore
        convertResult n = mapResult (More . (limitedSink (n-1))) 

mergeE :: Source s => Source s2 => s a -> s2 a -> Observable a
mergeE = undefined

sinkMap :: Source s => (Sink b -> Sink a) -> s a -> Observable b
sinkMap sinkMapper src = Observable $ subscribe'
  where subscribe' observer = subscribe (getObservable src) $ mappedObserver observer
        mappedObserver (Observer sink) = Observer $ sinkMapper sink

mapResult :: (Sink a -> HandleResult b) -> HandleResult a -> HandleResult b
mapResult _ NoMore = NoMore
mapResult f (More sink) = f sink

(==>) :: Source s => s a -> (a -> IO()) -> IO()
(==>) src f = void $ subscribe (getObservable src) $ toObserver f

(@?) :: Source s => s a -> (a -> Bool) -> Observable a
(@?) src f = filterE f (getObservable src)

(|>) = flip ($)
