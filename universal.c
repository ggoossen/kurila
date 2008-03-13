/*    universal.c
 *
 *    Copyright (C) 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004,
 *    2005, 2006, 2007 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * "The roots of those mountains must be roots indeed; there must be
 * great secrets buried there which have not been discovered since the
 * beginning." --Gandalf, relating Gollum's story
 */

/* This file contains the code that implements the functions in Perl's
 * UNIVERSAL package, such as UNIVERSAL->can().
 *
 * It is also used to store XS functions that need to be present in
 * miniperl for a lack of a better place to put them. It might be
 * clever to move them to seperate XS files which would then be pulled
 * in by some to-be-written build process.
 */

#include "EXTERN.h"
#define PERL_IN_UNIVERSAL_C
#include "perl.h"

#ifdef USE_PERLIO
#include "perliol.h" /* For the PERLIO_F_XXX */
#endif

/*
 * Contributed by Graham Barr  <Graham.Barr@tiuk.ti.com>
 * The main guts of traverse_isa was actually copied from gv_fetchmeth
 */

STATIC bool
S_isa_lookup(pTHX_ HV *stash, const char * const name, const HV* const name_stash)
{
    dVAR;
    AV* stash_linear_isa;
    SV** svp;
    const char *hvname;
    I32 items;

    PERL_ARGS_ASSERT_ISA_LOOKUP;

    /* A stash/class can go by many names (ie. User == main::User), so 
       we compare the stash itself just in case */
    if (name_stash && ((const HV *)stash == name_stash))
        return TRUE;

    hvname = HvNAME_get(stash);

    if (strEQ(hvname, name))
	return TRUE;

    if (strEQ(name, "UNIVERSAL"))
	return TRUE;

    stash_linear_isa = mro_get_linear_isa(stash);
    svp = AvARRAY(stash_linear_isa) + 1;
    items = AvFILLp(stash_linear_isa);
    while (items--) {
	SV* const basename_sv = *svp++;
        HV* const basestash = gv_stashsv(basename_sv, 0);
	if (!basestash) {
	    if (ckWARN(WARN_SYNTAX))
		Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
			    "Can't locate package %"SVf" for the parents of %s",
			    SVfARG(basename_sv), hvname);
	    continue;
	}
        if(name_stash == basestash || strEQ(name, SvPVX(basename_sv)))
	    return TRUE;
    }

    return FALSE;
}

/*
=head1 SV Manipulation Functions

=for apidoc sv_derived_from

Returns a boolean indicating whether the SV is derived from the specified class
I<at the C level>.  To check derivation at the Perl level, call C<isa()> as a
normal Perl method.

=cut
*/

bool
Perl_sv_derived_from(pTHX_ SV *sv, const char *const name)
{
    dVAR;
    HV *stash;

    PERL_ARGS_ASSERT_SV_DERIVED_FROM;

    SvGETMAGIC(sv);

    if (SvROK(sv)) {
	const char *type;
        sv = SvRV(sv);
        type = sv_reftype(sv,0);
	if (type && strEQ(type,name))
	    return TRUE;
	stash = SvOBJECT(sv) ? SvSTASH(sv) : NULL;
    }
    else {
        stash = gv_stashsv(sv, 0);
    }

    if (stash) {
	HV * const name_stash = gv_stashpv(name, 0);
	return isa_lookup(stash, name, name_stash);
    }
    else
	return FALSE;

}

/*
=for apidoc sv_does

Returns a boolean indicating whether the SV performs a specific, named role.
The SV can be a Perl object or the name of a Perl class.

=cut
*/

#include "XSUB.h"

bool
Perl_sv_does(pTHX_ SV *sv, const char *const name)
{
    bool does_it;
    SV *methodname;
    dSP;

    PERL_ARGS_ASSERT_SV_DOES;

    ENTER;
    SAVETMPS;

    SvGETMAGIC(sv);

    if (!SvOK(sv) || !(SvROK(sv) || (SvPOK(sv) && SvCUR(sv))
		|| (SvGMAGICAL(sv) && SvPOKp(sv) && SvCUR(sv))))
	return FALSE;

    if (sv_isobject(sv)) {
	const char *classname = sv_reftype(SvRV(sv),TRUE);
	if (strEQ(name,classname))
	    return TRUE;
    } else if (SvPOKp(sv)) {
	const char *classname = SvPV_nolen(sv);
	if (strEQ(name,classname))
	    return TRUE;
    }

    PUSHMARK(SP);
    XPUSHs(sv);
    mXPUSHs(newSVpv(name, 0));
    PUTBACK;

    methodname = newSVpvs_flags("isa", SVs_TEMP);
    /* ugly hack: use the SvSCREAM flag so S_method_common
     * can figure out we're calling DOES() and not isa(),
     * and report eventual errors correctly. --rgs */
    SvSCREAM_on(methodname);
    call_sv(methodname, G_SCALAR | G_METHOD);
    SPAGAIN;

    does_it = SvTRUE( TOPs );
    FREETMPS;
    LEAVE;

    return does_it;
}

PERL_XS_EXPORT_C void XS_UNIVERSAL_isa(pTHX_ CV *cv);
PERL_XS_EXPORT_C void XS_UNIVERSAL_can(pTHX_ CV *cv);
PERL_XS_EXPORT_C void XS_UNIVERSAL_DOES(pTHX_ CV *cv);
PERL_XS_EXPORT_C void XS_UNIVERSAL_VERSION(pTHX_ CV *cv);
XS(XS_version_new);
XS(XS_version_stringify);
XS(XS_version_numify);
XS(XS_version_normal);
XS(XS_version_vcmp);
XS(XS_version_boolean);
#ifdef HASATTRIBUTE_NORETURN
XS(XS_version_noop) __attribute__noreturn__;
#else
XS(XS_version_noop);
#endif
XS(XS_version_is_alpha);
XS(XS_version_qv);
XS(XS_utf8_valid);
XS(XS_utf8_encode);
XS(XS_utf8_decode);
XS(XS_utf8_unicode_to_native);
XS(XS_utf8_native_to_unicode);
XS(XS_Internals_SvREADONLY);
XS(XS_Internals_peek);
XS(XS_Internals_SvREFCNT);
XS(XS_Internals_hv_clear_placehold);
XS(XS_PerlIO_get_layers);
XS(XS_Regexp_DESTROY);
XS(XS_Internals_hash_seed);
XS(XS_Internals_rehash_seed);
XS(XS_Internals_HvREHASH);
XS(XS_Internals_inc_sub_generation);
XS(XS_Internals_set_hint_hash);
XS(XS_re_is_regexp); 
XS(XS_re_regname);
XS(XS_re_regnames);
XS(XS_re_regnames_count);
XS(XS_re_regexp_pattern);
XS(XS_Tie_Hash_NamedCapture_FETCH);
XS(XS_Tie_Hash_NamedCapture_STORE);
XS(XS_Tie_Hash_NamedCapture_DELETE);
XS(XS_Tie_Hash_NamedCapture_CLEAR);
XS(XS_Tie_Hash_NamedCapture_EXISTS);
XS(XS_Tie_Hash_NamedCapture_FIRSTK);
XS(XS_Tie_Hash_NamedCapture_NEXTK);
XS(XS_Tie_Hash_NamedCapture_SCALAR);
XS(XS_Tie_Hash_NamedCapture_flags);
XS(XS_Symbol_fetch_glob);
XS(XS_Symbol_stash);
XS(XS_Symbol_glob_name);
XS(XS_dump_view);
XS(XS_error_create);
XS(XS_error_message);
XS(XS_error_write_to_stderr);
XS(XS_ref_address);
XS(XS_ref_reftype);

