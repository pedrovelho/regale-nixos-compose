/* sha1types.h */

#ifndef _GLOBAL_H_
#define _GLOBAL_H_ 1
#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif
#ifdef HAVE_STDINT_H
#  include <stdint.h>
#endif
#ifdef HAVE_SYS_TYPES_H
#  include <sys/types.h>
#endif

/* POINTER defines a generic pointer type */
typedef void *POINTER;

/* UINT4 defines a four byte word */
typedef uint32_t UINT4;

/* BYTE defines a unsigned character */
typedef uint8_t BYTE;

#ifndef TRUE
  #define FALSE	0
  #define TRUE	( !FALSE )
#endif /* TRUE */

#endif /* end _GLOBAL_H_ */
