module Reactive.Bacon.PushCollection(PushCollection, newPushCollection, push, pushEvent, newDispatcher) where

import Reactive.Bacon.Core
import Data.IORef
import Control.Monad

data Subscription a = Subscription (Observer a) Int
instance Eq (Subscription q) where
  (==) (Subscription _ a) (Subscription _ b) = a == b 

data PushCollection a = PushCollection (IORef ([Subscription a], Int)) (Observable a) (IORef(Maybe Disposable))

-- TODO use STM
instance Source PushCollection where
  toObservable collection = Observable (subscribePushCollection collection)
    where subscribePushCollection pc@(PushCollection ref src dref) observer = do
            (subscriptions, id) <- readIORef ref
            let subscription = Subscription observer id
            writeIORef ref $ (subscription : subscriptions, id+1) 
            when (null subscriptions) $ do
              dispose <- subscribe src $ toObserver $ push pc
              writeIORef dref (Just dispose)
            return (removeSubscription pc subscription)

removeSubscription (PushCollection ref _ disposeRef) s = do
    (subscriptions, counter) <- readIORef ref
    let updated = (removeSubscription' subscriptions)
    writeIORef ref $ (updated, counter)
    dispose <- readIORef disposeRef
    when (null updated) (unsubscribe dispose)
  where removeSubscription' observers = filter (/= s) observers
        unsubscribe (Just dispose)    = dispose
        unsubscribe _                 = return ()

-- | Makes an observable with a single connection to the underlying source.
--   Automatically subscribes/unsubscribes from source based on whether there
--   are any Observers.
newDispatcher :: Source s => s a -> IO (Observable a)
newDispatcher src = newPushCollection' src >>= return . obs

newPushCollection' :: Source s => s a -> IO (PushCollection a)
newPushCollection' src = do
  stateRef <- newIORef ([], 1)
  disposeRef <- newIORef Nothing
  return $ PushCollection stateRef (obs src) disposeRef

newPushCollection :: IO (PushCollection a)
newPushCollection = newPushCollection' neverE

push :: PushCollection a -> a -> IO ()
push pc item = pushEvent pc $ Next item

pushEvent :: PushCollection a -> Event a -> IO ()
pushEvent pc@(PushCollection listRef src _) event = do
    (observers, _) <- readIORef listRef
    mapM_  (applyTo event) observers
  where applyTo event s@(Subscription observer _) = do 
          result <- consume observer event
          case result of
             More ob2 -> replaceObserver listRef s (Observer ob2)
             NoMore -> removeSubscription pc s
        replaceObserver ref (Subscription _ id) newObserver = modifyIORef ref replaceObserver'
            where replaceObserver' (subscriptions, counter) = (map replace subscriptions, counter)
                  replace s@(Subscription _ id2) | id2 == id = Subscription newObserver id
                                                 | otherwise = s

