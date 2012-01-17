module Reactive.Bacon.Timed where

import Reactive.Bacon.Core
import Reactive.Bacon.IO
import Reactive.Bacon.Concat
import Reactive.Bacon.PushCollection
import Reactive.Bacon.Monadic
import System.Time
import Control.Concurrent(threadDelay, forkIO)
import Control.Monad(void)

laterE :: TimeDiff -> a -> Observable a
laterE diff x = fromIO $ threadDelay (toMicros diff) >> return x

periodicallyE :: TimeDiff -> a -> Observable a
periodicallyE diff x = repeatE (laterE diff x)

delayE :: Source s => TimeDiff -> s a -> Observable a
delayE diff xs = obs xs >>= laterE diff

throttleE :: Source s => TimeDiff -> s a -> Observable a
throttleE diff xs = obs xs `switchE` laterE diff

-- | create a published stream, starting after given delay,
--   maintaining a single, persistent, connection to the given observable
atFixedTime :: Source s => TimeDiff -> s a -> IO (Observable a)
atFixedTime diff src = do
  (published, _) <- publishE (delayE diff src)
  return published

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

