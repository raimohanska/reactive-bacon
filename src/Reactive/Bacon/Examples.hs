module Reactive.Bacon.Examples where

import Reactive.Bacon
import Reactive.Bacon.PushCollection
import Reactive.Bacon.Applicative
import Reactive.Bacon.Monadic
import Control.Applicative
import Control.Concurrent
import Control.Monad

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
  let firstThreeWords = takeE 3 all
  firstThreeWords ==> print
  push c1 "left"
  push c2 "right"
  push c1 "left2"
  push c2 "don't show me"

combineLatestExample = do
  c1 <- newPushCollection
  c2 <- newPushCollection
  let combo = combineLatestE c1 c2
  --eitherE c1 c2 ==> print
  takeE 2 combo ==> print
  --combo ==> print
  push c1 "left"
  push c2 "right"
  push c1 "left2"
  push c2 "don't show me"

applicativeExample = do
  c1 <- newPushCollection
  c2 <- newPushCollection
  let combo = (+) <$> (obs c1) <*> (obs c2)
  combo ==> print
  push c1 1
  push c2 2
  push c1 2

numExample = do
  xs <- newPushCollection
  ys <- newPushCollection
  let sum = 100 + (obs xs) * 10 + (obs ys)
  sum ==> print
  push xs 1
  push ys 5
  push xs 2

scanExample = do
  numbers <- newPushCollection
  prefix "numbers=" (scanE append [] numbers) ==> print
  prefix "sum=" (scanE (+) 0 numbers) ==> print
  prefix "product=" (scanE (*) 1 numbers) ==> print
  push numbers 1
  push numbers 2
  push numbers 3

disposeExample = do
  messages <- newPushCollection
  dispose1 <- prefix "d1=" messages |=> print
  prefix "d2=" messages ==> print
  push messages "print me twice"
  dispose1
  push messages "print me once"

monadExample = do
  requests <- newPushCollection
  let responses = (obs requests) >>= ajaxCall
  responses ==> print
  push requests "http://lol.com/lolServlet"

ajaxCall :: String -> (Observable String)
ajaxCall request = Observable $ \observer -> 
                            do forkIO $ do
                                  threadDelay 1000000
                                  consume observer $ Next "404 - NOT FOUND"
                                  void $ consume observer $ End
                               return (return ())

prefix p e = mapE((p ++) .show) e
append :: [a] -> a -> [a]
append xs x = xs ++ [x]

