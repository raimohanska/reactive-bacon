{-# LANGUAGE TupleSections #-}
module Reactive.Bacon.EventStream.Timed where

import Reactive.Bacon.Core
import Reactive.Bacon.EventStream.IO
import Reactive.Bacon.PushCollection
import Reactive.Bacon.EventStream.Monadic
import System.Time
import Control.Concurrent(threadDelay, forkIO)
import Control.Monad(void, unless)
import Data.IORef

laterE :: TimeDiff -> a -> IO (EventStream a)
laterE diff x = timedE [(diff, x)] >>= return . fst

periodicallyE :: TimeDiff -> a -> IO (EventStream a, Disposable)
periodicallyE diff x = timedE (repeat (diff, x))

sequentiallyE :: TimeDiff -> [a] -> IO (EventStream a)
sequentiallyE delay xs = timedE (map (delay,) xs) >>= return . fst

timedE :: [(TimeDiff, a)] -> IO (EventStream a, Disposable)
timedE events = fromStoppableProcess $ \sink stopper -> void $ forkIO $ serve sink events stopper
  where serve sink [] _ = sink End
        serve sink ((diff, event) : events) getStopState = do
          stop <- getStopState
          unless stop $ do
            threadDelay (toMicros diff)
            sink $ Next event
            serve sink events getStopState

delayE :: EventSource s => TimeDiff -> s a -> IO (EventStream a)
delayE diff = selectManyE (laterE diff)

throttleE :: EventSource s => TimeDiff -> s a -> IO (EventStream a)
throttleE diff = switchE (laterE diff)

toMicros :: TimeDiff -> Int
toMicros diff = fromInteger((toPicos diff) `div` 1000000)
 where
    toPicos :: TimeDiff -> Integer
    toPicos (TimeDiff 0 0 0 h m s p) = p + (fromHours h) + (fromMinutes m) + (fromSeconds s)
      where fromSeconds s = 1000000000000 * (toInteger s)
            fromMinutes m = 60 * (fromSeconds m)
            fromHours   h = 60 * (fromMinutes h)

-- | Milliseconds to TimeDiff
milliseconds :: Integral a => a -> TimeDiff
milliseconds ms = noTimeDiff { tdPicosec = (toInteger ms) * 1000000000}

-- | Seconds to TimeDiff
seconds :: Integral a => a -> TimeDiff
seconds = milliseconds . (*1000)

