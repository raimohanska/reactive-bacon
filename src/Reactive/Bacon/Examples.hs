module Reactive.Bacon.Examples where

import Reactive.Bacon
import Reactive.Bacon.PushCollection
import Reactive.Bacon.Property
import Control.Applicative
import Control.Concurrent
import Control.Monad

pushCollectionExample = do
  pc <- newPushCollection
  pc ==> print
  push pc "lol"

mapFilterExample = do
  sequentiallyE (seconds 1) [1, 2, 3, 1] 
      >>= filterE (<3) 
      >>= mapE (("x=" ++) . show) 
      >>=! print

mergeExample = do
  c1 <- newPushCollection
  c2 <- newPushCollection
  mergeE c1 c2 >>= takeE 3 >>=! print
  push c1 "left"
  push c2 "right"
  push c1 "left2"
  push c2 "don't show me"

applicativeExample = do
  (c1, push1) <- newPushProperty
  (c2, push2) <- newPushProperty
  let combo = (+) <$> c1 <*> c2
  combo ==> print
  push1 1
  push2 2
  push1 2

numExample = do
  (xs, pushX) <- newPushProperty
  (ys, pushY) <- newPushProperty
  let sum = 100 + xs * 10 + ys
  sum ==> print
  pushX 1
  pushY 5
  pushX 2

scanExample = do
  numbers <- newPushCollection
  (scanE append [] numbers) >>= prefix "numbers=" >>=! print
  (scanE (+) 0 numbers) >>= prefix "sum=" >>=! print
  (scanE (*) 1 numbers) >>= prefix "product=" >>=! print
  push numbers 1
  push numbers 2
  push numbers 3

monadExample = do
  search <- newPushCollection
  selectManyE httpCall search 
    >>= mapE ("http://lol.com/lolServlet?search=" ++) 
    >>=! print
  push search "pron"

httpCall :: String -> IO (EventStream String)
httpCall request = return $ EventStream $ \sink -> 
                            do forkIO $ do
                                  putStrLn $ "Sending request " ++ request
                                  threadDelay 1000000
                                  sink $ Next $ "404 - NOT FOUND returned for " ++ request
                                  void $ sink $ End
                               return (return ())

prefix p e = mapE((p ++) .show) e

append :: [a] -> a -> [a]
append xs x = xs ++ [x]

