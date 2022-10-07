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
   NSUInteger          condition;

   pool = [NSAutoreleasePool new];

#ifndef NDEBUG
   [self assertMainThreadTargetSelector];
#endif

   for(;;)
   {
      // MulleThreadStateIdle,
      // MulleThreadStateBusy,
      [_threadLock mulleLockWhenNotCondition:MulleThreadStateIdle];

      _rval = MulleThreadContinueMain;
      for(;;)
      {
         if( [self isCancelled])
            goto done;

         if( _rval != MulleThreadContinueMain)
            break;

         [pool mulleReleaseAllObjects];
         [super main];
      }

      if( _rval == MulleThreadCancelMain)
         goto done;

      [_threadLock unlockWithCondition:MulleThreadStateIdle];
   }

done:
   [_threadLock unlockWithCondition:MulleThreadStateExited];
   [pool release];
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
   // ensure it's in Idle the first time
   if( [_threadLock mulleTryLockWhenNotCondition:MulleThreadStateIdle])
      [_threadLock unlockWithCondition:MulleThreadStateIdle];
   [super start];
}

@end

