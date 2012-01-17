module Reactive.Bacon.Property where

import Reactive.Bacon
import Control.Applicative

-- | Reactive property. Differences from Observable:
--   - Does not have an end
--   - addListener function must always deliver the latest known value to the new listener
--
--   So a Property is roughly an Observable that stores its latest value so
--   that it is always available for new listeners. Doesn't mean it has to be
--   up to date if it has been without listeners for a while.
data Property a = Property { addListener :: (PropertyListener a -> IO Disposable) }

type PropertyListener a = (a -> IO (PropertyListenerResult a))

data PropertyListenerResult a = More (PropertyListener a) | NoMore

class PropertySource s where
  toProperty :: s a -> Property a

instance PropertySource Property where
  toProperty = id

instance PropertySource Observable where
  toProperty = fromEventSource 

instance Source Property where
  toObservable = changesP

instance Functor Property where
  fmap = mapP

instance Applicative Property where
  (<*>) = applyP
  pure  = constantE

data ObservableWithStartValue a = OWS (Observable a) a

instance PropertySource ObservableWithStartValue where
  toProperty = undefined

fromEventSource :: Source s => s a -> Property a 
fromEventSource  = undefined
  -- TODO: store latest value, deliver that in addListener

-- | creates Observable with Property-like behavior:
--   delivers latest event on subscribe
changesP :: PropertySource s => s a -> Observable a
changesP = undefined
-- | some simple conversion here

mapP :: PropertySource s => (a -> b) -> s a -> Property b
mapP f = omap $ mapE f

filterP :: PropertySource s => (a -> Bool) -> s a -> Property a
filterP f = omap $ filterE f 

combineWithP :: PropertySource s1 => PropertySource s2 => (a -> b -> c) -> s1 a -> s2 b -> Property c
combineWithP f xs ys = toProperty $ combineLatestWithE f (changesP xs) (changesP ys)

omap f = fromEventSource . f . changesP

applyP :: PropertySource s1 => PropertySource s2 => s1 (a -> b) -> s2 a -> Property b
applyP = combineWithP ($) 

constantE :: a -> Property a
constantE value = fromEventSource [value]
