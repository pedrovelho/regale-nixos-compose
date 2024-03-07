###########################################################################
##
## File:        ./Makefile.am
## Versions:    $Id: Makefile.am,v 1.3 2008/04/08 17:08:16 rkowen Exp $
## Created:     2002/06/14
##
###########################################################################
##
## run  automake to generate a Makefile.in
##	Makefile.am \
##	configure.ac >  Makefile.in
##	aclocal.m4  /
##

AUTOMAKE_OPTIONS=foreign subdir-objects no-installinfo

ACLOCAL_AMFLAGS=-I config

SUBDIRS = . src

EXTRA_DIST=				\
		sim config pm		\
		jobmix/mkjobmix		\
		runesp			\
		ChangeLog		\
		NEWS			\
		esp-sc2000.pdf

CL:
	@echo "Updating ChangeLog"
	-@cvs2cl --no-time
#	-@svn2cl --group-by-day

dist-hook:
	rm -rf `find $(distdir) -name CVS -print`
	rm -rf `find $(distdir) -name .svn -print`
	rm -rf `find $(distdir) -name Makefile -print`
	rm -rf `find $(distdir) -name .deps -print`
	rm -rf `find $(distdir) -name "*.x" -print`
	rm -rf `find $(distdir) -name "*.o" -print`


help:
	@echo ""
	@echo "make		- compiles sources to library"
	@echo "make all		- same as above"
	@echo "make install	- copy library & man pages to destination"
	@echo "make clean	- cleans out most useless files"
	@echo "make dist-gzip	- makes a .tar.gz tarball"
	@echo "make distclean	- cleans & removes most made files"
	@echo "make CL		- updates the ChangeLog"
	@echo ""
