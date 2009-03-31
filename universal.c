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
        if(name_stash == basestash || strEQ(name, SvPVX_const(basename_sv)))
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

    if (!SvOK(sv) || !(SvROK(sv) || (SvPOK(sv) && SvCUR(sv))))
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
    does_it = SvTRUE( call_sv(methodname, G_SCALAR | G_METHOD) );
    SPAGAIN;
    FREETMPS;
    LEAVE;

    return does_it;
}

PERL_XS_EXPORT_C void XS_UNIVERSAL_isa(pTHX_ CV *cv);
PERL_XS_EXPORT_C void XS_UNIVERSAL_can(pTHX_ CV *cv);
PERL_XS_EXPORT_C void XS_UNIVERSAL_DOES(pTHX_ CV *cv);
PERL_XS_EXPORT_C void XS_UNIVERSAL_VERSION(pTHX_ CV *cv);
XS(XS_PerlIO_get_layers);
XS(XS_Regexp_DESTROY);
XS(XS_re_is_regexp); 
XS(XS_re_regname);
XS(XS_re_regnames);
XS(XS_re_regnames_count);
XS(XS_re_regexp_pattern);
XS(XS_Symbol_fetch_glob);
XS(XS_Symbol_stash);
XS(XS_Symbol_glob_name);
XS(XS_dump_view);
XS(XS_ref_address);
XS(XS_ref_reftype);
XS(XS_ref_svtype);
XS(XS_iohandle_input_line_number);
XS(XS_iohandle_output_autoflush);

