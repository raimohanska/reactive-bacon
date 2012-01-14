module Reactive.Bacon.Applicative where

import Reactive.Bacon
import Data.IORef
import Control.Monad
import Control.Applicative

instance Applicative Observable where
  pure x = getObservable [x]
  (<*>) = applyE

instance (Show a, Eq a, Num a) => Num (Observable a) where
  (+) xs ys = (+) <$> xs <*> ys
  (*) xs ys = (*) <$> xs <*> ys
  abs = fmap abs
  signum = fmap signum
  fromInteger x = getObservable [fromInteger x]

instance Show a => Show (Observable a) where
  show = const "Observable"

instance Eq a => Eq (Observable a) where
  (==) = \x y -> False

applyE :: Source s1 => Source s2 => s1 (a -> b) -> s2 a -> Observable b
applyE = combineLatestWithE ($) 

mergeE :: Source s1 => Source s2 => s1 a -> s2 a -> Observable a
mergeE xs ys = sinkMap skipFirstEnd $ mergeRawE xs ys
  where skipFirstEnd sink End   = return $ More $ sink
        skipFirstEnd sink event = sink event >>= return . mapResult (More . skipFirstEnd)

-- Contains End events of both streams. Two ends means real end here :)
mergeRawE :: Source s1 => Source s2 => s1 a -> s2 a -> Observable a
mergeRawE left right = Observable $ \observer -> do
  switcherRef <- newIORef observer
  disposeRightHolder <- newIORef Nothing
  disposeLeft <- subscribe (getObservable left) (Observer $ barrier switcherRef (disposeIfPossible disposeRightHolder))
  disposeRight <- subscribe (getObservable right) (Observer $ barrier switcherRef disposeLeft)
  writeIORef disposeRightHolder (Just disposeRight)
  return $ disposeLeft >> disposeRight
    where barrier switcher disposeOther event = do
              result <- sinkSwitched switcher event
              case result of
                 More newSink -> do
                    writeIORef switcher (Observer newSink)
                    return $ More (barrier switcher disposeOther)
                 NoMore   -> do
                    disposeOther
                    return NoMore
          sinkSwitched switcher event = do
              observer <- readIORef switcher
              consume observer event
          disposeIfPossible ref = do
              dispose <- readIORef ref
              case dispose of Nothing -> return () -- TODO: is it necessary to dispose later in this case?
                              Just f  -> f

combineLatestE :: Source s1 => Source s2 => s1 a -> s2 b -> Observable (a,b)
combineLatestE left right = sinkMap (combine (Nothing) (Nothing)) (eitherE left right)
  where combine leftVal rightVal sink event = do
            let (leftVal', rightVal') = update leftVal rightVal event
            result <- output sink leftVal' rightVal' event 
            return $ convertResult leftVal' rightVal' result
        update left right End              = (left   , right)
        update _    right (Next (Left x))  = (Just x , right) 
        update left _     (Next (Right x)) = (left   , Just x) 
        output sink _ _ End = sink End >> return NoMore
        output sink Nothing _ _ = continueWith sink
        output sink _ Nothing _ = continueWith sink
        output sink (Just l) (Just r) _  = sink $ Next (l, r)
        convertResult leftVal rightVal = mapResult (More . combine leftVal rightVal)
        continueWith sink = return $ More $ sink

combineLatestWithE :: Source s1 => Source s2 => (a -> b -> c) -> s1 a -> s2 b -> Observable c
combineLatestWithE f xs ys = mapE (\(a,b) -> f a b) (combineLatestE xs ys)

-- Contains End events for both streams
eitherE :: Source s1 => Source s2 => s1 a -> s2 b -> Observable (Either a b)
eitherE left right = mergeE (mapE Left left) (mapE Right right)
