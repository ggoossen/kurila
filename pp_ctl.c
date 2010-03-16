/*    pp_ctl.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000,
 *    2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 *      Now far ahead the Road has gone,
 *          And I must follow, if I can,
 *      Pursuing it with eager feet,
 *          Until it joins some larger way
 *      Where many paths and errands meet.
 *          And whither then?  I cannot say.
 *
 *     [Bilbo on p.35 of _The Lord of the Rings_, I/i: "A Long-Expected Party"]
 */

/* This file contains control-oriented pp ("push/pop") functions that
 * execute the opcodes that make up a perl program. A typical pp function
 * expects to find its arguments on the stack, and usually pushes its
 * results onto the stack, hence the 'pp' terminology. Each OP structure
 * contains a pointer to the relevant pp_foo() function.
 *
 * Control-oriented means things like pp_enteriter() and pp_next(), which
 * alter the flow of control of the program.
 */


#include "EXTERN.h"
#define PERL_IN_PP_CTL_C
#include "perl.h"

#ifndef WORD_ALIGN
#define WORD_ALIGN sizeof(U32)
#endif

#define DOCATCH(o) ((CATCH_GET == TRUE) ? docatch(o) : (o))

#define dopoptosub(plop)	dopoptosub_at(cxstack, (plop))

PP(pp_grepstart)
{
    dVAR; dSP;
    SV *srcitem;
    SV *src;
    SV *dst;
    SV *cv;

    if (PL_stack_base + *PL_markstack_ptr == SP) {
	(void)POPMARK;
	mXPUSHs(avTsv(newAV()));
	RETURNOP(PL_op->op_next->op_next->op_next);
    }

    PL_stack_sp = PL_stack_base + *PL_markstack_ptr + 1;

    src = POPs;
    cv = POPs;

    if ( ! SvOK(src) ) {
	(void)POPMARK;
	mXPUSHs(avTsv(newAV()));
	RETURNOP(PL_op->op_next->op_next->op_next);
    }
    if ( ! SvAVOK(src) )
	Perl_croak(aTHX_ "%s expected an array but got %s", OP_DESC(PL_op), Ddesc(src));
    
    if ( av_len(svTav(src)) == -1 ) {
	(void)POPMARK;
	mXPUSHs(avTsv(newAV()));
	RETURNOP(PL_op->op_next->op_next->op_next);
    }

    dst = sv_2mortal(avTsv(newAV()));

    ENTER_named("map/grep");					/* enter outer scope */
    SAVETMPS;

    src = sv_mortalcopy(src);

    PUSHMARK(SP);				/* push dst */
    XPUSHs(dst);                          /* push dst */
    XPUSHs(src);                          /* push dst */
    XPUSHs(cv);

    srcitem = av_shift(svTav(src));

    if (PL_op->op_type == OP_GREPSTART)
	XPUSHs(srcitem);
    PUSHMARK(SP);
    mPUSHs(srcitem);
    PUSHs(cv);
    PUTBACK;
    assert(PL_op->op_next->op_type == OP_ENTERSUB);
    return PL_op->op_next;
}

PP(pp_mapwhile)
{
    dVAR; dSP;
    const I32 gimme = GIMME_V;
    SV* newitem;
    AV* src;
    SV* dst;
    SV** cvp;

    newitem = POPs;
    cvp = SP;
    src = svTav(SP[-1]);
    dst = SP[-2];

    av_push(svTav(dst), SvTEMP(newitem) ? SvREFCNT_inc(newitem) : newSVsv(newitem));

    /* All done yet? */
    if ( av_len(src) == -1 ) {

	FREETMPS;
	LEAVE_named("map/grep");					/* exit outer scope */
	(void)POPMARK;				/* pop dst */
	SP = PL_stack_base + POPMARK;		/* pop original mark */
	if (gimme != G_VOID) {
	    PUSHs(dst);
	}
	RETURN;
    }
    else {
	SV *srcitem;

	/* set $_ to the new source item */
	srcitem = av_shift(src);
	PUSHMARK(SP);
	mXPUSHs(srcitem);
	XPUSHs(*cvp);
	PUTBACK;

	RETURNOP(cLOGOP->op_other);
    }
}

/* Range stuff. */

PP(pp_range)
{
    dVAR; dSP;

    AV* res = av_2mortal(newAV());
    dPOPPOPssrl;

    if ( !SvNIOKp(left) && SvPOKp(left) && !looks_like_number(left)) {
	Perl_croak(aTHX_ "Range must be numeric");
    }
    if ( !SvNIOKp(right) && SvPOKp(right) && !looks_like_number(right)) {
	Perl_croak(aTHX_ "Range must be numeric");
    }

    {
	register IV i, j;
	IV max;
	if ((SvOK(left) && SvNV(left) < IV_MIN) ||
	    (SvOK(right) && SvNV(right) > IV_MAX))
	    DIE(aTHX_ "Range iterator outside integer range");
	i = SvIV(left);
	max = SvIV(right);
	if (max >= i) {
	    j = max - i + 1;
	}
	else
	    j = 0;
	while (j--) {
	    av_push(res, newSViv(i++));
	}
    }

    XPUSHs(avTsv(res));
    RETURN;
}

/* Control. */

static const char * const context_name[] = {
    "pseudo-block",
    "(not used)",
    NULL, /* CXt_BLOCK never actually needs "block" */
    "(not used)",
    NULL, /* CXt_LOOP_FOR never actually needs "loop" */
    NULL, /* CXt_LOOP_PLAIN never actually needs "loop" */
    NULL, /* CXt_LOOP_LAZYIV never actually needs "loop" */
    "subroutine",
    "eval",
    "substitution",
    "XS-subroutine",
    "try",
};

STATIC I32
S_dopoptolabel(pTHX_ const char *label)
{
    dVAR;
    register I32 i;

    PERL_ARGS_ASSERT_DOPOPTOLABEL;

    for (i = cxstack_ix; i >= 0; i--) {
	register const PERL_CONTEXT * const cx = &cxstack[i];
	switch (CxTYPE(cx)) {
	case CXt_SUBST:
	case CXt_SUB:
	case CXt_XSSUB:
	case CXt_EVAL:
	case CXt_TRY:
	case CXt_NULL:
	    if (ckWARN(WARN_EXITING))
		Perl_warner(aTHX_ packWARN(WARN_EXITING), "Exiting %s via %s",
			context_name[CxTYPE(cx)], OP_NAME(PL_op));
	    if (CxTYPE(cx) == CXt_NULL)
		return -1;
	    break;
	case CXt_LOOP_LAZYIV:
	case CXt_LOOP_FOR:
	case CXt_LOOP_PLAIN:
	    if ( !CxLABEL(cx) || strNE(label, CxLABEL(cx)) ) {
		DEBUG_l(Perl_deb(aTHX_ "(Skipping label #%ld %s)\n",
			(long)i, CxLABEL(cx)));
		continue;
	    }
	    DEBUG_l( Perl_deb(aTHX_ "(Found label #%ld %s)\n", (long)i, label));
	    return i;
	}
    }
    return i;
}



I32
Perl_dowantarray(pTHX)
{
    dVAR;
    const I32 gimme = block_gimme();
    return (gimme == G_VOID) ? G_SCALAR : gimme;
}

I32
Perl_block_gimme(pTHX)
{
    dVAR;
    const I32 cxix = dopoptosub(cxstack_ix);
    if (cxix < 0)
	return G_VOID;

    switch (cxstack[cxix].blk_gimme) {
    case G_VOID:
	return G_VOID;
    case G_SCALAR:
	return G_SCALAR;
    case G_ARRAY:
	return G_ARRAY;
    default:
	Perl_croak(aTHX_ "panic: bad gimme: %d\n", cxstack[cxix].blk_gimme);
	/* NOTREACHED */
	return 0;
    }
}

I32
Perl_dopoptosub_at(pTHX_ const PERL_CONTEXT *cxstk, I32 startingblock)
{
    dVAR;
    I32 i;

    PERL_ARGS_ASSERT_DOPOPTOSUB_AT;

    for (i = startingblock; i >= 0; i--) {
	register const PERL_CONTEXT * const cx = &cxstk[i];
	switch (CxTYPE(cx)) {
	default:
	    continue;
	case CXt_EVAL:
	case CXt_TRY:
	case CXt_SUB:
	case CXt_XSSUB:
	    DEBUG_l( Perl_deb(aTHX_ "(Found sub #%ld)\n", (long)i));
	    return i;
	}
    }
    return i;
}

STATIC I32
S_dopoptotry(pTHX_ I32 startingblock)
{
    dVAR;
    I32 i;
    for (i = startingblock; i >= 0; i--) {
	register const PERL_CONTEXT *cx = &cxstack[i];
	switch (CxTYPE(cx)) {
	default:
	    continue;
	case CXt_EVAL:
	case CXt_TRY:
	    DEBUG_l( Perl_deb(aTHX_ "(Found eval #%ld)\n", (long)i));
	    return i;
	}
    }
    return i;
}

