static const char RCSID[]="@(#)$Id: fixtime.c,v 1.2 2008/04/08 16:34:32 rkowen Exp $";
static const char AUTHOR[]="@(#)fixtime 1.0 2008/02/26 R.K.Owen,Ph.D.";
/* fixtime  -  will execute a command in an exact amount of time
 * either padding it out to the given time or killing it when the
 * command goes over.
 */
/** ** Copyright *********************************************************** **
 ** 									     **
 ** Copyright 2008 by R.K.Owen,Ph.D.		                      	     **
 ** last known email: rkowen@nersc.gov					     **
 **                   rk@owen.sj.ca.us					     **
 ** 									     **
 ** ************************************************************************ **/
 
#define _POSIX_SOURCE

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>	/* sigaction, kill */
#include <setjmp.h>	/* sigsetjmp */
#include <unistd.h>	/* alarm, getopt, fork, execvp, pause */
#include <time.h>	/* time */
#include <sys/types.h>	/* kill, fork */
#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif

#define T_NOW	(time(NULL) - start_time)

/* need to use the POSIX sigjmp_buf to save the current signal mask
 * else if you make repeated calls, then the second SIGALRM will
 * not be caught, and it will hang in the read()
 */
static sigjmp_buf FXTMjumpbuffer;	/* siglongjump global variable */

static void FXTMsigalrm_handler(int signum) {
	/* alarm went off - the fixtime has timed out - jump back */
	siglongjmp(FXTMjumpbuffer, 1);
}

void usage(void) {
	printf(
"fixtime -  will execute a command in an exact amount of time\n"
"either padding it out to the given time or killing it when the\n"
"command goes over.\n\n"
"usage: fixtime [-h|-t N][-v] command...\n"
"where:\n"
"	-h		this helpful info\n"
"	-t N		number of seconds to execute\n"
"	-v		verbose execution\n"
"	command	...	the command with arguments to execute\n\n"
"Version: %s\n\n",RCSID);
}

extern char	*optarg;		/* value passed from getopt() */
extern int	 optind;		/* index of argv after options */

int main (int argc, char *argv[]) {

	struct sigaction newsigalrm, oldsigalrm;/* ALRM interrupt */
	unsigned old_alarm_time, new_alarm_time;/* alarm times */
	int	jumpval = 0,			/* longjump return value */
		returnstatus = EXIT_FAILURE,	/* this function status */
		verbose = 0,			/* runtime verbosity */ 
		seconds = 0,			/* how long to run for */
		child_pid = 0,			/* subprocess id */
		waitstatus = 0,			/* from waitpid() */
		opt;	
	time_t	start_time = 0;			/* initial epoch time */

	start_time = time(NULL);

	while ((opt = getopt(argc, argv, "+hvt:")) != -1) {
		switch (opt) {
		case 'h':
			usage();
			return EXIT_SUCCESS;
			break;
		case 'v':
			verbose++;
			break;
		case 't':
			seconds = atoi(optarg);
			break;
		default: /* '?' */
			perror("fixtime : unrecognized option");
			usage();
			return returnstatus;
			break;
		}
	}

	/* set-up interrupt for SIGALRM */
	newsigalrm.sa_handler = FXTMsigalrm_handler;
	sigemptyset(&newsigalrm.sa_mask);
#ifdef SA_RESTART
	newsigalrm.sa_flags = SA_RESTART;
#endif

	if (sigaction(SIGALRM, &newsigalrm, &oldsigalrm) < 0) {
		perror("fixtime : signal set error");
		return returnstatus;
	}

	/* set place for longjump */
	jumpval = sigsetjmp(FXTMjumpbuffer,1);

	/* is this the first time through, or did we longjump here? */
	switch (jumpval) {
	case 0:			/* 1st time through - set up alarm */
		if (seconds < 0) {
			perror("fixtime : user alarm time error");
			usage();
			return returnstatus;
		} else {
			new_alarm_time = (unsigned) seconds;
		}
		if (verbose)
			printf("t:%ld - Setting alarm time = %ld\n",
				T_NOW, seconds);
		/* don't interfere with alarm if time-out = 0 seconds */
		if (seconds) old_alarm_time = alarm(new_alarm_time);
		/* readjust the argument list to the new command */
		argc-= optind;
		argv+= optind;
		/* fork process - use inherited pipes */
		if (verbose)
			printf("t:%ld - Forking program\n", T_NOW);
		switch(child_pid = fork()) {
		case -1:			/* fork failure */
			perror("fixtime : failed to fork");
			return returnstatus;
		case 0:				/* child */
			if (verbose)
				printf("t:%ld - Executing program: %s\n",
					T_NOW, argv[0]);
			if (execvp(argv[0],argv) < 0) {
				perror("fixtime : child failed to execvp");
				_exit(returnstatus);
			}
			perror("fixtime : should not get here!");
		default:			/* parent */
			if (seconds) {	/* wait until timer trips */
				if (verbose)
					printf("t:%ld - Pausing\n", T_NOW);
				pause();
				/* sleep(seconds); */
			} else {	/* no time limit - wait for child */
				if (verbose)
					printf("t:%ld - Waiting for pid=%ld\n",
						T_NOW, (long) child_pid);
				(void) waitpid(child_pid,&waitstatus,0);
				if (verbose)
					printf("t:%ld - Waited for pid=%ld\n",
						T_NOW, (long) child_pid);
			}
		}
		break;
	case 1:			/* alarm went off */
		/* kill the boy ... */
		(void) kill(child_pid,SIGKILL);
		if (verbose)
			printf("t:%ld - Finishing up: %s\n", T_NOW, argv[0]);
		returnstatus = 0;
		break;
	default:		/* should not get here */
		perror("fixtime : `should not get here' error");
		return returnstatus;
	}

#if 0
	/* guard against another SIGALRM while resetting handler */
	(void) alarm(0);

	/* reset SIGALRM before leaving */
	if (sigaction(SIGALRM, &oldsigalrm, NULL) < 0) {
		perror("fixtime : signal reset error");
		return returnstatus;
	}
	/* reset alarm before leaving */
	(void) alarm(old_alarm_time);
#endif

	return returnstatus;
}
