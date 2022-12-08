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
- (void) assertMainThreadTargetSelector
{
   NSMethodSignature   *signature;
   char                *returnType;

   if( ! _target)
      return;

   signature  = [_target methodSignatureForSelector:_selector];
   assert( signature);
   returnType = [signature methodReturnType];
   // return value of function or _target/selector must be int
   assert( *returnType == _C_INT);
}
#endif


- (void) main
{
   NSAutoreleasePool   *pool;

#ifndef NDEBUG
   [self assertMainThreadTargetSelector];
#endif

   pool = [NSAutoreleasePool new];
   for(;;)
   {
      // MulleThreadStateIdle,
      // MulleThreadStateBusy,
#ifdef MAIN_DEBUG
      fprintf( stderr, "\n***** 0x%tx (%p) waiting on <> idle\n", mulle_thread_self(), self);
#endif
      [_threadLock mulleLockWhenNotCondition:MulleThreadStateIdle];
#ifdef MAIN_DEBUG
      fprintf( stderr, "\n***** 0x%tx (%p) got idle\n", mulle_thread_self(), self);
#endif

      _rval = MulleThreadContinueMain;
      for(;;)
      {
         if( [self isCancelled])
            goto done;

         if( _rval != MulleThreadContinueMain)
            break;

#ifdef MAIN_DEBUG
         fprintf( stderr, "***** 0x%tx (%p) call [super main]\n", mulle_thread_self(), self);
#endif
         [super main];
         [pool mulleReleaseAllObjects];
      }

      if( _rval == MulleThreadCancelMain)
         goto done;

      [_threadLock unlockWithCondition:MulleThreadStateIdle];
   }

done:
   [_threadLock unlockWithCondition:MulleThreadStateExited];
   [pool release];

#ifdef MAIN_DEBUG
   fprintf( stderr, "\n***** 0x%tx (%p) is exiting\n\n", mulle_thread_self(), self);
#endif
}


- (void) nudge
{
   // if exited, don't do anything, if busy don't do anything
   if( [_threadLock tryLockWhenCondition:MulleThreadStateIdle])
      [_threadLock unlockWithCondition:MulleThreadStateBusy];
}


- (void) mulleJoin
{
   [_threadLock lockWhenCondition:MulleThreadStateExited];
   [_threadLock unlockWithCondition:MulleThreadStateExited];
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
      [self cancel];   // set NSThread cancel flag
      condition = MulleThreadStateBusy;
   }
   [_threadLock unlockWithCondition:condition];
}


- (void) preempt
{
   [self cancel];   // set NSThread cancel flag
   [self nudge];
}


- (void) start
{
   // Ensure it's in Idle the first time. Usually it wil though and this
   // tryLock fails
   if( [_threadLock mulleTryLockWhenNotCondition:MulleThreadStateIdle])
      [_threadLock unlockWithCondition:MulleThreadStateIdle];
   [super start];
}

@end