STATIC I32
S_dopoptoloop(pTHX_ I32 startingblock)
{
    dVAR;
    I32 i;
    for (i = startingblock; i >= 0; i--) {
	register const PERL_CONTEXT * const cx = &cxstack[i];
	switch (CxTYPE(cx)) {
	case CXt_SUBST:
	case CXt_SUB:
	case CXt_XSSUB:
	case CXt_EVAL:
	case CXt_TRY:
	case CXt_NULL:
	    if (ckWARN(WARN_EXITING))
		Perl_warner(aTHX_ packWARN(WARN_EXITING), "Exiting %s via %s",
			context_name[CxTYPE(cx)], OP_NAME(PL_op));
	    if ((CxTYPE(cx)) == CXt_NULL)
		return -1;
	    break;
	case CXt_LOOP_LAZYIV:
	case CXt_LOOP_FOR:
	case CXt_LOOP_PLAIN:
	    DEBUG_l( Perl_deb(aTHX_ "(Found loop #%ld)\n", (long)i));
	    return i;
	}
    }
    return i;
}

void
Perl_dounwind(pTHX_ I32 cxix)
{
    dVAR;
    I32 optype;

    while (cxstack_ix > cxix) {
	SV *sv;
        register PERL_CONTEXT *cx;
	DEBUG_l(PerlIO_printf(Perl_debug_log, "Unwinding block %ld\n",
		(long) cxstack_ix));
	if (CxTYPE(&cxstack[cxstack_ix]) == CXt_SUBST) {
	    POPSUBST(cx);
	    continue;
	}
	cx = pop_block();
	/* Note: we don't need to restore the base context info till the end. */
	switch (CxTYPE(cx)) {
	case CXt_SUB:
	    LEAVE;
	    POPSUB(cx,sv);
	    break;
	case CXt_EVAL:
	case CXt_TRY:
	    LEAVE;
	    POPEVAL(cx);
	    break;
	case CXt_LOOP_LAZYIV:
	case CXt_LOOP_FOR:
	case CXt_LOOP_PLAIN:
	    POPLOOP(cx);
	    break;
	case CXt_NULL:
	    break;
	case CXt_XSSUB:
	    break;
	}
    }
    PERL_UNUSED_VAR(optype);
}

void
Perl_qerror(pTHX_ SV *err)
{
    dVAR;
    PERL_ARGS_ASSERT_QERROR;
    if (PL_in_eval) {
	sv_catsv(ERRSV, err);
    }
    else if (PL_errors) {
	sv_catsv(PL_errors, err);
    }
    else
	Perl_warn(aTHX_ "%"SVf, SVfARG(err));
    if (PL_parser)
	++PL_parser->error_count;
}

/* This function will never return */
void
Perl_die_where(pTHX_ SV *msv)
{
    dVAR;
    const char* message;
    STRLEN msglen;
    PERL_ARGS_ASSERT_DIE_WHERE;

    if (ERRSV != msv) {
	sv_setsv(ERRSV, msv);
    }

    if (PL_in_eval) {
	I32 cxix;
	I32 gimme;

	while ((cxix = dopoptotry(cxstack_ix)) < 0
	       && PL_curstackinfo->si_prev)
	{
	    dounwind(-1);
	    POPSTACK;
	}

	if (cxix >= 0) {
	    I32 optype;
	    register PERL_CONTEXT *cx;
	    SV **newsp;

	    if (cxix < cxstack_ix)
		dounwind(cxix);

	    POPBLOCK(cx,PL_curpm);
	    if (CxTYPE(cx) != CXt_EVAL && CxTYPE(cx) != CXt_TRY) {
		PerlIO_write(Perl_error_log, (const char *)"panic: die ", 11);
		PerlIO_write(Perl_error_log, message, msglen);
		my_exit(1);
	    }
	    optype = CxOLD_OP_TYPE(cx);
	    POPEVAL(cx);

	    if (gimme == G_SCALAR)
		*++newsp = &PL_sv_undef;
	    PL_stack_sp = newsp;

	    LEAVE;

	    /* LEAVE could clobber PL_curcop (see save_re_context())
	     * XXX it might be better to find a way to avoid messing with
	     * PL_curcop in save_re_context() instead, but this is a more
	     * minimal fix --GSAR */
	    PL_curcop = cx->blk_oldcop;

	    if (optype == OP_REQUIRE) {
		SV * const nsv = cx->blk_eval.old_namesv;
                (void)hv_store(PL_includedhv, SvPVX_const(nsv), SvCUR(nsv),
                               &PL_sv_undef, 0);
		die_where(ERRSV);
	    }
	    assert(CxTYPE(cx) == CXt_EVAL || CxTYPE(cx) == CXt_TRY);

	    PL_restartop = cx->blk_eval.retop;
	    JMPENV_JUMP(3);
	}
    }

    my_failure_exit();
    /* NOTREACHED */
}

PP(pp_xor)
{
    dVAR; dSP; dPOPTOPssrl;
    if (SvTRUE(left) != SvTRUE(right))
	RETSETYES;
    else
	RETSETNO;
}

PP(pp_caller)
{
    dVAR;
    dSP;
    register I32 cxix = dopoptosub(cxstack_ix);
    register const PERL_CONTEXT *cx;
    register const PERL_CONTEXT *ccstack = cxstack;
    const PERL_SI *top_si = PL_curstackinfo;
    I32 gimme;
    const char *stashname;
    I32 count = 0;

    if (MAXARG)
	count = POPi;

    for (;;) {
	/* we may be in a higher stacklevel, so dig down deeper */
	while (cxix < 0 && top_si->si_type != PERLSI_MAIN) {
	    top_si = top_si->si_prev;
	    ccstack = top_si->si_cxstack;
	    cxix = dopoptosub_at(ccstack, top_si->si_cxix);
	}
	if (cxix < 0) {
	    if (GIMME != G_ARRAY) {
		EXTEND(SP, 1);
		RETPUSHUNDEF;
            }
	    RETURN;
	}
	/* caller() should not report the automatic calls to &DB::sub */
	if (PL_DBsub && GvCV(PL_DBsub) && cxix >= 0 &&
		ccstack[cxix].blk_sub.cv == GvCV(PL_DBsub))
	    count++;
	if (!count--)
	    break;
	cxix = dopoptosub_at(ccstack, cxix - 1);
    }

    cx = &ccstack[cxix];
    if (CxTYPE(cx) == CXt_SUB) {
        const I32 dbcxix = dopoptosub_at(ccstack, cxix - 1);
	/* We expect that ccstack[dbcxix] is CXt_SUB, anyway, the
	   field below is defined for any cx. */
	/* caller() should not report the automatic calls to &DB::sub */
	if (PL_DBsub && GvCV(PL_DBsub) && dbcxix >= 0 && ccstack[dbcxix].blk_sub.cv == GvCV(PL_DBsub))
	    cx = &ccstack[dbcxix];
    }

    stashname = CopSTASHPV(cx->blk_oldcop);
    if (GIMME != G_ARRAY) {
        EXTEND(SP, 1);
	if (!stashname)
	    PUSHs(&PL_sv_undef);
	else {
	    dTARGET;
	    sv_setpv(TARG, stashname);
	    PUSHs(TARG);
	}
	RETURN;
    }

    EXTEND(SP, 11);

    if (!stashname)
	PUSHs(&PL_sv_undef);
    else
	mPUSHs(newSVpv(stashname, 0));
    {
	SV**linenr = NULL;
	SV* location = cx->blk_oldop->op_location;
	SV* filename = LocationFilename(cx->blk_oldop->op_location);
	if (location)
	    linenr = av_fetch((AV*)location, 1, FALSE);
	if (filename)
	    mPUSHs(newSVsv(filename));
	else 
	    mPUSHs(newSVpv("(unknown)", 0));
	if (linenr && *linenr) {
	    mPUSHi(SvIV(*linenr));
	}
	else {
	    mPUSHi(0);
	}
    }
    if (!MAXARG)
	RETURN;
    if (CxTYPE(cx) == CXt_SUB) {
	CV* cv = cx->blk_sub.cv;
	SV** name = NULL;
	if (SvLOCATION(cv) && SvAVOK(SvLOCATION(cv)))
	    name = av_fetch(svTav(SvLOCATION(cv)), 3, FALSE);
	mPUSHs( name ? newSVsv(*name) : &PL_sv_undef );

	if (CxHASARGS(cx)) {
	    AV * const padlist = CvPADLIST(cv);
	    SV ** pad = av_fetch(padlist, cx->blk_sub.olddepth + 1, 0);
	    SV ** args = av_fetch( svTav(*pad), PAD_ARGS_INDEX, 0);
	    if (CvFLAGS(cv) & CVf_BLOCK) {
		AV* av = newAV();
		av_push(av, newSVsv(*args));
		mPUSHs(avTsv(av));
	    }
	    else {
		mPUSHs(newSVsv( *args ) );
	    }
	}
	else
	    PUSHs(&PL_sv_undef);
    }
    else {
	PUSHs(newSVpvs_flags("(eval)", SVs_TEMP));
	PUSHs(&PL_sv_undef);
    }
    gimme = (I32)cx->blk_gimme;
    if (gimme == G_VOID)
	PUSHs(&PL_sv_undef);
    else
	PUSHs(boolSV((gimme & G_WANT) == G_ARRAY));
    if (CxTYPE(cx) == CXt_EVAL || CxTYPE(cx) == CXt_TRY) {
	/* eval STRING */
	if (CxOLD_OP_TYPE(cx) == OP_ENTEREVAL) {
	    PUSHs(cx->blk_eval.cur_text);
	    PUSHs(&PL_sv_no);
	}
	/* require */
	else if (cx->blk_eval.old_namesv) {
	    mPUSHs(newSVsv(cx->blk_eval.old_namesv));
	    PUSHs(&PL_sv_yes);
	}
	/* eval BLOCK (try blocks have old_namesv == 0) */
	else {
	    PUSHs(&PL_sv_undef);
	    PUSHs(&PL_sv_undef);
	}
    }
    else {
	PUSHs(&PL_sv_undef);
	PUSHs(&PL_sv_undef);
    }
    /* XXX only hints propagated via op_private are currently
     * visible (others are not easily accessible, since they
     * use the global PL_hints) */
    mPUSHi(CopHINTS_get(cx->blk_oldcop));
    {
	SV * mask ;
	STRLEN * const old_warnings = cx->blk_oldcop->cop_warnings ;

	if  (old_warnings == pWARN_NONE ||
		(old_warnings == pWARN_STD && (PL_dowarn & G_WARN_ON) == 0))
            mask = newSVpvn(WARN_NONEstring, WARNsize) ;
        else if (old_warnings == pWARN_ALL ||
		  (old_warnings == pWARN_STD && PL_dowarn & G_WARN_ON)) {
	    /* Get the bit mask for $warnings::Bits{all}, because
	     * it could have been extended by warnings::register */
	    SV **bits_all;
	    HV * const bits = get_hv("warnings::Bits", FALSE);
	    if (bits && (bits_all=hv_fetchs(bits, "all", FALSE))) {
		mask = newSVsv(*bits_all);
	    }
	    else {
		mask = newSVpvn(WARN_ALLstring, WARNsize) ;
	    }
	}
        else
            mask = newSVpvn((char *) (old_warnings + 1), old_warnings[0]);
        mPUSHs(mask);
    }

    PUSHs(cx->blk_oldcop->cop_hints_hash ?
	  sv_2mortal(newRV((SV*)cx->blk_oldcop->cop_hints_hash))
	  : &PL_sv_undef);
    RETURN;
}

