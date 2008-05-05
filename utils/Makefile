
PERL = ../miniperl
REALPERL = ../perl
RUN =   # Used mainly cross-compilation setups.

CPS = cp

# From MakeMaker.
FIXIN = "-I../lib" "-MExtUtils::MY" -e "MY->fixin(shift)"

# Files to be built with variable substitution after miniperl is
# available.  Dependencies handled manually below (for now).

plextract = perlbug perlivp
plfixlocal = h2xs h2ph perldoc pl2pm libnetcfg
plfix = corelist instmodsh shasum splain xsubpp

all: $(plextract) $(plfixlocal) $(plfix)

$(plextract):
	$(RUN) $(PERL) -I../lib $@.PL

$(plfixlocal):
	$(CPS) $@.pl $@
	$(RUN) $(PERL) $(FIXIN) $@

corelist: ../lib/Module/CoreList/bin/$@ ../config.sh
	$(CPS) ../lib/Module/CoreList/bin/$@ $@
	$(RUN) $(PERL) $(FIXIN) $@

h2ph:		h2ph.pl ../config.sh

h2xs:		h2xs.pl ../config.sh

instmodsh: ../lib/ExtUtils/$@ ../config.sh
	$(CPS) ../lib/ExtUtils/$@ $@
	$(RUN) $(PERL) $(FIXIN) $@

perlbug:	perlbug.PL ../config.sh ../patchlevel.h

perldoc:	perldoc.pl ../config.sh

perlivp:	perlivp.PL ../config.sh

pl2pm:		pl2pm.pl ../config.sh

shasum: ../ext/Digest/SHA/bin/$@ ../config.sh
	$(CPS) ../ext/Digest/SHA/bin/$@ $@
	$(RUN) $(PERL) $(FIXIN) $@

splain: ../lib/diagnostics.pm ../config.sh
	$(CPS) ../lib/diagnostics.pm $@
	$(RUN) $(PERL) $(FIXIN) $@

libnetcfg:	libnetcfg.pl ../config.sh

xsubpp: ../lib/ExtUtils/$@ ../config.sh
	$(CPS) ../lib/ExtUtils/$@ $@
	$(RUN) $(PERL) $(FIXIN) $@

clean:

realclean:
	rm -rf $(plextract) $(plextractexe)
	rm -f ../t/_h2ph_pre.ph

clobber:	realclean

distclean:	clobber

veryclean:	distclean
	-rm -f *~ *.org
