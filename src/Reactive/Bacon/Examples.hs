module Reactive.Bacon.Examples where

import Reactive.Bacon
import Reactive.Bacon.PushCollection

pushCollectionExample = do
  pc <- newPushCollection
  pc ==> print
  push pc "lol"

listExample = do
  takeWhileE (<3) [1,2,3,4,1] ==> print

pushCollectionMapFilterExample = do
  pc <- newPushCollection
  mapE (("x=" ++) . show) (filterE (<3) pc) ==> print
  push pc 1
  push pc 2
  push pc 3
  push pc 1
