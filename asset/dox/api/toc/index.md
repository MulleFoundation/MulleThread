# MulleThread Library Documentation for AI
<!-- Keywords: thread, nudge, concurrency, conditionlock, wakeup, objc, async -->
## 1. Introduction & Purpose

MulleThread is a small Objective-C library providing a single reusable worker
thread class. It combines an `NSThread` with an `NSConditionLock` to implement a
nudge-based wake-on-demand pattern: the thread idles (sleeps, consuming no CPU)
until it is "nudged", at which point it executes a target/selector pair in its
own thread and then returns to idle, waiting for the next nudge.

It solves the problem of running Objective-C methods on a dedicated background
thread without busy-waiting, without repeated thread creation/teardown, and with
simple, race-free shutdown semantics. Key features:

- Idle thread sleeps on a condition lock; zero CPU while waiting.
- One `NSAutoreleasePool` is managed automatically per work cycle by the library.
- Deterministic lifecycle: `-mulleStart`, `-nudge`, `-cancelWhenIdle`/`-preempt`, `-mulleJoin`.
- Subclassable hooks (`-willCallMain`, `-willIdle`) to control each cycle.
- Could be used to feed a serial work queue. A `MulleThread` is the combination of a `NSConditionLock` and an `NSThread` (see `README.md`).

It is a foundational component of the `MulleFoundation` / `mulle-objc` ecosystem and relies on `MulleObjC` for `NSThread` and `NSConditionLock`.

## 2. Key Concepts & Design Philosophy

- **Nudge-based wakeup**: The thread runs in a loop. When idle it blocks in
  `[_threadLock mulleLockWhenNotCondition:MulleThreadStateIdle]`. A `-nudge`
  from another thread transitions the lock condition from `Idle` to `Busy`,
  waking the thread. There is no polling and no busy-waiting.
- **Target/selector execution**: The work is supplied as a target object plus a
  selector. The selector must take one argument and return `int`. The returned
  integer is an instruction to the thread loop (see the `MulleThreadReturnValue`
  enum below).
- **Condition as state machine**: The `NSConditionLock` `threadLock` condition
  is the thread state: `Idle`, `Busy`, `Exited` (internal enum in `MulleThread.m`,
  not public). External control methods simply acquire the lock, inspect/change
  the condition, and unlock — which makes them safe to call from other threads.
- **Autorelease management**: `-main` wraps each cycle in a
  `[pool mulleReleaseAllPoolObjects]`, so the target/selector does not need its
  own autorelease pool.
- **Graceful vs. immediate shutdown**: `-cancelWhenIdle` waits for the thread to
  become idle before canceling; `-preempt` cancels immediately; the worker can
  also cancel itself (e.g. via `[[NSThread currentThread] cancel]`). Always
  `-mulleJoin` afterwards.
- **Thread confinement of control**: Control methods (`-nudge`, `-preempt`,
  `-cancelWhenIdle`, `-blockUntilNoLongerBusy`, `-setInvocation:`) must be called
  from *outside* the worker thread. Only `-cancel` may be called from within.

## 3. Core API & Data Structures

### 3.1. `src/MulleThread.h`

This is the only public header of the library. It declares the `MulleThread`
class (a subclass of `NSThread`) and the return-value enum.

#### Return values from target/selector

```objc
enum
{
   MulleThreadGoIdle        = 0,
   MulleThreadContinueMain  = 1,
   MulleThreadCancelMain    = -1
};
```

`MulleThreadGoIdle` = return to idle and wait for the next nudge.
`MulleThreadContinueMain` = run the target/selector again immediately (no nudge needed).
`MulleThreadCancelMain` = cancel and finish the thread.

#### `@interface MulleThread : NSThread`

- **Purpose:** A reusable worker thread that idles until nudged and then executes a target/selector.
- **Property:**
  - `@property( readonly, retain) NSConditionLock   *threadLock;`
    Underlying condition lock. Its condition encodes the thread state (`Idle`/`Busy`/`Exited`). Normally you never touch it directly, but it is exposed for advanced uses.