/* like pp_nextstate, but used instead when the debugger is active */

PP(pp_dbstate)
{
    dVAR;
    PL_curcop = (COP*)PL_op;
    PL_stack_sp = PL_stack_base + cxstack[cxstack_ix].blk_oldsp;
    FREETMPS;

    if (PL_op->op_flags & OPf_SPECIAL /* breakpoint */
	    || SvIV(PL_DBsingle) || SvIV(PL_DBsignal) || SvIV(PL_DBtrace))
    {
	dSP;
	register PERL_CONTEXT *cx;
	const I32 gimme = G_ARRAY;
	U8 hasargs;
	GV * const gv = PL_DBgv;
	register CV * const cv = GvCV(gv);

	if (!cv)
	    DIE(aTHX_ "No DB::DB routine defined");

	if (CvDEPTH(cv) >= 1 && !(PL_debug & DEBUG_DB_RECURSE_FLAG))
	    /* don't do recursive DB::DB call */
	    return NORMAL;

	ENTER;
	SAVETMPS;

	SAVEI32(PL_debug);
	SAVESTACK_POS();
	PL_debug = 0;
	hasargs = 0;
	SPAGAIN;

	if (CvISXSUB(cv)) {
	    CvDEPTH(cv)++;
	    PUSHMARK(SP);
	    (void)(*CvXSUB(cv))(aTHX_ cv);
	    CvDEPTH(cv)--;
	    FREETMPS;
	    LEAVE;
	    return NORMAL;
	}
	else {
	    PUSHBLOCK(cx, CXt_SUB, SP);
	    PUSHSUB_DB(cx);
	    cx->blk_sub.retop = PL_op->op_next;
	    CvDEPTH(cv)++;
	    SAVECOMPPAD();
	    pad_set_cur_nosave(CvPADLIST(cv), 1);
	    RETURNOP(CvSTART(cv));
	}
    }
    else
	return NORMAL;
}

PP(pp_enteriter)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    const I32 gimme = GIMME_V;
    SV **svp;
    U8 cxtype = CXt_LOOP_FOR;

    ENTER_named("loop1");
    SAVETMPS;

    if (PL_op->op_targ) {
	if (PL_op->op_private & OPpLVAL_INTRO) { /* for my $x (...) */
	    SvPADSTALE_off(PAD_SVl(PL_op->op_targ));
	    SAVESETSVFLAGS(PAD_SVl(PL_op->op_targ),
		    SVs_PADSTALE, SVs_PADSTALE);
	}
	SAVEPADSVANDMORTALIZE(PL_op->op_targ);
	svp = &PAD_SVl(PL_op->op_targ);		/* "my" variable */
    }
    else {
	GV * const gv = (GV*)POPs;
	svp = &GvSV(gv);			/* symbol table variable */
	SAVEGENERICSV(*svp);
	*svp = newSV(0);
    }

    if (PL_op->op_private & OPpITER_DEF)
	cxtype |= CXp_FOR_DEF;

    ENTER_named("loop2");

    PUSHBLOCK(cx, cxtype, SP);
    PUSHLOOP_FOR(cx, svp, SP-1, 0);
    if (PL_op->op_flags & OPf_SPECIAL) {
	SV * const right = POPs;
	dPOPss;

	if ( !SvNIOKp(sv) && SvPOKp(sv) && !looks_like_number(sv)) {
	    Perl_croak(aTHX_ "Range must be numeric");
	}
	if ( !SvNIOKp(right) && SvPOKp(right) && !looks_like_number(right)) {
	    Perl_croak(aTHX_ "Range must be numeric");
	}
	cx->cx_type &= ~CXTYPEMASK;
	cx->cx_type |= CXt_LOOP_LAZYIV;
	/* Make sure that no-one re-orders cop.h and breaks our
	   assumptions */
	assert(CxTYPE(cx) == CXt_LOOP_LAZYIV);
#ifdef NV_PRESERVES_UV
	if ((SvOK(sv) && ((SvNV(sv) < (NV)IV_MIN) ||
		    (SvNV(sv) > (NV)IV_MAX)))
	    ||
	    (SvOK(right) && ((SvNV(right) > (NV)IV_MAX) ||
		(SvNV(right) < (NV)IV_MIN))))
#else
	    if ((SvOK(sv) && ((SvNV(sv) <= (NV)IV_MIN)
			||
			((SvNV(sv) > 0) &&
			    ((SvUV(sv) > (UV)IV_MAX) ||
				(SvNV(sv) > (NV)UV_MAX)))))
		||
		(SvOK(right) && ((SvNV(right) <= (NV)IV_MIN)
		    ||
		    ((SvNV(right) > 0) &&
			((SvUV(right) > (UV)IV_MAX) ||
			    (SvNV(right) > (NV)UV_MAX))))))
#endif
		DIE(aTHX_ "Range iterator outside integer range");
	cx->blk_loop.state_u.lazyiv.cur = SvIV(sv);
	cx->blk_loop.state_u.lazyiv.end = SvIV(right);
#ifdef DEBUGGING
	/* for correct -Dstv display */
	cx->blk_oldsp = sp - PL_stack_base;
#endif
    }
    else { /* iterating over (copy of) the array on the stack */
	SV *maybe_ary = POPs;
	if ( ! ( PL_op->op_flags & OPf_STACKED) ) {
	    maybe_ary = sv_mortalcopy(maybe_ary);
	}
	if ( SvOK(maybe_ary) && ! SvAVOK(maybe_ary) )
	    croak(aTHX_ "for loop expected an array but got %s", Ddesc(maybe_ary));

	cx->blk_loop.state_u.ary.ary = (AV*)SvREFCNT_inc(maybe_ary);
	cx->blk_loop.state_u.ary.ix =
	    (PL_op->op_private & OPpITER_REVERSED)
	    ? (SvAVOK(maybe_ary) ? AvFILL(maybe_ary) + 1 : -1 )
	    : -1;
    }

    RETURN;
}

PP(pp_enterloop)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    const I32 gimme = GIMME_V;

    ENTER_named("loop1");
    SAVETMPS;
    ENTER_named("loop2");

    PUSHBLOCK(cx, CXt_LOOP_PLAIN, SP);
    PUSHLOOP_PLAIN(cx, SP);

    RETURN;
}

