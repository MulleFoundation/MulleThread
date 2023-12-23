#import <MulleThread/MulleThread.h>


@interface Foo : NSObject
@end


@implementation Foo

- (int) runServer:(id) argument
{
   return( MulleThreadGoIdle);
}

@end



int   main( int argc, const char * argv[])
{
   MulleThread       *thread;
   Foo               *foo;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   foo    = [Foo object];
   thread = [MulleThread mulleThreadWithTarget:foo
                                      selector:@selector( runServer:)
                                        object:nil];
   [thread start];
   [thread cancelWhenIdle];

   return( 0);
}
