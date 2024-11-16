#import <MulleThread/MulleThread.h>


static void   test_printf( char *format, ...)
{
   va_list   args;

   va_start( args, format);
#ifndef MULLE_TEST
   printf( "%lx : %.9f ", mulle_thread_self(), mulle_absolutetime_now());
#endif
   vprintf( format, args);
   fflush( stdout);
   va_end( args);
}


@interface Foo : NSObject
{
   NSUInteger   _count;
}
@end


@implementation Foo

- (int) runServer:(id) argument
{
   test_printf( "* %td\n", _count++);
   return( MulleThreadGoIdle);
}

@end


@interface DebugThread : MulleThread
@end


@implementation DebugThread

- (BOOL) isCancelled
{
   BOOL   flag;

   flag = [super isCancelled];
   mulle_fprintf( stderr, "%s -> %btd\n", __FUNCTION__, flag);
   return( flag);
}

- (BOOL) willCallMain
{
   BOOL   flag;

   flag = [super willCallMain];
   mulle_fprintf( stderr, "%s -> %btd\n", __FUNCTION__, flag);
   return( flag);
}


- (BOOL) willIdle
{
   BOOL   flag;

   flag = [super willIdle];
   mulle_fprintf( stderr, "%s -> %btd\n", __FUNCTION__, flag);
   return( flag);
}

- (void) cancelWhenIdle
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super cancelWhenIdle];
}


- (void) cancel
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super cancel];
}


- (void) preempt
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super preempt];
}


- (void) nudge
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super nudge];
}

@end



int   main( int argc, const char * argv[])
{
   NSConditionLock   *lock;
   MulleThread       *thread;
   NSUInteger        i;
   Foo               *foo;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   foo    = [Foo object];
   test_printf( "create\n");
   thread = [DebugThread mulleThreadWithTarget:foo
                                      selector:@selector( runServer:)
                                        object:nil];
   test_printf( "start\n");
   [thread mulleStart];
   test_printf( "sleep\n");
   mulle_relativetime_sleep( 0.1);

   for( i = 0; i < 100; i++)
   {
      test_printf( "nudge\n");
      [thread nudge];

      mulle_relativetime_sleep( 0.01);
   }
   test_printf( "cancel\n");
   [thread cancel];
   [thread nudge];
   mulle_relativetime_sleep( 0.01);
   test_printf( "join\n");
   [thread mulleJoin];

   return( 0);
}