PP(pp_leaveloop)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    I32 gimme;
    SV **newsp;
    PMOP *newpm;
    SV **mark;

    POPBLOCK(cx,newpm);
    assert(CxTYPE_is_LOOP(cx));
    mark = newsp;
    newsp = PL_stack_base + cx->blk_loop.resetsp;

    if (gimme == G_VOID)
	NOOP;
    else if (gimme == G_SCALAR) {
	if (mark < SP)
	    *++newsp = sv_mortalcopy(*SP);
	else
	    *++newsp = &PL_sv_undef;
    }
    else {
	while (mark < SP) {
	    *++newsp = sv_mortalcopy(*++mark);
	}
    }
    SP = newsp;
    PUTBACK;

    POPLOOP(cx);	/* Stack values are safe: release loop vars ... */
    PL_curpm = newpm;	/* ... and pop $1 et al */

    LEAVE_named("loop2");
    LEAVE_named("loop1");

    return NORMAL;
}

PP(pp_return)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    bool clear_errsv = FALSE;
    I32 gimme;
    SV **newsp;
    PMOP *newpm;
    SV *sv;
    OP *retop;

    const I32 cxix = dopoptosub(cxstack_ix);

    if (cxix < 0) {
	if (CxMULTICALL(cxstack)) { /* In this case we must be in a
				     * sort block, which is a CXt_NULL
				     * not a CXt_SUB */
	    dounwind(0);
	    PL_stack_base[1] = *PL_stack_sp;
	    PL_stack_sp = PL_stack_base + 1;
	    return 0;
	}
	else
	    DIE(aTHX_ "Can't return outside a subroutine");
    }
    if (cxix < cxstack_ix)
	dounwind(cxix);

    if (CxMULTICALL(&cxstack[cxix])) {
	gimme = cxstack[cxix].blk_gimme;
	if (gimme == G_VOID)
	    PL_stack_sp = PL_stack_base;
	else if (gimme == G_SCALAR) {
	    PL_stack_base[1] = *PL_stack_sp;
	    PL_stack_sp = PL_stack_base + 1;
	}
	return 0;
    }

    POPBLOCK(cx,newpm);

    if (gimme != G_VOID) {
	if (PL_op->op_flags & OPf_STACKED) {
	    if (CxTYPE(cx) == CXt_SUB) {
		if (cx->blk_sub.cv && CvDEPTH(cx->blk_sub.cv) > 1) {
		    if (SvTEMP(TOPs)) {
			*++newsp = SvREFCNT_inc(*SP);
			FREETMPS;
			sv_2mortal(*newsp);
		    }
		    else {
			sv = SvREFCNT_inc(*SP);	/* FREETMPS could clobber it */
			FREETMPS;
			*++newsp = sv_mortalcopy(sv);
			SvREFCNT_dec(sv);
		    }
		}
		else
		    *++newsp = (SvTEMP(*SP)) ? *SP : sv_mortalcopy(*SP);
	    }
	    else
		*++newsp = sv_mortalcopy(*SP);
	}
	else {
	    *++newsp = &PL_sv_undef;
	}
    }
    PL_stack_sp = newsp;

    LEAVE;
    /* Stack values are safe: */
    switch (CxTYPE(cx)) {
    case CXt_SUB:
	retop = cx->blk_sub.retop;
	POPSUB(cx,sv);
	break;
    case CXt_EVAL:
    case CXt_TRY:
	if (!(PL_in_eval & EVAL_KEEPERR))
	    clear_errsv = TRUE;
	POPEVAL(cx);
	retop = cx->blk_eval.retop;
	if (CxTYPE(cx) == CXt_TRY)
	    break;
	lex_end();
	break;
    default:
	DIE(aTHX_ "panic: return");
    }
    PL_curpm = newpm;	/* ... and pop $1 et al */

    if (clear_errsv)
	sv_setsv(ERRSV, &PL_sv_undef);
    return retop;
}

PP(pp_last)
{
    dVAR; dSP;
    I32 cxix;
    register PERL_CONTEXT *cx;
    I32 gimme;
    I32 optype;
    OP *nextop;
    SV **newsp;
    PMOP *newpm;
    SV **mark;

    if (PL_op->op_flags & OPf_SPECIAL) {
	cxix = dopoptoloop(cxstack_ix);
	if (cxix < 0)
	    DIE(aTHX_ "Can't \"last\" outside a loop block");
    }
    else {
	cxix = dopoptolabel(cPVOP->op_pv);
	if (cxix < 0)
	    DIE(aTHX_ "Label not found for \"last %s\"", cPVOP->op_pv);
    }
    if (cxix < cxstack_ix)
	dounwind(cxix);

    POPBLOCK(cx,newpm);
    cxstack_ix++; /* temporarily protect top context */
    mark = newsp;
    assert(CxTYPE(cx) == CXt_LOOP_LAZYIV
	|| CxTYPE(cx) == CXt_LOOP_FOR
	|| CxTYPE(cx) == CXt_LOOP_PLAIN);
    newsp = PL_stack_base + cx->blk_loop.resetsp;
    nextop = cx->blk_loop.my_op->op_lastop->op_next;

    if (gimme == G_SCALAR) {
	if (MARK < SP)
	    *++newsp = sv_mortalcopy(*SP);
	else
	    *++newsp = &PL_sv_undef;
    }
    else if (gimme == G_ARRAY) {
	while (++MARK <= SP) {
	    *++newsp = sv_mortalcopy(*MARK);
	}
    }
    SP = newsp;
    PUTBACK;

    LEAVE_named("loop2");
    cxstack_ix--;
    /* Stack values are safe: */
    POPLOOP(cx);	/* release loop vars ... */
    LEAVE_named("loop1");
    PL_curpm = newpm;	/* ... and pop $1 et al */

    PERL_UNUSED_VAR(optype);
    PERL_UNUSED_VAR(gimme);
    return nextop;
}

PP(pp_next)
{
    dVAR;
    I32 cxix;
    register PERL_CONTEXT *cx;
    I32 inner;

    if (PL_op->op_flags & OPf_SPECIAL) {
	cxix = dopoptoloop(cxstack_ix);
	if (cxix < 0)
	    DIE(aTHX_ "Can't \"next\" outside a loop block");
    }
    else {
	cxix = dopoptolabel(cPVOP->op_pv);
	if (cxix < 0)
	    DIE(aTHX_ "Label not found for \"next %s\"", cPVOP->op_pv);
    }
    if (cxix < cxstack_ix)
	dounwind(cxix);

    /* clear off anything above the scope we're re-entering, but
     * save the rest until after a possible continue block */
    inner = PL_scopestack_ix;
    TOPBLOCK(cx);
    if (PL_scopestack_ix < inner)
	leave_scope(PL_scopestack[PL_scopestack_ix]);
    PL_curcop = cx->blk_oldcop;
    return CX_LOOP_NEXTOP_GET(cx);
}

PP(pp_redo)
{
    dVAR;
    I32 cxix;
    register PERL_CONTEXT *cx;
    I32 oldsave;
    OP* redo_op;

    if (PL_op->op_flags & OPf_SPECIAL) {
	cxix = dopoptoloop(cxstack_ix);
	if (cxix < 0)
	    DIE(aTHX_ "Can't \"redo\" outside a loop block");
    }
    else {
	cxix = dopoptolabel(cPVOP->op_pv);
	if (cxix < 0)
	    DIE(aTHX_ "Label not found for \"redo %s\"", cPVOP->op_pv);
    }
    if (cxix < cxstack_ix)
	dounwind(cxix);

    redo_op = cxstack[cxix].blk_loop.my_op->op_redoop;
    if (redo_op->op_type == OP_ENTER) {
	/* pop one less context to avoid $x being freed in while (my $x..) */
	I32 gimme = cxstack[cxstack_ix+1].blk_gimme;
	ENTER_named("block");
	PUSHBLOCK(cx, CXt_BLOCK, PL_stack_sp);

	assert(CxTYPE(&cxstack[cxstack_ix]) == CXt_BLOCK);
	redo_op = redo_op->op_next;
    }

    TOPBLOCK(cx);
    oldsave = PL_scopestack[PL_scopestack_ix - 1];
    LEAVE_SCOPE(oldsave);
    FREETMPS;
    PL_curcop = cx->blk_oldcop;
    return redo_op;
}

PP(pp_exit)
{
    dVAR;
    dSP;
    I32 anum;

    if (MAXARG < 1)
	anum = 0;
    else {
	anum = SvIV(POPs);
#ifdef VMS
        if (anum == 1 && (PL_op->op_private & OPpEXIT_VMSISH))
	    anum = 0;
        VMSISH_HUSHED  = VMSISH_HUSHED || (PL_op->op_private & OPpHUSH_VMSISH);
#endif
    }
    PL_exit_flags |= PERL_EXIT_EXPECTED;
#ifdef PERL_MAD
    /* KLUDGE: When making a MAD dump the exit code is overriden */
    if (PL_minus_c && PL_madskills)
	anum = anum ? 3 : 2;
#endif
    my_exit(anum);
    PUSHs(&PL_sv_undef);
    RETURN;
}

/* Eval. */

