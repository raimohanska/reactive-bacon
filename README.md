reactive-bacon
==============

FRP (functional reactive programming) framework inspired by RX, reactive-banana and Iteratee. 

Main concepts are:

- `Event a`       : an event of type a. Either `Next a` or `End`
- `EventStream a` : a stream of events of type a
- `EventSink a`   : function that processes events of type a
- `Source a`      : typeclass for things that can be converted into
  `EventStream a`
- `Property a`    : a property that changes as a function of time. has
  "current value"
- `PropertySink a`: a function that processes property change events of
 type a
- `Observable a`  : common interface for EventStream and Property; you
  can assign side-effects to both using the same operators `==>` and
`>>=!`
- Stream Combinators : transform and combile EventStreams with `mapE`, `filterE`, `scanE`, `mergeE` and `combineLatestE` etc
- Property Combinators : transform and combine Properties with `map`, `filterP`, `combineWithP` etc

EventStream and Property
------------------------

EventStream is a stream of events. It can be thought of as a list of `(t,
x)` where t is time and x is a value. A Property is a value as a
function of time. It may or may not have an initial value to start with
but after the first value it will always have a current value that is
can supply its "sinks" with. 

For example, this is how you'd construct a stream that will pop out
numbers 1, 2, 3 and 1 with a second's interval. The `>>=!` symbol is
used to assign a side-effect; the values from the stream are printed to
the console.

~~~ .haskell
  sequentiallyE (seconds 1) [1, 2, 3, 1] >>=! print
~~~

A Property can be constructed from an EventStream using
`fromEventSource` or `fromEventSourceWithStartValue`. A Property can be
converted to an EventStream using `changesP`. It's noticeable that all
of these methods are in the IO monad, meaning that Property and
EventStream are not interchangeable without side-effects.

A Property differs from an EventStream in that it has the concept of
"current value" that it will have after it has got it's first value.
When you assign a side-effect to a Property, your "PropertySink"
function will be called with the current value immediately, if there's a
current value.

You should use EventStreams for discrete events (like mouse clicks) and
Properties for values as function-of-time (like mouse position).

Interfaces
----------

Property implements some of the standard typeclasses.

- `Functor` : `fmap` = `mapP`
- `Applicative` : based on `combineWithP`. You can apply a pure function
  to Property using this interface
- `Num`, based on Applicative. (Yes, you can do `a` + `Property a`!)

So, you can use the Num interface to make calculations on Properties and
constant numbers as in

~~~ .haskell
  (xs, pushX) <- newPushProperty
  (ys, pushY) <- newPushProperty
  let sum = 100 + xs * 10 + ys
  sum ==> print
  pushX 1
  pushY 5
  pushX 2
~~~

So first I create two "pushable properties", and create a composite
property "num". I assign the "print" side-effect and then push some
values to the properties. The output should obviously contain numbers 115 and 125.

EventStream is only a `Functor`. All functions on EventStream are in the IO
Monad, because most of them need mutable state to guarantee consistency
(see below). The bright side of this is that you get a nice monadic
syntax for applying transformations and side-effects, as in

~~~ .haskell
  sequentiallyE (seconds 1) [1, 2, 3, 1] 
      >>= filterE (<3) 
      >>= mapE (("x=" ++) . show) 
      >>=! print
~~~

The custom infix operators introduced in bacon are

- `==>` : assign side-effect of type `a -> IO ()`
- `>>=!` : a convenience-monadic version of the above, see usabe above. So `>>=! f` is
  equivalent to `>>= (==> f)`

Differences to RX:
------------------

- EventStreams are strictly consistent with regard to time and sinks
- Naming is more like Haskell/FP and less like SQL
- No OnError event
- The thing that is Observer in RX is roughly EventSink in bacon
- Sink returns a handle result for each event. This means it can signal
  whether or not it wants more events.

