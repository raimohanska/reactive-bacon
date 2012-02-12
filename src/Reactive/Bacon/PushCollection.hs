module Reactive.Bacon.PushCollection(PushCollection, newPushCollection, push, pushEvent, newDispatcher, wrap) where

import Reactive.Bacon.Core
import Data.IORef
import Control.Monad

data Subscription a = Subscription (EventSink a) Int
instance Eq (Subscription q) where
  (==) (Subscription _ a) (Subscription _ b) = a == b 

data PushCollection a = PushCollection (IORef ([Subscription a], Int)) (EventStream a) (IORef(Maybe Disposable)) (IORef Bool)

instance EventSource PushCollection where
  toEventStream collection = EventStream (subscribePushCollection collection)
    where subscribePushCollection pc@(PushCollection ref src dref eref) sink = do
            (subscriptions, id) <- readIORef ref
            let subscription = Subscription sink id
            writeIORef ref $ (subscription : subscriptions, id+1) 
            ended <- readIORef eref
            when (not ended && null subscriptions) $ do
              dispose <- subscribe src $ \event -> do
                pushEvent pc event
                return $ case event of
                  Next a -> More
                  End    -> NoMore
              writeIORef dref (Just dispose)
            return (removeSubscription pc subscription)

instance Observable PushCollection where
  (==>) = (==>) . obs

removeSubscription (PushCollection ref _ disposeRef _) s = do
    (subscriptions, counter) <- readIORef ref
    let updated = (removeSubscription' subscriptions)
    writeIORef ref $ (updated, counter)
    dispose <- readIORef disposeRef
    when (null updated) (unsubscribe dispose)
  where removeSubscription' sinks = filter (/= s) sinks
        unsubscribe (Just dispose)    = dispose
        unsubscribe _                 = return ()

-- | Makes an observable with a single connection to the underlying EventSource.
--   Automatically subscribes/unsubscribes from EventSource based on whether there
--   are any EventSinks.
wrap :: EventSource s => s a -> IO (EventStream a)
wrap src = newPushCollection' src >>= return . obs

newDispatcher :: ((a -> IO ()) -> IO Disposable) -> IO (EventStream a)
newDispatcher pusher = wrap $ EventStream $ \sink -> pusher (void . sink . Next)

newPushCollection' :: EventSource s => s a -> IO (PushCollection a)
newPushCollection' src = do
  stateRef <- newIORef ([], 1)
  disposeRef <- newIORef Nothing
  endRef <- newIORef False
  return $ PushCollection stateRef (obs src) disposeRef endRef

newPushCollection :: IO (PushCollection a)
newPushCollection = newPushCollection' neverE

push :: PushCollection a -> a -> IO ()
push pc item = pushEvent pc $ Next item

pushEvent :: PushCollection a -> Event a -> IO ()
pushEvent pc@(PushCollection listRef src _ endRef) event = do
    ended <- readIORef endRef
    unless ended $ do
      applyEnd event endRef
      (sinks, _) <- readIORef listRef
      mapM_  (applyTo event) sinks
  where applyTo event s@(Subscription sink _) = do 
          result <- sink event
          case result of
             More -> return ()
             NoMore -> removeSubscription pc s
        applyEnd End endRef = writeIORef endRef True
        applyEnd _ _ = return ()
