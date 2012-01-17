module Reactive.BaconTest(baconTests) where

import Test.HUnit
import Reactive.Bacon
import Reactive.Bacon.PushCollection
import Control.Concurrent.MVar
import Control.Concurrent(forkIO, threadDelay)
import Control.Monad
import qualified Data.Set as S

baconTests = TestList $ takeWhileTest : filterTest : mapTest 
  : scanTest : timedTest : combineLatestTest 
  : repeatTest : laterTest : periodicTest
  : takeUntilTests ++ switchTests ++ publishTests ++ zipTests
  ++ monadTests ++ concatTests ++ mergeTests ++ takeTests
  ++ delayTests ++ throttleTests

concatTests = [
  eventTest "concatE with cold observable"
  (concatE [1, 2] [3, 4])
  [1, 2, 3, 4]
  ,eventTest "concatE with hot observable"
  (concatE (timed [(0, 1), (1, 2)]) (timed [(0, 3), (1, 4)]))
  [1, 2, 3, 4]
  ]

repeatTest = eventTest "repeat repeats indefinitely"
  (takeE 5 $ repeatE [1, 2])
  [1, 2, 1, 2, 1]

laterTest = eventTest "later returns single element later"
  (laterE (units 1) "lol")
  ["lol"]

delayTests = [
  eventTest "delay returns same elements"
    (delayE (units 1) [1, 2, 3])
    [1, 2, 3]
  ,eventTest "elements are delayed"
    (takeUntilE (delayE (units 2) $ timed [(0, 1), (1, 2), (2, 3)]) (later 4 ["stop"]))
    [1, 2]
  ]

throttleTests = [
  publishedEventTest "throttle throttles"
    (timed [(0, 1), (1, 2), (3, 3), (1, 4), (1, 5)])
    (throttleE (units 2))
    [2, 5] 
  ]

periodicTest = eventTest "periodic repeats single event periodically"
  (takeE 2 $ periodicallyE (units 1) "lol")
  ["lol", "lol"]

mergeTests = [
  eventTest "mergeE with cold observable" 
    (mergeE [1, 2] [3, 4]) 
    ([1, 2, 3, 4])
  ,eventTest "mergeE with hot observable" 
    (mergeE (timed [(0, "1"), (1, "2")]) (timed [(2, "3"), (1, "4")])) 
    (["1", "2", "3", "4"])
  ]

timedTest = eventTest "timed source delivers" 
  (timed [(0, "a"), (1, "b"), (0, "c")]) 
  ["a", "b", "c"]

takeUntilTests = [ 
  eventTest "takeUntil with bounded input"
    (takeUntilE (timed [(0, "a"), (2, "b")]) (timed [(1, "stop")]))
    ["a"]
  ,eventTest "takeUntil with endless input"
    (takeUntilE (periodic 2 "a") (periodic 5 "stop")) 
    ["a", "a"]
  ]

takeWhileTest = eventTest "takeWhileE takes while conditiois true" 
  (takeWhileE (<3) [1, 2, 3, 1]) 
  [1, 2]

filterTest = eventTest "filterE filters" 
  (filterE (<3) [1, 2, 3, 1]) ([1, 2, 1])

mapTest = eventTest "mapE maps" (mapE (+1) [1, 2]) ([2, 3])

scanTest = eventTest "scanE scans" (scanE (+) 0 [1, 2]) ([1, 3])

combineLatestTest = eventTest "combineLatest combines" 
  (combineLatestE (timed [(0, "a1")]) (timed [(1, "b1"), (1, "b2")])) 
  [("a1", "b1"), ("a1", "b2")]

zipTests = [
  eventTest "zipE zips lists"
    (zipE [1,2,3] [4,5,6]) 
    [(1,4), (2,5), (3,6)]
  ,eventTest "zipE zips lists with hot observables"
    (zipE [1,2,3] (timed [(0, 4), (1, 5), (1, 6)])) 
    [(1,4), (2,5), (3,6)]
  ]