void
Perl_boot_core_UNIVERSAL(pTHX)
{
    dVAR;
    static const char file[] = __FILE__;

    newXS("UNIVERSAL::isa",             XS_UNIVERSAL_isa,         file);
    newXS("UNIVERSAL::can",             XS_UNIVERSAL_can,         file);
    newXS("UNIVERSAL::DOES",            XS_UNIVERSAL_DOES,        file);
    newXS("UNIVERSAL::VERSION", 	XS_UNIVERSAL_VERSION, 	  file);
    newXSproto("PerlIO::get_layers",
               XS_PerlIO_get_layers, file, "*;@");
    newXS("Regexp::DESTROY", XS_Regexp_DESTROY, file);
    newXSproto("re::is_regexp", XS_re_is_regexp, file, "$");
    newXSproto("re::regname", XS_re_regname, file, ";$$");
    newXSproto("re::regnames", XS_re_regnames, file, ";$");
    newXSproto("re::regnames_count", XS_re_regnames_count, file, "");
    newXSproto("re::regexp_pattern", XS_re_regexp_pattern, file, "$");
    newXSproto("Symbol::fetch_glob", XS_Symbol_fetch_glob, file, "$");
    newXSproto("Symbol::glob_name", XS_Symbol_glob_name, file, "$");
    newXSproto("Symbol::stash", XS_Symbol_stash, file, "$");

    newXS("dump::view", XS_dump_view, file);
    
    newXS("ref::address", XS_ref_address, file);
    newXS("ref::reftype", XS_ref_reftype, file);
    newXS("ref::svtype", XS_ref_svtype, file);

    newXSproto("iohandle::input_line_number",
	XS_iohandle_input_line_number, file, "$;$");
    newXSproto("iohandle::output_autoflush",
	XS_iohandle_output_autoflush, file, "$;$");

    boot_core_error();
    boot_core_version();
    boot_core_utf8();
    boot_core_Internals();
    boot_core_signals();
    boot_core_env();
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

	if (!SvOK(sv) || !(SvROK(sv) || (SvPOK(sv) && SvCUR(sv))))
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

    if (!SvOK(sv) || !(SvROK(sv) || (SvPOK(sv) && SvCUR(sv))))
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
	CV * const cv = gv_fetchmethod(pkg, name);
        if (cv)
	    rv = sv_2mortal(newRV(cvTsv(cv)));
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

	if (SvRVOK(sv))
	    sv = SvRV(sv);

	if (SvTYPE(sv) == SVt_PVGV) {
	    io = GvIO(svTgv(sv));
	}
	else if (SvIOOK(sv)) {
	    io = svTio(sv);
	}
	else {
	    Perl_croak(aTHX_ "Expected a io handle but got %s", Ddesc(sv));
	}

	if (io) {
	     AV* const av = PerlIO_get_layers(aTHX_ input ?
					IoIFP(io) : IoOFP(io));
	     I32 i;
	     const I32 last = av_len(av);
	     AV* retav = (AV*)sv_2mortal((SV*)newAV());
	     
	     for (i = last; i >= 0; i -= 3) {
		  SV * const * const namsvp = av_fetch(av, i - 2, FALSE);
		  SV * const * const argsvp = av_fetch(av, i - 1, FALSE);
		  SV * const * const flgsvp = av_fetch(av, i,     FALSE);

		  const bool namok = namsvp && *namsvp && SvPOK(*namsvp);
		  const bool argok = argsvp && *argsvp && SvPOK(*argsvp);
		  const bool flgok = flgsvp && *flgsvp && SvIOK(*flgsvp);

		  if (details) {
		      /* We know that PerlIO_get_layers creates a new SV for
			 the name and flags, so we can just take a reference
			 and "steal" it when we free the AV below.  */
		      av_push(retav, namok
			      ? SvREFCNT_inc_NN(*namsvp)
			      : &PL_sv_undef);
		      av_push(retav, argok
			      ? newSVpvn_flags(SvPVX_const(*argsvp),
					       SvCUR(*argsvp),
					       0)
			      : &PL_sv_undef);
		      av_push(retav, namok
			      ? SvREFCNT_inc_NN(*flgsvp)
			      : &PL_sv_undef);
		  }
		  else {
		       if (namok && argok)
			   av_push(retav, Perl_newSVpvf(aTHX_ "%"SVf"(%"SVf")",
						  SVfARG(*namsvp),
						  SVfARG(*argsvp)));
		       else if (namok)
			   av_push(retav, SvREFCNT_inc_NN(*namsvp));
		       else
			   av_push(retav, &PL_sv_undef);
		       if (flgok) {
			    const IV flags = SvIVX(*flgsvp);

			    if (flags & PERLIO_F_UTF8) {
				av_push(retav, newSVpvs_flags("utf8", 0));
			    }
		       }
		  }
	     }

	     AvREFCNT_dec(av);

	     XPUSHs((SV*)retav);

	     XSRETURN(1);
	}
    }
#endif

    XSRETURN(0);
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

    XPUSHs(sv_mortalcopy(SvRV(ret)));

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

	/* Use the string that Perl would return */
	/* return the pattern in (?msix:..) format */
	pattern = sv_2mortal(newSVsv((SV*)re));
	XPUSHs(pattern);
	XSRETURN(1);
    } else {
        /* It ain't a regexp folks */
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
    /* NOT-REACHED */
}