- **Lifecycle functions:**
  - Creation: a MulleThread is created with the inherited `NSThread` factory
    `+ (instancetype) mulleThreadWithTarget:(id) target selector:(SEL) sel object:(id) argument;`
    (declared in the `MulleObjC` dependency's `NSThread.h`; it binds the work
    target/selector and returns an autoreleased instance).
  - `- (instancetype) init` (inherited from `NSThread`): initializes the lock to `Idle` if no target/selector was given.
  - `- (void) mulleStart;` (overridden from `NSThread`): normalizes the state to `Idle`, then starts the OS thread via `[super mulleStart]`. The header comment says to use this instead of `-start`. Starting does *not* execute the target/selector — the thread waits for a nudge.
  - `- (void) mulleJoin;` (overridden from `NSThread`): blocks until the thread has reached the `Exited` state, then calls `[super mulleJoin]`. Only returns if the thread is exiting (see pitfalls).
- **Control functions (call only from outside the thread):**
  - `- (void) nudge;` — wake the thread to run the target/selector once. If the thread is `Busy` or `Exited`, the nudge is dropped.
  - `- (void) cancelWhenIdle;` — safely shut down: wait until not `Busy`, then set the cancel flag and nudge.
  - `- (void) preempt;` — cancel as soon as possible: set the cancel flag and nudge immediately.
  - `- (void) blockUntilNoLongerBusy;` — wait until the thread is no longer `Busy` (idle or exited). This is only a snapshot of the past; the thread may become busy again.
  - `- (void) setInvocation:(NSInvocation *) invocation;` — change the work executed on the next nudge. Blocks if the thread is not idle. Only call from outside. (The `NSThread` category comment says the caller is responsible to call `-retainArguments` on the invocation.)
- **State inspection:**
  - `- (BOOL) isIdle;` — check whether the thread currently idles. Snapshot semantics; do not call from within the thread.
- **Hooks (override in subclasses; called in the locked state within the thread):**
  - `- (BOOL) willCallMain;` — called before executing the target/selector on each cycle. Return `NO` to skip execution this cycle.
  - `- (BOOL) willIdle;` — called before the thread goes idle. Return `NO` to run the target/selector again immediately (only sensible if you change the invocation, otherwise main would just run twice).

#### Behavior notes (from `src/MulleThread.m`)

- Internal state enum (not public API):

  ```objc
  typedef NS_ENUM( NSUInteger, MulleThreadState)
  {
     MulleThreadStateIdle   = 0,
     MulleThreadStateBusy   = 1,
     MulleThreadStateExited = -1 // set by thread when main exits
  };
  ```

- `-main` loop: wait for state != `Idle`; inner loop: check `isCancelled`, run target/selector once (through `[super main]`) if `-willCallMain` returns `YES`, release all autorelease pool objects; repeat while the return value is `MulleThreadContinueMain`. After the inner loop, `MulleThreadCancelMain` terminates the thread (state = `Exited`); otherwise `-willIdle` decides whether to go idle or loop again.
- `+detachNewThreadSelector:toTarget:withObject:` and `+mulleDetachNewThreadWithFunction:argument:` are overridden to `abort()` — detached operation makes no sense with MulleThread; use plain `NSThread` for that.
- `-cancel` and `-isCancelled` are inherited from `NSThread`. `-cancel` may be called from within the worker thread (unlike the other control methods).

## 4. Performance Characteristics

- **Wakeup latency**: O(1) — a single condition-lock transition (`Idle` → `Busy`) wakes the thread; no polling.
- **Idle CPU**: essentially zero; the thread blocks on the condition lock.
- **Synchronization**: constant-time lock/unlock per nudge and per cycle; `-mulleJoin` waits for a single condition.
- **Memory**: one `NSConditionLock` plus one OS thread stack per `MulleThread`; the autorelease pool is flushed per cycle so no per-cycle memory accumulation.
- **Thread safety**: the control methods are safe to call from any thread *except* the worker thread itself. The state-machine design makes `-nudge` a benign no-op if the thread is busy or exited.

## 5. AI Usage Recommendations & Patterns

### Best Practices