STATIC OP *
S_docatch(pTHX_ OP *o)
{
    dVAR;
    int ret;
    OP * const oldop = PL_op;
    dJMPENV;

#ifdef DEBUGGING
    assert(CATCH_GET == TRUE);
#endif
    PL_op = o;

    JMPENV_PUSH(ret);
    switch (ret) {
    case 0:
	assert(cxstack_ix >= 0);
	assert(CxTYPE(&cxstack[cxstack_ix]) == CXt_EVAL
	    || CxTYPE(&cxstack[cxstack_ix]) == CXt_TRY);
	cxstack[cxstack_ix].blk_eval.cur_top_env = PL_top_env;
 redo_body:
	CALLRUNOPS(aTHX);
	break;
    case 3:
	/* die caught by an inner eval - continue inner loop */

	/* NB XXX we rely on the old popped CxEVAL still being at the top
	 * of the stack; the way die_where() currently works, this
	 * assumption is valid. In theory The cur_top_env value should be
	 * returned in another global, the way retop (aka PL_restartop)
	 * is. */
	assert(CxTYPE(&cxstack[cxstack_ix+1]) == CXt_EVAL
	    || CxTYPE(&cxstack[cxstack_ix+1]) == CXt_TRY);

	if (PL_restartop
	    && cxstack[cxstack_ix+1].blk_eval.cur_top_env == PL_top_env)
	{
	    PL_op = PL_restartop;
	    PL_restartop = 0;
	    goto redo_body;
	}
	/* FALL THROUGH */
    default:
	JMPENV_POP;
	PL_op = oldop;
	JMPENV_JUMP(ret);
	/* NOTREACHED */
    }
    JMPENV_POP;
    PL_op = oldop;
    return NULL;
}

OP *
Perl_sv_compile_2op(pTHX_ SV *sv, ROOTOP** rootopp, const char *code, PAD** padp)
/* sv Text to convert to OP tree. */
/* startop op_free() this to undo. */
/* code Short string id of the caller. */
{
    /* FIXME - how much of this code is common with pp_entereval?  */
    dVAR; dSP;				/* Make POPBLOCK work. */
    PERL_CONTEXT *cx;
    SV **newsp;
    I32 gimme = G_VOID;
    I32 optype;
    OP dummy;
    char tbuf[TYPE_DIGITS(long) + 12 + 10];
    char *tmpbuf = tbuf;
    char *safestr;
    int runtime;
    CV* runcv = NULL;	/* initialise to avoid compiler warnings */
    STRLEN len;
    OP *oldop;

    PERL_ARGS_ASSERT_SV_COMPILE_2OP;

    ENTER_named("compile_2op");
    lex_start(sv, NULL, FALSE);
    SAVETMPS;
    /* switch to eval mode */

    if (IN_PERL_COMPILETIME) {
	CopSTASH_set(&PL_compiling, PL_curstash);
    }
    len = my_snprintf(tmpbuf, sizeof(tbuf), "_<(%.10s_eval %lu)", code,
	(unsigned long)++PL_evalseq);
    SVcpSTEAL(PL_parser->lex_filename, newSVpvn(tmpbuf+2, len-2));
    /* XXX For C<eval "...">s within BEGIN {} blocks, this ends up
       deleting the eval's FILEGV from the stash before gv_check() runs
       (i.e. before run-time proper). To work around the coredump that
       ensues, we always turn GvMULTI_on for any globals that were
       introduced within evals. See force_ident(). GSAR 96-10-12 */
    safestr = savepvn(tmpbuf, len);
    SAVEDELETE(PL_defstash, safestr, len);
    SAVEHINTS();
#ifdef OP_IN_REGISTER
    PL_opsave = op;
#else
    SAVEVPTR(PL_op);
#endif

    /* we get here either during compilation, or via pp_regcomp at runtime */
    runtime = IN_PERL_RUNTIME;
    if (runtime)
	runcv = find_runcv(NULL);

    oldop = PL_op;
    PL_op = &dummy;
    PL_op->op_type = OP_ENTEREVAL;
    PL_op->op_flags = 0;			/* Avoid uninit warning. */
    PL_op->op_location = SvLOCATION(sv);
    PUSHBLOCK(cx, CXt_EVAL, SP);
    PUSHEVAL(cx, 0);

    if (runtime)
	(void) doeval(G_SCALAR, rootopp, runcv, PL_curcop->cop_seq);
    else
	(void) doeval(G_SCALAR, rootopp, PL_compcv, PL_cop_seqmax);
    rootop_refcnt_inc(*rootopp);
    POPBLOCK(cx,PL_curpm);
    POPEVAL(cx);

    /* remove "leaveeval" op */
    assert((*rootopp)->op_first->op_type == OP_LEAVEEVAL);
    (*rootopp)->op_first->op_type = OP_NULL;
    (*rootopp)->op_first->op_ppaddr = PL_ppaddr[OP_NULL];

    lex_end();
    /* XXX DAPM do this properly one year */
    *padp = AvREFCNT_inc(PL_comppad);
    LEAVE_named("compile_2op");
    if (IN_PERL_COMPILETIME)
	CopHINTS_set(&PL_compiling, PL_hints);
#ifdef OP_IN_REGISTER
    op = PL_opsave;
#endif
    PERL_UNUSED_VAR(newsp);
    PERL_UNUSED_VAR(optype);

    return (*rootopp)->op_next;
}


/*
=for apidoc find_runcv

Locate the CV corresponding to the currently executing sub or eval.
If db_seqp is non_null, skip CVs that are in the DB package and populate
*db_seqp with the cop sequence number at the point that the DB:: code was
entered. (allows debuggers to eval in the scope of the breakpoint rather
than in the scope of the debugger itself).

=cut
*/

CV*
Perl_find_runcv(pTHX_ U32 *db_seqp)
{
    dVAR;
    PERL_SI	 *si;

    if (db_seqp)
	*db_seqp = PL_curcop->cop_seq;
    for (si = PL_curstackinfo; si; si = si->si_prev) {
        I32 ix;
	for (ix = si->si_cxix; ix >= 0; ix--) {
	    const PERL_CONTEXT *cx = &(si->si_cxstack[ix]);
	    if (CxTYPE(cx) == CXt_SUB) {
		CV * const cv = cx->blk_sub.cv;
		return cv;
	    }
	    else if (CxTYPE(cx) == CXt_EVAL)
		return PL_compcv;
	}
    }
    return PL_main_cv;
}


/* Compile a require/do, an eval '', or a /(?{...})/.
 * In the last case, startop is non-null, and contains the address of
 * a pointer that should be set to the just-compiled code.
 * outside is the lexically enclosing CV (if any) that invoked us.
 * Returns a bool indicating whether the compile was successful; if so,
 * PL_eval_start contains the first op of the compiled ocde; otherwise,
 * pushes undef (also croaks if startop != NULL).
 */

