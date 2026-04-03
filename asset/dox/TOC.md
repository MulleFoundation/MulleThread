# MulleThread Library Documentation for AI

## 1. Introduction & Purpose

MulleThread provides a lightweight threading abstraction combining NSThread with NSConditionLock for efficient work dispatch. Implements a nudge-based wake-on-demand pattern where threads idle waiting for notifications, then execute target/selector methods and return to idle. Ideal for background task processing, worker thread pools, and event-driven architectures without busy-waiting overhead.

## 2. Key Concepts & Design Philosophy

- **Nudge-Based Wakeup**: Thread sleeps until nudged; no busy-waiting or polling
- **Target/Selector Execution**: Executes Objective-C methods in separate thread
- **Condition Lock**: Uses NSConditionLock internally for efficient synchronization
- **Autorelease Management**: Automatically manages NSAutoreleasePool per cycle
- **State Tracking**: Tracks idle/busy state for safe synchronization
- **Graceful Shutdown**: Multiple termination strategies (cancel, preempt, join)

## 3. Core API & Data Structures

### MulleThread Class

#### Return Values from target/selector

```objc
enum {
    MulleThreadGoIdle        = 0,      // Thread returns to idle, waits for nudge
    MulleThreadContinueMain  = 1,      // Run target/selector again immediately
    MulleThreadCancelMain    = -1      // Cancel thread execution
};
```

#### Creation & Initialization

- `+ mulleThreadWithTarget:(id)target selector:(SEL)selector object:(id)object` → `instancetype`: Create thread with work
- `+ mulleThreadWithTarget:(id)target selector:(SEL)selector object:(id)object autoreleasepool:(BOOL)flag` → `instancetype`: Create with autorelease pool control
- `- init` → `instancetype`: Initialize (no work assigned initially)

#### Thread Control

- `- start` → `void`: Start thread (does NOT execute target/selector yet; waits for nudge)
- `- nudge` → `void`: Wake thread to execute target/selector (can call from any thread)
- `- preempt` → `void`: Cancel immediately, don't wait for idle (not from within thread)
- `- cancelWhenIdle` → `void`: Cancel gracefully when thread becomes idle (not from within thread)
- `- cancel` → `void`: Cancel thread (can call from within thread)

#### Synchronization

- `- mulleJoin` → `void`: Block until thread exits (only after preempt or cancelWhenIdle called)
- `- blockUntilNoLongerBusy` → `void`: Wait until thread idles (snapshot in time; not from within thread)
- `- isIdle` → `BOOL`: Check if thread currently idle (snapshot; not from within thread)

#### Properties

- `threadLock` (NSConditionLock *, readonly): Access underlying condition lock

#### Customization Points

- `- setInvocation:(NSInvocation *)invocation` → `void`: Change work for next nudge (blocks if not idle)
- `- willCallMain` → `BOOL`: Called before executing target/selector (in locked state); return NO to skip
- `- willIdle` → `BOOL`: Called before going idle; return NO to run again immediately (only sensible if invocation changed)

### Thread Lifecycle

```
Created → Start → Idle → [Nudged] → Running → Idle → ... → Preempted/Cancelled
                                                          ↓
                                                       Exited
```

#### Execution Flow per Nudge

1. Thread receives nudge while idle
2. Wakes up and acquires lock
3. Calls `-willCallMain` (return NO to skip execution)
4. Executes target/selector (if willCallMain returned YES)
5. Target/selector returns code (GoIdle, ContinueMain, CancelMain)
6. If GoIdle: calls `-willIdle`, returns to idle if willIdle returns YES
7. If ContinueMain: runs target/selector again without nudge
8. If CancelMain: cancels and exits thread

## 4. Performance Characteristics

- **Wakeup Latency**: O(1) condition variable signal with low overhead
- **Idle CPU**: Essentially zero (thread blocked on condition, not polling)
- **Synchronization**: O(1) lock acquisitions using condition locks
- **Memory**: One NSConditionLock + thread stack per MulleThread
- **Autorelease**: Managed per-cycle; no accumulation
- **Context Switching**: Minimal; efficient on multi-core systems

## 5. AI Usage Recommendations & Patterns

### Best Practices