monadTests = [
  eventTest ">>= collects events from cold observable with hot sub-observables"
    (obs [1, 2, 3] >>= \n -> timed [(n, n)])
    [1, 2, 3]
  ,eventTest ">>= collects events from simultaneously returning substreams"
    ((obs [1, 2, 3]) >>= (later 2))
    (UnOrdered [1, 2, 3])
  ,eventTest ">>= collects events from cold sub-observables"
    ((obs [1, 2, 3]) >>= return)
    [1, 2, 3]
  ,eventTest ">>= collects events from hot observable with hot sub-observables"
    ((timed [(0, 1), (1, 2), (1, 3)]) >>= (later 2))
    [1, 2, 3]
  ]

switchTests = [ 
  eventTest "switch with cold observables is like >>="
    ([1, 2, 3] `switchE` return)
    [1, 2, 3]
  ,eventTest "switch with cold observables & hot subs is empty"
    ([1, 2, 3] `switchE` (later 1))
    []
  ,publishedEventTest "switch switches betweesub-observables on each new main event"
    (timed [(0, "a"), (1, "b"), (3, "c")])
    (\src -> src `switchE` (later 2))
    ["b", "c"]
  ,eventTest "doesn't work well for cold main observable, because is based on takeUntilE"
    ((timed [(0, "a"), (1, "b"), (3, "c")]) `switchE` (later 2))
    []
  ]

takeTests = [
  eventTest "takeE takes N first events" (takeE 3 [1, 2, 3, 1]) ([1, 2, 3])
  ,eventTest "takeE ends if source ends" (takeE 3 [1, 2]) ([1, 2])
  ]

publishTests = [
  publishedEventTest "publish produces same results for hot observable"
    (timed [(1, "a"), (2, "b")])
    id
    ["a", "b"]
  ,publishedEventTest "publish consumes a cold observable immediately"
    ([1, 2, 3] <++> later 1 4)
    id
    [4]
  ]

n = Next

delayMs = 10

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

periodic delay value = periodicallyE (units delay) value

later delay value = laterE (units delay) value

units delay = milliseconds $ delay * delayMs

class EventSpec s where
  verifyEvents :: Ord a => Eq a => Show a => s a -> [Event a] -> Assertion

instance EventSpec [] where
  verifyEvents expected actual = assertEqual "incorrect events" expectedEvents actual
    where expectedEvents = map Next expected ++ [End]

data UnOrdered a = UnOrdered [a]

instance EventSpec (UnOrdered) where
  verifyEvents (UnOrdered expected) actualEvents = do
      let actualItems = actualEvents >>= item
      when ((S.fromList actualItems) /= (S.fromList expected)) $ assertEqual "incorrect events" expected actualItems
    where item End = []
          item (Next a) = [a]

-- | creates a published observable, applies given mapping to that, then
-- tests it. Why? to simulate a real-life hot observable that doesn't
-- spit out a new stream of events for each observer
publishedEventTest label observable modifier spec = TestLabel label $ TestCase $ do
  (published, dispose) <- publishE observable
  verifyObservable (modifier published) spec
  dispose

eventTest :: EventSpec sp => Source s => Ord a => Show a => Eq a => String -> s a -> sp a -> Test
eventTest label observable spec = TestLabel label $ TestCase $ do
  verifyObservable observable spec

verifyObservable observable spec = do
  actual <- consumeAll observable
  verifyEvents spec actual

consumeAll :: Source s => s a -> IO [Event a]
consumeAll xs = do
    signal <- newEmptyMVar
    forkIO $ void $ subscribe (toObservable xs) $ Observer $ collector signal []
    readMVar signal >>= return . reverse
  where collector signal es End   = putMVar signal (End : es) >> return NoMore
        collector signal es event = return $ More $ collector signal (event : es)

runTests = runTestTT baconTests
