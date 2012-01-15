module Reactive.Bacon.Timed where

import Reactive.Bacon
import Reactive.Bacon.IO
import Reactive.Bacon.Concat
import System.Time
import Control.Concurrent(threadDelay, forkIO)
import Control.Monad(void)

laterE :: TimeDiff -> a -> Observable a
laterE diff x = fromIO $ threadDelay (toMicros diff) >> return x

periodicallyE :: TimeDiff -> a -> Observable a
periodicallyE diff x = repeatE (laterE diff x)

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

