# MulleInvocationQueue

#### 🚶🚶🚶 MulleInvocationQueue runs code in a separate thread

A MulleInvocationQueue is fed with NSInvocations, which it then executes in
serial in a separate thread.


## MulleThread

The MulleThread is the combination of a **NSConditionLock** and **NSThread**.
The thread idles waiting for work. If there is something to do, you `-nudge`
the thread and it runs it's "target" / "selector". Then the thread returns
to idle, waiting for the next `-nudge`.

MulleThread also manages a `NSAutoreleasePool` for your code.


Create a thread and start it:

``` objc
thread = [MulleThread mulleThreadWithTarget:foo
                                   selector:@selector( runServer:)
                                     object:nil];
[thread start];
```

The initial `-start` will not call "target" / "selector" yet. The thread waits
for a `-nudge`. You can `-preempt` the thread at any time. For a more graceful
shutdown use `-cancelWhenIdle`. The thread code can `-cancel` itself at any
time. Use of `+exit` to finish a "MulleThread" is bad style.


``` objc
[thread nudge];
[thread preempt];
[thread cancelWhenIdle];
```

To wait for a thread to complete use `-mulleJoin`. But you need to `-preempt`
or `-cancelWhenIdle` before.

## mulle-sde

This is a [mulle-sde](//github.com/mulle-sde) project. mulle-sde combines
recursive package management with cross-platform builds via **cmake**:

| Action  | Command                               | Description               |
|---------|---------------------------------------|---------------------------|
| Build   | `mulle-sde craft [--release|--debug]` | Builds into local `kitchen` folder |
| Add     | `mulle-sde dependency add --c --github MulleFoundation MulleInvocationQueue` | Add MulleInvocationQueue> to another mulle-sde project as a dependency |
| Install | `mulle-sde install --prefix /usr/local https://github.com/MulleFoundation/MulleInvocationQueue.git` | Like `make install` |


### Manual Installation


Install the requirements:

| Requirements                                      | Description             |
|---------------------------------------------------|-------------------------|
| [MulleObjCLockFoundation](//github.com/MulleFoundation/MulleObjCLockFoundation) | The MulleObjCLockFoundation       |


Install into `/usr/local`:

``` sh
cmake -B build \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCMAKE_PREFIX_PATH=/usr/local \
      -DCMAKE_BUILD_TYPE=Release &&
cmake --build build --config Release &&
cmake --install build --config Release
```


<!--
extension : mulle-sde/sde
directory : demo/library
template  : .../README.md
Suppress this comment with `export MULLE_SDE_GENERATE_FILE_COMMENTS=NO`
-->
