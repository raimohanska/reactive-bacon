reactive-bacon
==============

FRP (functional reactive programming) framework inspired by RX and Iteratee. 

Main concepts are:

- `Event a`      : an event of type a. Either `Next a` or `End`
- `Observable a` : a stream of events of type a
- `Observer a`   : listener of events of type a
- `Source a`     : typeclass for things that can be converted into `Observable a`

Included instances of `Source`:

- Lists
- PushCollection

Interfaces:

- Functor
- Applicative
- (Monad not yet implemented)`
- Num (yes, you can do `a` + `Observable a`!)

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
- Easiest combinators (filter, map) implemented

Todo
----

- Fix bugs
- Add tests
- Implement merge
- Implement combineLatest+zip based on merge
- Implement >>=
- Study show to make |> work beautifully
