static const char RCSID[]="@(#)$Id: genrand.c,v 1.2 2008/04/08 16:34:32 rkowen Exp $";
#include "genrand.h"

/* A C-program for MT19937: Integer version (1999/10/28)          */
/*  genrand() generates one pseudorandom unsigned integer (32bit) */
/* which is uniformly distributed among 0 to 2^32-1  for each     */
/* call. sgenrand(seed) sets initial values to the working area   */
/* of 624 words. Before genrand(), sgenrand(seed) must be         */
/* called once. (seed is any 32-bit integer.)                     */
/*   Coded by Takuji Nishimura, considering the suggestions by    */
/* Topher Cooper and Marc Rieffel in July-Aug. 1997.              */

/* This library is free software under the Artistic license:       */
/* see the file COPYING distributed together with this code.       */
/* For the verification of the code, its output sequence file      */
/* mt19937int.out is attached (2001/4/2)                           */

/* Copyright (C) 1997, 1999 Makoto Matsumoto and Takuji Nishimura. */
/* Any feedback is very welcome. For any question, comments,       */
/* see http://www.math.keio.ac.jp/matumoto/emt.html or email       */
/* matumoto@math.keio.ac.jp                                        */

/* REFERENCE                                                       */
/* M. Matsumoto and T. Nishimura,                                  */
/* "Mersenne Twister: A 623-Dimensionally Equidistributed Uniform  */
/* Pseudo-Random Number Generator",                                */
/* ACM Transactions on Modeling and Computer Simulation,           */
/* Vol. 8, No. 1, January 1998, pp 3--30.                          */


/* Period parameters */  
/* #define N 624 */  /* replaced with GENRAND_VLEN */
#define M 397
#define MATRIX_A 0x9908b0df   /* constant vector a */
#define UPPER_MASK 0x80000000 /* most significant w-r bits */
#define LOWER_MASK 0x7fffffff /* least significant r bits */

/* Tempering parameters */   
#define TEMPERING_MASK_B 0x9d2c5680
#define TEMPERING_MASK_C 0xefc60000
#define TEMPERING_SHIFT_U(y)  (y >> 11)
#define TEMPERING_SHIFT_S(y)  (y << 7)
#define TEMPERING_SHIFT_T(y)  (y << 15)
#define TEMPERING_SHIFT_L(y)  (y >> 18)

static unsigned long mt[GENRAND_VLEN]; /* the array for the state vector  */
static int mti=GENRAND_VLEN+1; /* mti==N+1 means mt[N] is not initialized */

/* Initializing the array with a seed */
void sgenrand(unsigned long seed)
{
    int i;

    for (i=0;i<GENRAND_VLEN;i++) {
         mt[i] = seed & 0xffff0000;
         seed = 69069 * seed + 1;
         mt[i] |= (seed & 0xffff0000) >> 16;
         seed = 69069 * seed + 1;
    }
    mti = GENRAND_VLEN;
}

/* Initialization by "sgenrand()" is an example. Theoretically,      */
/* there are 2^19937-1 possible states as an intial state.           */
/* This function allows to choose any of 2^19937-1 ones.             */
/* Essential bits in "seed_array[]" is following 19937 bits:         */
/*  (seed_array[0]&UPPER_MASK), seed_array[1], ..., seed_array[GENRAND_VLEN-1]. */
/* (seed_array[0]&LOWER_MASK) is discarded.                          */ 
/* Theoretically,                                                    */
/*  (seed_array[0]&UPPER_MASK), seed_array[1], ..., seed_array[GENRAND_VLEN-1]  */
/* can take any values except all zeros.                             */
void lsgenrand( unsigned long seed_array[] )
/* the length of seed_array[] must be at least GENRAND_VLEN */
{
    int i;

    for (i=0;i<GENRAND_VLEN;i++) 
      mt[i] = seed_array[i];
    mti=GENRAND_VLEN;
}

unsigned long genrand( void )
{
    unsigned long y;
    static unsigned long mag01[2]={0x0, MATRIX_A};
    /* mag01[x] = x * MATRIX_A  for x=0,1 */

    if (mti >= GENRAND_VLEN) { /* generate GENRAND_VLEN words at one time */
        int kk;

        if (mti == GENRAND_VLEN+1)   /* if sgenrand() has not been called, */
            sgenrand(4357); /* a default initial seed is used   */

        for (kk=0;kk<GENRAND_VLEN-M;kk++) {
            y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
            mt[kk] = mt[kk+M] ^ (y >> 1) ^ mag01[y & 0x1];
        }
        for (;kk<GENRAND_VLEN-1;kk++) {
            y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
            mt[kk] = mt[kk+(M-GENRAND_VLEN)] ^ (y >> 1) ^ mag01[y & 0x1];
        }
        y = (mt[GENRAND_VLEN-1]&UPPER_MASK)|(mt[0]&LOWER_MASK);
        mt[GENRAND_VLEN-1] = mt[M-1] ^ (y >> 1) ^ mag01[y & 0x1];

        mti = 0;
    }
  
    y = mt[mti++];
    y ^= TEMPERING_SHIFT_U(y);
    y ^= TEMPERING_SHIFT_S(y) & TEMPERING_MASK_B;
    y ^= TEMPERING_SHIFT_T(y) & TEMPERING_MASK_C;
    y ^= TEMPERING_SHIFT_L(y);

    return y; 
}




unsigned long genrand_r( unsigned long statevec[] )
{
    unsigned long 	y;
    static unsigned long mag01[2]={0x0, MATRIX_A};
    unsigned long	*mtip = &(statevec[0]);
    unsigned long	*mtp = &(statevec[1]);

    if (*mtip >= GENRAND_VLEN) { /* generate GENRAND_VLEN words at one time */
        int kk;
        for (kk=0;kk<GENRAND_VLEN-M;kk++) {
            y = (mtp[kk]&UPPER_MASK)|(mtp[kk+1]&LOWER_MASK);
            mtp[kk] = mtp[kk+M] ^ (y >> 1) ^ mag01[y & 0x1];
        }
        for (;kk<GENRAND_VLEN-1;kk++) {
            y = (mtp[kk]&UPPER_MASK)|(mtp[kk+1]&LOWER_MASK);
            mtp[kk] = mtp[kk+(M-GENRAND_VLEN)] ^ (y >> 1) ^ mag01[y & 0x1];
        }
        y = (mtp[GENRAND_VLEN-1]&UPPER_MASK)|(mtp[0]&LOWER_MASK);
        mtp[GENRAND_VLEN-1] = mtp[M-1] ^ (y >> 1) ^ mag01[y & 0x1];
        *mtip = 0;
    }
    y = mtp[(*mtip)++];
    y ^= TEMPERING_SHIFT_U(y);
    y ^= TEMPERING_SHIFT_S(y) & TEMPERING_MASK_B;
    y ^= TEMPERING_SHIFT_T(y) & TEMPERING_MASK_C;
    y ^= TEMPERING_SHIFT_L(y);

    return y; 
}




void initrandvec( unsigned long seed, unsigned long statevec[] )
{
    int i;
    for (i=1;i<=GENRAND_VLEN;i++) {
         statevec[i] = seed & 0xffff0000;
         seed = 69069 * seed + 1;
         statevec[i] |= (seed & 0xffff0000) >> 16;
         seed = 69069 * seed + 1;
    }
    statevec[0] = GENRAND_VLEN;
}
