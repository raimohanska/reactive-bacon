module Reactive.BaconTest(baconTests) where

import Test.HUnit
import Reactive.Bacon
import Reactive.Bacon.Applicative
import Reactive.Bacon.Monadic
import Reactive.Bacon.PushCollection
import Reactive.Bacon.Concat
import Reactive.Bacon.IO
import Control.Concurrent.MVar
import Control.Concurrent(forkIO, threadDelay)
import Control.Monad

baconTests = TestList $ takeWhileTest : filterTest : mapTest 
  : monadTest : scanTest : timedTest : combineLatestTest 
  : takeUntilTest : repeatTest
  : concatTests ++ mergeTests ++ takeTests

concatTests = [
  eventTest "concatE with cold observable"
  (concatE [1, 2] [3, 4])
  [n 1, n 2, n 3, n 4, e]
  ,eventTest "concatE with hot observable"
  (concatE (timed [(0, 1), (1, 2)]) (timed [(0, 3), (1, 4)]))
  [n 1, n 2, n 3, n 4, e]
  ]

repeatTest = eventTest "repeat repeats indefinitely"
  (takeE 5 $ repeatE [1, 2])
  [n 1, n 2, n 1, n 2, n 1, e]

mergeTests = [
  eventTest "mergeE with cold observable" 
    (mergeE [1, 2] [3, 4]) 
    ([n 1, n 2, n 3, n 4, e])
  ,eventTest "mergeE with hot observable" 
    (mergeE (timed [(0, "1"), (1, "2")]) (timed [(2, "3"), (1, "4")])) 
    ([n "1", n "2", n "3", n "4", e])
  ]

timedTest = eventTest "timed source delivers" 
  (timed [(0, "a"), (1, "b"), (0, "c")]) 
  [n "a", n "b", n "c", e]

takeUntilTest = eventTest "takeUntil works"
  (takeUntilE (timed [(0, "a"), (2, "b")]) (timed [(1, "stop")]))
  [n "a", e]

takeWhileTest = eventTest "takeWhileE takes while condition is true" 
  (takeWhileE (<3) [1, 2, 3, 1]) 
  [n 1, n 2, e]

filterTest = eventTest "filterE filters" 
  (filterE (<3) [1, 2, 3, 1]) ([n 1, n 2, n 1, e])

mapTest = eventTest "mapE maps" (mapE (+1) [1, 2]) ([n 2, n 3, e])

scanTest = eventTest "scanE scans" (scanE (+) 0 [1, 2]) ([n 1, n 3, e])

combineLatestTest = eventTest "combineLatest combines" (combineLatestE (timed [(0, "a1")]) (timed [(1, "b1"), (1, "b2")])) [n ("a1", "b1"), n ("a1", "b2"), e]

monadTest = eventTest ">>= collects all events from substreams"
  (obs [1, 2, 3] >>= \n -> timed [(n, n)])
  [n 1, n 2, n 3, e]

takeTests = [
  eventTest "takeE takes N first events" (takeE 3 [1, 2, 3, 1]) ([n 1, n 2, n 3, e])
  ,eventTest "takeE ends if source ends" (takeE 3 [1, 2]) ([n 1, n 2, e])
  ]

n = Next
e = End
timed :: [(Int, a)] -> Observable a
timed events = Observable $ \observer -> do
    forkIO $ serve observer events
    return $ return ()
  where serve observer [] = consume observer End >> return ()
        serve observer ((delay, event) : events) = do
          threadDelay $ delay * 100 * 1000
          result <- consume observer $ Next event
          case result of
            NoMore -> return ()
            More sink -> serve (Observer sink) events

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