One of the main motivators for reactive-bacon has been the weirdness of
RX with regard to "hot" and "cold" observables. In reactive-bacon, there
are no such things. The EventStream is always consistent with respect to
time, so there will be no WTFs from that direction.

Differences to reactive-banana:
-------------------------------

- EventStream and Property have quite similar meanings as Event and
  Discrete in reactive-banana
- No separate "build event network phase"
- More combinators included

Another motivator for reactive-bacon was that reactive-banana seemed a
bit inconvenient (event network building and stuff) and limited (not so
many combinators) compared to RxJs of which I'm still quite fond of.

More examples?
--------------

More [examples](https://github.com/raimohanska/reactive-bacon/blob/master/src/Reactive/Bacon/Examples.hs) available!

See also [tests](https://github.com/raimohanska/reactive-bacon/blob/master/test/Reactive/BaconTest.hs).

EventStream and Property behavior in detail
-------------------------------------------

The state of an EventStream can be defined as (t, os) where `t` is time
and `os` the list of current sinks. This state should define the
behavior of the stream in the sense that

1) When an event is emitted, the same event is emitted to all sinks
2) After an event has been emitted, it will never be emitted again, even
if a new sink is registered.
3) When a new sink is registered, it will get exactly the same
events as the other sink, after registration. This means that the
stream cannot emit any "initial" events to the new sink, unless it
emits them to all of its sinks.
5) A stream must never emit eny other events after End (not even another End)

The rules are deliberately redundant, explaining the constraints from
different perspectives. The contract between an EventStream and its
Sink is as follows:

1) For each incoming event, the function `consume :: Event a -> IO HandleResult
a` is called.
2) The function returns a `HandleResult` which is either `NoMore` or
`More consume`
3) In case of `NoMore` the source must never call the consume function
for this Sink again.
4) In case of `More consume` the source will deliver any further events
using the newly supplied consume-function.

A `Property` behaves similarly to an `EventStream` except that 

1) On a call to `addListener` it will deliver its current value (if any) to the provided
`consume : Event a -> IO HandleResult` function. 
2) This means that if the Property has previously emitted the value `x`
to its sinks and that is the latest value emitted, it will deliver
this value to any registered Sink.
3) Property may or may not have a current value to start with.

EventStream is not a Monad
--------------------------

Well, that's it. It's nearly a monad, because there's a function named
`selectMany` that has a signature almost equivalent to `>>=` but there's
a catch: It's not usually possible to create a new EventStream without
resorting to IO, so the purely monadic signature would not make sense.
Sorry dudes.


Building and using
------------------

Not on HackageDB yet, so you have to build it yourself. It's simple though: git clone, cabal install and it's there. You may now try it in GHCI, as in the examples above.

Status
------

- 27 test cases passing
- Not tried out in "real life" yet
- Not published on Hackage yet

Design considerations
---------------------

The concepts of "hot observable" vs "cold observable" have caused us trouble 
with RX. Cold observables (practically lists) may be used, for instance, to 
add a start value to a hot observable, in a case that we are actually modeling
a property, such as location or a textfield value. This is problemsome because
a cold observable always spits its value to any new sink. A new
sink might actually expect to get the latest position instead of a
fixed one.

I'm currently proposing a new abstraction `Property` for modeling
a property that is actually a value as a function of time. A `Property`
will always remember its latest value, so that new listeners will get
the most up-to-date value to start with.

In reactive-banana terms Observable and Property roughly correspond to Event
and Discrete.

Todo
----

- Maybe replace PushCollection with (EventStream, pushEvent)
- Fork "observable-bacon"
- Combinators for EventStream/Property combo, like combineWithProperty
  :: EventStream a -> Property b -> (a -> b -> c) -> EventStream c
- Documentation documentation documentation
- mapReduceE, just for the sake of it
- Try it out in the RUMP project
- Publish to Hackage
- Create a Javascript version when the design is settled. RxJs needs an
  open-source alternative.