void
Perl_boot_core_UNIVERSAL(pTHX)
{
    dVAR;
    static const char file[] = __FILE__;

    newXS("UNIVERSAL::isa",             XS_UNIVERSAL_isa,         file);
    newXS("UNIVERSAL::can",             XS_UNIVERSAL_can,         file);
    newXS("UNIVERSAL::DOES",            XS_UNIVERSAL_DOES,        file);
    newXS("UNIVERSAL::VERSION", 	XS_UNIVERSAL_VERSION, 	  file);
    {
	/* register the overloading (type 'A') magic */
	PL_amagic_generation++;
	/* Make it findable via fetchmethod */
	newXS("version::()", XS_version_noop, file);
	newXS("version::new", XS_version_new, file);
	newXS("version::(\"\"", XS_version_stringify, file);
	newXS("version::stringify", XS_version_stringify, file);
	newXS("version::(0+", XS_version_numify, file);
	newXS("version::numify", XS_version_numify, file);
	newXS("version::normal", XS_version_normal, file);
	newXS("version::(cmp", XS_version_vcmp, file);
	newXS("version::(<+>", XS_version_vcmp, file);
	newXS("version::vcmp", XS_version_vcmp, file);
	newXS("version::(bool", XS_version_boolean, file);
	newXS("version::boolean", XS_version_boolean, file);
	newXS("version::(nomethod", XS_version_noop, file);
	newXS("version::noop", XS_version_noop, file);
	newXS("version::is_alpha", XS_version_is_alpha, file);
	newXS("version::qv", XS_version_qv, file);
    }
    newXS("utf8::valid", XS_utf8_valid, file);
    newXS("utf8::encode", XS_utf8_encode, file);
    newXS("utf8::decode", XS_utf8_decode, file);
    newXS("utf8::native_to_unicode", XS_utf8_native_to_unicode, file);
    newXS("utf8::unicode_to_native", XS_utf8_unicode_to_native, file);
    newXSproto("Internals::SvREADONLY",XS_Internals_SvREADONLY, file, "\\[$%@];$");
    newXS("Internals::SvREFCNT",XS_Internals_SvREFCNT, file);
    newXS("Internals::peek",XS_Internals_peek, file);
    newXSproto("Internals::hv_clear_placeholders",
               XS_Internals_hv_clear_placehold, file, "\\%");
    newXSproto("PerlIO::get_layers",
               XS_PerlIO_get_layers, file, "*;@");
    newXS("Regexp::DESTROY", XS_Regexp_DESTROY, file);
    newXSproto("Internals::hash_seed",XS_Internals_hash_seed, file, "");
    newXSproto("Internals::rehash_seed",XS_Internals_rehash_seed, file, "");
    newXSproto("Internals::HvREHASH", XS_Internals_HvREHASH, file, "\\%");
    newXSproto("Internals::set_hint_hash", XS_Internals_set_hint_hash, file, "\\%");
    newXSproto("re::is_regexp", XS_re_is_regexp, file, "$");
    newXSproto("re::regname", XS_re_regname, file, ";$$");
    newXSproto("re::regnames", XS_re_regnames, file, ";$");
    newXSproto("re::regnames_count", XS_re_regnames_count, file, "");
    newXSproto("re::regexp_pattern", XS_re_regexp_pattern, file, "$");
    newXS("Tie::Hash::NamedCapture::FETCH", XS_Tie_Hash_NamedCapture_FETCH, file);
    newXS("Tie::Hash::NamedCapture::STORE", XS_Tie_Hash_NamedCapture_STORE, file);
    newXS("Tie::Hash::NamedCapture::DELETE", XS_Tie_Hash_NamedCapture_DELETE, file);
    newXS("Tie::Hash::NamedCapture::CLEAR", XS_Tie_Hash_NamedCapture_CLEAR, file);
    newXS("Tie::Hash::NamedCapture::EXISTS", XS_Tie_Hash_NamedCapture_EXISTS, file);
    newXS("Tie::Hash::NamedCapture::FIRSTKEY", XS_Tie_Hash_NamedCapture_FIRSTK, file);
    newXS("Tie::Hash::NamedCapture::NEXTKEY", XS_Tie_Hash_NamedCapture_NEXTK, file);
    newXS("Tie::Hash::NamedCapture::SCALAR", XS_Tie_Hash_NamedCapture_SCALAR, file);
    newXS("Tie::Hash::NamedCapture::flags", XS_Tie_Hash_NamedCapture_flags, file);
    newXSproto("Symbol::fetch_glob", XS_Symbol_fetch_glob, file, "$");
    newXSproto("Symbol::glob_name", XS_Symbol_glob_name, file, "$");
    newXSproto("Symbol::stash", XS_Symbol_stash, file, "$");

    newXS("dump::view", XS_dump_view, file);
    
    newXS("error::create", XS_error_create, file);
    newXS("error::message", XS_error_message, file);
    newXS("error::write_to_stderr", XS_error_write_to_stderr, file);

    newXS("ref::address", XS_ref_address, file);
    newXS("ref::reftype", XS_ref_reftype, file);

    PL_errorcreatehook = newRV_noinc(SvREFCNT_inc((SV*)GvCV(gv_fetchmethod(NULL, "error::create"))));
    PL_diehook = newRV_noinc(SvREFCNT_inc((SV*)GvCV(gv_fetchmethod(NULL, "error::write_to_stderr"))));
    PL_warnhook = newRV_noinc(SvREFCNT_inc((SV*)GvCV(gv_fetchmethod(NULL, "error::write_to_stderr"))));
}


XS(XS_UNIVERSAL_isa)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);

    if (items != 2)
	Perl_croak(aTHX_ "Usage: UNIVERSAL::isa(reference, kind)");
    else {
	SV * const sv = ST(0);
	const char *name;

	SvGETMAGIC(sv);

	if (!SvOK(sv) || !(SvROK(sv) || (SvPOK(sv) && SvCUR(sv))
		    || (SvGMAGICAL(sv) && SvPOKp(sv) && SvCUR(sv))))
	    XSRETURN_UNDEF;

	name = SvPV_nolen_const(ST(1));

	ST(0) = boolSV(sv_derived_from(sv, name));
	XSRETURN(1);
    }
}

XS(XS_UNIVERSAL_can)
{
    dVAR;
    dXSARGS;
    SV   *sv;
    const char *name;
    SV   *rv;
    HV   *pkg = NULL;
    PERL_UNUSED_ARG(cv);

    if (items != 2)
	Perl_croak(aTHX_ "Usage: UNIVERSAL::can(object-ref, method)");

    sv = ST(0);

    SvGETMAGIC(sv);

    if (!SvOK(sv) || !(SvROK(sv) || (SvPOK(sv) && SvCUR(sv))
		|| (SvGMAGICAL(sv) && SvPOKp(sv) && SvCUR(sv))))
	XSRETURN_UNDEF;

    name = SvPV_nolen_const(ST(1));
    rv = &PL_sv_undef;

    if (SvROK(sv)) {
        sv = (SV*)SvRV(sv);
        if (SvOBJECT(sv))
            pkg = SvSTASH(sv);
    }
    else {
        pkg = gv_stashsv(sv, 0);
    }

    if (pkg) {
	GV * const gv = gv_fetchmethod(pkg, name);
        if (gv && isGV(gv))
	    rv = sv_2mortal(newRV((SV*)GvCV(gv)));
    }

    ST(0) = rv;
    XSRETURN(1);
}

XS(XS_UNIVERSAL_DOES)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);

    if (items != 2)
	Perl_croak(aTHX_ "Usage: invocant->DOES(kind)");
    else {
	SV * const sv = ST(0);
	const char *name;

	name = SvPV_nolen_const(ST(1));
	if (sv_does( sv, name ))
	    XSRETURN_YES;

	XSRETURN_NO;
    }
}

