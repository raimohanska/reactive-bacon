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

instance Show a => Show (Event a) where
  show (Next x) = show x
  show End      = "<END>"

instance Eq a => Eq (Event a) where
  (==) End End = True
  (==) (Next x) (Next y) = (x==y)
  (==) _ _ = False

toEventObserver :: (Event a -> IO()) -> Observer a
toEventObserver next = Observer sink
  where sink event = next event >> return (More sink)

toObserver :: (a -> IO()) -> Observer a
toObserver next = Observer sink
  where sink (Next x) = next x >> return (More sink)
        sink End = return NoMore

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
takeE 0 _   = getObservable []
takeE n src = sinkMap (limitedSink n) src
  where limitedSink n sink End = sink End >> return NoMore
        limitedSink 1 sink (Next x) = do 
            result <- sink (Next x)
            (toSink result) End
        limitedSink n sink (Next x) = sink (Next x) >>= return . mapResult (More . (limitedSink (n-1)))

sinkMap :: Source s => (Sink b -> Sink a) -> s a -> Observable b
sinkMap sinkMapper src = Observable $ subscribe'
  where subscribe' observer = subscribe (getObservable src) $ mappedObserver observer
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

(==>) :: Source s => s a -> (a -> IO()) -> IO()
(==>) src f = void $ subscribe (getObservable src) $ toObserver f

(|=>) :: Source s => s a -> (a -> IO()) -> IO Disposable
(|=>) src f = subscribe (getObservable src) $ toObserver f

(@?) :: Source s => s a -> (a -> Bool) -> Observable a
(@?) src f = filterE f src

(|>) = flip ($)

obs :: Source s => s a -> Observable a
obs = getObservable