- **Nudge from Different Thread**: Nudge comes from main thread or other worker threads
- **Graceful Shutdown**: Use `-cancelWhenIdle` for clean shutdown; always call `-mulleJoin` after
- **Check Idle State**: Use `-isIdle` to verify thread state before operations
- **Autorelease Pool**: Let MulleThread manage it; don't create nested pools in target/selector
- **Error Handling**: Target/selector should return CancelMain on fatal errors
- **Work Queue Pattern**: Use target/selector to process from queue; ContinueMain for batching

### Common Pitfalls

- **Calling from Within Thread**: Never call nudge, preempt, or cancelWhenIdle from within target/selector
- **Join Without Cancel**: Calling -mulleJoin without preempt/cancelWhenIdle blocks forever (thread waits for nudges)
- **Race Conditions**: isIdle is snapshot; don't assume state unchanged after checking
- **Ignoring Return Value**: Target/selector return value controls thread flow; always return sensible value
- **Memory Leaks**: If using invocations, ensure arguments properly retained/released
- **Threading Deadlock**: Avoid calling blocking operations that wait on this thread from outside

### Idiomatic Usage

```objc
// Pattern 1: Create and start thread
MulleThread *thread = [MulleThread mulleThreadWithTarget:self 
                                                selector:@selector(workerRun:)
                                                  object:nil];
[thread start];

// Pattern 2: Wake thread to work
[thread nudge];

// Pattern 3: Graceful shutdown
[thread cancelWhenIdle];
[thread mulleJoin];

// Pattern 4: Target/selector implementation
- (int)workerRun:(id)object {
    // Do work...
    if (errorCondition) {
        return MulleThreadCancelMain;  // Abort
    }
    return MulleThreadGoIdle;          // Return to idle, wait for nudge
}

// Pattern 5: Batch processing
- (int)workerRun:(id)object {
    [self processNextBatch];
    if ([self hasMoreWork]) {
        return MulleThreadContinueMain;  // Process again without nudge
    }
    return MulleThreadGoIdle;
}
```

## 6. Integration Examples

### Example 1: Simple Worker Thread

```objc
#import <MulleThread/MulleThread.h>

@interface Worker : NSObject
@property (nonatomic, retain) MulleThread *thread;
@end

@implementation Worker
- (void)start {
    self.thread = [MulleThread mulleThreadWithTarget:self 
                                            selector:@selector(run:)
                                              object:nil];
    [self.thread start];
}

- (int)run:(id)object {
    NSLog(@"Thread doing work");
    sleep(1);  // Simulate work
    return MulleThreadGoIdle;
}

- (void)nudgeThread {
    [self.thread nudge];
}

- (void)stop {
    [self.thread cancelWhenIdle];
    [self.thread mulleJoin];
}

- (void)dealloc {
    [self.thread release];
    [super dealloc];
}
@end

int main() {
    Worker *worker = [[Worker alloc] init];
    [worker start];
    
    [worker nudgeThread];
    sleep(2);
    
    [worker stop];
    [worker release];
    
    return 0;
}
```

### Example 2: Background Task Processing

```objc
#import <MulleThread/MulleThread.h>

@interface TaskQueue : NSObject
{
    NSMutableArray *tasks;
    MulleThread *workerThread;
}
@end

@implementation TaskQueue
- (id)init {
    self = [super init];
    tasks = [[NSMutableArray alloc] init];
    workerThread = [MulleThread mulleThreadWithTarget:self
                                             selector:@selector(processQueue:)
                                               object:nil];
    [workerThread start];
    return self;
}

- (void)addTask:(NSString *)task {
    [tasks addObject:task];
    [workerThread nudge];
}

- (int)processQueue:(id)object {
    while ([tasks count] > 0) {
        NSString *task = [tasks objectAtIndex:0];
        [tasks removeObjectAtIndex:0];
        
        NSLog(@"Processing: %@", task);
    }
    return MulleThreadGoIdle;
}

- (void)dealloc {
    [workerThread cancelWhenIdle];
    [workerThread mulleJoin];
    [workerThread release];
    [tasks release];
    [super dealloc];
}
@end

int main() {
    TaskQueue *queue = [[TaskQueue alloc] init];
    
    [queue addTask:@"Task 1"];
    [queue addTask:@"Task 2"];
    [queue addTask:@"Task 3"];
    
    sleep(2);
    [queue release];
    
    return 0;
}
```

### Example 3: Checking Thread State

