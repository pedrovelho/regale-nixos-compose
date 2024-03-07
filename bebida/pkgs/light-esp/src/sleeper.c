static const char RCSID[]="@(#)$Id: sleeper.c,v 1.2 2008/04/08 16:34:32 rkowen Exp $";
static const char AUTHOR[]="@(#)sleeper 1.0 2008/02/26 R.K.Owen,Ph.D.";
/* just sleep and output periodically */
/** ** Copyright *********************************************************** **
 ** 									     **
 ** Copyright 2008 by R.K.Owen,Ph.D.		                      	     **
 ** last known email: rkowen@nersc.gov					     **
 **                   rk@owen.sj.ca.us					     **
 ** 									     **
 ** ************************************************************************ **/
 
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>		/* sleep */

#define SLEEPTIME	10	/* seconds */
#define MAXNAPS		10	/* MAXNAPS * SLEEPTIME = how long to run */
#define MAXLINE		255	/* line length */

int main(int argc, char *argv[]) {
	int cnt = 0;
	int maxcnt = MAXNAPS;
	char buffer[MAXLINE];
	int nomore = 0;
	if (argc > 1) {
		maxcnt = atoi(argv[1]);
	}
	printf("SLEEPER %d\n",cnt);
	while (cnt < maxcnt) {
		cnt++;
		sleep(SLEEPTIME);
		printf("SLEEPER %d",cnt);
		if (fgets(buffer,MAXLINE,stdin),!feof(stdin)) {
			printf(" - %s",buffer,stdout);
		} else
			printf("\n");
	}
	return EXIT_SUCCESS;
}
