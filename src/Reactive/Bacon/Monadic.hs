module Reactive.Bacon.Monadic(selectManyE, switchE) where

import Data.IORef
import Reactive.Bacon.Core
import Reactive.Bacon.Applicative
import Control.Concurrent.STM
import Control.Monad

instance Monad Observable where
  return x = toObservable [x]
  (>>=) = selectManyE

selectManyE :: Source s => s a -> (a -> Observable b) -> Observable b
selectManyE xs binder = Observable $ \(Observer sink) -> do
    state <- newTVarIO $ State sink Nothing 1 [] [] False
    dispose <- subscribe (obs xs) $ Observer $ mainEventSink state
    atomically $ modifyTVar state $ \state -> state { dispose = Just dispose }
    return $ disposeAll state
  where mainEventSink state eventA = do
            case eventA of
              End    -> do
                (end, sink) <- withState state $ \s -> do
                    modifyTVar state $ \s -> s { mainEnded = True }
                    return (null (childIds s), currentSink s)
                when end $ void $ sink End
                return NoMore
              Next x -> do
                id <- withState state $ \s -> do
                  let id = counter s
                  writeTVar state $ s { counter = (counter s + 1), childIds = id : (childIds s) }
                  return id
                child <- subscribe (binder x) $ Observer $ childEventSink id state
                atomically $ modifyTVar state $ \s -> s { childDisposables = (child : childDisposables s) }
                return $ More $ mainEventSink state
        childEventSink id state = \eventB -> do
                          case eventB of
                              End    -> do
                                (end, sink) <- withState state $ \s -> do
                                  let newState = removeChild s id
                                  writeTVar state newState
                                  let end = (null (childIds newState) && mainEnded newState)
                                  return (end, currentSink newState)
                                when end $ void $ sink End
                                return NoMore 
                              Next y -> do
                                sink <- withState state $ return.currentSink
                                result <- sink (Next y)
                                case result of
                                    NoMore    -> disposeAll state >> return NoMore
                                    More sink -> do
                                      atomically (modifyTVar state $ \s -> s { currentSink = sink})
                                      return (More $ childEventSink id state)
        disposeAll state = do
              (maybeDispose, children) <- withState state $ \s -> return (dispose s, childDisposables s)
              sequence_ children
              case maybeDispose of
                  Nothing -> return () -- TODO should dispose later?
                  Just dispose -> dispose
        removeChild state id = state { childIds = filter (/= id) (childIds state) }
        withState state action = atomically (readTVar state >>= action)

switchE :: Source s => s a -> (a -> Observable b) -> Observable b
switchE src binder = (obs src) >>= (`takeUntilE` src) . binder

data State a = State { currentSink :: Sink a, 
                       dispose :: Maybe Disposable,
                       counter :: Int,
                       childIds :: [Int],
                       childDisposables :: [Disposable],
                       mainEnded :: Bool }

modifyTVar :: TVar a -> (a -> a) -> STM ()
modifyTVar var f = do
  val <- readTVar var
  writeTVar var (f val)
