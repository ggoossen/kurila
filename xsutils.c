/*    xsutils.c
 *
 *    Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006,
 *    by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * "Perilous to us all are the devices of an art deeper than we possess
 * ourselves." --Gandalf
 */


#include "EXTERN.h"
#define PERL_IN_XSUTILS_C
#include "perl.h"

/*
 * Contributed by Spider Boardman (spider.boardman@orb.nashua.nh.us).
 */

/* package attributes; */
PERL_XS_EXPORT_C void XS_attributes_reftype(pTHX_ CV *cv);
PERL_XS_EXPORT_C void XS_attributes__guess_stash(pTHX_ CV *cv);
PERL_XS_EXPORT_C void XS_attributes__fetch_attrs(pTHX_ CV *cv);
PERL_XS_EXPORT_C void XS_attributes_bootstrap(pTHX_ CV *cv);


/*
 * Note that only ${pkg}::bootstrap definitions should go here.
 * This helps keep down the start-up time, which is especially
 * relevant for users who don't invoke any features which are
 * (partially) implemented here.
 *
 * The various bootstrap definitions can take care of doing
 * package-specific newXS() calls.  Since the layout of the
 * bundled *.pm files is in a version-specific directory,
 * version checks in these bootstrap calls are optional.
 */

static const char file[] = __FILE__;

void
Perl_boot_core_xsutils(pTHX)
{
    newXS("attributes::bootstrap",	XS_attributes_bootstrap,	file);
}

#include "XSUB.h"

/* package attributes; */

XS(XS_attributes_bootstrap)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);

    if( items > 1 )
        Perl_croak(aTHX_ "Usage: attributes::bootstrap $module");

    newXSproto("attributes::_guess_stash", XS_attributes__guess_stash, file, "$");
    newXSproto("attributes::_fetch_attrs", XS_attributes__fetch_attrs, file, "$");
    newXSproto("attributes::reftype",	XS_attributes_reftype,	file, "$");

    XSRETURN(0);
}

XS(XS_attributes__fetch_attrs)
{
    dVAR;
    dXSARGS;
    SV *rv, *sv;
    PERL_UNUSED_ARG(cv);

    if (items != 1) {
usage:
	Perl_croak(aTHX_
		   "Usage: attributes::_fetch_attrs $reference");
    }

    rv = ST(0);
    SP -= items;
    if (!(SvOK(rv) && SvROK(rv)))
	goto usage;
    sv = SvRV(rv);

    switch (SvTYPE(sv)) {
    case SVt_PVGV:
	if (GvUNIQUE(sv))
	    XPUSHs(newSVpvs_flags("unique", SVs_TEMP));
	break;
    default:
	break;
    }

    PUTBACK;
}

XS(XS_attributes__guess_stash)
{
    dVAR;
    dXSARGS;
    SV *rv, *sv;
    dXSTARG;
    PERL_UNUSED_ARG(cv);

    if (items != 1) {
usage:
	Perl_croak(aTHX_
		   "Usage: attributes::_guess_stash $reference");
    }

    rv = ST(0);
    ST(0) = TARG;
    if (!(SvOK(rv) && SvROK(rv)))
	goto usage;
    sv = SvRV(rv);

    if (SvOBJECT(sv))
	sv_setpvn(TARG, HvNAME_get(SvSTASH(sv)), HvNAMELEN_get(SvSTASH(sv)));
#if 0	/* this was probably a bad idea */
    else if (SvPADMY(sv))
	sv_setsv(TARG, &PL_sv_no);	/* unblessed lexical */
#endif
    else {
	const HV *stash = NULL;
	switch (SvTYPE(sv)) {
	case SVt_PVCV:
	    break;
	case SVt_PVGV:
	    if (GvGP(sv) && GvESTASH((GV*)sv))
		stash = GvESTASH((GV*)sv);
	    break;
	default:
	    break;
	}
	if (stash)
	    sv_setpvn(TARG, HvNAME_get(stash), HvNAMELEN_get(stash));
    }

    SvSETMAGIC(TARG);
    XSRETURN(1);
}

XS(XS_attributes_reftype)
{
    dVAR;
    dXSARGS;
    SV *rv, *sv;
    dXSTARG;
    PERL_UNUSED_ARG(cv);

    if (items != 1) {
usage:
	Perl_croak(aTHX_
		   "Usage: attributes::reftype $reference");
    }

    rv = ST(0);
    ST(0) = TARG;
    if (!(SvOK(rv) && SvROK(rv)))
	goto usage;
    sv = SvRV(rv);
    sv_setpv(TARG, sv_reftype(sv, 0));
    SvSETMAGIC(TARG);

    XSRETURN(1);
}

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
