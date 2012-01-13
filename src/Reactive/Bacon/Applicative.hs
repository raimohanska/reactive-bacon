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
        skipFirstEnd sink event = sink event


-- Contains End events of both streams. Two ends means real end here :)
mergeRawE :: Source s1 => Source s2 => s1 a -> s2 a -> Observable a
mergeRawE left right = Observable $ \observer -> do
  endLeftRef <- newIORef False
  endRightRef <- newIORef False
  switcherRef <- newIORef observer
  disposeRightHolder <- newIORef Nothing
  disposeLeft <- subscribe (getObservable left) (Observer $ barrier endLeftRef endRightRef switcherRef (disposeIfPossible disposeRightHolder))
  disposeRight <- subscribe (getObservable right) (Observer $ barrier endRightRef endLeftRef switcherRef disposeLeft)
  writeIORef disposeRightHolder (Just disposeRight)
  return $ disposeLeft >> disposeRight
    where barrier myFlag otherFlag switcher _ End = do 
              writeIORef myFlag True
              otherDone <- readIORef otherFlag
              if otherDone
                 then sinkSwitched switcher End
                 else return NoMore
          barrier myFlag otherFlag switcher disposeOther event = do
              result <- sinkSwitched switcher event
              case result of
                 More newSink -> do
                    writeIORef switcher (Observer newSink)
                    return $ More (barrier myFlag otherFlag switcher disposeOther)
                 NoMore   -> do
                    disposeOther
                    return NoMore
          sinkSwitched switcher event = do
              observer <- readIORef switcher
              consume observer event
          disposeIfPossible ref = do
              dispose <- readIORef ref
              case dispose of Nothing -> return ()
                              Just f  -> f
-- TODO: there's a gaping hole in disposeIfPossible logic

combineLatestE :: Source s1 => Source s2 => s1 a -> s2 b -> Observable (a,b)
combineLatestE left right = sinkMap (combine 0 (Nothing) (Nothing)) (eitherE left right)
  where combine endCount leftVal rightVal sink event = do
            let (endCount', leftVal', rightVal') = update endCount leftVal rightVal event
            result <- output sink endCount' leftVal' rightVal' event 
            return $ convertResult endCount' leftVal' rightVal' result
        update endCount left right End              = (endCount+1, left   , right)
        update endCount _    right (Next (Left x))  = (endCount  , Just x , right) 
        update endCount left _     (Next (Right x)) = (endCount  , left   , Just x) 
        output sink 2 _ _ _ = sink End >> return NoMore
        output sink 1 _ _ End = sink End >> return NoMore
        output sink 0 _ _ End = continueWith sink
        output sink _ Nothing _ _ = continueWith sink
        output sink _ _ Nothing _ = continueWith sink
        output sink _ (Just l) (Just r) _  = sink $ Next (l, r)
        convertResult endCount leftVal rightVal = mapResult (More . combine endCount leftVal rightVal)
        continueWith sink = return $ More $ sink

combineLatestWithE :: Source s1 => Source s2 => (a -> b -> c) -> s1 a -> s2 b -> Observable c
combineLatestWithE f xs ys = mapE (\(a,b) -> f a b) (combineLatestE xs ys)

-- Contains End events for both streams
eitherE :: Source s1 => Source s2 => s1 a -> s2 b -> Observable (Either a b)
eitherE left right = mergeRawE (mapE Left left) (mapE Right right)
