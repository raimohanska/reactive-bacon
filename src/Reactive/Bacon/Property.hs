module Reactive.Bacon.Property(changesP,
                               mapP,
                               combineP,
                               combineWithP,
                               combineWithLatestOfP,
                               constantP,
                               fromEventSource,
                               fromEventSourceWithStartValue,
                               newPushProperty)
where

import Reactive.Bacon.Core
import Reactive.Bacon.EventStream
import Reactive.Bacon.PushCollection
import Control.Applicative
import Data.IORef


instance Functor Property where
  fmap = mapP

instance Applicative Property where
  (<*>) = applyP
  pure  = constantP

instance Show a => Show (Property a) where
  show = const "Property"

instance Eq a => Eq (Property a) where
  (==) = \x y -> False

instance (Show a, Eq a, Num a) => Num (Property a) where
  (+) xs ys = (+) <$> xs <*> ys
  (*) xs ys = (*) <$> xs <*> ys
  abs = fmap abs
  signum = fmap signum
  fromInteger = pure . fromInteger

instance Observable Property where
  (==>) p f = changesP p >>=! f

changesP :: PropertySource s => s a -> IO (EventStream a)
changesP s = wrap $ EventStream $ addListener (toProperty s)
  where addListener (Property addL) sink = addL $ propertySink sink
        propertySink sink (Initial _) = return More
        propertySink sink (Update x) = sink (Next x)
        propertySink sink (EndUpdate) = sink End

fromEventSourceWithStartValue :: EventSource s => Maybe a -> s a -> IO (Property a)
fromEventSourceWithStartValue start src = do
  currentRef <- newIORef start
  return $ Property (addListener' currentRef)
  where addListener' currentRef sink = do
          result <- pushCurrent currentRef sink
          case result of
            NoMore -> return $ return ()
            More -> subscribe (obs src) (toEventSink $ sink)
        pushCurrent currentRef sink = do
          current <- readIORef currentRef 
          case current of
            Just x -> sink (Initial x)
            Nothing -> return $ More
        toEventSink propertySink End = propertySink EndUpdate
        toEventSink propertySink (Next x) = propertySink (Update x)

fromEventSource :: EventSource s => s a -> IO (Property a)
fromEventSource = fromEventSourceWithStartValue Nothing

filterP :: PropertySource s => (a -> Bool) -> s a -> Property a
filterP f = mapFilterP filter'
  where filter' x | f x = Just x
                  | otherwise = Nothing

mapP :: PropertySource s => (a -> b) -> s a -> Property b
mapP f = mapFilterP (Just . f)

mapFilterP :: PropertySource s => (a -> Maybe b) -> s a -> Property b
mapFilterP f src = Property $ addListener' (toProperty src)
  where addListener' (Property addL) sink = addL $ mapSink sink
        mapSink sink EndUpdate = sink EndUpdate
        mapSink sink (Initial x) = send sink Initial $ f x
        mapSink sink (Update x) = send sink Update $ f x
        send sink constructor Nothing = return More
        send sink constructor (Just x) = sink (constructor x)


combineRaw :: PropertySource s1 => PropertySource s2 => s1 a -> s2 b -> Property (Either (a, Maybe b) (b, Maybe a))
combineRaw x y = Property addL
  where addL sink = do
          curX <- newIORef Nothing
          curY <- newIORef Nothing
          sinkRef <- newIORef sink
          endCount <- newIORef 0
          disposeX <- addPropertyListener (toProperty x) $ combineWith Left curX curY endCount sinkRef
          disposeY <- addPropertyListener (toProperty y) $ combineWith Right curY curX endCount sinkRef
          return (disposeX >> disposeY)
        combineWith f this other endCountRef sinkRef EndUpdate = do
          endCount <- readIORef endCountRef
          case endCount of
            0 -> writeIORef endCountRef 1 >> return NoMore
            _ -> readIORef sinkRef >>= \sink -> sink EndUpdate >> return NoMore
        combineWith f this other endCount sinkRef (Initial x) = 
          combineWith' f this other endCount sinkRef Update x
        combineWith f this other endCount sinkRef (Update x) = 
          combineWith' f this other endCount sinkRef Update x
        combineWith' f this other endCount sinkRef constructor x = do
          writeIORef this $ Just x
          otherVal <- readIORef other
          sink <- readIORef sinkRef
          result <- sink $ constructor $ f (x, otherVal)
          case result of
            NoMore -> writeIORef sinkRef nullSink >> return NoMore
            More -> return More
        nullSink _ = return NoMore

combineWithP :: PropertySource s1 => PropertySource s2 => (a -> b -> c) -> s1 a -> s2 b -> Property c
combineWithP f xs ys = mapFilterP mapP' $ combineRaw xs ys
  where mapP' (Left (x, Just y)) = Just $ f x y
        mapP' (Right (y, Just x)) = Just $ f x y
        mapP' _ = Nothing

combineP :: PropertySource s1 => PropertySource s2 => s1 a -> s2 b -> Property (a, b)
combineP = combineWithP (,)

-- | Combines the values from the first source to the current value of the second source
combineWithLatestOfP :: PropertySource s1 => PropertySource s2 => (a -> b -> c) -> s1 a -> s2 b -> Property c
combineWithLatestOfP f xs ys = mapFilterP mapP' $ combineRaw ys xs
  where mapP' (Right (x, Just y)) = Just $ f x y
        mapP' _ = Nothing
  

applyP :: PropertySource s1 => PropertySource s2 => s1 (a -> b) -> s2 a -> Property b
applyP = combineWithP ($)

constantP :: a -> Property a
constantP value = Property $ \sink -> sink (Initial value) >> return (return ())

newPushProperty :: IO (Property a, (a -> IO ()))
newPushProperty = do pc <- newPushCollection
                     property <- fromEventSource pc
                     return (property, push pc)
