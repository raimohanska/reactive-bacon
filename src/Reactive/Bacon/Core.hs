module Reactive.Bacon.Core where

import Control.Monad
import Prelude hiding (map, filter)

data Observable a = Observable { subscribe :: (Observer a -> IO Disposable) }

data Observer a = Observer { consume :: Sink a }

type Sink a = (Event a -> IO (HandleResult a))

data HandleResult a = More (Sink a) | NoMore

data Event a = Next a | End

type Disposable = IO ()

class Source s where
  toObservable :: s a -> Observable a

instance Source Observable where
  toObservable = id

instance Source [] where
  toObservable = observableList

instance Functor Observable where
  fmap = mapE

instance Functor Event where
  fmap f (Next a)  = Next (f a)
  fmap _ End       = End

instance Show a => Show (Event a) where
  show (Next x) = show x
  show End      = "<END>"

instance Eq a => Eq (Event a) where
  (==) End End = True
  (==) (Next x) (Next y) = (x==y)
  (==) _ _ = False

observableList list = Observable subscribe 
  where subscribe (Observer sink) = feed sink list >> return (return ())
        feed sink (x:xs) = do result <- sink $ Next x
                              case result of
                                 More o2 -> feed o2 xs
                                 NoMore  -> return ()
        feed sink _      = sink End >> return ()

mapE :: Source s => (a -> b) -> s a -> Observable b
mapE f = sinkMap mappedSink 
  where mappedSink sink event = mapOutput mappedSink sink (fmap f event)

scanE :: Source s => (b -> a -> b) -> b -> s a -> Observable b
scanE f seed = sinkMap (scanSink seed)
  where scanSink acc sink End = sink End >> return NoMore 
        scanSink acc sink (Next x) = mapOutput (scanSink (f acc x)) sink (Next (f acc x))

filterE :: Source s => (a -> Bool) -> s a -> Observable a
filterE f = sinkMap filteredSink 
  where filteredSink sink End = sink End
        filteredSink sink (Next x) | f x  = mapOutput filteredSink sink (Next x)
                                   | otherwise = return $ More (filteredSink sink)

takeWhileE :: Source s => (a -> Bool) -> s a -> Observable a
takeWhileE f = sinkMap limitedSink
  where limitedSink sink End = sink End
        limitedSink sink (Next x) | f x  = mapOutput limitedSink sink (Next x)
                                  | otherwise = sink End >> return NoMore

takeE :: Source s => Int -> s a -> Observable a
takeE 0 _   = toObservable []
takeE n src = sinkMap (limitedSink n) src
  where limitedSink n sink End = sink End >> return NoMore
        limitedSink 1 sink (Next x) = do 
            result <- sink (Next x)
            (toSink result) End
        limitedSink n sink (Next x) = sink (Next x) >>= return . mapResult (More . (limitedSink (n-1)))

sinkMap :: Source s => (Sink b -> Sink a) -> s a -> Observable b
sinkMap sinkMapper src = Observable $ subscribe'
  where subscribe' observer = subscribe (toObservable src) $ mappedObserver observer
        mappedObserver (Observer sink) = Observer $ sinkMapper sink

mapOutput :: (Sink b -> Sink a) -> Sink b -> Event b -> IO (HandleResult a)
mapOutput mapper sink event = sink event >>= return . convertResult
  where convertResult = mapResult (More . mapper)

mapResult :: (Sink a -> HandleResult b) -> HandleResult a -> HandleResult b
mapResult _ NoMore = NoMore
mapResult f (More sink) = f sink

toSink :: HandleResult a -> Sink a
toSink NoMore = \_ -> return NoMore
toSink (More sink) = sink

(@?) :: Source s => s a -> (a -> Bool) -> Observable a
(@?) src f = filterE f src

obs :: Source s => s a -> Observable a
obs = toObservable