XS(XS_UNIVERSAL_VERSION)
{
    dVAR;
    dXSARGS;
    HV *pkg;
    GV **gvp;
    GV *gv;
    SV *sv;
    const char *undef;
    PERL_UNUSED_ARG(cv);

    if (SvROK(ST(0))) {
        sv = (SV*)SvRV(ST(0));
        if (!SvOBJECT(sv))
            Perl_croak(aTHX_ "Cannot find version of an unblessed reference");
        pkg = SvSTASH(sv);
    }
    else {
        pkg = gv_stashsv(ST(0), 0);
    }

    gvp = pkg ? (GV**)hv_fetchs(pkg, "VERSION", FALSE) : NULL;

    if (gvp && isGV(gv = *gvp) && (sv = GvSV(gv)) && SvOK(sv)) {
        SV * const nsv = sv_newmortal();
        sv_setsv(nsv, sv);
        sv = nsv;
	if ( !sv_derived_from(sv, "version"))
	    upg_version(sv, FALSE);
        undef = NULL;
    }
    else {
        sv = (SV*)&PL_sv_undef;
        undef = "(undef)";
    }

    if (items > 1) {
	SV *req = ST(1);

	if (undef) {
	    if (pkg) {
		const char * const name = HvNAME_get(pkg);
		Perl_croak(aTHX_
			   "%s does not define $%s::VERSION--version check failed",
			   name, name);
	    } else {
		Perl_croak(aTHX_
			     "%s defines neither package nor VERSION--version check failed",
			     SvPVx_nolen_const(ST(0)) );
	     }
	}

	if ( !sv_derived_from(req, "version")) {
	    /* req may very well be R/O, so create a new object */
	    req = sv_2mortal( new_version(req) );
	}

	if ( vcmp( req, sv ) > 0 ) {
	    if ( hv_exists((HV*)SvRV(req), "qv", 2 ) ) {
		Perl_croak(aTHX_ "%s version %"SVf" required--"
		       "this is only version %"SVf"", HvNAME_get(pkg),
		       SVfARG(vnormal(req)),
		       SVfARG(vnormal(sv)));
	    } else {
		Perl_croak(aTHX_ "%s version %"SVf" required--"
		       "this is only version %"SVf"", HvNAME_get(pkg),
		       SVfARG(vstringify(req)),
		       SVfARG(vstringify(sv)));
	    }
	}

    }

    if ( SvOK(sv) && sv_derived_from(sv, "version") ) {
	ST(0) = vstringify(sv);
    } else {
	ST(0) = sv;
    }

    XSRETURN(1);
}

XS(XS_version_new)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items > 3)
	Perl_croak(aTHX_ "Usage: version::new(class, version)");
    SP -= items;
    {
        SV *vs = ST(1);
	SV *rv;
	const char * const classname =
	    sv_isobject(ST(0)) /* get the class if called as an object method */
		? HvNAME(SvSTASH(SvRV(ST(0))))
		: (char *)SvPV_nolen(ST(0));

	if ( items == 1 || vs == &PL_sv_undef ) { /* no param or explicit undef */
	    /* create empty object */
	    vs = sv_newmortal();
	    sv_setpvn(vs,"",0);
	}
	else if ( items == 3 ) {
	    vs = sv_newmortal();
	    Perl_sv_setpvf(aTHX_ vs,"v%s",SvPV_nolen_const(ST(2)));
	}

	rv = new_version(vs);
	if ( strcmp(classname,"version") != 0 ) /* inherited new() */
	    sv_bless(rv, gv_stashpv(classname, GV_ADD));

	mPUSHs(rv);
	PUTBACK;
	return;
    }
}

XS(XS_version_stringify)
{
     dVAR;
     dXSARGS;
     PERL_UNUSED_ARG(cv);
     if (items < 1)
	  Perl_croak(aTHX_ "Usage: version::stringify(lobj, ...)");
     SP -= items;
     {
	  SV *	lobj;

	  if (sv_derived_from(ST(0), "version")) {
	       lobj = SvRV(ST(0));
	  }
	  else
	       Perl_croak(aTHX_ "lobj is not of type version");

	  mPUSHs(vstringify(lobj));

	  PUTBACK;
	  return;
     }
}

XS(XS_version_numify)
{
     dVAR;
     dXSARGS;
     PERL_UNUSED_ARG(cv);
     if (items < 1)
	  Perl_croak(aTHX_ "Usage: version::numify(lobj, ...)");
     SP -= items;
     {
	  SV *	lobj;

	  if (sv_derived_from(ST(0), "version")) {
	       lobj = SvRV(ST(0));
	  }
	  else
	       Perl_croak(aTHX_ "lobj is not of type version");

	  mPUSHs(vnumify(lobj));

	  PUTBACK;
	  return;
     }
}

XS(XS_version_normal)
{
     dVAR;
     dXSARGS;
     PERL_UNUSED_ARG(cv);
     if (items < 1)
	  Perl_croak(aTHX_ "Usage: version::normal(lobj, ...)");
     SP -= items;
     {
	  SV *	lobj;

	  if (sv_derived_from(ST(0), "version")) {
	       lobj = SvRV(ST(0));
	  }
	  else
	       Perl_croak(aTHX_ "lobj is not of type version");

	  mPUSHs(vnormal(lobj));

	  PUTBACK;
	  return;
     }
}

XS(XS_version_vcmp)
{
     dVAR;
     dXSARGS;
     PERL_UNUSED_ARG(cv);
     if (items < 1)
	  Perl_croak(aTHX_ "Usage: version::vcmp(lobj, ...)");
     SP -= items;
     {
	  SV *	lobj;

	  if (sv_derived_from(ST(0), "version")) {
	       lobj = SvRV(ST(0));
	  }
	  else
	       Perl_croak(aTHX_ "lobj is not of type version");

	  {
	       SV	*rs;
	       SV	*rvs;
	       SV * robj = ST(1);
	       const IV	 swap = (IV)SvIV(ST(2));

	       if ( ! sv_derived_from(robj, "version") )
	       {
		    robj = new_version(robj);
	       }
	       rvs = SvRV(robj);

	       if ( swap )
	       {
		    rs = newSViv(vcmp(rvs,lobj));
	       }
	       else
	       {
		    rs = newSViv(vcmp(lobj,rvs));
	       }

	       mPUSHs(rs);
	  }

	  PUTBACK;
	  return;
     }
}

XS(XS_version_boolean)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items < 1)
	Perl_croak(aTHX_ "Usage: version::boolean(lobj, ...)");
    SP -= items;
    if (sv_derived_from(ST(0), "version")) {
	SV * const lobj = SvRV(ST(0));
	SV * const rs = newSViv( vcmp(lobj,new_version(newSVpvs("0"))) );
	mPUSHs(rs);
	PUTBACK;
	return;
    }
    else
	Perl_croak(aTHX_ "lobj is not of type version");
}

XS(XS_version_noop)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items < 1)
	Perl_croak(aTHX_ "Usage: version::noop(lobj, ...)");
    if (sv_derived_from(ST(0), "version"))
	Perl_croak(aTHX_ "operation not supported with version object");
    else
	Perl_croak(aTHX_ "lobj is not of type version");
#ifndef HASATTRIBUTE_NORETURN
    XSRETURN_EMPTY;
#endif
}

XS(XS_version_is_alpha)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 1)
	Perl_croak(aTHX_ "Usage: version::is_alpha(lobj)");
    SP -= items;
    if (sv_derived_from(ST(0), "version")) {
	SV * const lobj = ST(0);
	if ( hv_exists((HV*)SvRV(lobj), "alpha", 5 ) )
	    XSRETURN_YES;
	else
	    XSRETURN_NO;
	PUTBACK;
	return;
    }
    else
	Perl_croak(aTHX_ "lobj is not of type version");
}

XS(XS_version_qv)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 1)
	Perl_croak(aTHX_ "Usage: version::qv(ver)");
    SP -= items;
    {
	SV *	ver = ST(0);
        SV * const rv = sv_newmortal();
        sv_setsv(rv,ver); /* make a duplicate */
        upg_version(rv, TRUE);
        PUSHs(rv);

	PUTBACK;
	return;
    }
}

