static const char RCSID[]="@(#)$Id: pchksum.c,v 1.2 2008/04/08 16:34:32 rkowen Exp $";
#include <stdlib.h>
#include <stdio.h>
#include <string.h>	/* memcpy */
#include <assert.h>
#if defined(HAVE_GETTIMEOFDAY) && !defined(HAVE_MPI_WTIME)
#  include <sys/time.h>	/* gettimeofday */
#  include <time.h>	/* gettimeofday */
#endif
#include <sys/resource.h>
#include <sys/types.h>
#include <stdint.h>
#include <unistd.h>	/* usleep */
#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif
#ifdef HAVE_MPI_H
#  include <mpi.h>
#elif HAVE_MPI_MPI_H
#  include <mpi/mpi.h>
#endif
#ifdef PE_CHKPT
#  include <pm_ckpt.h>
#endif
#include "genrand.h"
#include "sha1.h"

/* we will never pass 0 to malloc - hence no need for rpl_malloc */
#undef malloc

static int p_myrank = -1;
static struct timeval tck = { 0, 0 };
static struct timeval trs = { 0, 0 };

#ifdef PE_CHKPT
static long long tsub = 0;

void p_ck_cb( void )
{
  gettimeofday(&tck, 0);
}

void p_rs_cb( void )
{
  gettimeofday(&trs, 0);
  tsub = (trs.tv_sec - tck.tv_sec)*1000000 + (trs.tv_usec - tck.tv_usec);
  if (p_myrank == 0)
    printf(" Restart TSUB : %lld\n", tsub);
}

void p_rm_cb( void )
{
  gettimeofday(&trs, 0);
  tsub = (trs.tv_sec - tck.tv_sec)*1000000 + (trs.tv_usec - tck.tv_usec);
  if (p_myrank == 0)
    printf(" Resume TSUB : %lld\n", tsub);
}
#endif

long long pdelta_tv_offset( struct timeval tend, struct timeval tstart, struct timeval tckpt, struct timeval trsm )
{
  long long		xdel;

  xdel = (tend.tv_sec - tstart.tv_sec)*1000000 + (tend.tv_usec - tstart.tv_usec);
  if ((tstart.tv_sec < tckpt.tv_sec) && (tend.tv_sec > trsm.tv_sec)) {
    xdel -= (trsm.tv_sec - tckpt.tv_sec )*1000000 + (trsm.tv_usec - tckpt.tv_usec);
  }
  return xdel;
}


void usage(void) {
	printf(
"pchksum - a synthetic MPI application that runs a checksum for a specific\n"
"	amount of time or number of iterations, then unravels the checksum\n"
"	in the reverse.\n\n"
"usage: pchksum [-h][-v ...][-t secs|-T msecs|-n loopcount][-u usecs]\n\n"
"where:\n"
"  -h		this helpful info\n"
"  -v		verbosity (more occurences increases level)\n"
"  -t secs	run for the given number of seconds\n"
"  -T msecs	run for the given number of milliseconds\n"
"  -n loopcount	run for the given number of iterations\n"
"  -u usecs	sleep for this number of milliseconds between iterations\n\n"
	);
}

/*
 *   pchksum
 *
 *   Each task generates a random message string and computes 
 *   a digest.
 *               Z ----> task ----> Y
 *
 *   Each tasks sends the random message to Y and receives a 
 *   similar message from Z. The rank of Y & Z are randomly-
 *   generated. With each received message, the task does an 
 *   XOR operation onto a message buffer which initially contained
 *   its random message.
 *
 *   Continue this operation until requested time has expired.
 *
 *   The next part, repeats the above operation but in reverse
 *   order of Y & Z ranks. After the last XOR operation, the 
 *   updated message should be exactly the same as the initial 
 *   message. Or, equivalently their digests should match.
 *
 *   Return status if digests match.
 *
 *   This code does not do anything useful (apparently). It
 *   will however stress the communication subsystem and ensure
 *   correctness of the execution. It will also run on an
 *   arbitarily large partition size and for any specified time.
 *   
 */


#define MAX(x,y)		((x > y) ? x : y);
#define BUFFLEN			46543          		/* 64-bit words */
#define MAXREPLAY		1000

#ifdef HAVE_MPI_WTIME
	/* this GET_CLOCK() must run within MPI context */
