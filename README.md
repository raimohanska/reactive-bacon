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
> :M Reactive.Bacon
> [1, 2, 3, 4] @? (<3) ==> print
1
2
~~~

Status
------

- Observable, Observer and Disposable defined, working in the IO Monad
- "PushCollection" is a simple implementation of Observable. Push it!
- Observer has now next/end/error functions
- Some combinators implemented. Most of them badly.
