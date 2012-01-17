module Reactive.Bacon.Core where

import Control.Monad
import Prelude hiding (map, filter)

data Observable a = Observable { subscribe :: (Observer a -> IO Disposable) }

data Observer a = Observer { consume :: Sink a }

type Sink a = (Event a -> IO (HandleResult a))

data HandleResult a = More (Sink a) | NoMore

data Event a = Next a | End

type Disposable = IO ()

class Source s where
  toObservable :: s a -> Observable a

instance Source Observable where
  toObservable = id

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

obs :: Source s => s a -> Observable a
obs = toObservable

