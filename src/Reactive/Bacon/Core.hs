module Reactive.Bacon.Core where

import Control.Monad
import Prelude hiding (map, filter)

class Observable s where
  (==>) :: s a -> (a -> IO()) -> IO ()
  (>>=!) :: IO (s a) -> (a -> IO()) -> IO ()
  (>>=!) action f = action >>= \observable -> (observable ==> f)
  infixl 1 >>=!

data EventStream a = EventStream { subscribe :: (EventSink a -> IO Disposable) }
type EventSink a = (Event a -> IO (HandleResult))
data Event a = Next a | End

data HandleResult = More | NoMore
type Disposable = IO ()

class EventSource s where
  toEventStream :: s a -> EventStream a

instance EventSource EventStream where
  toEventStream = id

instance Observable EventStream where
  (==>) src f = void $ subscribe (toEventStream src) $ toObserver f

instance Functor Event where
  fmap f (Next a)  = Next (f a)
  fmap _ End       = End

instance Show a => Show (Event a) where
  show (Next x) = show x
  show End      = "<END>"

instance Eq a => Eq (Event a) where
  (==) End End = True
  (==) (Next x) (Next y) = (x==y)
  (==) _ _ = False

obs :: EventSource s => s a -> EventStream a
obs = toEventStream

neverE :: EventStream a
neverE = EventStream $ \_ -> return $ (return ())

toObserver :: (a -> IO()) -> EventSink a
toObserver next = sink
  where sink (Next x) = next x >> return More
        sink End = return NoMore

toEventObserver :: (Event a -> IO()) -> EventSink a
toEventObserver next = sink
  where sink event = next event >> return More

-- | Reactive property. Differences from EventStream:
--   - addListener function must always deliver the latest known value to the new listener
--
--   So a Property is roughly an EventStream that stores its latest value so
--   that it is always available for new listeners. Doesn't mean it has to be
--   up to date if it has been without listeners for a while.
data Property a = Property { addPropertyListener :: PropertySink a -> IO Disposable } 

class PropertySource s where
  toProperty :: s a -> Property a

instance PropertySource Property where
  toProperty = id

data PropertyEvent a = Initial a | Update a | EndUpdate

type PropertySink a = PropertyEvent a -> IO HandleResult
