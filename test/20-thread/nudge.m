#import <MulleInvocationQueue/MulleInvocationQueue.h>


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

- (void) runServer:(id) argument
{
   test_printf( "* %td\n", _count++);
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
   thread = [MulleThread mulleThreadWithTarget:foo
                                      selector:@selector( runServer:)
                                        object:nil];
   test_printf( "start\n");
   [thread start];
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
   mulle_relativetime_sleep( 0.01);
   test_printf( "join\n");
   [thread mulleJoin];

   return( 0);
}