- Create with the inherited factory and start with `-mulleStart` (not `-start`):

  ```objc
  thread = [MulleThread mulleThreadWithTarget:obj
                                     selector:@selector( runServer:)
                                       object:nil];
  [thread mulleStart];
  ```

- For a clean shutdown always pair `-cancelWhenIdle` (or `-preempt`) with a following `-mulleJoin`.
- Have the worker return `MulleThreadGoIdle` when done; use `MulleThreadContinueMain` for batching and `MulleThreadCancelMain` on fatal errors.
- Let the library manage the autorelease pool; do not create nested pools in the target/selector.
- If you replace the invocation, call `-retainArguments` on the `NSInvocation` first.

### Common Pitfalls

- **`-mulleJoin` hangs forever if the thread is not canceled**: a perfectly healthy, idle thread waits for nudges indefinitely, so `-mulleJoin` will block. Always `-cancelWhenIdle`/`-preempt` before joining.
- **`-cancel` from outside while idle is not enough**: when idle the thread is blocked on the lock; it only notices the cancel flag after waking. Either use `-cancelWhenIdle`/`-preempt`, or follow a bare `-cancel` with `-nudge` (see `test/20-thread/cancel.m`).
- **Do not call `-nudge`, `-preempt`, `-cancelWhenIdle`, `-blockUntilNoLongerBusy`, or `-setInvocation:` from within the worker thread** — they would block/lock against the very thread that holds the lock.
- **`-isIdle` and `-blockUntilNoLongerBusy` are snapshots**; the thread may become busy again right after they return unless you are sure nothing nudges it.
- **Never use the `+detach…` methods on MulleThread** (they abort) and avoid `+exit` — it is documented as bad style here.
- **The target/selector must return `int`**; MulleThread asserts this in debug builds.

### Idiomatic Usage

```objc
// Worker returns int; it controls the thread loop
- (int) runServer:(id) argument
{
   if( fatalError)
      return( MulleThreadCancelMain);   // terminate thread
   if( moreBatches)
      return( MulleThreadContinueMain); // run again without nudge
   return( MulleThreadGoIdle);          // wait for next nudge
}
```

```objc
// Outside code: nudge when there is work, shut down cleanly
[thread nudge];
...
[thread cancelWhenIdle];
[thread mulleJoin];
```

## 6. Integration Examples

Style notes: 3-space indent, Allman braces, aligned declarations, one variable
per line, `return( expr);`, no dot-syntax, no `alloc/init`/`retain/release`
outside of `-init`/`-dealloc`, library-managed autorelease pools in the worker.

### Example 1: Create, nudge, and gracefully shut down a worker thread

```objc
#import <MulleThread/MulleThread.h>


@interface Foo : NSObject
@end


@implementation Foo

- (int) runServer:(id) argument
{
   return( MulleThreadGoIdle);
}

@end


int   main( int argc, const char * argv[])
{
   MulleThread   *thread;
   Foo           *foo;

   foo    = [Foo instance];
   thread = [MulleThread mulleThreadWithTarget:foo
                                      selector:@selector( runServer:)
                                        object:nil];
   [thread mulleStart];       // start; worker idles, does not run yet

   [thread nudge];            // wake up and run target/selector once

   [thread cancelWhenIdle];   // safe shutdown when idle
   [thread mulleJoin];        // wait until the thread has exited

   return( 0);
}
```

### Example 2: Repeated work synchronized with `blockUntilNoLongerBusy`

```objc
#import <MulleThread/MulleThread.h>


@interface Foo : NSObject
{
   NSUInteger   _count;
}
@end


@implementation Foo

- (int) runServer:(id) argument
{
   mulle_printf( "* %td\n", _count++);
   return( MulleThreadGoIdle);
}

@end


int   main( int argc, const char * argv[])
{
   MulleThread   *thread;
   NSUInteger    i;
   Foo           *foo;

   foo    = [Foo instance];
   thread = [MulleThread mulleThreadWithTarget:foo
                                      selector:@selector( runServer:)
                                        object:nil];
   [thread mulleStart];

   for( i = 0; i < 3; i++)
   {
      [thread blockUntilNoLongerBusy];   // wait until previous iteration finished
      [thread nudge];
   }
   [thread blockUntilNoLongerBusy];
   [thread cancelWhenIdle];
   [thread mulleJoin];

   return( 0);
}
```

