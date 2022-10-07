#import <MulleInvocationQueue/MulleInvocationQueue.h>



int   main( int argc, const char * argv[])
{
   MulleInvocationQueue   *queue;

   queue  = [MulleInvocationQueue invocationQueue];

   [queue start];
   [queue cancelWhenIdle];

   return( 0);
}
