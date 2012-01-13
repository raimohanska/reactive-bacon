reactive-bacon
==============

FRP (functional reactive programming) framework inspired by RX and Iteratee

PushCollection GHCI example:

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
