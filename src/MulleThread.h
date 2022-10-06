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


#import "import.h"


//
// This thread object contains a threadLock. The first time the
// thread is started it will execute target/selector (from -main).
// Then the thread will sleep and wait until "-nudge"d. Then it will
// excute target/selector again. You can't use the -detach methods with
// MulleThread, but you can wait on it with -mulleJoin.
//
@interface MulleThread : NSThread

@property( readonly, retain) NSConditionLock   *threadLock;

- (void) nudge;
- (void) cancel;
- (void) mulleJoin;

@end