STATIC
AV* S_context_info(pTHX_ const PERL_CONTEXT *cx) {
    AV* av = newAV();
    const char *stashname;
    
    stashname = CopSTASHPV(cx->blk_oldcop);

    if (!stashname)
	av_push(av, &PL_sv_undef);
    else
	av_push(av, newSVpv(stashname, 0));
    av_push(av, newSVpv(OutCopFILE(cx->blk_oldcop), 0));
    av_push(av, newSViv((I32)CopLINE(cx->blk_oldcop)));
    if (CxTYPE(cx) == CXt_SUB) {
	GV * const cvgv = CvGV(cx->blk_sub.cv);
	/* So is ccstack[dbcxix]. */
	if (isGV(cvgv)) {
	    SV * const sv = newSV(0);
	    gv_efullname4(sv, cvgv, NULL, TRUE);
	    av_push(av, sv);
	}
	else {
	    av_push(av, newSVpvs("(unknown)"));
	}
    }
    else {
	av_push(av, newSVpvs("(eval)"));
    }
    
    if (CxTYPE(cx) == CXt_EVAL) {
	/* eval STRING */
	if (CxOLD_OP_TYPE(cx) == OP_ENTEREVAL) {
	    av_push(av, cx->blk_eval.cur_text);
	}
	/* require */
	else if (cx->blk_eval.old_namesv) {
	    av_push(av, newSVsv(cx->blk_eval.old_namesv));
	}
	/* eval BLOCK (try blocks have old_namesv == 0) */
	else {
	    av_push(av, &PL_sv_undef);
	}
    }
    else {
	av_push(av, &PL_sv_undef);
    }
    
    return av;
}

STATIC AV* S_error_backtrace(pTHX)
{
    register I32 cxix = dopoptosub_at(cxstack, cxstack_ix);
    register const PERL_CONTEXT *ccstack = cxstack;
    const PERL_SI *top_si = PL_curstackinfo;

    AV* trace;

    trace = newAV();

    for(;;) {
	/* we may be in a higher stacklevel, so dig down deeper */
 	while (cxix < 0 && top_si->si_type != PERLSI_MAIN) {
	    top_si = top_si->si_prev;
	    ccstack = top_si->si_cxstack;
	    cxix = dopoptosub_at(ccstack, top_si->si_cxix);
	}
	if (cxix < 0)
	    break;
	
	/* caller() should not report the automatic calls to &DB::sub */
/* 	if (PL_DBsub && GvCV(PL_DBsub) && */
/* 	    ccstack[cxix].blk_sub.cv == GvCV(PL_DBsub)) { */
/* 	    cxix = dopoptosub_at(ccstack, cxix - 1); */
/* 	    continue; */
/* 	} */

	/* stop on BEGIN/CHECK/.../END blocks */
	if ((CxTYPE(&ccstack[cxix]) == CXt_SUB) &&
	    (CvSPECIAL(ccstack[cxix].blk_sub.cv)))
	    break;

	/* make stack entry */
	av_push(trace, newRV_inc( (SV*) S_context_info(aTHX_ &ccstack[cxix]) ));

	cxix = dopoptosub_at(ccstack, cxix - 1);
    }

    return trace;
}

STATIC const COP*
S_closest_cop(pTHX_ const COP *cop, const OP *o)
{
    dVAR;
    /* Look for PL_op starting from o.  cop is the last COP we've seen. */

    if (!o || o == PL_op)
	return cop;

    if (o->op_flags & OPf_KIDS) {
	const OP *kid;
	for (kid = cUNOPo->op_first; kid; kid = kid->op_sibling) {
	    const COP *new_cop;

	    /* If the OP_NEXTSTATE has been optimised away we can still use it
	     * the get the file and line number. */

	    if (kid->op_type == OP_NULL && kid->op_targ == OP_NEXTSTATE)
		cop = (const COP *)kid;

	    /* Keep searching, and return when we've found something. */

	    new_cop = S_closest_cop(aTHX_ cop, kid);
	    if (new_cop)
		return new_cop;
	}
    }

    /* Nothing found. */

    return NULL;
}


XS(XS_error_create)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items > 3)
	Perl_croak(aTHX_ "Usage: version::new(class, version)");
    SP -= items;
    {
        SV *vs = ST(0);
	SV *rv;
	HV *hv;

	const char * const classname = "error";
/* 	    sv_isobject(ST(0)) /\* get the class if called as an object method *\/ */
/* 		? HvNAME(SvSTASH(SvRV(ST(0)))) */
/* 		: (char *)SvPV_nolen(ST(0)); */

	if (sv_isobject(vs)) {
	    XPUSHs(vs);
	    XSRETURN(1);
	    return;
	}

	if ( items == 0 || vs == &PL_sv_undef ) { /* no param or explicit undef */
	    /* create empty object */
	    vs = sv_newmortal();
	    sv_setpvn(vs,"",0);
	}

	rv = newSV(0);
	hv = (HV*)newSVrv(rv, "error"); 
	(void)sv_upgrade((SV*)hv, SVt_PVHV); /* needs to be an HV type */

	(void)hv_stores(hv, "description", SvREFCNT_inc(vs));

	if ( strcmp(classname,"error") != 0 ) /* inherited new() */
	    sv_bless(rv, gv_stashpv(classname, GV_ADD));

	{
	    /*
	     * Try and find the file and line for PL_op.  This will usually be
	     * PL_curcop, but it might be a cop that has been optimised away.  We
	     * can try to find such a cop by searching through the optree starting
	     * from the sibling of PL_curcop.
	     */

	    const COP *cop = S_closest_cop(aTHX_ PL_curcop, PL_curcop->op_sibling);
	    SV *sv = sv_newmortal();
	    sv_setpvn(sv,"",0);
	    if (!cop)
		cop = PL_curcop;

	    if (CopLINE(cop))
		Perl_sv_catpvf(aTHX_ sv, " at %s line %"IVdf".",
			       OutCopFILE(cop), (IV)CopLINE(cop));
	    /* Seems that GvIO() can be untrustworthy during global destruction. */
	    if (GvIO(PL_last_in_gv) && (SvTYPE(GvIOp(PL_last_in_gv)) == SVt_PVIO)
		&& IoLINES(GvIOp(PL_last_in_gv)))
		{
		    const bool line_mode = (RsSIMPLE(PL_rs) &&
					    SvCUR(PL_rs) == 1 && *SvPVX_const(PL_rs) == '\n');
		    Perl_sv_catpvf(aTHX_ sv, ", <%s> %s %"IVdf,
				   PL_last_in_gv == PL_argvgv ? "" : GvNAME(PL_last_in_gv),
				   line_mode ? "line" : "chunk",
				   (IV)IoLINES(GvIOp(PL_last_in_gv)));
		}
	    if (PL_dirty)
		sv_catpvs(sv, " during global destruction");

	    (void)hv_stores(hv, "location", SvREFCNT_inc(sv));
	}
	    
	/* backtrace */
	(void)hv_stores(hv, "stack", newRV_inc( (SV*) S_error_backtrace(aTHX) ));

	mPUSHs(rv);
	XSRETURN(1);
    }
}

