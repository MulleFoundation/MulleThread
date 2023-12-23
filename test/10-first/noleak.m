#import <MulleThread/MulleThread.h>


int   main( int argc, char *argv[])
{
   [MulleThread mulleThreadWithTarget:[MulleThread class]
                             selector:@selector( whatever)
                               object:nil];
   return( 0);
}


/*
 * extension : mulle-sde/objc-test-library-demo
 * directory : demo/all
 * template  : .../noleak.m
 * Suppress this comment with `export MULLE_SDE_GENERATE_FILE_COMMENTS=NO`
 */