STATIC bool
S_doeval(pTHX_ int gimme, ROOTOP** rootopp, CV* outside, U32 seq)
{
    dVAR; dSP;
    OP * const saveop = PL_op;

    assert(!PL_parser->error_count);

    PL_in_eval = ((saveop && saveop->op_type == OP_REQUIRE)
		  ? (EVAL_INREQUIRE | (PL_in_eval & EVAL_INEVAL))
		  : EVAL_INEVAL);

    PUSHMARK(SP);

    SAVESPTR(PL_compcv);
    CVcpSTEAL(PL_compcv, (CV*)newSV_type(SVt_PVCV));
    CvEVAL_on(PL_compcv);
    assert(CxTYPE(&cxstack[cxstack_ix]) == CXt_EVAL);
    cxstack[cxstack_ix].blk_eval.cv = PL_compcv;

    /* set up a scratch pad */

    if (outside) {
	CvPADLIST(PL_compcv) = pad_new(padnew_SAVE, 
	    PADLIST_PADNAMES(CvPADLIST(outside)),
	    svTav(AvARRAY(CvPADLIST(outside))[CvDEPTH(outside) ? CvDEPTH(outside) : 1]),
	    seq);
    }
    else {
	CvPADLIST(PL_compcv) = pad_new(padnew_SAVE,  NULL, NULL, seq);
    }
    PL_op = NULL; /* avoid PL_op and PL_curpad referring to different CVs */

    /* make sure we compile in the right package */

    if (CopSTASH_ne(PL_curcop, PL_curstash)) {
	SAVESPTR(PL_curstash);
	HVcpREPLACE(PL_curstash, CopSTASH(PL_curcop));
    }

    /* XXX:ajgo do we really need to alloc an AV for begin/checkunit */
    SAVESPTR(PL_unitcheckav);
    AVcpSTEAL(PL_unitcheckav, newAV());

#ifdef PERL_MAD
    SAVEBOOL(PL_madskills);
    PL_madskills = 0;
#endif

    /* try to compile it */

    PL_eval_root = NULL;
    PL_curcop = &PL_compiling;
    if (saveop && (saveop->op_type != OP_REQUIRE) && (saveop->op_flags & OPf_SPECIAL))
	PL_in_eval |= EVAL_KEEPERR;
    else
	sv_setpvn(ERRSV,"",0);
    if (yyparse() || PL_parser->error_count || !PL_eval_root) {
	SV **newsp;			/* Used by POPBLOCK. */
	PERL_CONTEXT *cx = &cxstack[cxstack_ix];
	I32 optype = 0;			/* Might be reset by POPEVAL. */
	const char *msg;

	PL_op = saveop;
	ROOTOPcpNULL(PL_eval_root);
	SP = PL_stack_base + POPMARK;		/* pop original mark */
	if (!rootopp) {
	    POPBLOCK(cx,PL_curpm);
	    optype = CxOLD_OP_TYPE(cx);
	    POPEVAL(cx);
	}
	lex_end();

	msg = SvPVx_nolen_const(ERRSV);
	if (optype == OP_REQUIRE) {
	    SV * const nsv = cx->blk_eval.old_namesv;
	    (void)hv_store(PL_includedhv, SvPVX_const(nsv), SvCUR(nsv),
                          &PL_sv_undef, 0);
	    Perl_croak(aTHX_ "%sCompilation failed in require",
		       *msg ? msg : "Unknown error\n");
	}
	else if (rootopp) {
	    POPBLOCK(cx,PL_curpm);
	    POPEVAL(cx);
	    Perl_croak(aTHX_ "%sCompilation failed in regexp",
		       (*msg ? msg : "Unknown error\n"));
	}
	LEAVE_named("eval");

	{
	    dSP;
	    ENTER_named("call_errorcreatehook");
	    PUSHSTACKi(PERLSI_DIEHOOK);
	
	    PUSHMARK(SP);
	    XPUSHs(ERRSV);
	    XPUSHs(PL_op->op_location);
	    PUTBACK;
	    sv_setsv(ERRSV, call_sv(PL_errorcreatehook, G_SCALAR));
	    SPAGAIN;
	    PUTBACK;

	    POPSTACK;
	    LEAVE_named("call_errorcreatehook");
	}

	PERL_UNUSED_VAR(newsp);
	PUSHs(&PL_sv_undef);
	PUTBACK;
	return FALSE;
    }
    if (rootopp) {
	*rootopp = PL_eval_root;
    }

    /* Set the context for this new optree.
     * If the last op is an OP_REQUIRE, force scalar context.
     * Otherwise, propagate the context from the eval(). */
    if (PL_eval_root->op_type == OP_LEAVEEVAL
	    && cUNOPx(PL_eval_root)->op_first->op_type == OP_LINESEQ
	    && cLISTOPx(cUNOPx(PL_eval_root)->op_first)->op_last->op_type
	    == OP_REQUIRE)
	scalar(PL_eval_root->op_first);
    else if ((gimme & G_WANT) == G_VOID)
	scalarvoid(PL_eval_root->op_first);
    else if ((gimme & G_WANT) == G_ARRAY)
	list(PL_eval_root->op_first);
    else
	scalar(PL_eval_root->op_first);

    DEBUG_x(dump_eval());

    /* Register with debugger: */
    if (PERLDB_INTER && saveop && saveop->op_type == OP_REQUIRE) {
	CV * const cv = get_cv("DB::postponed", FALSE);
	if (cv) {
	    dSP;
	    PUSHMARK(SP);
	    XPUSHs(LocationFilename(PL_compiling.op_location));
	    PUTBACK;
	    call_sv((SV*)cv, G_DISCARD);
	}
    }

    if (PL_unitcheckav)
	call_list(PL_scopestack_ix, PL_unitcheckav);

    /* compiled okay, so do it */

    CvDEPTH(PL_compcv) = 1;
    SP = PL_stack_base + POPMARK;		/* pop original mark */
    PL_op = saveop;			/* The caller may need it. */
    PL_parser->lex_state = LEX_NOTPARSING;	/* $^S needs this. */

    PUTBACK;
    return TRUE;
}

STATIC PerlIO *
S_check_type_and_open(pTHX_ const char *name)
{
    Stat_t st;
    const int st_rc = PerlLIO_stat(name, &st);

    PERL_ARGS_ASSERT_CHECK_TYPE_AND_OPEN;

    if (st_rc < 0 || S_ISDIR(st.st_mode) || S_ISBLK(st.st_mode)) {
	return NULL;
    }

    return PerlIO_open(name, PERL_SCRIPT_MODE);
}

#ifndef PERL_DISABLE_PMC
STATIC PerlIO *
S_doopen_pm(pTHX_ const char *name, const STRLEN namelen)
{
    PerlIO *fp;

    PERL_ARGS_ASSERT_DOOPEN_PM;

    if (namelen > 3 && memEQs(name + namelen - 3, 3, ".pm")) {
	SV *const pmcsv = newSV(namelen + 2);
	char *const pmc = SvPVX_mutable(pmcsv);
	Stat_t pmcstat;

	memcpy(pmc, name, namelen);
	pmc[namelen] = 'c';
	pmc[namelen + 1] = '\0';

	if (PerlLIO_stat(pmc, &pmcstat) < 0) {
	    fp = check_type_and_open(name);
	}
	else {
	    fp = check_type_and_open(pmc);
	}
	SvREFCNT_dec(pmcsv);
    }
    else {
	fp = check_type_and_open(name);
    }
    return fp;
}
#else
#  define doopen_pm(name, namelen) check_type_and_open(name)
#endif /* !PERL_DISABLE_PMC */

PP(pp_require)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    SV *sv;
    const char *name;
    STRLEN len;
    char * unixname;
    STRLEN unixlen;
#ifdef VMS
    int vms_unixname = 0;
#endif
    const char *tryname = NULL;
    SV *namesv = NULL;
    const I32 gimme = GIMME_V;
    int filter_has_file = 0;
    PerlIO *tryrsfp = NULL;
    SV *filter_cache = NULL;
    SV *filter_state = NULL;
    SV *filter_sub = NULL;
    SV *hook_sv = NULL;
    OP *op;
    SV *filename;
    bool eval_ok;

    sv = POPs;
    name = SvPV_const(sv, len);
    if (!(name && len > 0 && *name))
	DIE(aTHX_ "Null filename used");


#ifdef VMS
    /* The key in the %ENV hash is in the syntax of file passed as the argument
     * usually this is in UNIX format, but sometimes in VMS format, which
     * can result in a module being pulled in more than once.
     * To prevent this, the key must be stored in UNIX format if the VMS
     * name can be translated to UNIX.
     */
    if ((unixname = tounixspec(name, NULL)) != NULL) {
	unixlen = strlen(unixname);
	vms_unixname = 1;
    }
    else
