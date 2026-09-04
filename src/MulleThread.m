//
//  MulleThread.m
//  MulleThread
//
//  Copyright (c) 2022 Nat! - Mulle kybernetiK.
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
#import "MulleThread.h"


// thread states do not convey error/completion status
// thread states are also not "commands" you don't set
// the state to MulleThreadStateExited and expect
// the thread to cancel
typedef NS_ENUM( NSUInteger, MulleThreadState)
{
   MulleThreadStateIdle   = 0,
   MulleThreadStateBusy   = 1,
   MulleThreadStateExited = -1 // set by thread when main exits
};


#define MAIN_DEBUG

@implementation MulleThread

+ (void) detachNewThreadSelector:(SEL) sel
                        toTarget:(id) target
                      withObject:(id) argument
{
MULLE_C_UNUSED( sel );
MULLE_C_UNUSED( target );
MULLE_C_UNUSED( argument );
// makes no sense with MulleThread, use NSThread
   abort();
}


+ (void) mulleDetachNewThreadWithFunction:(MulleThreadFunction_t *) f
                                 argument:(void *) argument
{
MULLE_C_UNUSED( f );
MULLE_C_UNUSED( argument );
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
   id   objects[ 2];

   [_threadLock lockWhenCondition:MulleThreadStateIdle];
   {
      // We need to put both invocation into the same uniquing set
      // to make sure mulleRelinquishAccess is only called once. Probably
      // need API to relinquish more
      objects[ 0] = _invocation;
      objects[ 1] = invocation;
      MulleObjCRelinquishAccessToObjects( objects, 2);

      [_invocation autorelease];
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
      mulle_fprintf( stderr, "\n***** %p (%p) waiting on <> idle\n", (void *) mulle_thread_self(), self);
#endif
      [_threadLock mulleLockWhenNotCondition:MulleThreadStateIdle];
#ifdef MAIN_DEBUG
      mulle_fprintf( stderr, "\n***** %p (%p) got <> idle\n", (void *) mulle_thread_self(), self);
#endif
      _rval = MulleThreadContinueMain;
      for(;;)
      {
         if( [self isCancelled])
         {
#ifdef MAIN_DEBUG
            mulle_fprintf( stderr, "***** 0x%p (%p) thread has received a cancel\n", (void *) mulle_thread_self(), self);
#endif
            goto done;
         }

         if( _rval != MulleThreadContinueMain)
            break;

#ifdef MAIN_DEBUG
         mulle_fprintf( stderr, "***** 0x%p (%p) call [super main]\n", (void *) mulle_thread_self(), self);
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
         mulle_fprintf( stderr, "***** 0x%p (%p) main return value indicates cancel\n", (void *) mulle_thread_self(), self);
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
   mulle_fprintf( stderr, "\n***** 0x%p (%p) is exiting\n\n", (void *) mulle_thread_self(), self);
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
   MulleThreadState   condition;

   [_threadLock mulleLockWhenNotCondition:MulleThreadStateBusy];
   condition = [_threadLock condition];
   [_threadLock unlockWithCondition:condition];
}


- (void) cancelWhenIdle
{
   MulleThreadState   condition;

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

