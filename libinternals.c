
#include "EXTERN.h"
#include "perl.h"

#include "XSUB.h"

XS(XS_Internals_SvREADONLY);
XS(XS_Internals_HvRESTRICTED);
XS(XS_Internals_peek);
XS(XS_Internals_SvREFCNT);
XS(XS_Internals_hv_clear_placehold);
XS(XS_Internals_refcnt_check);
XS(XS_Internals_hash_seed);
XS(XS_Internals_rehash_seed);
XS(XS_Internals_HvREHASH);
XS(XS_Internals_inc_sub_generation);
XS(XS_Internals_set_hint_hash);

void
Perl_boot_core_Internals(pTHX)
{
    dVAR;
    static const char file[] = __FILE__;

    newXSproto("Internals::SvREADONLY",XS_Internals_SvREADONLY, file, "\\[$%@];$");
    newXSproto("Internals::HvRESTRICTED",XS_Internals_HvRESTRICTED, file, "\\[$%@];$");
    newXS("Internals::SvREFCNT",XS_Internals_SvREFCNT, file);
    newXS("Internals::peek",XS_Internals_peek, file);
    newXSproto("Internals::hv_clear_placeholders",
               XS_Internals_hv_clear_placehold, file, "\\%");
    newXS("Internals::refcnt_check", XS_Internals_refcnt_check, file);
    newXSproto("Internals::hash_seed",XS_Internals_hash_seed, file, "");
    newXSproto("Internals::rehash_seed",XS_Internals_rehash_seed, file, "");
    newXSproto("Internals::HvREHASH", XS_Internals_HvREHASH, file, "\\%");
    newXSproto("Internals::set_hint_hash", XS_Internals_set_hint_hash, file, "\\%");
}

XS(XS_Internals_SvREADONLY)	/* This is dangerous stuff. */
{
    dVAR;
    dXSARGS;
    SV* sv = ST(0);
    PERL_UNUSED_ARG(cv);
    if (!SvRVOK(sv))
        Perl_croak(aTHX_ "argument to SvREADONLY must be a HASH REF not a %s", Ddesc(ST(0)));
    sv = SvRV(sv);

    if (items == 1) {
	 if (SvREADONLY(sv))
	     XSRETURN_YES;
	 else
	     XSRETURN_NO;
    }
    else if (items == 2) {
	if (SvTRUE(ST(1))) {
	    SvREADONLY_on(sv);
	    XSRETURN_YES;
	}
	else {
	    /* I hope you really know what you are doing. */
	    SvREADONLY_off(sv);
	    XSRETURN_NO;
	}
    }
    XSRETURN_UNDEF; /* Can't happen. */
}

XS(XS_Internals_HvRESTRICTED)	/* This is dangerous stuff. */
{
    dVAR;
    dXSARGS;
    SV* sv = ST(0);
    PERL_UNUSED_ARG(cv);
    if (!SvRVOK(sv))
        Perl_croak(aTHX_ "argument to HvRESTRICTED must be a HASH REF not a %s", Ddesc(ST(0)));
    sv = SvRV(sv);

    if ( ! SvHVOK(sv) )
        Perl_croak(aTHX_ "HvRESTRICTED expected a hash but got a %s", Ddesc(sv));
    if (items == 1) {
	 if (HvRESTRICTED(sv))
	     XSRETURN_YES;
	 else
	     XSRETURN_NO;
    }
    else if (items == 2) {
	if (SvTRUE(ST(1))) {
	    HvRESTRICTED_on(sv);
	    XSRETURN_YES;
	}
	else {
	    HvRESTRICTED_off(sv);
	    XSRETURN_NO;
	}
    }
    XSRETURN_UNDEF; /* Can't happen. */
}

XS(XS_Internals_peek)	/* This is dangerous stuff. */
{
    dVAR;
    dXSARGS;
    SV * const sv = ST(0);
    PERL_UNUSED_ARG(cv);

    if (items == 1) {
	sv_dump(sv);
    }
    XSRETURN_UNDEF;
}

XS(XS_Internals_SvREFCNT)	/* This is dangerous stuff. */
{
    dVAR;
    dXSARGS;
    SV* sv = ST(0);
    PERL_UNUSED_ARG(cv);
    if (!SvRVOK(sv))
        Perl_croak(aTHX_ "argument to SvREFCNT must be a REF not a %s", Ddesc(ST(0)));
    sv = SvRV(sv);

    if (items == 1)
	 XSRETURN_IV(SvREFCNT(sv)); /* Minus the ref created for us. */
    else if (items == 2) {
         /* I hope you really know what you are doing. */
	 SvREFCNT(sv) = SvIV(ST(1));
	 XSRETURN_IV(SvREFCNT(sv));
    }
    XSRETURN_UNDEF; /* Can't happen. */
}

XS(XS_Internals_hv_clear_placehold)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);

    if (items != 1)
	Perl_croak(aTHX_ "Usage: UNIVERSAL::hv_clear_placeholders(hv)");
    else {
        SV* sv = ST(0);
        if (!SvRVOK(sv))
            Perl_croak(aTHX_ "argument to hv_clear_placeholders must be a HASH REF not a %s", Ddesc(ST(0)));
	sv = SvRV(sv);
        if (!SvHVOK(sv))
            Perl_croak(aTHX_ "argument to hv_clear_placeholders must be an HASH not a %s", Ddesc(sv));
	hv_clear_placeholders(svThv(sv));
	XSRETURN(0);
    }
}

XS(XS_Internals_refcnt_check)
{
    PERL_UNUSED_CONTEXT;
    PERL_UNUSED_ARG(cv);
    refcnt_check();
}

XS(XS_Internals_hash_seed)
{
    dVAR;
    /* Using dXSARGS would also have dITEM and dSP,
     * which define 2 unused local variables.  */
    dAXMARK;
    PERL_UNUSED_ARG(cv);
    PERL_UNUSED_VAR(mark);
    XSRETURN_UV(PERL_HASH_SEED);
}

XS(XS_Internals_rehash_seed)
{
    dVAR;
    /* Using dXSARGS would also have dITEM and dSP,
     * which define 2 unused local variables.  */
    dAXMARK;
    PERL_UNUSED_ARG(cv);
    PERL_UNUSED_VAR(mark);
    XSRETURN_UV(PL_rehash_seed);
}

XS(XS_Internals_HvREHASH)	/* Subject to change  */
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (SvROK(ST(0))) {
	const HV * const hv = (HV *) SvRV(ST(0));
	if (items == 1 && SvTYPE(hv) == SVt_PVHV) {
	    if (HvREHASH(hv))
		XSRETURN_YES;
	    else
		XSRETURN_NO;
	}
    }
    Perl_croak(aTHX_ "Internals::HvREHASH $hashref");
}

XS(XS_Internals_set_hint_hash)
{
    dVAR;
    dXSARGS;
    SV* hv;
    if (!SvROK(ST(0)))
	Perl_croak(aTHX_ "Internals::set_hint_hash $hashref");
    hv = SvRV(ST(0));
    if (items == 1 && SvHVOK(hv)) {
	HvREFCNT_dec(PL_compiling.cop_hints_hash);
	PL_compiling.cop_hints_hash = HvREFCNT_inc(svThv(hv));
    }
}