XS(XS_error_message)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items < 1)
	Perl_croak(aTHX_ "Usage: error::message()");
    SP -= items;
    {
	HV *err;
	SV *res = sv_newmortal();
	sv_setpvn(res, "", 0);
	
	if (sv_derived_from(ST(0), "error")) {
	    err = (HV*)SvRV(ST(0));
	}
	else
	    Perl_croak(aTHX_ "not an error object");

	{
	    SV **sv;
	    sv = hv_fetchs(err, "description", 0);
	    if (sv) {
		sv_catsv(res, *sv);
	    }

	    sv = hv_fetchs(err, "location", 0);
	    if (sv) {
		sv_catsv(res, *sv);
	    }
	    sv_catpv(res, "\n");

	    sv = hv_fetchs(err, "stack", 0);
	    if (sv && SvROK(*sv)) {
		AV *av = (AV*)SvRV(*sv);
		SV** svp = AvARRAY(av);
		int avlen = av_len(av);
		int i=0;
		for (i=0; i<=avlen;i++) {
		    if (svp[i] && SvROK(svp[i])) {
			AV* item = (AV*)SvRV(svp[i]);

			SV **v = av_fetch(item, 3, 0);
			sv_catpv(res, "    ");
			if (v)
			    sv_catsv(res, *v);

			sv_catpv(res, " called at ");
			v = av_fetch(item, 1, 0);
			if (v)
			    sv_catsv(res, *v);

			sv_catpv(res, " line ");
			v = av_fetch(item, 2, 0);
			if (v)
			    sv_catsv(res, *v);
			sv_catpv(res, ".\n");
		    }
		}
	    }

	    sv = hv_fetchs(err, "notes", 0);
	    if (sv) {
		sv_catsv(res, *sv);
	    }
	}

	PUSHs(res);
	XSRETURN(1);
    }
}

XS(XS_error_write_to_stderr) {
    dXSARGS;
    STRLEN msglen;
    const char * message;
    SV* tmpsv;

    if (items != 1)
	Perl_croak(aTHX_ "Usage: $error->write_to_stderr()");

    ENTER;
    PUSHMARK(SP);
    PUSHs(ST(0));
    PUTBACK;

    call_method("message", G_SCALAR);
    SPAGAIN;
    tmpsv = POPs;
    message = SvPV_const(tmpsv, msglen);

    LEAVE;

    write_to_stderr(message, msglen);
}

XS(XS_utf8_valid)
{
     dVAR;
     dXSARGS;
     PERL_UNUSED_ARG(cv);
     if (items != 1)
	  Perl_croak(aTHX_ "Usage: utf8::valid(sv)");
    else {
	SV * const sv = ST(0);
	STRLEN len;
	const char * const s = SvPV_const(sv,len);
	if (is_utf8_string(s,len))
	    XSRETURN_YES;
	else
	    XSRETURN_NO;
    }
     XSRETURN_EMPTY;
}

XS(XS_utf8_encode)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 1)
	Perl_croak(aTHX_ "Usage: utf8::encode(sv)");
    XSRETURN_EMPTY;
}

XS(XS_utf8_decode)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items != 1)
	Perl_croak(aTHX_ "Usage: utf8::decode(sv)");
    else {
	ST(0) = boolSV(1);
	sv_2mortal(ST(0));
    }
    XSRETURN(1);
}

XS(XS_utf8_native_to_unicode)
{
 dVAR;
 dXSARGS;
 const UV uv = SvUV(ST(0));
 PERL_UNUSED_ARG(cv);

 if (items > 1)
     Perl_croak(aTHX_ "Usage: utf8::native_to_unicode(sv)");

 ST(0) = sv_2mortal(newSViv(NATIVE_TO_UNI(uv)));
 XSRETURN(1);
}

XS(XS_utf8_unicode_to_native)
{
 dVAR;
 dXSARGS;
 const UV uv = SvUV(ST(0));
 PERL_UNUSED_ARG(cv);

 if (items > 1)
     Perl_croak(aTHX_ "Usage: utf8::unicode_to_native(sv)");

 ST(0) = sv_2mortal(newSViv(UNI_TO_NATIVE(uv)));
 XSRETURN(1);
}

XS(XS_Internals_SvREADONLY)	/* This is dangerous stuff. */
{
    dVAR;
    dXSARGS;
    SV * const sv = SvRV(ST(0));
    PERL_UNUSED_ARG(cv);

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

XS(XS_Internals_peek)	/* This is dangerous stuff. */
{
    dVAR;
    dXSARGS;
    SV * const sv = SvRV(ST(0));
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
    SV * const sv = SvRV(ST(0));
    PERL_UNUSED_ARG(cv);

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
	HV * const hv = (HV *) SvRV(ST(0));
	hv_clear_placeholders(hv);
	XSRETURN(0);
    }
}

XS(XS_Regexp_DESTROY)
{
    PERL_UNUSED_CONTEXT;
    PERL_UNUSED_ARG(cv);
}

XS(XS_PerlIO_get_layers)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items < 1 || items % 2 == 0)
	Perl_croak(aTHX_ "Usage: PerlIO_get_layers(filehandle[,args])");
#ifdef USE_PERLIO
    {
	SV *	sv;
	GV *	gv;
	IO *	io;
	bool	input = TRUE;
	bool	details = FALSE;

	if (items > 1) {
	     SV * const *svp;
	     for (svp = MARK + 2; svp <= SP; svp += 2) {
		  SV * const * const varp = svp;
		  SV * const * const valp = svp + 1;
		  STRLEN klen;
		  const char * const key = SvPV_const(*varp, klen);

		  switch (*key) {
		  case 'i':
		       if (klen == 5 && memEQ(key, "input", 5)) {
			    input = SvTRUE(*valp);
			    break;
		       }
		       goto fail;
		  case 'o': 
		       if (klen == 6 && memEQ(key, "output", 6)) {
			    input = !SvTRUE(*valp);
			    break;
		       }
		       goto fail;
		  case 'd':
		       if (klen == 7 && memEQ(key, "details", 7)) {
			    details = SvTRUE(*valp);
			    break;
		       }
		       goto fail;
		  default:
		  fail:
		       Perl_croak(aTHX_
				  "get_layers: unknown argument '%s'",
				  key);
		  }
	     }

	     SP -= (items - 1);
	}

	sv = POPs;
	gv = (GV*)sv;

	if (!isGV(sv)) {
	     if (SvROK(sv) && isGV(SvRV(sv)))
		  gv = (GV*)SvRV(sv);
	     else if (SvPOKp(sv))
		  gv = gv_fetchsv(sv, 0, SVt_PVIO);
	}

	if (gv && (io = GvIO(gv))) {
	     AV* const av = PerlIO_get_layers(aTHX_ input ?
					IoIFP(io) : IoOFP(io));
	     I32 i;
	     const I32 last = av_len(av);
	     I32 nitem = 0;
	     
	     for (i = last; i >= 0; i -= 3) {
		  SV * const * const namsvp = av_fetch(av, i - 2, FALSE);
		  SV * const * const argsvp = av_fetch(av, i - 1, FALSE);
		  SV * const * const flgsvp = av_fetch(av, i,     FALSE);

		  const bool namok = namsvp && *namsvp && SvPOK(*namsvp);
		  const bool argok = argsvp && *argsvp && SvPOK(*argsvp);
		  const bool flgok = flgsvp && *flgsvp && SvIOK(*flgsvp);

		  if (details) {
		      /* Indents of 5? Yuck.  */
		      /* We know that PerlIO_get_layers creates a new SV for
			 the name and flags, so we can just take a reference
			 and "steal" it when we free the AV below.  */
		       XPUSHs(namok
			      ? sv_2mortal(SvREFCNT_inc_simple_NN(*namsvp))
			      : &PL_sv_undef);
		       XPUSHs(argok
			      ? newSVpvn_flags(SvPVX_const(*argsvp),
					       SvCUR(*argsvp),
					       SVs_TEMP)
			      : &PL_sv_undef);
		       XPUSHs(namok
			      ? sv_2mortal(SvREFCNT_inc_simple_NN(*flgsvp))
			      : &PL_sv_undef);
		       nitem += 3;
		  }
		  else {
		       if (namok && argok)
			    XPUSHs(sv_2mortal(Perl_newSVpvf(aTHX_ "%"SVf"(%"SVf")",
						 SVfARG(*namsvp),
						 SVfARG(*argsvp))));
		       else if (namok)
			   XPUSHs(sv_2mortal(SvREFCNT_inc_simple_NN(*namsvp)));
		       else
			    XPUSHs(&PL_sv_undef);
		       nitem++;
		       if (flgok) {
			    const IV flags = SvIVX(*flgsvp);

			    if (flags & PERLIO_F_UTF8) {
				 XPUSHs(newSVpvs_flags("utf8", SVs_TEMP));
				 nitem++;
			    }
		       }
		  }
	     }

	     SvREFCNT_dec(av);

	     XSRETURN(nitem);
	}
    }
