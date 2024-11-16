//
//  main.m
//  archiver-test
//
//  Created by Nat! on 19.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//
#import "MulleThread.h"


// thread states do not convey error/completion status
// thread states are also not "commands" you don't set
// the state to MulleThreadStateExited and expect
// the thread to cancel
enum
{
   MulleThreadStateIdle,
   MulleThreadStateBusy,
   MulleThreadStateExited  // set by thread when main exits
};


#define MAIN_DEBUG

@implementation MulleThread

+ (void) detachNewThreadSelector:(SEL) sel
                        toTarget:(id) target
                      withObject:(id) argument
{
// makes no sense with MulleThread, use NSThread
   abort();
}


+ (void) mulleDetachNewThreadWithFunction:(MulleThreadFunction_t *) f
                                 argument:(void *) argument
{
// makes no sense with MulleThread, use NSThread
   abort();
}


- (instancetype) init
{
   [super init];

   _threadLock = [[NSConditionLock alloc] initWithCondition:MulleThreadStateIdle];

   return( self);
}


- (void) dealloc
{
   [_threadLock release];

   [super dealloc];
}


#ifndef NDEBUG
- (void) assertInvocationOnMainThread
{
   NSMethodSignature   *signature;
   char                *returnType;

   signature  = [_invocation methodSignature];
   assert( signature);
   returnType = [signature methodReturnType];
   // return value of function or _target/selector must be int
   assert( *returnType == _C_INT);
}
#endif


//
// this routine must be called from the "outside" only, we transfer
// it to temporary space in the thread, and then tell MulleThread to copy
// it with a special state
//
- (void) setInvocation:(NSInvocation *) invocation
{
   [_threadLock lockWhenCondition:MulleThreadStateIdle];
   {
      [_invocation mulleRelinquishAccess];
      [_invocation autorelease];

      [invocation mulleRelinquishAccess];
      _invocation = [invocation retain];
   }
   [_threadLock unlockWithCondition:MulleThreadStateIdle];
}


- (BOOL) willCallMain
{
   return( YES);
}


- (BOOL) willIdle
{
   return( YES);
}


- (void) main
{
   NSAutoreleasePool   *pool;

#ifndef NDEBUG
   [self assertInvocationOnMainThread];
#endif

   pool = [NSAutoreleasePool new];
   for(;;)
   {
      // MulleThreadStateIdle,
      // MulleThreadStateBusy,
#ifdef MAIN_DEBUG
      fprintf( stderr, "\n***** %p (%p) waiting on <> idle\n", (void *) mulle_thread_self(), self);
#endif
      [_threadLock mulleLockWhenNotCondition:MulleThreadStateIdle];
#ifdef MAIN_DEBUG
      fprintf( stderr, "\n***** %p (%p) got <> idle\n", (void *) mulle_thread_self(), self);
#endif
      _rval = MulleThreadContinueMain;
      for(;;)
      {
         if( [self isCancelled])
         {
#ifdef MAIN_DEBUG
            fprintf( stderr, "***** 0x%p (%p) thread has received a cancel\n", (void *) mulle_thread_self(), self);
#endif
            goto done;
         }

         if( _rval != MulleThreadContinueMain)
            break;

#ifdef MAIN_DEBUG
         fprintf( stderr, "***** 0x%p (%p) call [super main]\n", (void *) mulle_thread_self(), self);
#endif
         // this will eventually call the "user" method that was given
         // when the MulleThread was created
         if( [self willCallMain])
            [super main];
         [pool mulleReleaseAllPoolObjects];
      }

      if( _rval == MulleThreadCancelMain)
      {
#ifdef MAIN_DEBUG
         fprintf( stderr, "***** 0x%p (%p) main return value indicates cancel\n", (void *) mulle_thread_self(), self);
#endif
         goto done;
      }

      if( [self willIdle])
      {
         [_threadLock unlockWithCondition:MulleThreadStateIdle];
      }
   }

done:
   [_threadLock unlockWithCondition:MulleThreadStateExited];
   [pool release];

#ifdef MAIN_DEBUG
   fprintf( stderr, "\n***** 0x%p (%p) is exiting\n\n", (void *) mulle_thread_self(), self);
#endif
}


- (BOOL) isIdle
{
   // just check if idling
   if( [_threadLock tryLockWhenCondition:MulleThreadStateIdle])
   {
      [_threadLock unlockWithCondition:MulleThreadStateIdle];
      return( YES);
   }
   return( NO);
}


- (void) nudge
{
   // if exited, don't do anything, if busy don't do anything
   if( [_threadLock tryLockWhenCondition:MulleThreadStateIdle])
      [_threadLock unlockWithCondition:MulleThreadStateBusy];
}


- (void) blockUntilNoLongerBusy
{
   NSUInteger   condition;

   [_threadLock mulleLockWhenNotCondition:MulleThreadStateBusy];
   condition = [_threadLock condition];
   [_threadLock unlockWithCondition:condition];
}


- (void) cancelWhenIdle
{
   NSUInteger   condition;

   [_threadLock mulleLockWhenNotCondition:MulleThreadStateBusy];
   condition = [_threadLock condition];
   if( condition != MulleThreadStateExited)
   {
      [self cancel];                    // set NSThread cancel flag
      condition = MulleThreadStateBusy; // this is a nudge
   }
   [_threadLock unlockWithCondition:condition];
}


- (void) preempt
{
   [self cancel];   // set NSThread cancel flag
   [self nudge];
}


- (void) mulleStart
{
   // Ensure it's in Idle the first time. Usually it will though and this
   // tryLock fails
   if( [_threadLock mulleTryLockWhenNotCondition:MulleThreadStateIdle])
      [_threadLock unlockWithCondition:MulleThreadStateIdle];
   [super mulleStart];
}


- (void) mulleJoin
{
   [_threadLock lockWhenCondition:MulleThreadStateExited];
   [_threadLock unlockWithCondition:MulleThreadStateExited];
   [super mulleJoin];
}


@end

