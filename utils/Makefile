
PERL = ../miniperl
REALPERL = ../perl
RUN =   # Used mainly cross-compilation setups.

CPS = cp

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