#endif

    XSRETURN(0);
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
    const SV* hv;
    if (!SvROK(ST(0)))
	Perl_croak(aTHX_ "Internals::set_hint_hash $hashref");
    hv = SvRV(ST(0));
    if (items == 1 && SvTYPE(hv) == SVt_PVHV) {
	SvREFCNT_dec(PL_compiling.cop_hints_hash);
	PL_compiling.cop_hints_hash = (HV*)SvREFCNT_inc(hv);
    }
}

XS(XS_re_is_regexp)
{
    dVAR; 
    dXSARGS;
    PERL_UNUSED_VAR(cv);

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "re::is_regexp", "sv");

    SP -= items;

    if (SvRXOK(ST(0))) {
        XSRETURN_YES;
    } else {
        XSRETURN_NO;
    }
}

XS(XS_re_regnames_count)
{
    REGEXP *rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;
    SV * ret;
    dVAR; 
    dXSARGS;
    PERL_UNUSED_ARG(cv);

    if (items != 0)
       Perl_croak(aTHX_ "Usage: %s(%s)", "re::regnames_count", "");

    SP -= items;

    if (!rx)
        XSRETURN_UNDEF;

    ret = CALLREG_NAMED_BUFF_COUNT(rx);

    SPAGAIN;

    if (ret) {
        XPUSHs(ret);
        PUTBACK;
        return;
    } else {
        XSRETURN_UNDEF;
    }
}

XS(XS_re_regname)
{
    dVAR;
    dXSARGS;
    REGEXP * rx;
    U32 flags;
    SV * ret;
    PERL_UNUSED_ARG(cv);

    if (items < 1 || items > 2)
        Perl_croak(aTHX_ "Usage: %s(%s)", "re::regname", "name[, all ]");

    SP -= items;

    rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;

    if (!rx)
        XSRETURN_UNDEF;

    if (items == 2 && SvTRUE(ST(1))) {
        flags = RXapif_ALL;
    } else {
        flags = RXapif_ONE;
    }
    ret = CALLREG_NAMED_BUFF_FETCH(rx, ST(0), (flags | RXapif_REGNAME));

    if (ret) {
        if (SvROK(ret))
            XPUSHs(ret);
        else
            XPUSHs(SvREFCNT_inc(ret));
        XSRETURN(1);
    }
    XSRETURN_UNDEF;    
}


XS(XS_re_regnames)
{
    dVAR;
    dXSARGS;
    REGEXP * rx;
    U32 flags;
    SV *ret;
    AV *av;
    I32 length;
    I32 i;
    SV **entry;
    PERL_UNUSED_ARG(cv);

    if (items > 1)
        Perl_croak(aTHX_ "Usage: %s(%s)", "re::regnames", "[all]");

    rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;

    if (!rx)
        XSRETURN_UNDEF;

    if (items == 1 && SvTRUE(ST(0))) {
        flags = RXapif_ALL;
    } else {
        flags = RXapif_ONE;
    }

    SP -= items;

    ret = CALLREG_NAMED_BUFF_ALL(rx, (flags | RXapif_REGNAMES));

    SPAGAIN;

    SP -= items;

    if (!ret)
        XSRETURN_UNDEF;

    av = (AV*)SvRV(ret);
    length = av_len(av);

    for (i = 0; i <= length; i++) {
        entry = av_fetch(av, i, FALSE);
        
        if (!entry)
            Perl_croak(aTHX_ "NULL array element in re::regnames()");

        XPUSHs(*entry);
    }
    PUTBACK;
    return;
}

XS(XS_re_regexp_pattern)
{
    dVAR;
    dXSARGS;
    REGEXP *re;
    PERL_UNUSED_ARG(cv);

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "re::regexp_pattern", "sv");

    SP -= items;

    /*
       Checks if a reference is a regex or not. If the parameter is
       not a ref, or is not the result of a qr// then returns false
       in scalar context and an empty list in list context.
       Otherwise in list context it returns the pattern and the
       modifiers, in scalar context it returns the pattern just as it
       would if the qr// was stringified normally, regardless as
       to the class of the variable and any strigification overloads
       on the object.
    */

    if ((re = SvRX(ST(0)))) /* assign deliberate */
    {
        /* Housten, we have a regex! */
        SV *pattern;
        STRLEN left = 0;
        char reflags[6];

        if ( GIMME_V == G_ARRAY ) {
            /*
               we are in list context so stringify
               the modifiers that apply. We ignore "negative
               modifiers" in this scenario.
            */

            const char *fptr = INT_PAT_MODS;
            char ch;
            U16 match_flags = (U16)((RX_EXTFLAGS(re) & PMf_COMPILETIME)
                                    >> RXf_PMf_STD_PMMOD_SHIFT);

            while((ch = *fptr++)) {
                if(match_flags & 1) {
                    reflags[left++] = ch;
                }
                match_flags >>= 1;
            }

            pattern = newSVpvn_flags(RX_PRECOMP(re),RX_PRELEN(re), SVs_TEMP);

            /* return the pattern and the modifiers */
            XPUSHs(pattern);
            XPUSHs(newSVpvn_flags(reflags, left, SVs_TEMP));
            XSRETURN(2);
        } else {
            /* Scalar, so use the string that Perl would return */
            /* return the pattern in (?msix:..) format */
            pattern = sv_2mortal(newSVsv((SV*)re));
            XPUSHs(pattern);
            XSRETURN(1);
        }
    } else {
        /* It ain't a regexp folks */
        if ( GIMME_V == G_ARRAY ) {
            /* return the empty list */
            XSRETURN_UNDEF;
        } else {
            /* Because of the (?:..) wrapping involved in a
               stringified pattern it is impossible to get a
               result for a real regexp that would evaluate to
               false. Therefore we can return PL_sv_no to signify
               that the object is not a regex, this means that one
               can say

                 if (regex($might_be_a_regex) eq '(?:foo)') { }

               and not worry about undefined values.
            */
            XSRETURN_NO;
        }
    }
    /* NOT-REACHED */
}

XS(XS_Tie_Hash_NamedCapture_FETCH)
{
    dVAR;
    dXSARGS;
    REGEXP * rx;
    U32 flags;
    SV * ret;
    PERL_UNUSED_ARG(cv);

    if (items != 2)
        Perl_croak(aTHX_ "Usage: Tie::Hash::NamedCapture::STORE($key, $flags)");

    rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;

    if (!rx)
        XSRETURN_UNDEF;

    SP -= items;

    flags = (U32)INT2PTR(IV,SvIV(SvRV((SV*)ST(0))));
    ret = CALLREG_NAMED_BUFF_FETCH(rx, ST(1), flags);

    SPAGAIN;

    if (ret) {
        if (SvROK(ret))
            XPUSHs(ret);
        else
            XPUSHs(SvREFCNT_inc(ret));
        PUTBACK;
        return;
    }
    XSRETURN_UNDEF;
}

XS(XS_Tie_Hash_NamedCapture_STORE)
{
    dVAR;
    dXSARGS;
    REGEXP * rx;
    U32 flags;
    PERL_UNUSED_ARG(cv);

    if (items != 3)
        Perl_croak(aTHX_ "Usage: Tie::Hash::NamedCapture::STORE($key, $value, $flags)");

    rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;

    if (!rx) {
        if (!PL_localizing)
            Perl_croak(aTHX_ PL_no_modify);
        else
            XSRETURN_UNDEF;
    }

    SP -= items;

    flags = (U32)INT2PTR(IV,SvIV(SvRV((SV*)ST(0))));
    CALLREG_NAMED_BUFF_STORE(rx,ST(1), ST(2), flags);
}

