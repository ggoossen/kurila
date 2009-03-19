
#include "EXTERN.h"
#include "perl.h"

#include "XSUB.h"

XS(XS_error_create);
XS(XS_error_message);
XS(XS_error_description);
XS(XS_error_stacktrace);
XS(XS_error_write_to_stderr);

void
Perl_boot_core_error(pTHX)
{
    dVAR;
    static const char file[] = __FILE__;

    newXS("error::create", XS_error_create, file);
    newXS("error::message", XS_error_message, file);
    newXS("error::description", XS_error_description, file);
    newXS("error::stacktrace", XS_error_stacktrace, file);
    newXS("error::write_to_stderr", XS_error_write_to_stderr, file);

    PL_errorcreatehook = newRV_inc(cvTsv(gv_fetchmethod(NULL, "error::create")));
    PL_diehook = newRV_inc(cvTsv(gv_fetchmethod(NULL, "error::write_to_stderr")));
    PL_warnhook = newRV_inc(cvTsv(gv_fetchmethod(NULL, "error::write_to_stderr")));
}

STATIC
AV* S_context_info(pTHX_ const PERL_CONTEXT *cx) {
    AV* av = av_2mortal(newAV());
    const char *stashname;
    
    stashname = CopSTASHPV(cx->blk_oldcop);

    if (!stashname)
	av_push(av, &PL_sv_undef);
    else
	av_push(av, newSVpv(stashname, 0));
    if (cx->blk_oldop->op_location) {
	sv_setsv(avTsv(av), cx->blk_oldop->op_location);
    } else {
	av_push(av, newSVpv("unknown location", 0));
    }

    if (CxTYPE(cx) == CXt_SUB) {
	/* So is ccstack[dbcxix]. */
	CV* cv = cx->blk_sub.cv;
	SV** name = NULL;
	if (SvLOCATION(cv) && SvAVOK(SvLOCATION(cv)))
	    name = av_fetch(svTav(SvLOCATION(cv)), 3, FALSE);
	av_push(av, name ? newSVsv(*name) : &PL_sv_undef );
    }
    else {
	av_push(av, newSVpvs("(eval)"));
    }
    
    if (CxTYPE(cx) == CXt_EVAL) {
	/* eval STRING */
	if (CxOLD_OP_TYPE(cx) == OP_ENTEREVAL) {
	    av_push(av, newSVsv(cx->blk_eval.cur_text));
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

    trace = av_2mortal(newAV());

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

	/* make stack entry */
	av_push(trace, SvREFCNT_inc((SV*)S_context_info(aTHX_ &ccstack[cxix]) ));

	/* stop after BEGIN/CHECK/.../END blocks */
	if ((CxTYPE(&ccstack[cxix]) == CXt_SUB) &&
	    (CvSPECIAL(ccstack[cxix].blk_sub.cv)))
	    break;


	cxix = dopoptosub_at(ccstack, cxix - 1);
    }

    return trace;
}

XS(XS_error_create)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items > 3)
	Perl_croak(aTHX_ "Usage: error::create(message, location)");
    SP -= items;
    {
        SV *vs = ST(0);
	SV *location = ST(1);
	SV *rv;
	HV *hv;

	const char * const classname = "error";
/* 	    sv_isobject(ST(0)) /\* get the class if called as an object method *\/ */
/* 		? HvNAME(SvSTASH(SvRV(ST(0)))) */
/* 		: (char *)SvPV_nolen(ST(0)); */

	if (sv_derived_from(vs, "error")) {
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

	(void)hv_stores(hv, "description", newSVsv(vs));

	if ( strcmp(classname,"error") != 0 ) /* inherited new() */
	    sv_bless(rv, gv_stashpv(classname, GV_ADD));

	{
	    /*
	     * Try and find the file and line for PL_op.  This will usually be
	     * PL_curcop, but it might be a cop that has been optimised away.  We
	     * can try to find such a cop by searching through the optree starting
	     * from the sibling of PL_curcop.
	     */

	    SV *sv = sv_newmortal();
	    sv_setpvn(sv,"",0);
	    if ( items >= 2 ) {
		if (location && SvAVOK(location) && av_len(svTav(location)) >= 2) {
                    SV* loc_0 = *av_fetch((AV*)location, 0, FALSE);
                    SV* loc_1 = *av_fetch((AV*)location, 1, FALSE);
                    SV* loc_2 = *av_fetch((AV*)location, 2, FALSE);
		    Perl_sv_catpvf(aTHX_ sv, " at %s line %"IVdf" character %"IVdf".",
			SvPVOK(loc_0) ? SvPVX_const(loc_0) : "???",
			SvPVOK(loc_1) ? SvIV(loc_1) : 0,
			SvPVOK(loc_2) ? SvIV(loc_2) : 0
			);
		}
	    }
	    if (PL_dirty)
		sv_catpvs(sv, " during global destruction");

	    (void)hv_stores(hv, "location", SvREFCNT_inc(sv));
	}
	    
	/* backtrace */
	(void)hv_stores(hv, "stack", SvREFCNT_inc((SV*) S_error_backtrace(aTHX) ));

	mPUSHs(rv);
	XSRETURN(1);
    }
}

