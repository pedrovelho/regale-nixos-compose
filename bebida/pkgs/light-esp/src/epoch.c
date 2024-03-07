static const char RCSID[]="@(#)$Id: epoch.c,v 1.2 2008/04/08 16:34:32 rkowen Exp $";
#include <stdio.h>
#include <time.h>
/*
 * print current time in seconds from Epoch
 */

int main( int argc, char *(argv[]) )
{
  time_t		e;

  e = time(0);
  printf("%ld\n", (long) e);
  return 0;
}

