//
//  main.m
//  archiver-test
//
//  Created by Nat! on 19.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//
#import "MulleInvocationQueue.h"

#import "import-private.h"

#import "MulleThread.h"


@class MulleInvocationQueue;


NS_OPTIONS_TABLE( MulleInvocationQueueState, 7) =
{
   NS_OPTIONS_ITEM( MulleInvocationQueueIdle),
   NS_OPTIONS_ITEM( MulleInvocationQueueRun),
   NS_OPTIONS_ITEM( MulleInvocationQueueDone),
   NS_OPTIONS_ITEM( MulleInvocationQueueError),
   NS_OPTIONS_ITEM( MulleInvocationQueueException),
   NS_OPTIONS_ITEM( MulleInvocationQueueCancel),
   NS_OPTIONS_ITEM( MulleInvocationQueueNotified)
};


@implementation MulleInvocationQueue


+ (instancetype) invocationQueue
{
   return( [[[self alloc] initWithCapacity:1024] autorelease]);
}


- (instancetype) initWithCapacity:(NSUInteger) capacity
{
   mulle_pointerqueue_init( &_queue, capacity / 8, 8, MulleObjCInstanceGetAllocator( self));

   return( self);
}


- (void) finalize
{
   [_executionThread cancel];
   [super finalize];
}


- (void) dealloc
{
   NSInvocation   *invocation;

   [_executionThread mulleJoin];
   [_executionThread release];

   [self _discardInvocations];

   mulle_pointerqueue_done( &_queue);

   [super dealloc];
}


- (BOOL) isExecutionThread
{
   return( ! _executionThread || [NSThread currentThread] == _executionThread);
}


- (NSUInteger) state
{
   return( (NSUInteger) _mulle_atomic_pointer_read( &_state));
}


- (void) _setState:(NSUInteger) state
{
   _mulle_atomic_pointer_write( &_state, (void *) state);

   if( _messageDelegateOnExecutionThread && [self isExecutionThread])
   {
      [_delegate invocationQueueDidChangeState:self];
      state = state | MulleInvocationQueueNotified;
      _mulle_atomic_pointer_write( &_state, (void *) state);
   }
}


- (void) addInvocation:(NSInvocation *) invocation
{
   [invocation retainArguments];
   [invocation retain];

   mulle_pointerqueue_push( &_queue, invocation);
   [_executionThread nudge];
}


- (void) addFinalInvocation:(NSInvocation *) invocation
{
   [_finalInvocation autorelease];
   _finalInvocation = [invocation retain];

   [self addInvocation:invocation];
}


- (void) _discardInvocations
{
   NSInvocation   *invocation;

   while( invocation = mulle_pointerqueue_pop( &_queue))
      [invocation autorelease];
}


- (void) _finalizing:(NSInvocation *) invocation
{
   assert( [self isExecutionThread]);

   [_finalInvocation autorelease];
   _finalInvocation = nil;
}


- (void) invokeAll
{
   NSInvocation   *invocation;

   assert( [self isExecutionThread]);

   if( _pedanticStateChanges)
      [self _setState:MulleInvocationQueueRun];

   for(;;)
   {
      invocation = mulle_pointerqueue_pop( &_queue);
      if( ! invocation)
      {
         if( _doneOnEmptyQueue)
         {
            [self _finalizing:invocation];  // do this before _setState:
            [self _setState:MulleInvocationQueueDone];
         }
         break;
      }

      invocation = [invocation autorelease];

      if( _catchesExceptions)
      {
         @try
         {
            [invocation invoke];
         }
         @catch( NSObject *exception)
         {
            if( _ignoresCaughtExceptions)
               continue;

            [_exception autorelease];
            _exception = [exception retain];

            [self _discardInvocations];
            [self _setState:MulleInvocationQueueException];
            return;
         }
      }
      else
      {
         [invocation invoke];
      }

      if( _cancelsOnFailedReturnStatus && [invocation mulleReturnStatus])
      {
         [self _discardInvocations];
         [self _setState:MulleInvocationQueueError];
         return;
      }

      if( _finalInvocation == invocation)
      {
         [self _setState:MulleInvocationQueueDone];
         [self _finalizing:invocation]; // do this after _setState:
         return;
      }
   }

   if( _pedanticStateChanges)
      [self _setState:MulleInvocationQueueIdle];

}


- (void) run
{
   if( ! _executionThread)
      _executionThread = [MulleThread mulleThreadWithTarget:self
                                                   selector:@selector( invokeAll)
                                                     object:nil];
   [self _setState:MulleInvocationQueueIdle];
   [_executionThread start];
}  


- (void) cancel
{
   [_executionThread cancel];
}


// returns 1 if running
- (BOOL) poll
{
   NSUInteger   state;

   assert( [NSThread currentThread] != _executionThread);

   state = [self state];
   if( ! (state & MulleInvocationQueueNotified))
   {
      if( ! _messageDelegateOnExecutionThread && ! [self isExecutionThread])
      {
         [self _setState:state|MulleInvocationQueueNotified];
         [_delegate invocationQueueDidChangeState:self];
      }
   }

   return( (state & ~MulleInvocationQueueNotified) == MulleInvocationQueueRun);
}

@end 



#if 0

#define UIInvocationQueueEventType  @selector( UIInvocationQueueEvent)


@interface UIInvocationQueueEvent : UIUserEvent

- (instancetype) initWithInvocationQueue:(MulleInvocationQueue *) queue;

@property( assign, readonly) MulleInvocationQueue   *invocationQueue;

@end


@implementation UIInvocationQueueEvent

- (instancetype) initWithInvocationQueue:(MulleInvocationQueue *) queue
{
   assert( windowInfo);

   [self initWithEventIdentifier:UIInvocationQueueEventType];
   _invocationQueue = [queue retain];
   return( self);
}


- (void) dealloc
{
   [_invocationQueue release];
   [super dealloc];
}


- (char *) _payloadUTF8String
{
   return( MulleObjC_asprintf( "invocationQueue=%#@", _invocationQueue));
}

@end

#endif