XS(XS_error_description)
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
	
	if (sv_isobject(ST(0))) {
	    err = (HV*)SvRV(ST(0));
	}
	else
	    Perl_croak(aTHX_ "not an error object");

	{
	    SV **sv;

	    sv = hv_fetchs(err, "description", 0);
	    if (sv) {
		if (SvPVOK(*sv))
		    sv_catsv(res, *sv);
		else
		    sv_catpv(res, "(error description isn't a string)");
	    }
	}

	PUSHs(res);
	XSRETURN(1);
    }
}

XS(XS_error_message)
{
    dVAR;
    dXSARGS;
    SV* error;
    SV* msg;
    PERL_UNUSED_ARG(cv);
    if (items < 1)
	Perl_croak(aTHX_ "Usage: $error->message()");
    error = POPs;
    ENTER;
    PUSHMARK(SP);
    PUSHs(error);
    PUTBACK;
    msg = call_method("description", G_SCALAR);
    SPAGAIN;
    LEAVE;
    ENTER;
    PUSHMARK(SP);
    XPUSHs(error);
    PUTBACK;
    sv_catsv(msg, call_method("stacktrace", G_SCALAR) );
    SPAGAIN;
    LEAVE;
    XPUSHs(msg);
    XSRETURN(1);
}

XS(XS_error_stacktrace)
{
    dVAR;
    dXSARGS;
    PERL_UNUSED_ARG(cv);
    if (items < 1)
	Perl_croak(aTHX_ "Usage: error::stacktrace()");
    SP -= items;
    {
	HV *err;
	SV *res = sv_newmortal();
	sv_setpvn(res, "", 0);
	
	if (sv_isobject(ST(0))) {
	    err = (HV*)SvRV(ST(0));
	}
	else
	    Perl_croak(aTHX_ "not an error object");

	{
	    SV **sv;

	    sv = hv_fetchs(err, "location", 0);
	    if (sv) {
		sv_catsv(res, *sv);
	    }
	    sv_catpv(res, "\n");

	    sv = hv_fetchs(err, "stack", 0);
	    if (sv && SvAVOK(*sv)) {
		AV *av = (AV*)(*sv);
		SV** svp = AvARRAY(av);
		int avlen = av_len(av);
		int i=0;
		for (i=0; i<=avlen;i++) {
		    if (svp[i] && SvAVOK(svp[i])) {
			AV* item = (AV*)(svp[i]);

			SV **v = av_fetch(item, 3, 0);
			sv_catpv(res, "    ");
			if (v && SvOK(*v))
			    sv_catsv(res, *v);

			sv_catpv(res, " called at ");
			v = av_fetch(item, 0, 0);
			if (v && SvOK(*v))
			    sv_catsv(res, *v);

			sv_catpv(res, " line ");
			v = av_fetch(item, 1, 0);
			if (v && SvOK(*v))
			    sv_catsv(res, *v);
			sv_catpv(res, " character ");
			v = av_fetch(item, 2, 0);
			if (v && SvOK(*v))
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

    tmpsv = call_method("message", G_SCALAR);
    SPAGAIN;
    message = SvPV_const(tmpsv, msglen);

    LEAVE;

    write_to_stderr(message, msglen);
}

