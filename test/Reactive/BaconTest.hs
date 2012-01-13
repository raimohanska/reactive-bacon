module Reactive.BaconTest(baconTests) where

import Test.HUnit
import Reactive.Bacon
import Reactive.Bacon.Applicative
import Reactive.Bacon.Monadic
import Reactive.Bacon.PushCollection
import Control.Concurrent.MVar
import Control.Concurrent(forkIO)
import Control.Monad

baconTests = TestList $ mergeTests

mergeTests = [
  eventTest "mergeE produces events from both + End" (mergeE [1, 2] [3, 4]) ([n 1, n 2, n 3, n 4, e])
  ]

n = Next
e = End

eventTest :: Source s => Show a => Eq a => String -> s a -> [Event a] -> Test
eventTest label observable expected = TestLabel label $ TestCase $ do
  actual <- consumeAll observable
  assertEqual "incorrect events" expected actual

consumeAll :: Source s => s a -> IO [Event a]
consumeAll xs = do
    signal <- newEmptyMVar
    forkIO $ void $ subscribe (getObservable xs) $ Observer $ collector signal []
    readMVar signal >>= return . reverse
  where collector signal es End   = putMVar signal (End : es) >> return NoMore
        collector signal es event = return $ More $ collector signal (event : es)

runTests = runTestTT baconTests
