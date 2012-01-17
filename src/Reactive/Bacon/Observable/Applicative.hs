module Reactive.Bacon.Observable.Applicative(combineLatestE, combineLatestWithE, zipE, zipWithE, mergeE, takeUntilE) where

import Reactive.Bacon.Core
import Reactive.Bacon.Observable
import Data.IORef
import Control.Monad
import Data.Monoid
import Control.Applicative

instance Applicative Observable where
  pure x = toObservable [x]
  (<*>) = applyE

instance Monoid (Observable a) where
  mempty = neverE
  mappend = mergeE

instance (Show a, Eq a, Num a) => Num (Observable a) where
  (+) xs ys = (+) <$> xs <*> ys
  (*) xs ys = (*) <$> xs <*> ys
  abs = fmap abs
  signum = fmap signum
  fromInteger x = toObservable [fromInteger x]

instance Show a => Show (Observable a) where
  show = const "Observable"

instance Eq a => Eq (Observable a) where
  (==) = \x y -> False

applyE :: Source s1 => Source s2 => s1 (a -> b) -> s2 a -> Observable b
applyE = combineLatestWithE ($) 

mergeE :: Source s1 => Source s2 => s1 a -> s2 a -> Observable a
mergeE xs ys = mapE simplify $ eitherE xs ys
   where simplify (Right x) = x
         simplify (Left x)  = x

mergeRawE :: Source s1 => Source s2 => s1 a -> s2 b -> Observable (Either (Event a) (Event b))
mergeRawE left right = Observable $ \observer -> do
  switcherRef <- newIORef observer
  disposeRightHolder <- newIORef Nothing
  disposeLeft <- subscribe (toObservable left) (Observer $ barrier Left switcherRef (disposeIfPossible disposeRightHolder))
  disposeRight <- subscribe (toObservable right) (Observer $ barrier Right switcherRef disposeLeft)
  writeIORef disposeRightHolder (Just disposeRight)
  return $ disposeLeft >> disposeRight
    where barrier mapping switcher disposeOther event = do
              result <- sinkSwitched switcher $ Next (mapping event)
              case result of
                 More newSink -> do
                    writeIORef switcher (Observer newSink)
                    return $ More (barrier mapping switcher disposeOther)
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

takeUntilE :: Source s1 => Source s2 => s1 a -> s2 b -> Observable a
takeUntilE src stopper = sinkMap takeUntil' $ mergeRawE src stopper
  where takeUntil' sink (Next (Left (Next x)))  = sink (Next x) >>= return . mapResult (More . takeUntil')
        takeUntil' sink (Next (Left End))       = sink End >> return NoMore
        takeUntil' sink (Next (Right (Next x))) = sink End >> return NoMore
        takeUntil' sink (Next (Right End))      = return $ More $ takeUntil' sink

zipE :: Source s1 => Source s2 => s1 a -> s2 b -> Observable (a, b)
zipE xs ys = sinkMap (zipSink [] []) (eitherE xs ys)
  where zipSink _ _ sink End                     = sink End >> return NoMore
        zipSink xs [] sink (Next(Left(x)))       = return $ More $ zipSink (xs ++ [x]) [] sink 
        zipSink [] ys sink (Next(Right(y)))      = return $ More $ zipSink [] (ys ++ [y]) sink 
        zipSink (x:xs) ys sink (Next(Right(y)))  = sink (Next (x, y)) >>= return . mapResult (More . zipSink xs ys)
        zipSink xs (y:ys) sink (Next(Left(x)))   = sink (Next (x, y)) >>= return . mapResult (More . zipSink xs ys)

zipWithE :: Source s1 => Source s2 => (a -> b -> c) -> s1 a -> s2 b -> Observable c
zipWithE f xs ys = mapE (\(a,b) -> f a b) (zipE xs ys)

eitherE :: Source s1 => Source s2 => s1 a -> s2 b -> Observable (Either a b)
eitherE left right = sinkMap skipFirstEnd $ mergeRawE left right
  where skipFirstEnd sink event | isEnd event = return $ More $ mapEnd sink
                                | otherwise   = send sink skipFirstEnd event
        mapEnd sink event | isEnd event = sink End >> return NoMore
                          | otherwise   = send sink mapEnd event 
        send sink mapper (Next (Right (Next x))) = sink (Next (Right x)) >>= return . mapResult (More . mapper)
        send sink mapper (Next (Left (Next x))) = sink (Next (Left x)) >>= return . mapResult (More . mapper)

isEnd :: Event (Either (Event a) (Event b)) -> Bool
isEnd (Next (Right End)) = True
isEnd (Next (Left End))  = True
isEnd _                  = False