#endif
    {
        /* if not VMS or VMS name can not be translated to UNIX, pass it
	 * through.
	 */
	unixname = (char *) name;
	unixlen = len;
    }
    if (PL_op->op_type == OP_REQUIRE) {
	SV * const * const svp = hv_fetch(PL_includedhv,
					  unixname, unixlen, 0);
	if ( svp ) {
	    if (SvTRUE(*svp))
		RETPUSHYES;
	    else if (*svp == &PL_sv_undef)
		DIE(aTHX_ "Attempt to reload %s aborted.\n"
			    "Compilation failed in require", unixname);
	    else
		DIE(aTHX_ "Circular dependency: %s is still being compiled", unixname);
	}
    }

    /* prepare to compile file */

    if (path_is_absolute(name)) {
	tryname = name;
	tryrsfp = doopen_pm(name, len);
    }
    if (!tryrsfp) {
	AV * const ar = PL_includepathav;
	I32 i;
	if (!SvAVOK(ar)) 
	    Perl_croak(aTHX_ "$^INCLUDE_PATH must be an array not a %s", Ddesc((SV*)ar));
#ifdef VMS
	if (vms_unixname)
#endif
	{
	    namesv = sv_2mortal(newSV_type(SVt_PV));
	    for (i = 0; i <= AvFILL(ar); i++) {
		SV * const dirsv = *av_fetch(ar, i, TRUE);

		if (SvROK(dirsv) || SvTYPE(dirsv) == SVt_PVCV) {
		    SV **svp;
		    SV *loader = dirsv;
		    SV *arg;

		    if (SvTYPE(loader) == SVt_PVCV) {
			Perl_sv_setpvf(aTHX_ namesv, "/loader/0x%"UVxf"/%s",
			    PTR2UV(dirsv), name);
		    }
		    else {
			if (SvTYPE(SvRV(loader)) == SVt_PVAV
			    && !sv_isobject(loader)) {
			    loader = *av_fetch((AV *)SvRV(loader), 0, TRUE);
			}

			Perl_sv_setpvf(aTHX_ namesv, "/loader/0x%"UVxf"/%s",
			    PTR2UV(SvRV(dirsv)), name);
		    }
		    tryname = SvPVX_const(namesv);
		    tryrsfp = NULL;

		    ENTER_named("require_INC");
		    SAVETMPS;
		    EXTEND(SP, 2);

		    PUSHMARK(SP);
		    PUSHs(dirsv);
		    PUSHs(sv);
		    PUTBACK;
		    if (sv_isobject(loader))
			arg = call_method("INC", G_SCALAR);
		    else
			arg = call_sv(loader, G_SCALAR);
		    SPAGAIN;

		    /* Adjust file name if the hook has set an $^INCLUDED entry */
		    svp = hv_fetch(PL_includedhv, name, len, 0);
		    if (svp)
			tryname = SvPVX_const(*svp);

		    if (SvROK(arg) && (SvTYPE(SvRV(arg)) <= SVt_PVGV)
			&& !isGV_with_GP(SvRV(arg))) {
			filter_cache = SvRV(arg);
			SvREFCNT_inc_void_NN(filter_cache);
		    }

		    if (SvROK(arg) && SvTYPE(SvRV(arg)) == SVt_PVGV) {
			arg = SvRV(arg);
		    }

		    if (SvTYPE(arg) == SVt_PVGV) {
			IO * const io = GvIO((GV *)arg);

			++filter_has_file;

			if (io) {
			    tryrsfp = IoIFP(io);
			    if (IoOFP(io) && IoOFP(io) != IoIFP(io)) {
				PerlIO_close(IoOFP(io));
			    }
			    IoIFP(io) = NULL;
			    IoOFP(io) = NULL;
			}

		    }

		    if (SvROK(arg) && SvTYPE(SvRV(arg)) == SVt_PVCV) {
			filter_sub = arg;
			SvREFCNT_inc_void_NN(filter_sub);
		    }

		    if (!tryrsfp && (filter_cache || filter_sub)) {
			tryrsfp = PerlIO_open(BIT_BUCKET,
			    PERL_SCRIPT_MODE);
		    }

		    FREETMPS;
		    LEAVE_named("require_INC");

		    if (tryrsfp) {
			hook_sv = dirsv;
			break;
		    }

		    filter_has_file = 0;
		    if (filter_cache) {
			SvREFCNT_dec(filter_cache);
			filter_cache = NULL;
		    }
		    if (filter_state) {
			SvREFCNT_dec(filter_state);
			filter_state = NULL;
		    }
		    if (filter_sub) {
			SvREFCNT_dec(filter_sub);
			filter_sub = NULL;
		    }
		}
		else {
		  if (!path_is_absolute(name)) {
		    const char *dir = SvOK(dirsv) ? SvPV_nolen_const(dirsv) : "";
#  ifdef VMS
		    char *unixdir;
		    if ((unixdir = tounixpath(dir, NULL)) == NULL)
			continue;
		    sv_setpv(namesv, unixdir);
		    sv_catpv(namesv, unixname);
#  else
#    ifdef __SYMBIAN32__
		    if (PL_origfilename[0] &&
			PL_origfilename[1] == ':' &&
			!(dir[0] && dir[1] == ':'))
		        Perl_sv_setpvf(aTHX_ namesv,
				       "%c:%s\\%s",
				       PL_origfilename[0],
				       dir, name);
		    else
		        Perl_sv_setpvf(aTHX_ namesv,
				       "%s\\%s",
				       dir, name);
#    else
		    Perl_sv_setpvf(aTHX_ namesv, "%s/%s", dir, name);
#    endif
#  endif
		    tryname = SvPVX_const(namesv);
		    tryrsfp = doopen_pm(tryname, SvCUR(namesv));
		    if (tryrsfp) {
			if (tryname[0] == '.' && tryname[1] == '/')
			    tryname += 2;
			break;
		    }
		    else if (errno == EMFILE)
			/* no point in trying other paths if out of handles */
			break;
		  }
		}
	    }
	}
    }
    filename = sv_2mortal(newSVpv( tryrsfp ? tryname : name, 0)); /* temporary reference leak */
    if (!tryrsfp) {
	if (PL_op->op_type == OP_REQUIRE) {
	    const char *msgstr = name;
	    if(errno == EMFILE) {
		SV * const msg
		    = sv_2mortal(Perl_newSVpvf(aTHX_ "%s:   %s", msgstr,
					       Strerror(errno)));
		msgstr = SvPV_nolen_const(msg);
	    } else {
	        if (namesv) {			/* did we lookup $^INCLUDE_PATH? */
		    AV * const ar = PL_includepathav;
		    I32 i;
		    SV * const msg = sv_2mortal(Perl_newSVpvf(aTHX_ 
			"%s in $^INCLUDE_PATH ($^INCLUDE_PATH contains:", msgstr));
		    
		    for (i = 0; i <= AvFILL(ar); i++) {
			sv_catpvs(msg, " ");
			sv_catsv(msg, *av_fetch(ar, i, TRUE));
		    }
		    sv_catpvs(msg, ")");
		    msgstr = SvPV_nolen_const(msg);
		}    
	    }
	    DIE(aTHX_ "Can't locate %s", msgstr);
	}

	RETPUSHUNDEF;
    }
    else
	SETERRNO(0, SS_NORMAL);

    /* Assume success here to prevent recursive requirement. */
    /* name is never assigned to again, so len is still strlen(name)  */
    /* Check whether a hook in $^INCLUDE_PATH has already filled $^INCLUDED */
    if (!hook_sv) {
	(void)hv_store(PL_includedhv,
	    unixname, unixlen, &PL_sv_no, 0);
    } else {
	SV** const svp = hv_fetch(PL_includedhv, unixname, unixlen, 0);
	if (!svp)
	    (void)hv_store(PL_includedhv,
			   unixname, unixlen, &PL_sv_no, 0 );
    }

    ENTER_named("eval");
    SAVETMPS;
    lex_start(NULL, tryrsfp, TRUE);
    SVcpREPLACE(PL_parser->lex_filename, filename);

    SAVEHINTS();
    PL_hints = DEFAULT_HINTS;
    if (PL_compiling.cop_hints_hash) {
	HvREFCNT_dec(PL_compiling.cop_hints_hash);
	PL_compiling.cop_hints_hash = newHV();
    }

    SAVECOMPILEWARNINGS();
    if (PL_dowarn & G_WARN_ALL_ON)
        PL_compiling.cop_warnings = pWARN_ALL ;
    else if (PL_dowarn & G_WARN_ALL_OFF)
        PL_compiling.cop_warnings = pWARN_NONE ;
    else
        PL_compiling.cop_warnings = pWARN_STD ;

    if (filter_sub || filter_cache) {
	SV * const datasv = filter_add(S_run_user_filter, NULL);
	IoLINES(datasv) = filter_has_file;
    }

    /* switch to eval mode */
    PUSHBLOCK(cx, CXt_EVAL, SP);
    PUSHEVAL(cx, name);
    cx->blk_eval.retop = PL_op->op_next;
    cx->blk_oldop = PL_op;

    PUTBACK;

    eval_ok = doeval(gimme, NULL, NULL, PL_curcop->cop_seq);

    /* mark require as finished */
    if (!hook_sv) {
	(void)hv_store(PL_includedhv,
	    unixname, unixlen, SvREFCNT_inc(filename), 0);
    } else {
	SV** const svp = hv_fetch(PL_includedhv, unixname, unixlen, 0);
	if ( ! ( svp && SvTRUE(*svp) ) )
	    (void)hv_store(PL_includedhv,
		unixname, unixlen, SvREFCNT_inc(hook_sv), 0 );
    }

    if (eval_ok)
	op = DOCATCH(PL_eval_start);
    else
	op = PL_op->op_next;

    return op;
}

/* This is a op added to hold the hints hash for
   pp_entereval. The hash can be modified by the code
   being eval'ed, so we return a copy instead. */

PP(pp_hintseval)
{
    dVAR;
    dSP;
    mXPUSHs(newSVsv(cSVOP_sv));
    RETURN;
}


PP(pp_entereval)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    SV *sv;
    const I32 gimme = GIMME_V;
    const I32 was = PL_sub_generation;
    char tbuf[TYPE_DIGITS(long) + 12];
    char *tmpbuf = tbuf;
    char *safestr;
    STRLEN len;
    bool ok;
    CV* runcv;
    U32 seq;
    HV *saved_hh = NULL;
    const char * const fakestr = "_<(eval )";
    const int fakelen = 9 + 1;
    
    if (PL_op->op_private & OPpEVAL_HAS_HH) {
	saved_hh = (HV*) SvREFCNT_inc(POPs);
    }
    sv = POPs;

    ENTER_named("eval");
    lex_start(sv, NULL, FALSE);
    SAVETMPS;

    /* switch to eval mode */
    if (!PL_parser->lex_filename) {
	len = my_snprintf(tmpbuf, sizeof(tbuf), "_<(eval %lu)", (unsigned long)++PL_evalseq);
	SVcpSTEAL(PL_parser->lex_filename, newSVpvn(tmpbuf+2, len-2));
	/* XXX For C<eval "...">s within BEGIN {} blocks, this ends up
	   deleting the eval's FILEGV from the stash before gv_check() runs
	   (i.e. before run-time proper). To work around the coredump that
	   ensues, we always turn GvMULTI_on for any globals that were
	   introduced within evals. See force_ident(). GSAR 96-10-12 */
	safestr = savepvn(tmpbuf, len);
	SAVEDELETE(PL_defstash, safestr, len);
    }
    SAVEHINTS();
    PL_hints = PL_op->op_targ;
    if (saved_hh)
	HVcpSTEAL(PL_hinthv, saved_hh);

    SAVESPTR(PL_diehook);
    SVcpREPLACE(PL_diehook, PERL_DIEHOOK_IGNORE);

    SAVECOMPILEWARNINGS();
    PL_compiling.cop_warnings = DUP_WARNINGS(PL_curcop->cop_warnings);
    if (PL_curcop->cop_hints_hash) {
	HINTS_REFCNT_LOCK;
	HvREFCNT_inc(PL_curcop->cop_hints_hash);
	HINTS_REFCNT_UNLOCK;
    }
    if (PL_compiling.cop_hints_hash) {
	HINTS_REFCNT_LOCK;
	HvREFCNT_dec(PL_compiling.cop_hints_hash);
	HINTS_REFCNT_UNLOCK;
    }
    PL_compiling.cop_hints_hash = PL_curcop->cop_hints_hash;
    /* special case: an eval '' executed within the DB package gets lexically
     * placed in the first non-DB CV rather than the current CV - this
     * allows the debugger to execute code, find lexicals etc, in the
     * scope of the code being debugged. Passing &seq gets find_runcv
     * to do the dirty work for us */
    runcv = find_runcv(&seq);

    PUSHBLOCK(cx, CXt_EVAL, SP);
    PUSHEVAL(cx, 0);
    cx->blk_eval.retop = PL_op->op_next;

    /* prepare to compile string */

    PUTBACK;
    ok = doeval(gimme, NULL, runcv, seq);
    if (PERLDB_INTER && was != (I32)PL_sub_generation /* Some subs defined here. */
	&& ok) {
	/* Copy in anything fake and short. */
	my_strlcpy(safestr, fakestr, fakelen);
    }
    return ok ? DOCATCH(PL_eval_start) : PL_op->op_next;
}

