module Reactive.Bacon.PushCollection(PushCollection, newPushCollection, push, publishE) where

import Reactive.Bacon
import Data.IORef
import Control.Monad

data Subscription a = Subscription (Observer a) Int
instance Eq (Subscription q) where
  (==) (Subscription _ a) (Subscription _ b) = a == b 

data PushCollection a = PushCollection (IORef ([Subscription a], Int))

instance Source PushCollection where
  getObservable collection = Observable (subscribePushCollection collection)

subscribePushCollection (PushCollection ref) observer = do
        (subscriptions, id) <- readIORef ref
        let subscription = Subscription observer id
        writeIORef ref $ (subscription : subscriptions, id+1) 
        return (removeSubscription ref subscription)

removeSubscription ref s = modifyIORef ref removeSubscription'
    where removeSubscription' (observers, counter) = (filter (/= s) observers, counter)

replaceObserver ref (Subscription _ id) newObserver = modifyIORef ref replaceObserver'
    where replaceObserver' (subscriptions, counter) = (map replace subscriptions, counter)
          replace s@(Subscription _ id2) | id2 == id = Subscription newObserver id
                                         | otherwise = s
  
newPushCollection :: IO (PushCollection a)
newPushCollection = liftM PushCollection (newIORef ([], 1))

push :: PushCollection a -> a -> IO ()
push pc item = pushEvent pc $ Next item

pushEvent :: PushCollection a -> Event a -> IO ()
pushEvent (PushCollection listRef) event = do
    (observers, _) <- readIORef listRef
    mapM_  (applyTo event) observers
  where applyTo event s@(Subscription observer _) = do 
          result <- consume observer event
          case result of
             More ob2 -> replaceObserver listRef s (Observer ob2)
             NoMore -> removeSubscription listRef s

-- |Returns new Observable with a single, persistent connection to the wrapped observable
-- Also returns Disposable for disconnecting from the source
publishE :: Source s => s a -> IO (Observable a, Disposable)
publishE src = do
  pushCollection <- newPushCollection
  dispose <- subscribe (obs src) $ toEventObserver $ (pushEvent pushCollection)
  return (obs pushCollection, dispose)