XS(XS_Tie_Hash_NamedCapture_DELETE)
{
    dVAR;
    dXSARGS;
    REGEXP * rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;
    U32 flags;
    PERL_UNUSED_ARG(cv);

    if (items != 2)
        Perl_croak(aTHX_ "Usage: Tie::Hash::NamedCapture::DELETE($key, $flags)");

    if (!rx)
        Perl_croak(aTHX_ PL_no_modify);

    SP -= items;

    flags = (U32)INT2PTR(IV,SvIV(SvRV((SV*)ST(0))));
    CALLREG_NAMED_BUFF_DELETE(rx, ST(1), flags);
}

XS(XS_Tie_Hash_NamedCapture_CLEAR)
{
    dVAR;
    dXSARGS;
    REGEXP * rx;
    U32 flags;
    PERL_UNUSED_ARG(cv);

    if (items != 1)
        Perl_croak(aTHX_ "Usage: Tie::Hash::NamedCapture::CLEAR($flags)");

    rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;

    if (!rx)
        Perl_croak(aTHX_ PL_no_modify);

    SP -= items;

    flags = (U32)INT2PTR(IV,SvIV(SvRV((SV*)ST(0))));
    CALLREG_NAMED_BUFF_CLEAR(rx, flags);
}

XS(XS_Tie_Hash_NamedCapture_EXISTS)
{
    dVAR;
    dXSARGS;
    REGEXP * rx;
    U32 flags;
    SV * ret;
    PERL_UNUSED_ARG(cv);

    if (items != 2)
        Perl_croak(aTHX_ "Usage: Tie::Hash::NamedCapture::EXISTS($key, $flags)");

    rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;

    if (!rx)
        XSRETURN_UNDEF;

    SP -= items;

    flags = (U32)INT2PTR(IV,SvIV(SvRV((SV*)ST(0))));
    ret = CALLREG_NAMED_BUFF_EXISTS(rx, ST(1), flags);

    SPAGAIN;

	XPUSHs(ret);
	PUTBACK;
	return;
}

XS(XS_Tie_Hash_NamedCapture_FIRSTK)
{
    dVAR;
    dXSARGS;
    REGEXP * rx;
    U32 flags;
    SV * ret;
    PERL_UNUSED_ARG(cv);

    if (items != 1)
        Perl_croak(aTHX_ "Usage: Tie::Hash::NamedCapture::FIRSTKEY()");

    rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;

    if (!rx)
        XSRETURN_UNDEF;

    SP -= items;

    flags = (U32)INT2PTR(IV,SvIV(SvRV((SV*)ST(0))));
    ret = CALLREG_NAMED_BUFF_FIRSTKEY(rx, flags);

    SPAGAIN;

    if (ret) {
        XPUSHs(SvREFCNT_inc(ret));
        PUTBACK;
    } else {
        XSRETURN_UNDEF;
    }

}

XS(XS_Tie_Hash_NamedCapture_NEXTK)
{
    dVAR;
    dXSARGS;
    REGEXP * rx;
    U32 flags;
    SV * ret;
    PERL_UNUSED_ARG(cv);

    if (items != 2)
        Perl_croak(aTHX_ "Usage: Tie::Hash::NamedCapture::NEXTKEY($lastkey)");

    rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;

    if (!rx)
        XSRETURN_UNDEF;

    SP -= items;

    flags = (U32)INT2PTR(IV,SvIV(SvRV((SV*)ST(0))));
    ret = CALLREG_NAMED_BUFF_NEXTKEY(rx, ST(1), flags);

    SPAGAIN;

    if (ret) {
        XPUSHs(ret);
    } else {
        XSRETURN_UNDEF;
    }  
    PUTBACK;
}

XS(XS_Tie_Hash_NamedCapture_SCALAR)
{
    dVAR;
    dXSARGS;
    REGEXP * rx;
    U32 flags;
    SV * ret;
    PERL_UNUSED_ARG(cv);

    if (items != 1)
        Perl_croak(aTHX_ "Usage: Tie::Hash::NamedCapture::SCALAR()");

    rx = PL_curpm ? PM_GETRE(PL_curpm) : NULL;

    if (!rx)
        XSRETURN_UNDEF;

    SP -= items;

    flags = (U32)INT2PTR(IV,SvIV(SvRV((SV*)ST(0))));
    ret = CALLREG_NAMED_BUFF_SCALAR(rx, flags);

    SPAGAIN;

    if (ret) {
        XPUSHs(ret);
        PUTBACK;
        return;
    } else {
        XSRETURN_UNDEF;
    }
}

XS(XS_Tie_Hash_NamedCapture_flags)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);

    if (items != 0)
        Perl_croak(aTHX_ "Usage: Tie::Hash::NamedCapture::flags()");

	mXPUSHu(RXapif_ONE);
	mXPUSHu(RXapif_ALL);
	PUTBACK;
	return;
}

XS(XS_Symbol_fetch_glob)
{
    dVAR; 
    dXSARGS;
    PERL_UNUSED_VAR(cv);

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "Symbol::fetch_glob", "sv");

    ST(0) = (SV*)gv_fetchsv(ST(0), GV_ADD | GV_ADDMULTI, SVt_PVGV);
    ST(0) = newRV_noinc(ST(0));
    XSRETURN(1);
}

XS(XS_Symbol_glob_name)
{
    dVAR; 
    dXSARGS;
    SV * const sv = sv_newmortal();
    PERL_UNUSED_VAR(cv);

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "Symbol::glob_name", "gv");

    if (SvTYPE(ST(0)) != SVt_PVGV)
       Perl_croak(aTHX_ "Argument must be glob");

    gv_efullname4(sv, (GV*)ST(0), NULL, TRUE);
    ST(0) = sv;
    
    XSRETURN(1);
}

XS(XS_Symbol_stash)
{
    dVAR; 
    dXSARGS;
    PERL_UNUSED_VAR(cv);

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "Symbol::stash", "sv");

    ST(0) = (SV*)gv_stashsv(ST(0), GV_ADD);
    ST(0) = newRV_noinc(ST(0));
    XSRETURN(1);
}

