{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances, FunctionalDependencies #-}

module Reactive.BaconTest(baconTests) where

import Test.HUnit
import Reactive.Bacon
import Reactive.Bacon.Applicative
import Reactive.Bacon.Monadic
import Reactive.Bacon.PushCollection
import Reactive.Bacon.Concat
import Reactive.Bacon.IO
import Reactive.Bacon.Timed
import Control.Concurrent.MVar
import Control.Concurrent(forkIO, threadDelay)
import Control.Monad
import qualified Data.Set as S

baconTests = TestList $ takeWhileTest : filterTest : mapTest 
  : scanTest : timedTest : combineLatestTest 
  : repeatTest : laterTest : periodicTest
  : takeUntilTests ++ switchTests ++ publishTests
  ++ monadTests ++ concatTests ++ mergeTests ++ takeTests

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

laterTest = eventTest "later returns single element later"
  (laterE (milliseconds delayMs) "lol")
  [n "lol", e]

periodicTest = eventTest "periodic repeats single event periodically"
  (takeE 2 $ periodicallyE (milliseconds delayMs) "lol")
  [n "lol", n "lol", e]

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

takeUntilTests = [ 
  eventTest "takeUntil with bounded input"
    (takeUntilE (timed [(0, "a"), (2, "b")]) (timed [(1, "stop")]))
    [n "a", e]
  ,eventTest "takeUntil with endless input"
    (takeUntilE (periodic 2 "a") (periodic 5 "stop")) 
    [n "a", n "a", e]
  ]

takeWhileTest = eventTest "takeWhileE takes while condition is true" 
  (takeWhileE (<3) [1, 2, 3, 1]) 
  [n 1, n 2, e]

filterTest = eventTest "filterE filters" 
  (filterE (<3) [1, 2, 3, 1]) ([n 1, n 2, n 1, e])

mapTest = eventTest "mapE maps" (mapE (+1) [1, 2]) ([n 2, n 3, e])

scanTest = eventTest "scanE scans" (scanE (+) 0 [1, 2]) ([n 1, n 3, e])

combineLatestTest = eventTest "combineLatest combines" (combineLatestE (timed [(0, "a1")]) (timed [(1, "b1"), (1, "b2")])) [n ("a1", "b1"), n ("a1", "b2"), e]

monadTests = [
  eventTest ">>= collects events from cold observable with hot sub-observables"
    (obs [1, 2, 3] >>= \n -> timed [(n, n)])
    [n 1, n 2, n 3, e]
  ,eventTest ">>= collects events from simultaneously returning substreams"
    ((obs [1, 2, 3]) >>= (later 2))
    (UnOrdered [1, 2, 3])
  ,eventTest ">>= collects events from cold sub-observables"
    ((obs [1, 2, 3]) >>= return)
    [n 1, n 2, n 3, e]
  ,eventTest ">>= collects events from hot observable with hot sub-observables"
    ((timed [(0, 1), (1, 2), (1, 3)]) >>= (later 2))
    [n 1, n 2, n 3, e]
  ]

switchTests = [ 
  eventTest "switch with cold observables is like >>="
    ([1, 2, 3] `switchE` return)
    [n 1, n 2, n 3, e]
  ,eventTest "switch with cold observables & hot subs is empty"
    ([1, 2, 3] `switchE` (later 1))
    [e]
  ,publishedEventTest "switch switches between sub-observables on each new main event"
    (timed [(0, "a"), (1, "b"), (3, "c")])
    (\src -> src `switchE` (later 2))
    [n "b", n "c", e]
  ,eventTest "doesn't work well for cold main observable, because is based on takeUntilE"
    ((timed [(0, "a"), (1, "b"), (3, "c")]) `switchE` (later 2))
    [e]
  ]

takeTests = [
  eventTest "takeE takes N first events" (takeE 3 [1, 2, 3, 1]) ([n 1, n 2, n 3, e])
  ,eventTest "takeE ends if source ends" (takeE 3 [1, 2]) ([n 1, n 2, e])
  ]

publishTests = [
  publishedEventTest "publish produces same results for hot observable"
    (timed [(1, "a"), (2, "b")])
    id
    [n "a", n "b", e]
  ,publishedEventTest "publish consumes a cold observable immediately"
    ([1, 2, 3] <++> later 1 4)
    id
    [n 4, e]
  ]

n = Next
e = End

delayMs = 100

timed :: [(Int, a)] -> Observable a
timed events = Observable $ \observer -> do
    forkIO $ serve observer events
    return $ return ()
  where serve observer [] = consume observer End >> return ()
        serve observer ((delay, event) : events) = do
          threadDelay $ delay * delayMs * 1000
          result <- consume observer $ Next event
          case result of
            NoMore -> return ()
            More sink -> serve (Observer sink) events

periodic delay value = periodicallyE (milliseconds $ delay * delayMs) value

later delay value = laterE (milliseconds $ delay * delayMs) value

class EventSpec a s | s -> a where
  verifyEvents :: s -> [Event a] -> Assertion

instance (Show a, Eq a) => (EventSpec a) [Event a] where
  verifyEvents expected actual = assertEqual "incorrect events" expected actual

data UnOrdered a = UnOrdered [a]

instance (Show a, Eq a, Ord a) => (EventSpec a) (UnOrdered a) where
  verifyEvents (UnOrdered expected) actualEvents = do
      let actualItems = actualEvents >>= item
      when ((S.fromList actualItems) /= (S.fromList expected)) $ assertEqual "incorrect events" expected actualItems
    where item End = []
          item (Next a) = [a]

--publishedEventTest :: EventSpec a sp => Source s => Show a => Eq a => String -> s a -> sp -> Test
publishedEventTest label observable modifier spec = TestLabel label $ TestCase $ do
  (published, dispose) <- publishE observable
  verifyObservable (modifier published) spec
  dispose

eventTest :: EventSpec a sp => Source s => Show a => Eq a => String -> s a -> sp -> Test
eventTest label observable spec = TestLabel label $ TestCase $ do
  verifyObservable observable spec

verifyObservable observable spec = do
  actual <- consumeAll observable
  verifyEvents spec actual

consumeAll :: Source s => s a -> IO [Event a]
consumeAll xs = do
    signal <- newEmptyMVar
    forkIO $ void $ subscribe (getObservable xs) $ Observer $ collector signal []
    readMVar signal >>= return . reverse
  where collector signal es End   = putMVar signal (End : es) >> return NoMore
        collector signal es event = return $ More $ collector signal (event : es)

runTests = runTestTT baconTests
