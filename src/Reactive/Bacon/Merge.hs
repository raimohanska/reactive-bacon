module Reactive.Bacon.Merge where

import Reactive.Bacon
import Data.IORef
import Control.Monad

mergeE :: Source s1 => Source s2 => s1 a -> s2 a -> Observable a
mergeE left right = Observable $ \observer -> do
  endLeftRef <- newIORef False
  endRightRef <- newIORef False
  switcherRef <- newIORef observer
  disposeLeft <- subscribe (getObservable left) (Observer $ barrier endLeftRef endRightRef switcherRef)
  disposeRight <- subscribe (getObservable right) (Observer $ barrier endRightRef endLeftRef switcherRef)
  return $ disposeLeft >> disposeRight
    where barrier myFlag otherFlag switcher End = do 
              writeIORef myFlag True
              otherDone <- readIORef otherFlag
              if otherDone
                 then sinkSwitched switcher End
                 else return NoMore
          barrier myFlag otherFlag switcher event = do
              result <- sinkSwitched switcher event
              case result of
                 More newSink -> do
                    writeIORef switcher (Observer newSink)
                    return $ More (barrier myFlag otherFlag switcher)
                 NoMore   -> return NoMore
          sinkSwitched switcher event = do
              observer <- readIORef switcher
              consume observer event