#  define GET_CLOCK(x)		(x = MPI_Wtime())
#  define DELTA_TV2MSEC(x,y)	((long long) ((x-y)*1000))
#  define DELTA_TV2USEC(x,y)	((long long) ((x-y)*1000000))
#elif HAVE_GETTIMEOFDAY
#  define GET_CLOCK(x)		gettimeofday(&x,0)
#  define DELTA_TV2MSEC(x,y)	(pdelta_tv_offset(x,y,tck,trs)/1000)
#  define DELTA_TV2USEC(x,y)	pdelta_tv_offset(x,y,tck,trs)
#else
#  error  No suitable wallclock timer
#endif
#define RUNTIME(x)		(DELTA_TV2MSEC(x,tv00))

#if DEBUG>0
#  define DEFAULT_VERBOSE		DEBUG
#else
#  define DEFAULT_VERBOSE		0
#endif

void			gettofrom( int, int [], int []);
void 			XOR_merge( int, uint64_t [], const uint64_t [] );

static unsigned long	svec[GENRAND_VLEN+1];

int main(int argc, char *(argv[]) ) {
  struct tfreplay {
    int		to;
    int		from;
  } 			tfr[MAXREPLAY];
  int			*to, *from,
			i, j, jj,
			itmp = -1,
			loopmax = -1,
			verbose = DEFAULT_VERBOSE,
			buflen,
			myrank, nnode, nodecntrl;
  double		maxtime = -1.0;
  uint64_t		*rbuff, *sbuff, *tbuff;
  char			*rbuf0, *sbuf0, *tbuf0;
  unsigned char		*csp, *ctp;
  unsigned int		ttag = 0x77a;
  unsigned long		*snd_ts, *rcv_ts, *t_ts, delta_ts, max_delta_ts;
  MPI_Request		mreq;
  MPI_Status		mstat;
  MPI_Comm		comm = MPI_COMM_WORLD;
  /* the basic unit of time for code is msec = sec/1000 */
#ifdef HAVE_MPI_WTIME
  double		tv0, tv1, tv00, tv0ts;
  double		mtv0;
#elif HAVE_GETTIMEOFDAY
  struct timeval	tv0, tv1, tv00, tv0ts;
  struct timeval	mtv0;
#endif
#ifdef HAVE_USECONDS_T
  useconds_t		sleep_time = 1;
#else
  unsigned int		sleep_time = 1;
#endif
  double		msec,
			stx;
  unsigned long		s2vec[GENRAND_VLEN+1];
  SHA_CTX		shainfo;
  BYTE			shadigest1[20], shadigest2[20];
#ifdef PE_CHKPT
  callbacks_t 		cbt = { p_ck_cb, p_rs_cb, p_rm_cb };
#endif

  MPI_Init(&argc, &argv);
  GET_CLOCK(tv00);
  MPI_Comm_rank(comm, &p_myrank);
#ifdef PE_CHKPT
  i = mpc_set_ckpt_callbacks(&cbt);
  if (p_myrank == 0)
    printf("mpc_set_ckpt_callbacks: return val: %d\n", i);
#endif

  /*
   * parse args
   */
  {
    char		**cpp;
    for (cpp=argv+1; *cpp; ++cpp) {
      if (**cpp == '-') {
	switch ((*cpp)[1]) {
	case 't':
	  maxtime = (double)atoi(*(++cpp)) * 1000.0;
	  break;
	case 'T':
	  maxtime = (double)atoi(*(++cpp));
	  break;
	case 'v':
	  ++verbose;
	  break;
	case 'n':
	  loopmax = atoi(*(++cpp));
	  break;
	case 'u':
	  sleep_time = atoi(*(++cpp));
	  break;
	case 'h':
	default:
	  usage();
	  exit(1);
	}
      } else {
	usage();
	exit(1);
      }
    }
    if (((loopmax<0) && (maxtime<0.0)) || ((loopmax>0) && (maxtime>0.0))) {
      fprintf(stderr, "Error: specify only time or loopcount\n");
      exit(1);
    }
  }
  /*
   * initialization
   */
  MPI_Comm_rank(comm, &myrank);
  MPI_Comm_size(comm, &nnode);
  nodecntrl = nnode/2;
  to   = malloc(sizeof(int)*nnode);
  from = malloc(sizeof(int)*nnode);
  initrandvec(myrank, s2vec);
  buflen = sizeof(uint64_t)*BUFFLEN + sizeof(unsigned long);
  rbuf0 = malloc(buflen);
  sbuf0 = malloc(buflen);
  tbuf0 = malloc(buflen);
  rcv_ts = (unsigned long*)rbuf0;
  snd_ts = (unsigned long*)sbuf0;
  t_ts   = (unsigned long*)tbuf0;
  rbuff = (uint64_t *)(rcv_ts + 1);
  sbuff = (uint64_t *)(snd_ts + 1);
  tbuff = (uint64_t *)(t_ts + 1);
  memset(rbuf0, '\0', buflen);
  csp = (unsigned char *)sbuff;
  ctp = (unsigned char *)tbuff;
  for (i=0; i<BUFFLEN*sizeof(uint64_t); ++i)
    csp[i] = ctp[i] = genrand_r(s2vec)%256;
  SHAInit(&shainfo);
  SHAUpdate(&shainfo, (BYTE *)tbuff, (int) sizeof(uint64_t)*BUFFLEN);
  SHAFinal(shadigest1, &shainfo);
  if ((!myrank) && (verbose)) {
    printf(" Number of tasks: %d\n", nnode);
    printf(" Initial digest\n ");
    for (i=0; i<20; ++i) 
      printf("%02x", shadigest1[i]);
    printf("\n");
    if (verbose > 1) {
      printf("maxtime   = %10.4g secs\n",maxtime/1000.);
      printf("sleeptime = %ld\n",(long) sleep_time);
      printf("loopmax   = %d\n", loopmax);
      printf("verbosity = %d\n", verbose);
    }
    fflush(stdout);
  }
  initrandvec(1, svec);
  max_delta_ts = 0;
  /*
   * XOR merge - forward loop
   */
  MPI_Barrier(comm);
  GET_CLOCK(tv0);
  memcpy(&tv0ts,&tv0,sizeof(tv0ts));

  /* reduce by anticipated overhead time */
  if (maxtime > 0.0)
    maxtime -= 4.0*RUNTIME(tv0);

  for (stx=0.0, j=0; (loopmax<0) || (j<loopmax); ++j) {

    if (j == 1 && loopmax < 0) { /* gone through loop once - estimate loopmax */
      if (myrank == nodecntrl) {
	GET_CLOCK(tv1);
	msec = DELTA_TV2MSEC(tv1,tv0);
	loopmax = maxtime / msec / 2;
      }
      MPI_Bcast( &loopmax, 1, MPI_INTEGER, nodecntrl, comm);
      if (loopmax <= 0) {
	if (!myrank) printf(" insufficient time to run loops\n");
	MPI_Abort(comm,1);
      }
      if (!myrank && verbose > 1)
	printf("loopmax   = %d\n", loopmax);
      if (loopmax == 1)
	continue;
    }
    if (j < MAXREPLAY) {
      gettofrom(nnode, to, from);
#ifdef DEBUG
/* Build to/from assuming the maximum loop count MAXREPLAY.  Note
 * this is very unscalable.  At 5000 PEs this loop takes 30sec.  If
 * the long initialization is not desired, the assert checks could
 * be commented out as debugging code.
 */

      for (i=0; i<nnode; ++i) {
	assert((from[to[i]] == i));
	for (k=0; k<nnode; ++k) {
	  if (i!=k)
	    assert((to[i] != to[k]));
	}
      }
#endif
      tfr[j].to   = to[myrank];
      tfr[j].from = from[myrank];
    }
    jj = j % MAXREPLAY;
    if (tfr[jj].to == tfr[jj].from)	continue;
    GET_CLOCK(mtv0);
    *snd_ts = DELTA_TV2USEC(mtv0, tv0ts);
    if (verbose > 2) {
      printf("[%3d] Forward:  send to: %d  receive from: %d\n",
	  myrank, tfr[jj].to, tfr[jj].from);
      fflush(stdout);
    }
    MPI_Irecv(rbuf0, buflen, MPI_BYTE, tfr[jj].from, ttag+j, comm, &mreq);
    MPI_Send(sbuf0,  buflen, MPI_BYTE, tfr[jj].to,   ttag+j, comm);
    MPI_Wait(&mreq, &mstat);
    delta_ts = labs(*rcv_ts - *snd_ts);
    max_delta_ts = MAX(max_delta_ts, delta_ts);
    stx += buflen;

    XOR_merge(BUFFLEN, tbuff, rbuff);

    if (sleep_time > 0)
      usleep(sleep_time*1000);
    if ((!myrank) && (verbose > 2)) {
      GET_CLOCK(tv1);
      printf(" Iteration: %d Elapsed time: %.2f msecs\n",
	  j, (double) RUNTIME(tv1));
      fflush(stdout);
    }
  }
  if ((!myrank)) {
    if (verbose) {
      printf(" Forward merge complete");
#ifdef PE_CHKPT
      printf(" ( tsub = %d sec)\n",(int)(tsub/1000000));
#endif
      GET_CLOCK(tv1);
      msec = DELTA_TV2MSEC(tv1,tv0);
      printf("\n Elapsed time: %.2f msecs\n", msec);
      printf(" Outbound data volume: %.2f MB\n", stx/(1024.0*1024.0));
      fflush(stdout);
    }
    if ((verbose) || (maxtime>0.0)) {
      printf(" Iteration count: %d\n", loopmax);
      fflush(stdout);
    }
  }
  MPI_Barrier(comm);
  /*
   * XOR merge - in reverse order
   */
  GET_CLOCK(tv0);
  for (j=loopmax-1; j>=0; --j) {
    jj = j % MAXREPLAY;
    if (tfr[jj].to == tfr[jj].from)	continue;
    GET_CLOCK(mtv0);
    *snd_ts = DELTA_TV2USEC(mtv0, tv0ts);
    if (verbose > 2) {
      printf("[%3d] Reverse:  send to: %d  receive from: %d\n",
	  myrank, tfr[jj].to, tfr[jj].from);
      fflush(stdout);
    }
    MPI_Irecv(rbuf0, buflen, MPI_BYTE, tfr[jj].from, ttag+j, comm, &mreq);
    MPI_Send(sbuf0,  buflen, MPI_BYTE, tfr[jj].to,   ttag+j, comm);
    MPI_Wait(&mreq, &mstat);
    delta_ts = labs(*rcv_ts - *snd_ts);
    max_delta_ts = MAX(max_delta_ts, delta_ts);
    XOR_merge(BUFFLEN, tbuff, rbuff);

    if (sleep_time > 0)
      usleep(sleep_time*1000);
    if ((!myrank) && (verbose > 2)) {
      GET_CLOCK(tv1);
      printf(" Iteration: %d Elapsed time: %.2f msecs\n",
	  j, (double) RUNTIME(tv1));
      fflush(stdout);
    }
  }
  MPI_Barrier(comm);
  SHAInit(&shainfo);
  SHAUpdate(&shainfo, (BYTE *)tbuff, (int) sizeof(uint64_t)*BUFFLEN);
  SHAFinal(shadigest2, &shainfo);
  /*
   * optional printout
   */
  if ((!myrank) && (verbose)) {
    printf(" Reverse merge complete\n");
    GET_CLOCK(tv1);
    msec = DELTA_TV2MSEC(tv1,tv0);
    printf(" Elapsed time: %.2f msecs\n", msec);
    printf(" Final digest\n ");
    for (i=0; i<20; ++i) 
      printf("%02x", shadigest2[i]);
    printf("\n");
    printf(" Max stagger delta: %lu usecs\n", max_delta_ts);
    fflush(stdout);
  }
  /*
   * check status and finish
   */
  free(to); free(from);
  for (j=0, i=0; i<20; ++i)
    j |= (shadigest1[i] != shadigest2[i]);
  MPI_Allreduce(&j, &itmp, 1, MPI_INT, MPI_BOR, comm);
  if ((!myrank)) {
    GET_CLOCK(tv1);
    msec = RUNTIME(tv1);
    msec = maxtime - msec;
    if ( msec<0 ) msec= 0;
    if ( verbose ) printf(" Makeup nap: %.2f mSec\n", msec );
    if ( msec>0 ) usleep( msec*1000. );

    if ((verbose) || (maxtime>0.0)) {
      GET_CLOCK(tv1);
      msec = RUNTIME(tv1);
      printf(" Total elapsed time: %.2f secs\n", msec/1000);
    }
    if (verbose) {
      printf(" Status: %s\n", ((itmp)?"Failed":"OK"));
      fflush(stdout);
    }
  }
  MPI_Finalize();
  return (itmp);
}


void XOR_merge( int n, uint64_t p[], const uint64_t q[] ) {
  int			i;
  for (i=0; i<n; ++i) 
    p[i] ^= q[i];
}


void gettofrom( int p, int to[], int from[] ) {
  int			i, ii, j, k;

 reset:  
  for (i=0; i<p; ++i)
    to[i] = from[i] = -1;
  for (i=0; i<p; ++i) {
    ii = 1 - 2*(i%2);
    j = genrand_r(svec)%p;
    for (k=0; ((i==j) || (from[j]>=0)) && (k<p); ++k)
      j = ((j+=ii)<0) ? (p-1) : (j>(p-1)) ? 0 : j;
    if (k == p) {
      goto reset;
    }
    to[i] = j;
    from[j] = i;
  }
}
