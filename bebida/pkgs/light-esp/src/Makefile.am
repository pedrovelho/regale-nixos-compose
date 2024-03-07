###########################################################################
##
## File:        ./Makefile.am
## Versions:    $Id: Makefile.am,v 1.2 2008/04/08 16:34:32 rkowen Exp $
## Created:     2002/06/14
##
###########################################################################
##
## run  automake to generate a Makefile.in
##      Makefile.am \
##      configure.ac >  Makefile.in
##      aclocal.m4  /
##

AUTOMAKE_OPTIONS=foreign no-installinfo

ACLOCAL_AMFLAGS= -I config

bin_PROGRAMS	= pchksum epoch fixtime sleeper

pchksum_SOURCES		= pchksum.c genrand.c sha1.c
pchksum_CFLAGS		=
pchksum_LDFLAGS		= @LIBS@

epoch_SOURCES		= epoch.c
epoch_CFLAGS		=
epoch_LDFLAGS		=

fixtime_SOURCES		= fixtime.c
fixtime_CFLAGS		=
fixtime_LDFLAGS		=

sleeper_SOURCES		= sleeper.c
sleeper_CFLAGS		=
sleeper_LDFLAGS		=

special_includes=				\
			genrand.h		\
			sha1.h			\
			sha1types.h

EXTRA_DIST=			\
		$(special_includes)

dist-hook:
	-rm -rf `find $(distdir) -name .svn`

clobber: maintainer-clean
	-rm -f configure Makefile.in config.h.in aclocal.m4

help:
	@echo ""
	@echo "make		- compile sources"
	@echo "make all		- same as above"
	@echo "make install	- copy executables to destination"
	@echo "make clean	- cleans out most useless files"
	@echo "make distclean	- cleans & removes most made files"
	@echo "make maintainer-clean	- removes even more made files"
	@echo "make clobber	- removes all made files"
	@echo ""

