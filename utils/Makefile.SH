case $PERL_CONFIG_SH in
'')
	if test -f config.sh; then TOP=.;
	elif test -f ../config.sh; then TOP=..;
	elif test -f ../../config.sh; then TOP=../..;
	elif test -f ../../../config.sh; then TOP=../../..;
	elif test -f ../../../../config.sh; then TOP=../../../..;
	else
		echo "Can't find config.sh."; exit 1
	fi
	. $TOP/config.sh
	;;
esac
: This forces SH files to create target in same directory as SH file.
: This is so that make depend always knows where to find SH derivatives.
case "$0" in
*/Makefile.SH) cd `expr X$0 : 'X\(.*\)/'` ;;
Makefile.SH) ;;
*) case `pwd` in
   */utils) ;;
   *) if test -d utils; then cd utils
      else echo "Can't figure out where to write output."; exit 1
	  fi;;
   esac;;
esac

echo "Extracting utils/Makefile (with variable substitutions)"
rm -f Makefile
cat >Makefile <<!GROK!THIS!

PERL = ../miniperl
REALPERL = ../perl
RUN = $run  # Used mainly cross-compilation setups.

CPS = $cp
!GROK!THIS!

cat >>Makefile <<'!NO!SUBS!'

# From MakeMaker.
FIXIN = "-I../lib" "-MExtUtils::MY" -e "MY->fixin: shift @ARGV"

# Files to be built with variable substitution after miniperl is
# available.  Dependencies handled manually below (for now).

plextract = perlbug perlivp
plfixlocal = h2xs perldoc pl2pm
plfix = instmodsh xsubpp

all: $(plextract) $(plfixlocal) $(plfix)

$(plextract):
	$(RUN) $(PERL) -I../lib $@.PL

$(plfixlocal):
	$(CPS) $@.pl $@
	$(RUN) $(PERL) $(FIXIN) $@

h2xs:		h2xs.pl ../config.sh

instmodsh: ../lib/ExtUtils/$@ ../config.sh
	$(CPS) ../lib/ExtUtils/$@ $@
	$(RUN) $(PERL) $(FIXIN) $@

perlbug:	perlbug.PL ../config.sh ../patchlevel.h

perldoc:	perldoc.pl ../config.sh

perlivp:	perlivp.PL ../config.sh

pl2pm:		pl2pm.pl ../config.sh

xsubpp: ../lib/ExtUtils/$@ ../config.sh
	$(CPS) ../lib/ExtUtils/$@ $@
	$(RUN) $(PERL) $(FIXIN) $@

clean:

realclean:
	rm -rf $(plextract) $(plextractexe)

clobber:	realclean

distclean:	clobber

veryclean:	distclean
	-rm -f *~ *.org
!NO!SUBS!
$eunicefix Makefile
case `pwd` in
*SH)
    $rm -f ../Makefile
    $ln Makefile ../Makefile
    ;;
esac
rm -f $firstmakefile