XS(XS_dump_view)
{
    dVAR;
    dXSARGS;
    SV * const sv = TOPs;
    SV * const retsv = ST(0) = sv_newmortal();

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "dump::view", "sv");

    if (SvGMAGICAL(sv))
	mg_get(sv);

    if ( ! SvOK(sv) ) {
	sv_setpv(retsv, "undef");
	XSRETURN(1);
    }

    if (SvPOKp(sv)) {
	/* mostly stoken from Data::Dumper/Dumper.xs */
	char *r, *rstart;
	const char * const src = SvPVX_const(sv);
	const char * const send = src + SvCUR(sv);
	const char *s;

	STRLEN j = 0;
	/* Could count 128-255 and 256+ in two variables, if we want to
	   be like &qquote and make a distinction.  */
	STRLEN grow = 0;	/* bytes needed to represent chars 128+ */
	/* STRLEN topbit_grow = 0;	bytes needed to represent chars 128-255 */
	STRLEN backslashes = 0;
	STRLEN single_quotes = 0;
	STRLEN qq_escapables = 0;	/* " $ @ will need a \ in "" strings.  */
	STRLEN normal = 0;
	
	/* this will need EBCDICification */
	STRLEN charlen = 0;
	for (s = src; s < send; s += charlen) {
	    const UV k = utf8_to_uvchr(s, &charlen);

	    if (k == 0 || s + charlen > send ) {
		/* invalid character escape: \x[XX] */
		grow += 6;
		charlen = 1;
		continue;
	    } else if (k > 127) {
		/* 4: \x{} then count the number of hex digits.  */
		grow += 4 + (k <= 0xFF ? 2 : k <= 0xFFF ? 3 : k <= 0xFFFF ? 4 : 8);
	    } else if ( ! isPRINT(k) ) {
		switch (*s) {
		case '\t' : 
		case '\r' :
		case '\n' :
		case '\f' :
		    grow += 2;
		    break;
		default:
		    grow += 6;
		}
	    } else if (k == '\\') {
		backslashes++;
	    } else if (k == '\'') {
		single_quotes++;
	    } else if (k == '"' || k == '$' || k == '@' || k == '{' || k == '}') {
		qq_escapables++;
	    } else {
		normal++;
	    }
	}
	if (single_quotes || grow) {
	    /* We have something needing hex. 3 is ""\0 */
	    STRLEN charlen;
	    sv_grow(retsv, 3 + grow + 2*backslashes + single_quotes
		    + 2*qq_escapables + normal);
	    rstart = r = SvPVX(retsv);

	    *r++ = '"';

	    for (s = src; s < send; s += charlen) {
		const UV k = utf8_to_uvchr(s, &charlen);

		if (k == 0 || s + charlen > send ) {
		    /* invalid character */
		    r = r + my_sprintf(r, "\\x[%02x]", (U8)*s);
		    charlen = 1;
		    continue;
		} else if (k > 127) {
		    r = r + my_sprintf(r, "\\x{%"UVxf"}", k);
		} else if ( ! isPRINT(k) ) {
		    *r++ = '\\';
		    switch (*s) {
		    case '\t': *r++ = 't';  break;
		    case '\r': *r++ = 'r';  break;
		    case '\n': *r++ = 'n';  break;
		    case '\f': *r++ = 'f';  break;
		    default: 
			r = r + my_sprintf(r, "x{%02"UVxf"}", k);
		    }
		} else if (k == '"' || k == '\\' || k == '$' || k == '@' || k == '{' || k == '}') {
		    *r++ = '\\';
		    *r++ = (char)k;
		}
		else {
		    *r++ = (char)k;
		}
	    }
	    *r++ = '"';
	} else {
	    /* Single quotes.  */
	    sv_grow(retsv, 3 + backslashes + single_quotes + qq_escapables + normal);
	    rstart = r = SvPVX(retsv);
	    *r++ = '\'';
	    for (s = src; s < send; s ++) {
		*r++ = *s;
	    }
	    *r++ = '\'';
	}
	*r = '\0';
	j = r - rstart;
	SvCUR_set(retsv, j);
	SvPOK_on(retsv);

	XSRETURN(1);
    }

    if (SvIOKp(sv) || SvNOKp(sv)) {
	sv_setsv(retsv, sv); /* let perl handle the stringification */
	XSRETURN(1);
    }

    if (SvROK(sv)) {
/* 	sv_setpv(retsv, "REF"); */

/*             if (SvAMAGIC(sv)) { */
/* 		SV *const tmpstr = AMG_CALLun(sv,string); */
/* 		if (tmpstr && (!SvROK(tmpstr) || (SvRV(tmpstr) != SvRV(sv)))) { */
/* 		    /\* Unwrap this:  *\/ */
/* 		    /\* char *pv = lp ? SvPV(tmpstr, *lp) : SvPV_nolen(tmpstr); */
/* 		     *\/ */

/* 		    char *pv; */
/* 		    if ((SvFLAGS(tmpstr) & (SVf_POK)) == SVf_POK) { */
/* 			if (flags & SV_CONST_RETURN) { */
/* 			    pv = (char *) SvPVX_const(tmpstr); */
/* 			} else { */
/* 			    pv = (flags & SV_MUTABLE_RETURN) */
/* 				? SvPVX_mutable(tmpstr) : SvPVX(tmpstr); */
/* 			} */
/* 			if (lp) */
/* 			    *lp = SvCUR(tmpstr); */
/* 		    } else { */
/* 			pv = sv_2pv_flags(tmpstr, lp, flags); */
/* 		    } */
/* 		    return pv; */
/* 		} */
/* 	    } */
/* 	    { */
		STRLEN len;
		char *retval;
		char *buffer;
/* 		MAGIC *mg; */
		const SV *const referent = (SV*)SvRV(sv);

		if (!referent) {
		    sv_setpv(retsv, "NULLREF");
/* 		} else if (SvTYPE(referent) == SVt_PVMG */
/* 			   && ((SvFLAGS(referent) & */
/* 				(SVs_OBJECT|SVf_OK|SVs_GMG|SVs_SMG|SVs_RMG)) */
/* 			       == (SVs_OBJECT|SVs_SMG)) */
/* 			   && (mg = mg_find(referent, PERL_MAGIC_qr))) */
/*                 { */
/*                     char *str = NULL; */
/*                     I32 haseval = 0; */
/*                     U32 flags = 0; */
/*                     (str) = CALLREG_AS_STR(mg,lp,&flags,&haseval); */
/*                     PL_reginterp_cnt += haseval; */
/* 		    return str; */
		} else {
		    const char *const typestr = sv_reftype(referent, 0);
		    const STRLEN typelen = strlen(typestr);
		    UV addr = PTR2UV(referent);
		    const char *stashname = NULL;
		    STRLEN stashnamelen = 0; /* hush, gcc */
		    const char *buffer_end;
		    UV i;

		    if (SvOBJECT(referent)) {
			const HEK *const name = HvNAME_HEK(SvSTASH(referent));

			if (name) {
			    stashname = HEK_KEY(name);
			    stashnamelen = HEK_LEN(name);
			} else {
			    stashname = "__ANON__";
			    stashnamelen = 8;
			}
			len = stashnamelen + 1 /* = */ + typelen + 3 /* (0x */
			    + 2 * sizeof(UV) + 2 /* )\0 */;
		    } else {
			len = typelen + 3 /* (0x */
			    + 2 * sizeof(UV) + 2 /* )\0 */;
		    }

		    sv_grow(retsv, len);
		    buffer = SvPVX(retsv);
		    buffer_end = retval = buffer + len;

		    /* Working backwards  */
		    *--retval = '\0';
		    *--retval = ')';
		    for (i=0; i < 2*sizeof(UV); i++) {
			*--retval = PL_hexdigit[addr & 15];
			addr >>= 4;
		    }
		    *--retval = 'x';
		    *--retval = '0';
		    *--retval = '(';

		    retval -= typelen;
		    memcpy(retval, typestr, typelen);

		    if (stashname) {
			*--retval = '=';
			retval -= stashnamelen;
			memcpy(retval, stashname, stashnamelen);
		    }
		    /* retval may not neccesarily have reached the start of the
		       buffer here.  */
		    assert (retval == buffer);

		    len = buffer_end - retval - 1; /* -1 for that \0  */

		    SvCUR_set(retsv, len);
		    SvPOK_on(retsv);
		}
/* 		if (lp) */
/* 		    *lp = len; */
/* 		SAVEFREEPV(buffer); */
/* 		return retval; */
/* 	    } */
	XSRETURN(1);
    }
    
    if (isGV(sv)) {
	gv_efullname4(retsv, (GV*)sv, "*", TRUE);

	XSRETURN(1);
    }

    Perl_croak(aTHX_ "Unknown scalar type");

    XSRETURN(1);
}

XS(XS_ref_address)
{
    dVAR; 
    dXSARGS;
    PERL_UNUSED_VAR(cv);

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "ref::address", "sv");

    {
	SV* sv = ST(0);
	if (SvMAGICAL(sv))
	    mg_get(sv);
	if(!SvROK(sv)) {
	    XSRETURN_UNDEF;
	}
	SP -= items;
	mPUSHi(PTR2UV(SvRV(sv)));
	XSRETURN(1);
    }
}

XS(XS_ref_reftype)
{
    dVAR; 
    dXSARGS;
    PERL_UNUSED_VAR(cv);

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "ref::reftype", "sv");

    {
	SV* sv = ST(0);
	const char* type; 
	if (SvMAGICAL(sv))
	    mg_get(sv);
	if(!SvROK(sv)) {
	    XSRETURN_UNDEF;
	}
	SP -= items;
	type = sv_reftype(SvRV(sv), 0);
	mPUSHp(type, strlen(type));
	XSRETURN(1);
    }
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
