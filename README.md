reactive-bacon
==============

FRP (functional reactive programming) framework inspired by RX, reactive-banana and Iteratee. 

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

- `==>` : assign side-effect of type `a -> IO ()`
- `===>` : assign side-effect of type `Event a -> IO ()`
- `|=>` : side-effect, return Dispose function for unsubscribing
- `@?` : infix form of filterE
- `<++>` : concat two sources
- `<:>` : prepend single element to stream

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

More [examples](https://github.com/raimohanska/reactive-bacon/blob/master/src/Reactive/Bacon/Examples.hs) available!

See also [tests](https://github.com/raimohanska/reactive-bacon/blob/master/test/Reactive/BaconTest.hs).

Status
------

- Working Source instances for PushCollection and Lists
- Some combinators implemented: `filterE`, `mapE`, `scanE`, `takeWhileE`, `takeE`, `mergeE`, `combineLatestE`, `combineLatestWithE`, `zipE`, `zipWithE`, `takeUntilE`, `publishE` etc
- Applicative, Monad implemented
- 29 test cases passing
- Not tried out in "real life" yet

Design considerations
---------------------

The concepts of "hot observable" vs "cold observable" have caused us trouble 
with RX. Cold observables (practically lists) may be used, for instance, to 
add a start value to a hot observable, in a case that we are actually modeling
a property, such as location or a textfield value. This is problemsome because
a cold observable always spits its value to any new observer. A new
observer might actually expect to get the latest position instead of a
fixed one.

I'm currently proposing a new abstraction `Property` for modeling
a property that is actually a value as a function of time. A `Property`
will always remember its latest value, so that new listeners will get
the most up-to-date value to start with.

In reactive-banana terms Observable and Property roughly correspond to Event
and Discrete.

Todo
----

- Introduce Sink class for easier side-effects
- Documentation documentation documentation
- Refactor into modules (core, combinators, num ..)
- Configure cabal test suite
- Try it out in the RUMP project
- Publish to Hackage
- Create a Javascript version when the design is settled. RxJs needs an
  open-source alternative.
