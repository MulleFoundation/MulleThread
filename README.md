# MulleInvocationQueue

#### 🚶🚶🚶 MulleInvocationQueue runs code in a separate thread

A MulleInvocationQueue is fed with NSInvocations, which it then executes in
serial in a separate thread.



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
