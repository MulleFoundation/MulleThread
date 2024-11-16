//
//  main.m
//  archiver-test
//
//  Created by Nat! on 19.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//
#ifdef __has_include
# if __has_include( "NSThread.h")
#  import "NSThread.h"
# endif
#endif

#define MULLE_THREAD_VERSION   ((0UL << 20) | (1 << 8) | 0)


#import "import.h"


// Values returned from target/selector
// OK will rerun after cancel check.
// Error will cancel,
// Idle will wait for a nudge
//
enum
{
   MulleThreadGoIdle        = 0,
   MulleThreadContinueMain  = 1,
   MulleThreadCancelMain    = -1
};

//
// This thread object contains a threadLock. The first time the
// thread is started it will execute target/selector (from -main).
// Then the thread will sleep and wait until "-nudge"d. Then it will
// execute target/selector again. You can't use the -detach methods with
// MulleThread, but you can wait on it with -mulleJoin. Do not use -start
// use -mulleStart.
//
@interface MulleThread : NSThread

@property( readonly, retain) NSConditionLock   *threadLock;


// wake up thread, do not call from "within" thread
- (void) nudge;

// use cancelWhenIdle to safely close down the thread, don't call from
// "within" thread
- (void) cancelWhenIdle;

// This waits until idle or exited. Of course this is just a snapshot
// of the past, and the thread may well have become busy again (unless
// you can ascertain, noone nudges it)
- (void) blockUntilNoLongerBusy;

// use preempt to cancel ASAP. Do not call from "within" thread
- (void) preempt;

// if the thread idles, this will wait forever, do not call from "within" thread
- (void) mulleJoin;

// check if thread idles, do not call from "within" thread

- (BOOL) isIdle;

//
// only to be called from the "outside", change the next "main" routine for
// the next nudge... will block if the thread is not idle
//
- (void) setInvocation:(NSInvocation *) invocation;


//
// this will be called in a locked state in -main before calling the
// -[NSThread main], return NO if you don't want that to happen
//
- (BOOL) willCallMain;


//
// this will be called before going idle, return NO, if you want to run
// again immediately (would call -[NSThread main], twice, so this is only
// desirable, if you change the invocation...
//
- (BOOL) willIdle;

@end


