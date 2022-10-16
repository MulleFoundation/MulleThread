#ifdef __has_include
# if __has_include( "NSObject.h")
#  import "NSObject.h"
# endif
#endif

#import "import.h"

#define MULLE_INVOCATION_QUEUE_VERSION ((0 << 24) | (0 << 8) | 1)


@class MulleThread;
@class MulleInvocationQueue;


typedef NS_OPTIONS( NSUInteger, MulleInvocationQueueState)
{
   MulleInvocationQueueInit = 0,                  // in the beginning
   MulleInvocationQueueIdle,                      // when empty
   MulleInvocationQueueRun,                       // queue is executing
   MulleInvocationQueueEmpty,                     // all invocations processed
   MulleInvocationQueueDone,                      // all invocations till final processed
   MulleInvocationQueueError,                     // cancel request fulfilled by "execution"
   MulleInvocationQueueException,
   MulleInvocationQueueCancel,
   MulleInvocationQueueNotified = 0x8000,         // "main" has notified
};


MULLE_INVOCATION_QUEUE_GLOBAL
NS_OPTIONS_TABLE( MulleInvocationQueueState, 9);


static inline char   *MulleInvocationQueueStateUTF8String( NSUInteger options)
{
   return( NS_OPTIONS_PRINT( MulleInvocationQueueState, options));
}


static BOOL   MulleInvocationQueueStateIsFinished( NSUInteger state)
{
   state &= ~MulleInvocationQueueNotified;
   switch( state)
   {
   default                            : return( NO);
   case MulleInvocationQueueEmpty     :
   case MulleInvocationQueueCancel    :
   case MulleInvocationQueueException :
   case MulleInvocationQueueDone      : return( YES);
   }
}

static BOOL   MulleInvocationQueueStateCanBeCancelled( NSUInteger state)
{
   state &= ~MulleInvocationQueueNotified;
   switch( state)
   {
   default                            : return( NO);
   case MulleInvocationQueueIdle      :
   case MulleInvocationQueueCancel    :
   case MulleInvocationQueueException :
   case MulleInvocationQueueEmpty     :
   case MulleInvocationQueueDone      : return( YES);
   }
}



@protocol MulleInvocationQueueDelegate

// check state
- (void) invocationQueueDidChangeState:(MulleInvocationQueue *) queue;

@end




@interface MulleInvocationQueue : NSObject
{
   mulle_thread_mutex_t          _queueLock;
   struct mulle_pointerqueue     _queue;
   mulle_atomic_pointer_t        _state;
   NSInvocation                  *_finalInvocation;
   BOOL                          _notified;
}

@property( assign) id <MulleInvocationQueueDelegate>   delegate;
@property( readonly, retain) MulleThread               *executionThread;
@property( readonly, retain) NSInvocation              *failedInvocation;
@property( readonly, retain) id                        exception;

// TODO make this optiona and set atomically
@property( assign) BOOL   trace;                            // send "done", whenever queue is empty (NO)
@property( assign) BOOL   doneOnEmptyQueue;                 // send "done", whenever queue is empty (NO)
@property( assign) BOOL   catchesExceptions;                // cancel on exception (NO)
@property( assign) BOOL   ignoresCaughtExceptions;          // (NO)
@property( assign) BOOL   cancelsOnFailedReturnStatus;      // (NO)
@property( assign) BOOL   messageDelegateOnExecutionThread; // (NO)
@property( assign) BOOL   terminateWaitsForCompletion;      // don't terminate before complete (NO)


+ (instancetype) invocationQueue;
- (instancetype) initWithCapacity:(NSUInteger) capacity;

- (BOOL) poll;
- (int) invokeNextInvocation:(id) sender;  // unused sender

- (int) terminate;  // calls cancel if not appShouldWaitForCompletion, else blocks
- (void) preempt;
- (void) cancelWhenIdle;
- (void) start;

- (void) addInvocation:(NSInvocation *) invocation;
- (void) addFinalInvocation:(NSInvocation *) invocation;

- (NSUInteger) state;


@end


#import "_MulleInvocationQueue-export.h"


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
