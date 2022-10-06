//
//  main.m
//  archiver-test
//
//  Created by Nat! on 19.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//
#import "MulleThread.h"


enum
{
   MulleThreadStartup,
   MulleThreadIdle,
   MulleThreadBusy,
   MulleThreadCancelled  // set by thread if cancel was received
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

   _threadLock = [[NSConditionLock alloc] initWithCondition:MulleThreadStartup];

   return( self);
}


- (void) dealloc
{
   [_threadLock release];

   [super dealloc];
}


- (void) nudge
{
   [_threadLock mulleLockWhenNotCondition:MulleThreadStartup];
   [_threadLock unlockWithCondition:MulleThreadBusy];
}


- (void) cancel
{
   [super cancel];
   [self nudge];
}


- (void) main
{
   NSAutoreleasePool   *pool;

   pool = [NSAutoreleasePool new];
   for(;;)
   {
      [_threadLock mulleLockWhenNotCondition:MulleThreadIdle];

      if( [self isCancelled])
      {
         [_threadLock unlockWithCondition:MulleThreadCancelled];
         break;
      }

      [_threadLock unlockWithCondition:MulleThreadIdle];

      [pool mulleReleaseAllObjects];
      [super main];
   }

   [pool release];
}


- (void) mulleJoin
{
   [_threadLock lockWhenCondition:MulleThreadCancelled];
   [_threadLock unlockWithCondition:MulleThreadCancelled];
}


@end