PP(pp_leaveeval)
{
    dVAR; dSP;
    register SV **mark;
    SV **newsp;
    PMOP *newpm;
    I32 gimme;
    register PERL_CONTEXT *cx;
    OP *retop;
    const U8 save_flags = PL_op -> op_flags;

    POPBLOCK(cx,newpm);

    if (gimme == G_VOID)
	MARK = newsp;
    else if (gimme == G_SCALAR) {
	MARK = newsp + 1;
	if (MARK <= SP) {
	    if (SvFLAGS(TOPs) & SVs_TEMP)
		*MARK = TOPs;
	    else
		*MARK = sv_mortalcopy(TOPs);
	}
	else {
	    MEXTEND(mark,0);
	    *MARK = &PL_sv_undef;
	}
	SP = MARK;
    }
    else {
	/* in case LEAVE wipes old return values */
	for (mark = newsp + 1; mark <= SP; mark++) {
	    if (!(SvFLAGS(*mark) & SVs_TEMP)) {
		*mark = sv_mortalcopy(*mark);
	    }
	}
    }

    PL_op = NULL;
    POPEVAL(cx);
    retop = cx->blk_eval.retop;

    PL_curpm = newpm;	/* Don't pop $1 et al till now */

#ifdef DEBUGGING
    assert(CvDEPTH(PL_compcv) == 1);
#endif
    CvDEPTH(PL_compcv) = 0;
    lex_end();

    LEAVE_named("eval");
    if (!(save_flags & OPf_SPECIAL))
	sv_setpvn(ERRSV,"",0);

    RETURNOP(retop);
}

/* Common code for Perl_call_sv and Perl_fold_constants, put here to keep it
   close to the related Perl_create_eval_scope.  */
void
Perl_delete_eval_scope(pTHX)
{
    SV **newsp;
    PMOP *newpm;
    I32 gimme;
    register PERL_CONTEXT *cx;
    I32 optype;
	
    POPBLOCK(cx,newpm);
    POPEVAL(cx);
    PL_curpm = newpm;
    LEAVE_named("eval_scope");
    PERL_UNUSED_VAR(newsp);
    PERL_UNUSED_VAR(gimme);
    PERL_UNUSED_VAR(optype);
}

/* Common-ish code salvaged from Perl_call_sv and pp_entertry, because it was
   also needed by Perl_fold_constants.  */
PERL_CONTEXT *
Perl_create_eval_scope(pTHX_ U32 flags)
{
    PERL_CONTEXT *cx;
    const I32 gimme = GIMME_V;
	
    ENTER_named("eval_scope");
    SAVETMPS;

    PUSHBLOCK(cx, CXt_TRY, PL_stack_sp);
    PUSHEVAL(cx, 0);

    PL_in_eval = EVAL_INEVAL;
    if (flags & G_KEEPERR)
	PL_in_eval |= EVAL_KEEPERR;
    else
	sv_setpvn(ERRSV,"",0);
    return cx;
}
    
PP(pp_entertry)
{
    dVAR;
    PERL_CONTEXT * const cx = create_eval_scope(0);

    SAVESPTR(PL_diehook);
    SVcpREPLACE(PL_diehook, PERL_DIEHOOK_IGNORE);

    cx->blk_eval.retop = cLOGOP->op_other->op_next;
    return DOCATCH(PL_op->op_next);
}

PP(pp_leavetry)
{
    dVAR; dSP;
    SV **newsp;
    PMOP *newpm;
    I32 gimme;
    register PERL_CONTEXT *cx;
    I32 optype;

    POPBLOCK(cx,newpm);
    POPEVAL(cx);
    PERL_UNUSED_VAR(optype);

    if (gimme == G_VOID)
	SP = newsp;
    else if (gimme == G_SCALAR) {
	register SV **mark;
	MARK = newsp + 1;
	if (MARK <= SP) {
	    if (SvFLAGS(TOPs) & (SVs_PADTMP|SVs_TEMP))
		*MARK = TOPs;
	    else
		*MARK = sv_mortalcopy(TOPs);
	}
	else {
	    MEXTEND(mark,0);
	    *MARK = &PL_sv_undef;
	}
	SP = MARK;
    }
    else {
	/* in case LEAVE wipes old return values */
	register SV **mark;
	for (mark = newsp + 1; mark <= SP; mark++) {
	    if (!(SvFLAGS(*mark) & (SVs_PADTMP|SVs_TEMP))) {
		*mark = sv_mortalcopy(*mark);
	    }
	}
    }
    PL_curpm = newpm;	/* Don't pop $1 et al till now */

    LEAVE_named("eval_scope");
    sv_setpvn(ERRSV,"",0);
    RETURN;
}

static I32
S_run_user_filter(pTHX_ int idx, SV *buf_sv, int maxlen)
{
    dVAR;
    SV * const datasv = FILTER_DATA(idx);
    const int filter_has_file = IoLINES(datasv);
    SV * const filter_state = NULL; /* (SV *)IoTOP_GV(datasv); */
    SV * const filter_sub = NULL; /* (SV *)IoBOTTOM_GV(datasv); */
    int status = 0;
    SV *upstream;
    STRLEN got_len;
    const char *got_p = NULL;
    const char *prune_from = NULL;
    STRLEN umaxlen;

    PERL_ARGS_ASSERT_RUN_USER_FILTER;

    assert(maxlen >= 0);
    umaxlen = maxlen;

    /* Filter API says that the filter appends to the contents of the buffer.
       Usually the buffer is "", so the details don't matter. But if it's not,
       then clearly what it contains is already filtered by this filter, so we
       don't want to pass it in a second time.
       I'm going to use a mortal in case the upstream filter croaks.  */
    upstream = ((SvOK(buf_sv) && sv_len(buf_sv)))
	? sv_newmortal() : buf_sv;
    SvUPGRADE(upstream, SVt_PV);
	
    if (filter_has_file) {
	status = FILTER_READ(idx+1, upstream, 0);
    }

    if (filter_sub && status >= 0) {
	dSP;
	SV* out;

	ENTER_named("call_filter");
	SAVE_DEFSV;
	SAVETMPS;
	EXTEND(SP, 2);

	DEFSV_set(upstream);
	PUSHMARK(SP);
	mPUSHi(0);
	if (filter_state) {
	    PUSHs(filter_state);
	}
	PUTBACK;
	out = call_sv(filter_sub, G_SCALAR);
	SPAGAIN;

	if (SvOK(out)) {
	    status = SvIV(out);
	}

	PUTBACK;
	FREETMPS;
	LEAVE_named("call_filter");
    }

    if(SvOK(upstream)) {
	got_p = SvPV(upstream, got_len);
	if (umaxlen) {
	    if (got_len > umaxlen) {
		prune_from = got_p + umaxlen;
	    }
	} else {
	    const char *const first_nl =
		(const char *)memchr(got_p, '\n', got_len);
	    if (first_nl && first_nl + 1 < got_p + got_len) {
		/* There's a second line here... */
		prune_from = first_nl + 1;
	    }
	}
    }
    return status;
}

/* perhaps someone can come up with a better name for
   this?  it is not really "absolute", per se ... */
static bool
S_path_is_absolute(const char *name)
{
    PERL_ARGS_ASSERT_PATH_IS_ABSOLUTE;

    if (PERL_FILE_IS_ABSOLUTE(name)
#ifdef WIN32
	|| (*name == '.' && ((name[1] == '/' ||
			     (name[1] == '.' && name[2] == '/'))
			 || (name[1] == '\\' ||
			     ( name[1] == '.' && name[2] == '\\')))
	    )
#else
	|| (*name == '.' && (name[1] == '/' ||
			     (name[1] == '.' && name[2] == '/')))
#endif
	 )
    {
	return TRUE;
    }
    else
    	return FALSE;
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
