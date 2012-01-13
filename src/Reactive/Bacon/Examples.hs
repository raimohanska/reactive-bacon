module Reactive.Bacon.Examples where

import Reactive.Bacon
import Reactive.Bacon.PushCollection
import Reactive.Bacon.Merge

pushCollectionExample = do
  pc <- newPushCollection
  pc ==> print
  push pc "lol"

listExample = do
  takeWhileE (<3) [1,2,3,4,1] ==> print

pushCollectionMapFilterExample = do
  pc <- newPushCollection
  mapE (("x=" ++) . show) (takeWhileE (<3) pc) ==> print
  push pc 1
  push pc 2
  push pc 3
  push pc 1

mergeExample = do
  c1 <- newPushCollection
  c2 <- newPushCollection
  let all = mergeE c1 c2
  let firstTwoWords = takeE 2 all
  firstTwoWords ==> print
  push c1 "left"
  push c2 "right"
  push c2 "don't show me"
