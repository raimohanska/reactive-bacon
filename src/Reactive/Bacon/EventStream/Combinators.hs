module Reactive.Bacon.EventStream.Combinators(mergeE, takeUntilE, eitherE, combineLatestE) where

import Reactive.Bacon.Core
import Reactive.Bacon.EventStream
import Reactive.Bacon.PushStream
import Reactive.Bacon.Property
import Data.IORef
import Control.Monad
import Control.Applicative

instance Show a => Show (EventStream a) where
  show = const "EventStream"

instance Eq a => Eq (EventStream a) where
  (==) = \x y -> False

mergeE :: EventSource s1 => EventSource s2 => s1 a -> s2 a -> IO (EventStream a)
mergeE xs ys = eitherE xs ys >>= mapE simplify 
   where simplify (Right x) = x
         simplify (Left x)  = x

takeUntilE :: EventSource s1 => EventSource s2 => s1 a -> s2 b -> IO (EventStream b)
takeUntilE stopper src = wrap $ sinkMap takeUntil' $ mergeRawE src stopper
  where takeUntil' sink (Next (Left (Next x)))  = sink (Next x)
        takeUntil' sink (Next (Left End))       = sink End >> return NoMore
        takeUntil' sink (Next (Right (Next x))) = sink End >> return NoMore
        takeUntil' sink (Next (Right End))      = return More

eitherE :: EventSource s1 => EventSource s2 => s1 a -> s2 b -> IO (EventStream (Either a b))
eitherE left right = do endFlag <- newIORef False
                        return $ sinkMap (skipFirstEnd endFlag) (mergeRawE left right)
  where skipFirstEnd flag sink event | isEnd event = do done <- readIORef flag
                                                        writeIORef flag True
                                                        handleEnd done sink
                                     | otherwise   = send sink skipFirstEnd event
        handleEnd True sink = sink End >> return NoMore
        handleEnd False sink = return More
        send sink mapper (Next (Right (Next x))) = sink (Next (Right x))
        send sink mapper (Next (Left (Next x))) = sink (Next (Left x))

combineLatestE :: EventSource s1 => EventSource s2 => s1 a -> s2 b -> IO (EventStream (a, b))
combineLatestE left right = do leftP <- fromEventSource left
                               rightP <- fromEventSource right
                               changesP $ combineP leftP rightP

mergeRawE :: EventSource s1 => EventSource s2 => s1 a -> s2 b -> EventStream (Either (Event a) (Event b))
mergeRawE left right = EventStream $ \sink -> do
  disposeRightHolder <- newIORef Nothing
  disposeLeft <- subscribe (toEventStream left) (barrier Left sink (disposeIfPossible disposeRightHolder))
  disposeRight <- subscribe (toEventStream right) (barrier Right sink disposeLeft)
  writeIORef disposeRightHolder (Just disposeRight)
  return $ disposeLeft >> disposeRight
    where barrier mapping sink disposeOther event = do
              result <- sink $ Next (mapping event)
              case result of
                 More -> do
                    return More
                 NoMore   -> do
                    disposeOther
                    return NoMore
          disposeIfPossible ref = do
              dispose <- readIORef ref
              case dispose of Nothing -> return () -- TODO: is it necessary to dispose later in this case?
                              Just f  -> f

isEnd :: Event (Either (Event a) (Event b)) -> Bool
isEnd (Next (Right End)) = True
isEnd (Next (Left End))  = True
isEnd _                  = False
