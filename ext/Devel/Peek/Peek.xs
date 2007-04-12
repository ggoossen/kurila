#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef PURIFY
#define DeadCode() NULL
#else
SV *
DeadCode()
{
    SV* sva;
    SV* sv, *dbg;
    SV* ret = newRV_noinc((SV*)newAV());
    register SV* svend;
    int tm = 0, tref = 0, ts = 0, ta = 0, tas = 0;

    for (sva = PL_sv_arenaroot; sva; sva = (SV*)SvANY(sva)) {
	svend = &sva[SvREFCNT(sva)];
	for (sv = sva + 1; sv < svend; ++sv) {
	    if (SvTYPE(sv) == SVt_PVCV) {
		CV *cv = (CV*)sv;
		AV* padlist = CvPADLIST(cv), *argav;
		SV** svp;
		SV** pad;
		int i = 0, j, levelm, totm = 0, levelref, totref = 0;
		int levels, tots = 0, levela, tota = 0, levelas, totas = 0;
		int dumpit = 0;

		if (CvXSUB(sv)) {
		    continue;		/* XSUB */
		}
		if (!CvGV(sv)) {
		    continue;		/* file-level scope. */
		}
		if (!CvROOT(cv)) {
		    /* PerlIO_printf(PerlIO_stderr(), "  no root?!\n"); */
		    continue;		/* autoloading stub. */
		}
		do_gvgv_dump(0, PerlIO_stderr(), "GVGV::GV", CvGV(sv));
		if (CvDEPTH(cv)) {
		    PerlIO_printf(PerlIO_stderr(), "  busy\n");
		    continue;
		}
		svp = AvARRAY(padlist);
		while (++i <= AvFILL(padlist)) { /* Depth. */
		    SV **args;
		    
		    pad = AvARRAY((AV*)svp[i]);
		    argav = (AV*)pad[0];
		    if (!argav || (SV*)argav == &PL_sv_undef) {
			PerlIO_printf(PerlIO_stderr(), "    closure-template\n");
			continue;
		    }
		    args = AvARRAY(argav);
		    levelm = levels = levelref = levelas = 0;
		    levela = sizeof(SV*) * (AvMAX(argav) + 1);
		    if (AvREAL(argav)) {
			for (j = 0; j < AvFILL(argav); j++) {
			    if (SvROK(args[j])) {
				PerlIO_printf(PerlIO_stderr(), "     ref in args!\n");
				levelref++;
			    }
			    /* else if (SvPOK(args[j]) && SvPVX(args[j])) { */
			    else if (SvTYPE(args[j]) >= SVt_PV && SvLEN(args[j])) {
				levelas += SvLEN(args[j])/SvREFCNT(args[j]);
			    }
			}
		    }
		    for (j = 1; j < AvFILL((AV*)svp[1]); j++) {	/* Vars. */
			if (SvROK(pad[j])) {
			    levelref++;
			    do_sv_dump(0, PerlIO_stderr(), pad[j], 0, 4, 0, 0);
			    dumpit = 1;
			}
			/* else if (SvPOK(pad[j]) && SvPVX(pad[j])) { */
			else if (SvTYPE(pad[j]) >= SVt_PVAV) {
			    if (!SvPADMY(pad[j])) {
				levelref++;
				do_sv_dump(0, PerlIO_stderr(), pad[j], 0, 4, 0, 0);
				dumpit = 1;
			    }
			}
			else if (SvTYPE(pad[j]) >= SVt_PV && SvLEN(pad[j])) {
			    int db_len = SvLEN(pad[j]);
			    SV *db_sv = pad[j];
			    levels++;
			    levelm += SvLEN(pad[j])/SvREFCNT(pad[j]);
				/* Dump(pad[j],4); */
			}
		    }
		    PerlIO_printf(PerlIO_stderr(), "    level %i: refs: %i, strings: %i in %i,\targsarray: %i, argsstrings: %i\n", 
			    i, levelref, levelm, levels, levela, levelas);
		    totm += levelm;
		    tota += levela;
		    totas += levelas;
		    tots += levels;
		    totref += levelref;
		    if (dumpit)
			do_sv_dump(0, PerlIO_stderr(), (SV*)cv, 0, 2, 0, 0);
		}
		if (AvFILL(padlist) > 1) {
		    PerlIO_printf(PerlIO_stderr(), "  total: refs: %i, strings: %i in %i,\targsarrays: %i, argsstrings: %i\n", 
			    totref, totm, tots, tota, totas);
		}
		tref += totref;
		tm += totm;
		ts += tots;
		ta += tota;
		tas += totas;
	    }
	}
    }
    PerlIO_printf(PerlIO_stderr(), "total: refs: %i, strings: %i in %i\targsarray: %i, argsstrings: %i\n", tref, tm, ts, ta, tas);

    return ret;
}
#endif /* !PURIFY */

#if defined(PERL_DEBUGGING_MSTATS)
#   define mstat(str) dump_mstats(str)
#else
#   define mstat(str) \
	PerlIO_printf(PerlIO_stderr(), "%s: perl not compiled with DEBUGGING_MSTATS\n",str);
#endif

MODULE = Devel::Peek		PACKAGE = Devel::Peek

void
mstat(str="Devel::Peek::mstat: ")
char *str

void
Dump(sv,lim=4)
SV *	sv
I32	lim
PPCODE:
{
    SV *pv_lim_sv = perl_get_sv("Devel::Peek::pv_limit", FALSE);
    STRLEN pv_lim = pv_lim_sv ? SvIV(pv_lim_sv) : 0;
    SV *dumpop = perl_get_sv("Devel::Peek::dump_ops", FALSE);
    I32 save_dumpindent = PL_dumpindent;
    PL_dumpindent = 2;
    do_sv_dump(0, PerlIO_stderr(), sv, 0, 4, dumpop && SvTRUE(dumpop), pv_lim);
    PL_dumpindent = save_dumpindent;
}

void
DumpArray(lim,...)
I32	lim
PPCODE:
{
    long i;
    SV *pv_lim_sv = perl_get_sv("Devel::Peek::pv_limit", FALSE);
    STRLEN pv_lim = pv_lim_sv ? SvIV(pv_lim_sv) : 0;
    SV *dumpop = perl_get_sv("Devel::Peek::dump_ops", FALSE);
    I32 save_dumpindent = PL_dumpindent;
    PL_dumpindent = 2;

    for (i=1; i<items; i++) {
	PerlIO_printf(PerlIO_stderr(), "Elt No. %ld  0x%lx\n", i - 1, ST(i));
	do_sv_dump(0, PerlIO_stderr(), ST(i), 0, lim, dumpop && SvTRUE(dumpop), pv_lim);
    }
    PL_dumpindent = save_dumpindent;
}

void
DumpProg()
PPCODE:
{
    warn("dumpindent is %d", PL_dumpindent);
    if (PL_main_root)
	op_dump(PL_main_root);
}

I32
SvREFCNT(sv)
SV *	sv

# PPCODE needed since otherwise sv_2mortal is inserted that will kill the value.

SV *
SvREFCNT_inc(sv)
SV *	sv
PPCODE:
{
    RETVAL = SvREFCNT_inc(sv);
    PUSHs(RETVAL);
}

# PPCODE needed since by default it is void

SV *
SvREFCNT_dec(sv)
SV *	sv
PPCODE:
{
    SvREFCNT_dec(sv);
    PUSHs(sv);
}

SV *
DeadCode()
