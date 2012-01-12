Rx for Haskell
==============

Attempt to implement the Reactive Extensions API in Haskell. Just for
the sake of it. Like this:

~~~ {.haskell}
*Rx> subscribe (select show (Rx.filter even $ observableList [1, 2])) putStrLn
2
~~~

Status
------

- Observable, Observer and Disposable defined, working in the IO Monad
- "PushCollection" is a simple implementation of Observable. Push it!
- Observer has now next/end/error functions
- Some combinators implemented. Most of them badly.
