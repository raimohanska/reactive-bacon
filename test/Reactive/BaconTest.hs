{-# LANGUAGE TupleSections #-}
module Reactive.BaconTest(baconTests) where

import Test.HUnit
import Reactive.Bacon
import Reactive.Bacon.PushCollection
import Reactive.Bacon.Property
import Reactive.Bacon.Examples
import Control.Concurrent.MVar
import Control.Concurrent(forkIO, threadDelay)
import Control.Monad
import Control.Applicative
import Data.IORef
import qualified Data.Set as S

baconTests = TestList $ mergeTest : eitherTest : laterTest : timedTest : filterTest
  : takeTest : mapTest : combineWithTest : combineWithLatestOfTest : throttleTest
  : combineLatestTests ++ takeUntilTests 
  ++ delayTests ++ propertyTests ++ takeWhileTests ++ pushCollectionTests ++ wrapTests 
  ++ monadTests

propertyTests = [
  propertyTest "Property can be constructed from EventStream"
    (timed [(1, "a")] >>= fromEventSource)
    ["a"]
  ,propertyTest "Property with start value"
    (timed [(1, "a")] >>= fromEventSourceWithStartValue (Just "b"))
    ["b", "a"]
  ,eventTest "changesP reports changes to property"
    (timed[(1, "a")] >>= fromEventSource >>= changesP)
    ["a"]
  ,eventTest "changesP ignores initial value"
    (timed[(1, "a")] >>= fromEventSourceWithStartValue (Just "b") >>= changesP)
    ["a"]
  ]

combineWithTest = propertyTest "combineWithP combines values of 2 properties"
  (do as <- timed [(2, "a1"), (3, "a2")] >>= fromEventSource
      bs <- timed [(1, "b1"), (3, "b2")] >>= fromEventSource
      return $ combineWithP (,) as bs
  )
  [("a1", "b1"), ("a1", "b2"), ("a2", "b2")]

combineWithLatestOfTest = propertyTest "combineWithLatestOfP combines values of 2 properties but updates only on changes to former"
  (do as <- timed [(2, "a1"), (3, "a2")] >>= fromEventSource
      bs <- timed [(1, "b1"), (3, "b2")] >>= fromEventSource
      return $ combineWithLatestOfP (,) as bs
  )
  [("a1", "b1"), ("a2", "b2")]

pushCollectionTests = [ TestLabel "PushCollection remembers End" $ TestCase $ do
                        (stream, push) <- newPushCollection
                        events <- newIORef []
                        stream ==> prependTo events
                        push $ Next "lol"
                        push End
                        push $ Next "wut"
                        eventsSoFar <- readIORef events
                        assertEqual "discards events after End" ["lol"] eventsSoFar
                      ]

wrapTests = [ TestLabel "wrap uses single connection" $ TestCase $ do 
              counter <- newIORef 0
              events <- newIORef []
              wrapped <- wrap $ countingDummyStream counter
              wrapped ==> prependTo events
              wrapped ==> devNull
              eventsSoFar <- readIORef events
              assertEqual "delivered event" ["dummy"] eventsSoFar
              calls <- readIORef counter
              assertEqual "single connection" 1 calls

            , TestLabel "wrap remembers source end" $ TestCase $ do
              wrapped <- wrap $ singleEventStream
              wrapped ==> devNull
              events <- newIORef []
              wrapped ==> prependTo events
              eventsSoFar <- readIORef events
              assertEqual "does not request more after End" [] eventsSoFar
            ]
  where countingDummyStream counter = EventStream $ \sink -> do modifyIORef counter (+1)
                                                                sink (Next "dummy")
                                                                return $ return ()
        singleEventStream = EventStream $ \sink -> do sink (Next "dummy")
                                                      sink End
                                                      return $ return ()
prependTo events event = modifyIORef events (event :)

devNull = (void . return)

laterTest = eventTest "later returns single element later"
  (laterE (units 1) "lol")
  ["lol"]

delayTests = [
  eventTest "delayE returns same elements"
    (seqE 1 [1, 2, 3] >>= delayE (units 1))
    [1, 2, 3]
  ,eventTest "delayE delays"
    (do stopper <- laterE (units 4) 0
        seqE 2 [1, 2, 3] >>= delayE (units 1) >>= takeUntilE stopper)
    [1]
  ]

throttleTest = eventTest "throttle throttles"
    (timed [(0, 1), (1, 2), (3, 3), (1, 4), (1, 5)] >>= throttleE (units 2))
    [2, 5] 

periodicTest = eventTest "periodic repeats single event periodically"
  (periodicallyE (units 1) 100 >>= takeE 2 . fst)
  [100, 100]

mergeTest = eventTest "mergeE combines events from two streams" 
    (join(mergeE <$> timed [(1, "1"), (1, "2")] <*> timed [(3, "3"), (1, "4")]))
    ["1", "2", "3", "4"]

eitherTest = eventTest "eitherE combines events from two streams" 
    (join(eitherE <$> timed [(1, "1"), (1, "2")] <*> timed [(3, "3"), (1, "4")]))
    [Left "1", Left "2", Right "3", Right "4"]

timedTest = eventTest "timed source delivers" 
  (timed [(1, "a"), (1, "b"), (0, "c")]) 
  ["a", "b", "c"]

takeUntilTests = [ 
  eventTest "takeUntil with bounded input"
    (join(takeUntilE <$> timed [(2, "stop")] <*> timed [(1, "a"), (2, "b")] ))
    ["a"]
  ,eventTest "takeUntil with endless input"
    (join(takeUntilE <$> periodic 5 "stop" <*> periodic 2 "a"))
    ["a", "a"]
  ]

takeWhileTests = [
  eventTest "takeWhileE takes while condition is true" 
    just12
    [1, 2]
  ,eventTest "takeWhileE is stateful"
    (do stream <- just12
        stream ==> (void . return)
        threadDelay $ delayMs * 3 * 1000 -- happens between first and second data
        return stream)
    [2]
  ] where just12 = (seqE 2 (concat $ repeat [1, 2, 3]) >>= takeWhileE (<3))

takeTest = eventTest "takeE takes n first elements"
    (seqE 2 [1, 2, 3] >>= takeE 2)
    [1, 2]

filterTest = eventTest "filterE filters" 
  (timed [(1, 10), (1, 20), (1, 30), (1, 10)] >>= filterE (<30)) 
  ([10, 20, 10])

mapTest = eventTest "mapE maps" 
  (timed [(1, 11), (1, 12)] >>= mapE (+1)) 
  ([12, 13])

scanTest = eventTest "scanE scans" 
  (seqE 1 [1, 2] >>= scanE (+) 0)
  [1, 3]

monadTests = [
  eventTest "selectManyE spawns new stream for each input and collects results"
  (src >>= selectManyE spawner)
  [1, 10, 2, 20, 3, 30]
  , eventTest "switchE switches between spawned streams"
  (src >>= switchE spawner)
  [1, 2, 3, 30]
  ]
 where src = seqE 3 [1, 2, 3]
       spawner x = seqE 2 [x, x * 10]

combineLatestTests = [
  eventTest "combineLatest combines" 
    (do as <- timed [(1, "a1")]
        bs <- timed [(2, "b1"), (3, "b2")]
        combineLatestE as bs) 
    [("a1", "b1"), ("a1", "b2")]
  ,eventTest "combineLatest combines" 
    (do as <- timed [(3, "a1")]
        bs <- timed [(2, "b1"), (3, "b2")]
        combineLatestE as bs) 
    [("a1", "b1"), ("a1", "b2")]
  ]

n = Next

delayMs = 20

timed :: [(Int, a)] -> IO (EventStream a)
timed events = timedE (map (\(delay, x) -> (milliseconds (delay * delayMs), x)) events) >>= return . fst

seqE :: Int -> [a] -> IO (EventStream a)
seqE delay events = timed (map (delay,) events)

periodic delay value = periodicallyE (units delay) value >>= return . fst

later delay value = laterE (units delay) value

units delay = milliseconds $ delay * delayMs

propertyTest :: PropertySource s => Ord a => Show a => Eq a => String -> IO (s a) -> [a] -> Test
propertyTest label srcAction spec = TestLabel label $ TestCase $ do
  srcAction >>= consumeAllPropertyValues >>= verifyPropertyEvents spec
  where verifyPropertyEvents expected actual = assertEqual "incorrect events" expected (justValues actual)
        justValues events = events >>= toValues
        toValues EndUpdate = []
        toValues (Initial x) = [x]
        toValues (Update x) = [x]

eventTest :: EventSource s => Ord a => Show a => Eq a => String -> IO (s a) -> [a] -> Test
eventTest label srcAction spec = TestLabel label $ TestCase $ do
  srcAction >>= consumeAll >>= verifyEvents "with single sink" spec
  srcAction >>= consumeAll2 >>= verifyEvents "with multiple sinks" spec
  where verifyEvents desc expected actual = assertEqual ("incorrect events " ++ desc) (toEvents expected) actual
        toEvents expected = map Next expected ++ [End]


-- On each Next, register new sink to verify statefulness of the stream
consumeAll2 :: EventSource s => s a -> IO [Event a]
consumeAll2 xs = do
    signal <- newEmptyMVar
    forkIO $ collect signal []
    readMVar signal >>= return . reverse
  where collect signal es = void $ subscribe (toEventStream xs) $ collector signal es
        collector signal es End   = putMVar signal (End : es) >> return NoMore
        collector signal es event = do collect signal (event : es)
                                       return NoMore

-- Consume all events from stream using a single sink
consumeAll :: EventSource s => s a -> IO [Event a]
consumeAll xs = do
    signal <- newEmptyMVar
    events <- newIORef []
    forkIO $ void $ subscribe (toEventStream xs) $ collector signal events
    readMVar signal >>= return . reverse
  where collector signal events End = readIORef events >>= \es -> putMVar signal (End : es) >> return NoMore
        collector signal events event = modifyIORef events (event : ) >> return More

-- Consume all events from stream using a single sink
consumeAllPropertyValues :: PropertySource s => s a -> IO [PropertyEvent a]
consumeAllPropertyValues xs = do
    signal <- newEmptyMVar
    events <- newIORef []
    forkIO $ void $ addPropertyListener (toProperty xs) $ collector signal events
    readMVar signal >>= return . reverse
  where collector signal events EndUpdate = readIORef events >>= \es -> putMVar signal (EndUpdate : es) >> return NoMore
        collector signal events event = modifyIORef events (event : ) >> return More

runTests = runTestTT baconTests