XS(XS_Symbol_fetch_glob)
{
    dVAR; 
    dXSARGS;
    PERL_UNUSED_VAR(cv);

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "Symbol::fetch_glob", "sv");

    ST(0) = (SV*)gv_fetchsv(ST(0), GV_ADD | GV_ADDMULTI, SVt_PVGV);
    if (ST(0))
	ST(0) = sv_2mortal(newRV(ST(0)));
    else
	ST(0) = &PL_sv_undef;
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

    gv_efullname3(sv, (GV*)ST(0), NULL);
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
    if (ST(0))
	ST(0) = sv_2mortal(newRV(ST(0)));
    else
	ST(0) = &PL_sv_undef;
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

    if ( ! SvOK(sv) ) {
	sv_setpv(retsv, "undef");
	XSRETURN(1);
    }

    if ( SvAVOK(sv) ) {
	sv_setpv(retsv, "@(ARRAY (TODO))");
	XSRETURN(1);
    }

    if ( SvHVOK(sv) ) {
	sv_setpv(retsv, "%(HASH (TODO))");
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
	    const UV k = utf8n_to_uvchr(s, UTF8_MAXBYTES, &charlen, UTF8_ALLOW_ANY | UTF8_CHECK_ONLY );

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
	    rstart = r = SvPVX_mutable(retsv);

	    *r++ = '"';

	    for (s = src; s < send; s += charlen) {
		const UV k = utf8n_to_uvchr(s, UTF8_MAXBYTES, &charlen, UTF8_ALLOW_ANY | UTF8_CHECK_ONLY );

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
	    rstart = r = SvPVX_mutable(retsv);
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
		    buffer = SvPVX_mutable(retsv);
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
	gv_efullname3(retsv, (GV*)sv, "*");

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
	if(!SvROK(sv)) {
	    XSRETURN_UNDEF;
	}
	SP -= items;
	mPUSHi(PTR2UV(SvRV(sv)));
	XSRETURN(1);
    }
}

XS(XS_ref_svtype)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_VAR(cv);

    if (items != 1)
       Perl_croak(aTHX_ "Usage: %s(%s)", "ref::svtype", "sv");

    {
	SV* sv = ST(0);
	const char* type; 
	type = Ddesc(sv);
	SP -= items;
	mPUSHp(type, strlen(type));
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
	if(!SvROK(sv)) {
	    XSRETURN_UNDEF;
	}
	SP -= items;
	type = sv_reftype(SvRV(sv), 0);
	mPUSHp(type, strlen(type));
	XSRETURN(1);
    }
}

XS(XS_iohandle_input_line_number)
{
    dVAR; 
    dXSARGS;
    PERL_UNUSED_VAR(cv);

    if (items < 1 || items > 2 )
      Perl_croak(aTHX_ "Usage: %s(%s[, %s])", "iohandle::input_line_number", "gv", "line_number");

    {
	SV* sv = ST(0);
        IO* io;

	if (SvROK(sv))
	    sv = SvRV(sv);

	if (SvTYPE(sv) == SVt_PVGV) {
	    io = GvIOn(svTgv(sv));
	}
	else if (SvIOOK(sv)) {
	    io = svTio(sv);
	}
	else {
	    Perl_croak(aTHX_ "iohandle::input_line_number expected a filehandle not %s", Ddesc(sv));
	}

        if ( items == 2 ) {
            IoLINES(io) = SvIV(ST(1));
        }

        XSRETURN_IV((IV)IoLINES(io));
    }
}

XS(XS_iohandle_output_autoflush)
{
    dVAR; 
    dXSARGS;
    PERL_UNUSED_VAR(cv);

    if (items < 1 || items > 2 )
      Perl_croak(aTHX_ "Usage: %s(%s[, %s])", "iohandle::output_autoflush", "gv", "boolean");

    {
	SV* sv = ST(0);
        IO* io;
        
	if (SvROK(sv))
	    sv = SvRV(sv);

	if (SvTYPE(sv) == SVt_PVGV) {
	    io = GvIOn(svTgv(sv));
	}
	else if (SvIOOK(sv)) {
	    io = svTio(sv);
	}
	else {
	    Perl_croak(aTHX_ "autoflush expected a filehandle not %s", Ddesc(sv));
	}

        if ( items == 2 ) {
	    if (SvTRUE(ST(1))) {
		if (!(IoFLAGS(io) & IOf_FLUSH)) {
		    PerlIO *ofp = IoOFP(io);
		    if (ofp)
			(void)PerlIO_flush(ofp);
		    IoFLAGS(io) |= IOf_FLUSH;
		}
	    }
	    else {
		IoFLAGS(io) &= ~IOf_FLUSH;
	    }
        }
	
	if (IoFLAGS(io) & IOf_FLUSH) 
	    XSRETURN_YES;
	else
	    XSRETURN_NO;
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
