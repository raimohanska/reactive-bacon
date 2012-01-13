reactive-bacon
==============

FRP (functional reactive programming) framework inspired by RX and Iteratee. 

Main concepts are:

- `Event a`      : an event of type a. Either `Next a` or `End`
- `Observable a` : a stream of events of type a
- `Observer a`   : listener of events of type a
- `Source a`     : typeclass for things that can be converted into `Observable a`
- Combinators    : transform and combile Observables with `mapE`, `filterE`, `scanE`, `mergeE` and `combineLatestE`

Differences to RX:

- Naming is more like Haskell/FP and less like SQL
- No OnError event
- Observer calls return observer state as in Iteratee. Makes it easier to implement combinators without explicit mutable state.

Differences to reactive-banana:

- No separate "build event network phase"
- No Behavior/Discrete types. Just Observable (which is similar to Event in banana)
- Easier to implement combinators
- More combinators included
- Monad and Applicative instances for Observable

Included instances of `Source`:

- Lists
- PushCollection

Interfaces:

- Functor
- Applicative
- Monad
- Num (yes, you can do `a` + `Observable a`!)

Infix operators:

- `==>` : assign side-effect
- `|=>` : side-effect, return Dispose function for unsubscribing
- `@?` : infix form of filterE

PushCollection example:

~~~ {.haskell}
> :m Reactive.Bacon Reactive.Bacon.PushCollection
> pc <- newPushCollection :: IO (PushCollection String)
> pc ==> print
> push pc "lol"
"lol"
~~~

List example:

~~~ {.haskell}
> import Reactive.Bacon
> takeWhileE (<3) [1,2,3,4,1] ==> print
1
2
~~~

Numeric example:

~~~ {.haskell}
> import Reactive.Bacon
> import Reactive.Bacon.Merge
> xs <- newPushCollection
> ys <- newPushCollection
> let sum = 100 + (obs xs) * 10 + (obs ys)
> sum ==> print
> push xs 1
> push ys 5
> push xs 2
115
125
~~~

More [examples](src/Reactive/Bacon/Examples.hs) available!

Status
------

- Working Source instances for PushCollection and Lists
- Simple transformers implemented: `filterE`, `mapE`, `scanE`, `takeWhileE`, `takeE`
- Some combinators implemented: `mergeE`, `combineLatestE`, `combineLatestWithE`

Design considerations
---------------------

- Should I use the E suffix as in mapE? This is used to avoid conflict with Prelude functions
- Might I dispose of the Dispose functionality? Would it be enough to be able to unsubscribe passively by returning NoMore? This would make the framework simpler. 

Todo
----

- Configure cabal test suite
- Implement zipE and zipWithE
- Try it out in the RUMP project
- Re-implement the rather hackish monadic and applicative interfaces
- Publish to Hackage :)