```objc
#import <MulleThread/MulleThread.h>

int main() {
    MulleThread *thread = [MulleThread mulleThreadWithTarget:nil
                                                    selector:NULL
                                                      object:nil];
    [thread start];
    
    NSLog(@"After start, idle: %s", [thread isIdle] ? "yes" : "no");
    
    // Check idle after giving thread time to settle
    sleep(1);
    NSLog(@"After sleep, idle: %s", [thread isIdle] ? "yes" : "no");
    
    [thread cancelWhenIdle];
    [thread mulleJoin];
    
    return 0;
}
```

### Example 4: Continuous Background Work

```objc
#import <MulleThread/MulleThread.h>

@interface BackgroundWorker : NSObject
{
    MulleThread *thread;
    int workCount;
}
@end

@implementation BackgroundWorker
- (id)init {
    self = [super init];
    workCount = 0;
    thread = [MulleThread mulleThreadWithTarget:self
                                      selector:@selector(work:)
                                        object:nil];
    [thread start];
    return self;
}

- (int)work:(id)object {
    workCount++;
    NSLog(@"Work iteration: %d", workCount);
    
    if (workCount < 5) {
        // Continue work without waiting for nudge
        return MulleThreadContinueMain;
    }
    
    // After 5 iterations, wait for nudge
    return MulleThreadGoIdle;
}

- (void)startWork {
    [thread nudge];
}

- (void)dealloc {
    [thread cancelWhenIdle];
    [thread mulleJoin];
    [thread release];
    [super dealloc];
}
@end

int main() {
    BackgroundWorker *worker = [[BackgroundWorker alloc] init];
    
    [worker startWork];
    sleep(2);
    
    [worker release];
    return 0;
}
```

### Example 5: Coordinated Multiple Threads

```objc
#import <MulleThread/MulleThread.h>

@interface Coordinator : NSObject
{
    NSMutableArray *threads;
}
@end

@implementation Coordinator
- (id)init {
    self = [super init];
    threads = [[NSMutableArray alloc] init];
    
    // Create 3 worker threads
    for (int i = 0; i < 3; i++) {
        MulleThread *thread = [MulleThread mulleThreadWithTarget:self
                                                       selector:@selector(work:)
                                                         object:[NSNumber numberWithInt:i]];
        [thread start];
        [threads addObject:thread];
    }
    
    return self;
}

- (int)work:(NSNumber *)threadId {
    NSLog(@"Thread %@ working", threadId);
    sleep(1);
    return MulleThreadGoIdle;
}

- (void)wakeAll {
    for (MulleThread *thread in threads) {
        [thread nudge];
    }
}

- (void)stopAll {
    for (MulleThread *thread in threads) {
        [thread cancelWhenIdle];
    }
    for (MulleThread *thread in threads) {
        [thread mulleJoin];
    }
}

- (void)dealloc {
    [self stopAll];
    [threads release];
    [super dealloc];
}
@end

int main() {
    Coordinator *coord = [[Coordinator alloc] init];
    
    [coord wakeAll];
    sleep(3);
    
    [coord stopAll];
    [coord release];
    
    return 0;
}
```

### Example 6: Error Handling with CancelMain

```objc
#import <MulleThread/MulleThread.h>

@interface SafeWorker : NSObject
{
    MulleThread *thread;
}
@end

@implementation SafeWorker
- (id)init {
    self = [super init];
    thread = [MulleThread mulleThreadWithTarget:self
                                      selector:@selector(work:)
                                        object:nil];
    [thread start];
    return self;
}

- (int)work:(id)object {
    NSError *error = nil;
    
    // Simulate work that might fail
    BOOL success = [self performWorkWithError:&error];
    
    if (!success) {
        NSLog(@"Error: %@", [error localizedDescription]);
        return MulleThreadCancelMain;  // Abort thread on error
    }
    
    NSLog(@"Work completed successfully");
    return MulleThreadGoIdle;
}

- (BOOL)performWorkWithError:(NSError **)error {
    // Simulate work
    return YES;  // Or NO on error
}

- (void)nudge {
    [thread nudge];
}

- (void)dealloc {
    [thread cancelWhenIdle];
    [thread mulleJoin];
    [thread release];
    [super dealloc];
}
@end

int main() {
    SafeWorker *worker = [[SafeWorker alloc] init];
    
    [worker nudge];
    sleep(1);
    
    [worker release];
    return 0;
}
```

## 7. Dependencies

- MulleObjC (NSThread, NSConditionLock)
- MulleFoundationBase