### Example 3: Worker that cancels itself, then join

```objc
#import <MulleThread/MulleThread.h>


@interface Foo : NSObject
@end


@implementation Foo

- (int) runServer:(id) argument
{
   [[NSThread currentThread] cancel];   // request cancellation from within
   return( MulleThreadGoIdle);
}

@end


int   main( int argc, const char * argv[])
{
   MulleThread   *thread;
   Foo           *foo;

   foo    = [Foo instance];
   thread = [MulleThread mulleThreadWithTarget:foo
                                      selector:@selector( runServer:)
                                        object:nil];
   [thread mulleStart];
   [thread nudge];

   [thread mulleJoin];   // thread cancels itself and exits, join returns

   return( 0);
}
```

### Example 4: Batching with `MulleThreadContinueMain` and a subclass hook

```objc
#import <MulleThread/MulleThread.h>


@interface BatchWorker : NSObject
{
   NSUInteger   _count;
}
@end


@implementation BatchWorker

- (BOOL) willCallMain
{
   // this hook runs in the worker thread, in the locked state
   mulle_printf( "willCallMain\n");
   return( [super willCallMain]);
}

- (int) runBatch:(id) argument
{
   mulle_printf( "batch %td\n", _count++);
   if( _count < 5)
      return( MulleThreadContinueMain);   // run again without a nudge
   return( MulleThreadGoIdle);
}

@end


int   main( int argc, const char * argv[])
{
   MulleThread   *thread;
   BatchWorker   *worker;

   worker = [BatchWorker instance];
   thread = [MulleThread mulleThreadWithTarget:worker
                                      selector:@selector( runBatch:)
                                        object:nil];
   [thread mulleStart];
   [thread nudge];        // runBatch then repeats 4 more times automatically

   [thread blockUntilNoLongerBusy];
   [thread cancelWhenIdle];
   [thread mulleJoin];

   return( 0);
}
```

### Example 5: Swapping the work with `setInvocation:`

```objc
#import <MulleThread/MulleThread.h>


@interface Foo : NSObject
@end


@implementation Foo

- (int) firstJob:(id) argument
{
   return( MulleThreadGoIdle);
}

- (int) secondJob:(id) argument
{
   return( MulleThreadGoIdle);
}

@end


int   main( int argc, const char * argv[])
{
   NSMethodSignature   *signature;
   NSInvocation        *invocation;
   MulleThread         *thread;
   Foo                 *foo;

   foo    = [Foo instance];
   thread = [MulleThread mulleThreadWithTarget:foo
                                      selector:@selector( firstJob:)
                                        object:nil];
   [thread mulleStart];

   [thread nudge];
   [thread blockUntilNoLongerBusy];   // ensure idle before changing work

   // point the next nudge at -secondJob:
   signature  = [Foo instanceMethodSignatureForSelector:@selector( secondJob:)];
   invocation = [NSInvocation invocationWithMethodSignature:signature];
   [invocation setTarget:foo];
   [invocation setSelector:@selector( secondJob:)];
   [invocation retainArguments];      // arguments survive across threads
   [thread setInvocation:invocation];
   [thread nudge];
   [thread blockUntilNoLongerBusy];

   [thread cancelWhenIdle];
   [thread mulleJoin];

   return( 0);
}
```

## 7. Dependencies

Direct `mulle-sde` library dependencies (from `.mulle/etc/sourcetree/config`):

- `MulleObjC` — provides `NSThread` and `NSConditionLock`, and the factory method `+mulleThreadWithTarget:selector:object:`
- `mulle-objc-list` (tooling/CI dependency; `no-link` mark, not linked)

## 8. Notes

This document was regenerated from the public header `src/MulleThread.h`
(version macro `MULLE_THREAD_VERSION`), the implementation `src/MulleThread.m`,
the tests in `test/20-thread`, and `README.md`. The existing `index.md` was
committed in `241d7ba` (2026-09-04) together with the test rework; no library
source changes have occurred since, but the previous document was rewritten to
use verbatim signatures and correct API details.