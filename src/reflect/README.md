# Header files in `reflect`

## External consumption only

### `MulleThread-export.h`

This file is generated for the Objective-C envelope header (typically
`MulleThread
.h`). It contains the list of Objective-C headers that
are advertised to consumers of this library


### `MulleThread-provide.h`

This file is generated for the Objective-C or C envelope header (typically
`MulleThread
.h`). It contains the list of C headers that will be
advertised to consumers of this library.


### `objc-loader.inc`

This file contains Objective-C dependency information of this library.
It's updated during a build.


## Internal and External consumption


### `MulleThread-import.h`

Objective-C dependency headers that this project uses are imported via
this file. Dependencies are managed with `mulle-sde dependency`
These dependencies are also available to consumers of this library.


### `MulleThread-include.h`

C dependency and library headers that this project uses are imported via
this file. Dependencies are managed with `mulle-sde dependency`.
Libraries with `mulle-sde library`.
These dependencies are also available to consumers of this library.


## Internal consumption only


### `MulleThread-import-private.h`

Objective-C dependency headers that this project uses privately are imported
via this file.


### `MulleThread-include-private.h`

C dependency and library headers that this project uses privately are imported
via this file.


<!--
extension : mulle-objc/objc
directory : project-oneshot/library
template  : .../README.md
Suppress this comment with `export MULLE_SDE_GENERATE_FILE_COMMENTS=NO`
-->
