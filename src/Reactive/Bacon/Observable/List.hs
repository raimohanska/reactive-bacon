module Reactive.Bacon.Observable.List where

import Reactive.Bacon.Core

instance Source [] where
  toObservable = observableList

observableList list = Observable subscribe 
  where subscribe (Observer sink) = feed sink list >> return (return ())
        feed sink (x:xs) = do result <- sink $ Next x
                              case result of
                                 More o2 -> feed o2 xs
                                 NoMore  -> return ()
        feed sink _      = sink End >> return ()


