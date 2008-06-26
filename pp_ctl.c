/*    pp_ctl.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * Now far ahead the Road has gone,
 * And I must follow, if I can,
 * Pursuing it with eager feet,
 * Until it joins some larger way
 * Where many paths and errands meet.
 * And whither then?  I cannot say.
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

PP(pp_wantarray)
{
    dVAR;
    dSP;
    I32 cxix;
    EXTEND(SP, 1);

    cxix = dopoptosub(cxstack_ix);
    if (cxix < 0)
	RETPUSHUNDEF;

    switch (cxstack[cxix].blk_gimme) {
    case G_ARRAY:
	RETPUSHYES;
    case G_SCALAR:
	RETPUSHNO;
    default:
	RETPUSHUNDEF;
    }
}

PP(pp_regcreset)
{
    dVAR;
    /* XXXX Should store the old value to allow for tie/overload - and
       restore in regcomp, where marked with XXXX. */
    PL_reginterp_cnt = 0;
    TAINT_NOT;
    return NORMAL;
}

PP(pp_regcomp)
{
    dVAR;
    dSP;
    register PMOP *pm = (PMOP*)cLOGOP->op_other;
    SV *tmpstr;
    REGEXP *re = NULL;

    /* prevent recompiling under /o and ithreads. */
#if defined(USE_ITHREADS)
    if (pm->op_pmflags & PMf_KEEP && PM_GETRE(pm)) {
	if (PL_op->op_flags & OPf_STACKED) {
	    dMARK;
	    SP = MARK;
	}
	else
	    (void)POPs;
	RETURN;
    }
#endif
    if (PL_op->op_flags & OPf_STACKED) {
	/* multiple args; concatentate them */
	dMARK; dORIGMARK;
	tmpstr = PAD_SV(ARGTARG);
	sv_setpvn(tmpstr, "", 0);
	while (++MARK <= SP) {
	    if (PL_amagic_generation) {
		SV *sv;
		if ((SvAMAGIC(tmpstr) || SvAMAGIC(*MARK)) &&
		    (sv = amagic_call(tmpstr, *MARK, concat_amg, AMGf_assign)))
		{
		   sv_setsv(tmpstr, sv);
		   continue;
		}
	    }
	    sv_catsv(tmpstr, *MARK);
	}
    	SvSETMAGIC(tmpstr);
	SP = ORIGMARK;
    }
    else
	tmpstr = POPs;

    if (SvROK(tmpstr)) {
	SV * const sv = SvRV(tmpstr);
	if (SvTYPE(sv) == SVt_REGEXP)
	    re = (REGEXP*) sv;
    }
    if (re) {
	re = reg_temp_copy(re);
	ReREFCNT_dec(PM_GETRE(pm));
	PM_SETRE(pm, re);
    }
    else {
	STRLEN len;
	const char *t = SvOK(tmpstr) ? SvPV_const(tmpstr, len) : "";
	re = PM_GETRE(pm);
	assert (re != (REGEXP*) &PL_sv_undef);

	/* Check against the last compiled regexp. */
	if (!re || !RX_PRECOMP(re) || RX_PRELEN(re) != len ||
	    memNE(RX_PRECOMP(re), t, len))
	{
	    const regexp_engine *eng = re ? RX_ENGINE(re) : NULL;
            U32 pm_flags = pm->op_pmflags & PMf_COMPILETIME;
	    if (re) {
	        ReREFCNT_dec(re);
#ifdef USE_ITHREADS
		PM_SETRE(pm, (REGEXP*) &PL_sv_undef);
#else
		PM_SETRE(pm, NULL);	/* crucial if regcomp aborts */
#endif
	    } else if (PL_curcop->cop_hints_hash) {
	        SV **ptr = hv_fetch(PL_curcop->cop_hints_hash, "regcomp", 7, 0);
                if (ptr && *ptr && SvIOK(*ptr) && SvIV(*ptr))
                    eng = INT2PTR(regexp_engine*,SvIV(*ptr));
	    }

	    if (PL_op->op_flags & OPf_SPECIAL)
		PL_reginterp_cnt = I32_MAX; /* Mark as safe.  */

	    if (eng) 
	        PM_SETRE(pm, CALLREGCOMP_ENG(eng, tmpstr, pm_flags));
            else
                PM_SETRE(pm, CALLREGCOMP(tmpstr, pm_flags));

	    PL_reginterp_cnt = 0;	/* XXXX Be extra paranoid - needed
					   inside tie/overload accessors.  */
	}
    }
    
    re = PM_GETRE(pm);

#ifndef INCOMPLETE_TAINTS
    if (PL_tainting) {
	if (PL_tainted)
	    RX_EXTFLAGS(re) |= RXf_TAINTED;
	else
	    RX_EXTFLAGS(re) &= ~RXf_TAINTED;
    }
#endif

    if (!RX_PRELEN(PM_GETRE(pm)) && PL_curpm)
	pm = PL_curpm;


#if !defined(USE_ITHREADS)
    /* can't change the optree at runtime either */
    /* PMf_KEEP is handled differently under threads to avoid these problems */
    if (pm->op_pmflags & PMf_KEEP) {
	pm->op_private &= ~OPpRUNTIME;	/* no point compiling again */
	cLOGOP->op_first->op_next = PL_op->op_next;
    }
#endif
    RETURN;
}

PP(pp_substcont)
{
    dVAR;
    dSP;
    register PERL_CONTEXT *cx = &cxstack[cxstack_ix];
    register PMOP * const pm = (PMOP*) cLOGOP->op_other;
    register SV * const dstr = cx->sb_dstr;
    register char *s = cx->sb_s;
    register char *m = cx->sb_m;
    char *orig = cx->sb_orig;
    register REGEXP * const rx = cx->sb_rx;
    REGEXP *old = PM_GETRE(pm);
    if(old != rx) {
	if(old)
	    ReREFCNT_dec(old);
	PM_SETRE(pm,ReREFCNT_inc(rx));
    }

    rxres_restore(&cx->sb_rxres, rx);

    if (cx->sb_iters++) {
	const I32 saviters = cx->sb_iters;
	if (cx->sb_iters > cx->sb_maxiters)
	    DIE(aTHX_ "Substitution loop");

	if (!(cx->sb_rxtainted & 2) && SvTAINTED(TOPs))
	    cx->sb_rxtainted |= 2;
	sv_catsv(dstr, POPs);

	/* Are we done */
	if (CxONCE(cx) || !CALLREGEXEC(rx, s, cx->sb_strend, orig,
				     s == m, cx->sb_targ, NULL,
				     ((cx->sb_rflags & REXEC_COPY_STR)
				      ? (REXEC_IGNOREPOS|REXEC_NOT_FIRST)
				      : (REXEC_COPY_STR|REXEC_IGNOREPOS|REXEC_NOT_FIRST))))
	{
	    SV * const targ = cx->sb_targ;

	    assert(cx->sb_strend >= s);
	    if(cx->sb_strend > s) {
		sv_catpvn(dstr, s, cx->sb_strend - s);
	    }
	    cx->sb_rxtainted |= RX_MATCH_TAINTED(rx);

#ifdef PERL_OLD_COPY_ON_WRITE
	    if (SvIsCOW(targ)) {
		sv_force_normal_flags(targ, SV_COW_DROP_PV);
	    } else
#endif
	    {
		SvPV_free(targ);
	    }
	    SvPV_set(targ, SvPVX(dstr));
	    SvCUR_set(targ, SvCUR(dstr));
	    SvLEN_set(targ, SvLEN(dstr));
	    SvPV_set(dstr, NULL);

	    TAINT_IF(cx->sb_rxtainted & 1);
	    mPUSHi(saviters - 1);

	    (void)SvPOK_only(targ);
	    TAINT_IF(cx->sb_rxtainted);
	    SvSETMAGIC(targ);
	    SvTAINT(targ);

	    LEAVE_SCOPE(cx->sb_oldsave);
	    POPSUBST(cx);
	    RETURNOP(pm->op_next);
	}
	cx->sb_iters = saviters;
    }
    if (RX_MATCH_COPIED(rx) && RX_SUBBEG(rx) != orig) {
	m = s;
	s = orig;
	cx->sb_orig = orig = RX_SUBBEG(rx);
	s = orig + (m - s);
	cx->sb_strend = s + (cx->sb_strend - m);
    }
    cx->sb_m = m = RX_OFFS(rx)[0].start + orig;
    if (m > s) {
	sv_catpvn(dstr, s, m-s);
    }
    cx->sb_s = RX_OFFS(rx)[0].end + orig;
    { /* Update the pos() information. */
	SV * const sv = cx->sb_targ;
	MAGIC *mg;
	I32 i;
	SvUPGRADE(sv, SVt_PVMG);
	if (!(mg = mg_find(sv, PERL_MAGIC_regex_global))) {
#ifdef PERL_OLD_COPY_ON_WRITE
	    if (SvIsCOW(sv))
		sv_force_normal_flags(sv, 0);
#endif
	    mg = sv_magicext(sv, NULL, PERL_MAGIC_regex_global, &PL_vtbl_mglob,
			     NULL, 0);
	}
	i = m - orig;
	mg->mg_len = i;
    }
    if (old != rx)
	(void)ReREFCNT_inc(rx);
    cx->sb_rxtainted |= RX_MATCH_TAINTED(rx);
    rxres_save(&cx->sb_rxres, rx);
    RETURNOP(pm->op_pmstashstartu.op_pmreplstart);
}

void
Perl_rxres_save(pTHX_ void **rsp, REGEXP *rx)
{
    UV *p = (UV*)*rsp;
    U32 i;

    PERL_ARGS_ASSERT_RXRES_SAVE;
    PERL_UNUSED_CONTEXT;

    if (!p || p[1] < RX_NPARENS(rx)) {
#ifdef PERL_OLD_COPY_ON_WRITE
	i = 7 + RX_NPARENS(rx) * 2;
#else
	i = 6 + RX_NPARENS(rx) * 2;
#endif
	if (!p)
	    Newx(p, i, UV);
	else
	    Renew(p, i, UV);
	*rsp = (void*)p;
    }

    *p++ = PTR2UV(RX_MATCH_COPIED(rx) ? RX_SUBBEG(rx) : NULL);
    RX_MATCH_COPIED_off(rx);

#ifdef PERL_OLD_COPY_ON_WRITE
    *p++ = PTR2UV(RX_SAVED_COPY(rx));
    RX_SAVED_COPY(rx) = NULL;
#endif

    *p++ = RX_NPARENS(rx);

    *p++ = PTR2UV(RX_SUBBEG(rx));
    *p++ = (UV)RX_SUBLEN(rx);
    for (i = 0; i <= RX_NPARENS(rx); ++i) {
	*p++ = (UV)RX_OFFS(rx)[i].start;
	*p++ = (UV)RX_OFFS(rx)[i].end;
    }
}

void
Perl_rxres_restore(pTHX_ void **rsp, REGEXP *rx)
{
    UV *p = (UV*)*rsp;
    U32 i;

    PERL_ARGS_ASSERT_RXRES_RESTORE;
    PERL_UNUSED_CONTEXT;

    RX_MATCH_COPY_FREE(rx);
    RX_MATCH_COPIED_set(rx, *p);
    *p++ = 0;

#ifdef PERL_OLD_COPY_ON_WRITE
    if (RX_SAVED_COPY(rx))
	SvREFCNT_dec (RX_SAVED_COPY(rx));
    RX_SAVED_COPY(rx) = INT2PTR(SV*,*p);
    *p++ = 0;
#endif

    RX_NPARENS(rx) = *p++;

    RX_SUBBEG(rx) = INT2PTR(char*,*p++);
    RX_SUBLEN(rx) = (I32)(*p++);
    for (i = 0; i <= RX_NPARENS(rx); ++i) {
	RX_OFFS(rx)[i].start = (I32)(*p++);
	RX_OFFS(rx)[i].end = (I32)(*p++);
    }
}

void
Perl_rxres_free(pTHX_ void **rsp)
{
    UV * const p = (UV*)*rsp;

    PERL_ARGS_ASSERT_RXRES_FREE;
    PERL_UNUSED_CONTEXT;

    if (p) {
#ifdef PERL_POISON
	void *tmp = INT2PTR(char*,*p);
	Safefree(tmp);
	if (*p)
	    PoisonFree(*p, 1, sizeof(*p));
#else
	Safefree(INT2PTR(char*,*p));
#endif
#ifdef PERL_OLD_COPY_ON_WRITE
	if (p[1]) {
	    SvREFCNT_dec (INT2PTR(SV*,p[1]));
	}
#endif
	Safefree(p);
	*rsp = NULL;
    }
}

PP(pp_grepstart)
{
    dVAR; dSP;
    SV *src;

    if (PL_stack_base + *PL_markstack_ptr == SP) {
	(void)POPMARK;
	if (GIMME_V == G_SCALAR)
	    mXPUSHi(0);
	RETURNOP(PL_op->op_next->op_next);
    }
    PL_stack_sp = PL_stack_base + *PL_markstack_ptr + 1;
    pp_pushmark();				/* push dst */
    pp_pushmark();				/* push src */
    ENTER;					/* enter outer scope */

    SAVETMPS;
    if (PL_op->op_private & OPpGREP_LEX)
	SAVESPTR(PAD_SVl(PL_op->op_targ));
    else
	SAVE_DEFSV;
    ENTER;					/* enter inner scope */
    SAVEVPTR(PL_curpm);

    src = PL_stack_base[*PL_markstack_ptr];
    SvTEMP_off(src);
    if (PL_op->op_private & OPpGREP_LEX)
	SVcpREPLACE(PAD_SVl(PL_op->op_targ), src)
    else
	SVcpREPLACE(DEFSV, src);

    PUTBACK;
    if (PL_op->op_type == OP_MAPSTART)
	pp_pushmark();			/* push top */
    return ((LOGOP*)PL_op->op_next)->op_other;
}

PP(pp_mapwhile)
{
    dVAR; dSP;
    const I32 gimme = GIMME_V;
    I32 items = (SP - PL_stack_base) - *PL_markstack_ptr; /* how many new items */
    I32 count;
    I32 shift;
    SV** src;
    SV** dst;

    /* first, move source pointer to the next item in the source list */
    ++PL_markstack_ptr[-1];

    /* if there are new items, push them into the destination list */
    if (items && gimme != G_VOID) {
	/* might need to make room back there first */
	if (items > PL_markstack_ptr[-1] - PL_markstack_ptr[-2]) {
	    /* XXX this implementation is very pessimal because the stack
	     * is repeatedly extended for every set of items.  Is possible
	     * to do this without any stack extension or copying at all
	     * by maintaining a separate list over which the map iterates
	     * (like foreach does). --gsar */

	    /* everything in the stack after the destination list moves
	     * towards the end the stack by the amount of room needed */
	    shift = items - (PL_markstack_ptr[-1] - PL_markstack_ptr[-2]);

	    /* items to shift up (accounting for the moved source pointer) */
	    count = (SP - PL_stack_base) - (PL_markstack_ptr[-1] - 1);

	    /* This optimization is by Ben Tilly and it does
	     * things differently from what Sarathy (gsar)
	     * is describing.  The downside of this optimization is
	     * that leaves "holes" (uninitialized and hopefully unused areas)
	     * to the Perl stack, but on the other hand this
	     * shouldn't be a problem.  If Sarathy's idea gets
	     * implemented, this optimization should become
	     * irrelevant.  --jhi */
            if (shift < count)
                shift = count; /* Avoid shifting too often --Ben Tilly */

	    EXTEND(SP,shift);
	    src = SP;
	    dst = (SP += shift);
	    PL_markstack_ptr[-1] += shift;
	    *PL_markstack_ptr += shift;
	    while (count--)
		*dst-- = *src--;
	}
	/* copy the new items down to the destination list */
	dst = PL_stack_base + (PL_markstack_ptr[-2] += items) - 1;
	if (gimme == G_ARRAY) {
	    while (items-- > 0)
		*dst-- = SvTEMP(TOPs) ? POPs : sv_mortalcopy(POPs);
	}
	else {
	    /* scalar context: we don't care about which values map returns
	     * (we use undef here). And so we certainly don't want to do mortal
	     * copies of meaningless values. */
	    while (items-- > 0) {
		(void)POPs;
		*dst-- = &PL_sv_undef;
	    }
	}
    }
    LEAVE;					/* exit inner scope */

    /* All done yet? */
    if (PL_markstack_ptr[-1] > *PL_markstack_ptr) {

	(void)POPMARK;				/* pop top */
	LEAVE;					/* exit outer scope */
	(void)POPMARK;				/* pop src */
	items = --*PL_markstack_ptr - PL_markstack_ptr[-1];
	(void)POPMARK;				/* pop dst */
	SP = PL_stack_base + POPMARK;		/* pop original mark */
	if (gimme == G_SCALAR) {
	    if (PL_op->op_private & OPpGREP_LEX) {
		SV* sv = sv_newmortal();
		sv_setiv(sv, items);
		PUSHs(sv);
	    }
	    else {
		dTARGET;
		XPUSHi(items);
	    }
	}
	else if (gimme == G_ARRAY)
	    SP += items;
	RETURN;
    }
    else {
	SV *src;

	ENTER;					/* enter inner scope */
	SAVEVPTR(PL_curpm);

	/* set $_ to the new source item */
	src = PL_stack_base[PL_markstack_ptr[-1]];
	SvTEMP_off(src);
	if (PL_op->op_private & OPpGREP_LEX)
	    SVcpREPLACE(PAD_SVl(PL_op->op_targ), src)
	else
	    SVcpREPLACE(DEFSV, src);

	RETURNOP(cLOGOP->op_other);
    }
}

/* Range stuff. */

PP(pp_range)
{
    dVAR;
    if (GIMME == G_ARRAY)
	return NORMAL;
    DIE(aTHX_ "range operator .. can only be used in list context.");
}

PP(pp_flip)
{
    dVAR;
    dSP;

    assert(GIMME == G_ARRAY);
    RETURNOP(((LOGOP*)cUNOP->op_first)->op_other);
}

/* This code tries to decide if "$left .. $right" should use the
   magical string increment, or if the range is numeric (we make
   an exception for .."0" [#18165]). AMS 20021031. */

#define RANGE_IS_NUMERIC(left,right) ( \
	SvNIOKp(left)  || (SvOK(left)  && !SvPOKp(left))  || \
	SvNIOKp(right) || (SvOK(right) && !SvPOKp(right)) || \
	(((!SvOK(left) && SvOK(right)) || ((!SvOK(left) || \
          looks_like_number(left)) && SvPOKp(left) && *SvPVX_const(left) != '0')) \
         && (!SvOK(right) || looks_like_number(right))))

PP(pp_flop)
{
    dVAR; dSP;

    dPOPPOPssrl;
    assert(GIMME == G_ARRAY);

    SvGETMAGIC(left);
    SvGETMAGIC(right);

    if (RANGE_IS_NUMERIC(left,right)) {
	register IV i, j;
	IV max;
	if ((SvOK(left) && SvNV(left) < IV_MIN) ||
	    (SvOK(right) && SvNV(right) > IV_MAX))
	    DIE(aTHX_ "Range iterator outside integer range");
	i = SvIV(left);
	max = SvIV(right);
	if (max >= i) {
	    j = max - i + 1;
	    EXTEND_MORTAL(j);
	    EXTEND(SP, j);
	}
	else
	    j = 0;
	while (j--) {
	    SV * const sv = sv_2mortal(newSViv(i++));
	    PUSHs(sv);
	}
    }
    else {
	SV * const final = sv_mortalcopy(right);
	STRLEN len;
	const char * const tmps = SvPV_const(final, len);

	SV *sv = sv_mortalcopy(left);
	SvPV_force_nolen(sv);
	while (!SvNIOKp(sv) && SvCUR(sv) <= len) {
	    XPUSHs(sv);
	    if (strEQ(SvPVX_const(sv),tmps))
		break;
	    sv = sv_2mortal(newSVsv(sv));
	    sv_inc(sv);
	}
    }

    RETURN;
}

/* Control. */

static const char * const context_name[] = {
    "pseudo-block",
    "when",
    NULL, /* CXt_BLOCK never actually needs "block" */
    "given",
    NULL, /* CXt_LOOP_FOR never actually needs "loop" */
    NULL, /* CXt_LOOP_PLAIN never actually needs "loop" */
    NULL, /* CXt_LOOP_LAZYSV never actually needs "loop" */
    NULL, /* CXt_LOOP_LAZYIV never actually needs "loop" */
    "subroutine",
    "eval",
    "substitution",
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
	case CXt_EVAL:
	case CXt_NULL:
	case CXt_GIVEN:
	case CXt_WHEN:
	    if (ckWARN(WARN_EXITING))
		Perl_warner(aTHX_ packWARN(WARN_EXITING), "Exiting %s via %s",
			context_name[CxTYPE(cx)], OP_NAME(PL_op));
	    if (CxTYPE(cx) == CXt_NULL)
		return -1;
	    break;
	case CXt_LOOP_LAZYIV:
	case CXt_LOOP_LAZYSV:
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
	case CXt_SUB:
	    DEBUG_l( Perl_deb(aTHX_ "(Found sub #%ld)\n", (long)i));
	    return i;
	}
    }
    return i;
}

STATIC I32
S_dopoptoeval(pTHX_ I32 startingblock)
{
    dVAR;
    I32 i;
    for (i = startingblock; i >= 0; i--) {
	register const PERL_CONTEXT *cx = &cxstack[i];
	switch (CxTYPE(cx)) {
	default:
	    continue;
	case CXt_EVAL:
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
	case CXt_EVAL:
	case CXt_NULL:
	    if (ckWARN(WARN_EXITING))
		Perl_warner(aTHX_ packWARN(WARN_EXITING), "Exiting %s via %s",
			context_name[CxTYPE(cx)], OP_NAME(PL_op));
	    if ((CxTYPE(cx)) == CXt_NULL)
		return -1;
	    break;
	case CXt_LOOP_LAZYIV:
	case CXt_LOOP_LAZYSV:
	case CXt_LOOP_FOR:
	case CXt_LOOP_PLAIN:
	    DEBUG_l( Perl_deb(aTHX_ "(Found loop #%ld)\n", (long)i));
	    return i;
	}
    }
    return i;
}

STATIC I32
S_dopoptogiven(pTHX_ I32 startingblock)
{
    dVAR;
    I32 i;
    for (i = startingblock; i >= 0; i--) {
	register const PERL_CONTEXT *cx = &cxstack[i];
	switch (CxTYPE(cx)) {
	default:
	    continue;
	case CXt_GIVEN:
	    DEBUG_l( Perl_deb(aTHX_ "(Found given #%ld)\n", (long)i));
	    return i;
	case CXt_LOOP_PLAIN:
	    assert(!CxFOREACHDEF(cx));
	    break;
	case CXt_LOOP_LAZYIV:
	case CXt_LOOP_LAZYSV:
	case CXt_LOOP_FOR:
	    if (CxFOREACHDEF(cx)) {
		DEBUG_l( Perl_deb(aTHX_ "(Found foreach #%ld)\n", (long)i));
		return i;
	    }
	}
    }
    return i;
}

STATIC I32
S_dopoptowhen(pTHX_ I32 startingblock)
{
    dVAR;
    I32 i;
    for (i = startingblock; i >= 0; i--) {
	register const PERL_CONTEXT *cx = &cxstack[i];
	switch (CxTYPE(cx)) {
	default:
	    continue;
	case CXt_WHEN:
	    DEBUG_l( Perl_deb(aTHX_ "(Found when #%ld)\n", (long)i));
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
        register PERL_CONTEXT *cx = &cxstack[cxstack_ix];
	DEBUG_l(PerlIO_printf(Perl_debug_log, "Unwinding block %ld, type %s\n",
			      (long) cxstack_ix, PL_block_type[CxTYPE(cx)]));
	/* Note: we don't need to restore the base context info till the end. */
	switch (CxTYPE(cx)) {
	case CXt_SUBST:
	    POPSUBST(cx);
	    continue;  /* not break */
	case CXt_SUB:
	    POPSUB(cx,sv);
	    LEAVESUB(sv);
	    break;
	case CXt_EVAL:
	    POPEVAL(cx);
	    break;
	case CXt_LOOP_LAZYIV:
	case CXt_LOOP_LAZYSV:
	case CXt_LOOP_FOR:
	case CXt_LOOP_PLAIN:
	    POPLOOP(cx);
	    break;
	case CXt_NULL:
	    break;
	}
	cxstack_ix--;
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
	SvREFCNT_dec(ERRSV);
	ERRSV = SvREFCNT_inc(msv);
    }

    if (PL_in_eval) {
	I32 cxix;
	I32 gimme;

	while ((cxix = dopoptoeval(cxstack_ix)) < 0
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
	    if (CxTYPE(cx) != CXt_EVAL) {
		PerlIO_write(Perl_error_log, (const char *)"panic: die ", 11);
		PerlIO_write(Perl_error_log, message, msglen);
		my_exit(1);
	    }
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
                (void)hv_store(GvHVn(PL_incgv), SvPVX_const(nsv), SvCUR(nsv),
                               &PL_sv_undef, 0);
		die_where(ERRSV);
	    }
	    assert(CxTYPE(cx) == CXt_EVAL);

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
    mPUSHs(newSVpv(OutCopFILE(cx->blk_oldcop), 0));
    mPUSHi((I32)CopLINE(cx->blk_oldcop));
    if (!MAXARG)
	RETURN;
    if (CxTYPE(cx) == CXt_SUB) {
	GV * const cvgv = CvGV(ccstack[cxix].blk_sub.cv);
	/* So is ccstack[dbcxix]. */
	if (isGV(cvgv)) {
	    SV * const sv = newSV(0);
	    gv_efullname3(sv, cvgv, NULL);
	    mPUSHs(sv);
	    PUSHs(boolSV(CxHASARGS(cx)));
	}
	else {
	    PUSHs(newSVpvs_flags("(unknown)", SVs_TEMP));
	    PUSHs(boolSV(CxHASARGS(cx)));
	}
    }
    else {
	PUSHs(newSVpvs_flags("(eval)", SVs_TEMP));
	mPUSHi(0);
    }
    gimme = (I32)cx->blk_gimme;
    if (gimme == G_VOID)
	PUSHs(&PL_sv_undef);
    else
	PUSHs(boolSV((gimme & G_WANT) == G_ARRAY));
    if (CxTYPE(cx) == CXt_EVAL) {
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
    if (CxTYPE(cx) == CXt_SUB && CxHASARGS(cx)
	&& CopSTASH_eq(PL_curcop, PL_debstash))
    {
	AV * const ary = cx->blk_sub.argarray;
	const int off = AvARRAY(ary) - AvALLOC(ary);

	if (!PL_dbargs) {
	    GV* const tmpgv = gv_fetchpvs("DB::args", GV_ADD, SVt_PVAV);
	    PL_dbargs = GvAV(gv_AVadd(tmpgv));
	    GvMULTI_on(tmpgv);
	    AvREAL_off(PL_dbargs);	/* XXX should be REIFY (see av.h) */
	}

	if (AvMAX(PL_dbargs) < AvFILLp(ary) + off)
	    av_extend(PL_dbargs, AvFILLp(ary) + off);
	Copy(AvALLOC(ary), AvARRAY(PL_dbargs), AvFILLp(ary) + 1 + off, SV*);
	AvFILLp(PL_dbargs) = AvFILLp(ary) + off;
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
    TAINT_NOT;		/* Each statement is presumed innocent */
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
	    PAD_SET_CUR_NOSAVE(CvPADLIST(cv), 1);
	    RETURNOP(CvSTART(cv));
	}
    }
    else
	return NORMAL;
}

PP(pp_enteriter)
{
    dVAR; dSP; dMARK;
    register PERL_CONTEXT *cx;
    const I32 gimme = GIMME_V;
    SV **svp;
    U8 cxtype = CXt_LOOP_FOR;
#ifdef USE_ITHREADS
    PAD *iterdata;
#endif

    ENTER;
    SAVETMPS;

    if (PL_op->op_targ) {
	if (PL_op->op_private & OPpLVAL_INTRO) { /* for my $x (...) */
	    SvPADSTALE_off(PAD_SVl(PL_op->op_targ));
	    SAVESETSVFLAGS(PAD_SVl(PL_op->op_targ),
		    SVs_PADSTALE, SVs_PADSTALE);
	}
	SAVEPADSVANDMORTALIZE(PL_op->op_targ);
#ifndef USE_ITHREADS
	svp = &PAD_SVl(PL_op->op_targ);		/* "my" variable */
#else
	iterdata = NULL;
#endif
    }
    else {
	GV * const gv = (GV*)POPs;
	svp = &GvSV(gv);			/* symbol table variable */
	SAVEGENERICSV(*svp);
	*svp = newSV(0);
#ifdef USE_ITHREADS
	iterdata = (PAD*)gv;
#endif
    }

    if (PL_op->op_private & OPpITER_DEF)
	cxtype |= CXp_FOR_DEF;

    ENTER;

    PUSHBLOCK(cx, cxtype, SP);
#ifdef USE_ITHREADS
    PUSHLOOP_FOR(cx, iterdata, MARK, PL_op->op_targ);
#else
    PUSHLOOP_FOR(cx, svp, MARK, 0);
#endif
    if (PL_op->op_flags & OPf_STACKED) {
	SV *maybe_ary = POPs;
	if (SvTYPE(maybe_ary) != SVt_PVAV) {
	    dPOPss;
	    SV * const right = maybe_ary;
	    SvGETMAGIC(sv);
	    SvGETMAGIC(right);
	    if (RANGE_IS_NUMERIC(sv,right)) {
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
	    else {
		cx->cx_type &= ~CXTYPEMASK;
		cx->cx_type |= CXt_LOOP_LAZYSV;
		/* Make sure that no-one re-orders cop.h and breaks our
		   assumptions */
		assert(CxTYPE(cx) == CXt_LOOP_LAZYSV);
		cx->blk_loop.state_u.lazysv.cur = newSVsv(sv);
		cx->blk_loop.state_u.lazysv.end = right;
		SvREFCNT_inc(right);
		(void) SvPV_force_nolen(cx->blk_loop.state_u.lazysv.cur);
		/* This will do the upgrade to SVt_PV, and warn if the value
		   is uninitialised.  */
		(void) SvPV_nolen_const(right);
		/* Doing this avoids a check every time in pp_iter in pp_hot.c
		   to replace !SvOK() with a pointer to "".  */
		if (!SvOK(right)) {
		    SvREFCNT_dec(right);
		    cx->blk_loop.state_u.lazysv.end = &PL_sv_no;
		}
	    }
	}
	else /* SvTYPE(maybe_ary) == SVt_PVAV */ {
	    cx->blk_loop.state_u.ary.ary = (AV*)maybe_ary;
	    SvREFCNT_inc(maybe_ary);
	    cx->blk_loop.state_u.ary.ix =
		(PL_op->op_private & OPpITER_REVERSED) ?
		AvFILL(cx->blk_loop.state_u.ary.ary) + 1 :
		-1;
	}
    }
    else { /* iterating over items on the stack */
	cx->blk_loop.state_u.ary.ary = NULL; /* means to use the stack */
	if (PL_op->op_private & OPpITER_REVERSED) {
	    cx->blk_loop.state_u.ary.ix = cx->blk_oldsp + 1;
	}
	else {
	    cx->blk_loop.state_u.ary.ix = MARK - PL_stack_base;
	}
    }

    RETURN;
}

PP(pp_enterloop)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    const I32 gimme = GIMME_V;

    ENTER;
    SAVETMPS;
    ENTER;

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

    TAINT_NOT;
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
	    TAINT_NOT;		/* Each item is independent */
	}
    }
    SP = newsp;
    PUTBACK;

    POPLOOP(cx);	/* Stack values are safe: release loop vars ... */
    PL_curpm = newpm;	/* ... and pop $1 et al */

    LEAVE;
    LEAVE;

    return NORMAL;
}

PP(pp_return)
{
    dVAR; dSP; dMARK;
    register PERL_CONTEXT *cx;
    bool popsub2 = FALSE;
    bool clear_errsv = FALSE;
    I32 gimme;
    SV **newsp;
    PMOP *newpm;
    I32 optype = 0;
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
    switch (CxTYPE(cx)) {
    case CXt_SUB:
	popsub2 = TRUE;
	retop = cx->blk_sub.retop;
	cxstack_ix++; /* preserve cx entry on stack for use by POPSUB */
	break;
    case CXt_EVAL:
	if (!(PL_in_eval & EVAL_KEEPERR))
	    clear_errsv = TRUE;
	POPEVAL(cx);
	retop = cx->blk_eval.retop;
	if (CxTRYBLOCK(cx))
	    break;
	lex_end();
	break;
    default:
	DIE(aTHX_ "panic: return");
    }

    TAINT_NOT;
    if (gimme == G_SCALAR) {
	if (MARK < SP) {
	    if (popsub2) {
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
	else
	    *++newsp = &PL_sv_undef;
    }
    else if (gimme == G_ARRAY) {
	while (++MARK <= SP) {
	    *++newsp = (popsub2 && SvTEMP(*MARK))
			? *MARK : sv_mortalcopy(*MARK);
	    TAINT_NOT;		/* Each item is independent */
	}
    }
    PL_stack_sp = newsp;

    LEAVE;
    /* Stack values are safe: */
    if (popsub2) {
	cxstack_ix--;
	POPSUB(cx,sv);	/* release CV and @_ ... */
    }
    else
	sv = NULL;
    PL_curpm = newpm;	/* ... and pop $1 et al */

    LEAVESUB(sv);
    if (clear_errsv)
	sv_setsv(ERRSV, &PL_sv_undef);
    return retop;
}

PP(pp_last)
{
    dVAR; dSP;
    I32 cxix;
    register PERL_CONTEXT *cx;
    I32 pop2 = 0;
    I32 gimme;
    I32 optype;
    OP *nextop;
    SV **newsp;
    PMOP *newpm;
    SV **mark;
    SV *sv = NULL;


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
    switch (CxTYPE(cx)) {
    case CXt_LOOP_LAZYIV:
    case CXt_LOOP_LAZYSV:
    case CXt_LOOP_FOR:
    case CXt_LOOP_PLAIN:
	pop2 = CxTYPE(cx);
	newsp = PL_stack_base + cx->blk_loop.resetsp;
	nextop = cx->blk_loop.my_op->op_lastop->op_next;
	break;
    case CXt_SUB:
	pop2 = CXt_SUB;
	nextop = cx->blk_sub.retop;
	break;
    case CXt_EVAL:
	POPEVAL(cx);
	nextop = cx->blk_eval.retop;
	break;
    default:
	DIE(aTHX_ "panic: last");
    }

    TAINT_NOT;
    if (gimme == G_SCALAR) {
	if (MARK < SP)
	    *++newsp = ((pop2 == CXt_SUB) && SvTEMP(*SP))
			? *SP : sv_mortalcopy(*SP);
	else
	    *++newsp = &PL_sv_undef;
    }
    else if (gimme == G_ARRAY) {
	while (++MARK <= SP) {
	    *++newsp = ((pop2 == CXt_SUB) && SvTEMP(*MARK))
			? *MARK : sv_mortalcopy(*MARK);
	    TAINT_NOT;		/* Each item is independent */
	}
    }
    SP = newsp;
    PUTBACK;

    LEAVE;
    cxstack_ix--;
    /* Stack values are safe: */
    switch (pop2) {
    case CXt_LOOP_LAZYIV:
    case CXt_LOOP_PLAIN:
    case CXt_LOOP_LAZYSV:
    case CXt_LOOP_FOR:
	POPLOOP(cx);	/* release loop vars ... */
	LEAVE;
	break;
    case CXt_SUB:
	POPSUB(cx,sv);	/* release CV and @_ ... */
	break;
    }
    PL_curpm = newpm;	/* ... and pop $1 et al */

    LEAVESUB(sv);
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
	cxstack_ix++;
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

STATIC OP *
S_dofindlabel(pTHX_ OP *o, const char *label, OP **opstack, OP **oplimit)
{
    dVAR;
    OP **ops = opstack;
    static const char too_deep[] = "Target of goto is too deeply nested";

    PERL_ARGS_ASSERT_DOFINDLABEL;

    if (ops >= oplimit)
	Perl_croak(aTHX_ too_deep);
    if (o->op_type == OP_LEAVE ||
	o->op_type == OP_SCOPE ||
	o->op_type == OP_LEAVELOOP ||
	o->op_type == OP_LEAVESUB ||
	o->op_type == OP_LEAVETRY)
    {
	*ops++ = cUNOPo->op_first;
	if (ops >= oplimit)
	    Perl_croak(aTHX_ too_deep);
    }
    *ops = 0;
    if (o->op_flags & OPf_KIDS) {
	OP *kid;
	/* First try all the kids at this level, since that's likeliest. */
	for (kid = cUNOPo->op_first; kid; kid = kid->op_sibling) {
	    if ((kid->op_type == OP_NEXTSTATE || kid->op_type == OP_DBSTATE) &&
		    kCOP->cop_label && strEQ(kCOP->cop_label, label))
		return kid;
	}
	for (kid = cUNOPo->op_first; kid; kid = kid->op_sibling) {
	    if (kid == PL_lastgotoprobe)
		continue;
	    if (kid->op_type == OP_NEXTSTATE || kid->op_type == OP_DBSTATE) {
	        if (ops == opstack)
		    *ops++ = kid;
		else if (ops[-1]->op_type == OP_NEXTSTATE ||
		         ops[-1]->op_type == OP_DBSTATE)
		    ops[-1] = kid;
		else
		    *ops++ = kid;
	    }
	    if ((o = dofindlabel(kid, label, ops, oplimit)))
		return o;
	}
    }
    *ops = 0;
    return 0;
}

PP(pp_goto)
{
    dVAR; dSP;
    OP *retop = NULL;
    I32 ix;
    register PERL_CONTEXT *cx;
#define GOTO_DEPTH 64
    OP *enterops[GOTO_DEPTH];
    const char *label = NULL;
    const bool do_dump = (PL_op->op_type == OP_DUMP);
    static const char must_have_label[] = "goto must have label";

    if (PL_op->op_flags & OPf_STACKED) {
	SV * const sv = POPs;

	/* This egregious kludge implements goto &subroutine */
	if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVCV) {
	    I32 cxix;
	    register PERL_CONTEXT *cx;
	    CV* cv = (CV*)SvRV(sv);
	    SV** mark;
	    I32 items = 0;
	    I32 oldsave;
	    bool reified = 0;

	retry:
	    if (!CvROOT(cv) && !CvXSUB(cv)) {
		const GV * const gv = CvGV(cv);
		if (gv) {
		    SV *tmpstr;
		    /* autoloaded stub? */
		    if (cv != GvCV(gv) && (cv = GvCV(gv)))
			goto retry;
		    tmpstr = sv_newmortal();
		    gv_efullname3(tmpstr, gv, NULL);
		    DIE(aTHX_ "Goto undefined subroutine &%"SVf"", SVfARG(tmpstr));
		}
		DIE(aTHX_ "Goto undefined subroutine");
	    }

	    /* First do some returnish stuff. */
	    SvREFCNT_inc_simple_void(cv); /* avoid premature free during unwind */
	    FREETMPS;
	    cxix = dopoptosub(cxstack_ix);
	    if (cxix < 0)
		DIE(aTHX_ "Can't goto subroutine outside a subroutine");
	    if (cxix < cxstack_ix)
		dounwind(cxix);
	    TOPBLOCK(cx);
	    SPAGAIN;
	    /* ban goto in eval: see <20050521150056.GC20213@iabyn.com> */
	    if (CxTYPE(cx) == CXt_EVAL) {
		if (CxREALEVAL(cx))
		    DIE(aTHX_ "Can't goto subroutine from an eval-string");
		else
		    DIE(aTHX_ "Can't goto subroutine from an eval-block");
	    }
	    else if (CxMULTICALL(cx))
		DIE(aTHX_ "Can't goto subroutine from a sort sub (or similar callback)");
	    if (CxTYPE(cx) == CXt_SUB && CxHASARGS(cx)) {
		/* put @_ back onto stack */
		AV* av = cx->blk_sub.argarray;

		items = AvFILLp(av) + 1;
		EXTEND(SP, items+1); /* @_ could have been extended. */
		Copy(AvARRAY(av), SP + 1, items, SV*);
		SvREFCNT_dec(GvAV(PL_defgv));
		GvAV(PL_defgv) = cx->blk_sub.savearray;
		CLEAR_ARGARRAY(av);
		/* abandon @_ if it got reified */
		if (AvREAL(av)) {
		    reified = 1;
		    SvREFCNT_dec(av);
		    av = newAV();
		    av_extend(av, items-1);
		    AvREIFY_only(av);
		    PAD_SVl(0) = (SV*)(cx->blk_sub.argarray = av);
		}
	    }
	    else if (CvISXSUB(cv)) {	/* put GvAV(defgv) back onto stack */
		AV* const av = GvAV(PL_defgv);
		items = AvFILLp(av) + 1;
		EXTEND(SP, items+1); /* @_ could have been extended. */
		Copy(AvARRAY(av), SP + 1, items, SV*);
	    }
	    mark = SP;
	    SP += items;
	    if (CxTYPE(cx) == CXt_SUB &&
		!(CvDEPTH(cx->blk_sub.cv) = cx->blk_sub.olddepth))
		SvREFCNT_dec(cx->blk_sub.cv);
	    oldsave = PL_scopestack[PL_scopestack_ix - 1];
	    LEAVE_SCOPE(oldsave);

	    /* Now do some callish stuff. */
	    SAVETMPS;
	    SAVEFREESV(cv); /* later, undo the 'avoid premature free' hack */
	    if (CvISXSUB(cv)) {
		OP* const retop = cx->blk_sub.retop;
		SV **newsp;
		I32 gimme;
		if (reified) {
		    I32 index;
		    for (index=0; index<items; index++)
			sv_2mortal(SP[-index]);
		}

		/* XS subs don't have a CxSUB, so pop it */
		POPBLOCK(cx, PL_curpm);
		/* Push a mark for the start of arglist */
		PUSHMARK(mark);
		PUTBACK;
		(void)(*CvXSUB(cv))(aTHX_ cv);
		LEAVE;
		return retop;
	    }
	    else {
		AV* const padlist = CvPADLIST(cv);
		if (CxTYPE(cx) == CXt_EVAL) {
		    PL_in_eval = CxOLD_IN_EVAL(cx);
		    PL_eval_root = cx->blk_eval.old_eval_root;
		    cx->cx_type = CXt_SUB;
		}
		cx->blk_sub.cv = cv;
		cx->blk_sub.olddepth = CvDEPTH(cv);

		CvDEPTH(cv)++;
		if (CvDEPTH(cv) < 2)
		    SvREFCNT_inc_simple_void_NN(cv);
		else {
		    if (CvDEPTH(cv) == PERL_SUB_DEPTH_WARN && ckWARN(WARN_RECURSION))
			sub_crush_depth(cv);
		    pad_push(padlist, CvDEPTH(cv));
		}
		SAVECOMPPAD();
		PAD_SET_CUR_NOSAVE(padlist, CvDEPTH(cv));
		if (CxHASARGS(cx))
		{
		    AV* const av = (AV*)PAD_SVl(0);

		    cx->blk_sub.savearray = GvAV(PL_defgv);
		    GvAV(PL_defgv) = (AV*)SvREFCNT_inc_simple(av);
		    CX_CURPAD_SAVE(cx->blk_sub);
		    cx->blk_sub.argarray = av;

		    if (items >= AvMAX(av) + 1) {
			SV **ary = AvALLOC(av);
			if (AvARRAY(av) != ary) {
			    AvMAX(av) += AvARRAY(av) - AvALLOC(av);
			    AvARRAY(av) = ary;
			}
			if (items >= AvMAX(av) + 1) {
			    AvMAX(av) = items - 1;
			    Renew(ary,items+1,SV*);
			    AvALLOC(av) = ary;
			    AvARRAY(av) = ary;
			}
		    }
		    ++mark;
		    Copy(mark,AvARRAY(av),items,SV*);
		    AvFILLp(av) = items - 1;
		    assert(!AvREAL(av));
		    if (reified) {
			/* transfer 'ownership' of refcnts to new @_ */
			AvREAL_on(av);
			AvREIFY_off(av);
		    }
		    while (items--) {
			if (*mark)
			    SvTEMP_off(*mark);
			mark++;
		    }
		}
		if (PERLDB_SUB) {	/* Checking curstash breaks DProf. */
		    Perl_get_db_sub(aTHX_ NULL, cv);
		    if (PERLDB_GOTO) {
			CV * const gotocv = get_cv("DB::goto", FALSE);
			if (gotocv) {
			    PUSHMARK( PL_stack_sp );
			    call_sv((SV*)gotocv, G_SCALAR | G_NODEBUG);
			    PL_stack_sp--;
			}
		    }
		}
		RETURNOP(CvSTART(cv));
	    }
	}
	else {
	    label = SvPV_nolen_const(sv);
	    if (!(do_dump || *label))
		DIE(aTHX_ must_have_label);
	}
    }
    else if (PL_op->op_flags & OPf_SPECIAL) {
	if (! do_dump)
	    DIE(aTHX_ must_have_label);
    }
    else
	label = cPVOP->op_pv;

    if (label && *label) {
	OP *gotoprobe = NULL;
	bool leaving_eval = FALSE;
	bool in_block = FALSE;
	PERL_CONTEXT *last_eval_cx = NULL;

	/* find label */

	PL_lastgotoprobe = NULL;
	*enterops = 0;
	for (ix = cxstack_ix; ix >= 0; ix--) {
	    cx = &cxstack[ix];
	    switch (CxTYPE(cx)) {
	    case CXt_EVAL:
		leaving_eval = TRUE;
                if (!CxTRYBLOCK(cx)) {
		    gotoprobe = (last_eval_cx ?
				last_eval_cx->blk_eval.old_eval_root :
				PL_eval_root);
		    last_eval_cx = cx;
		    break;
                }
                /* else fall through */
	    case CXt_LOOP_LAZYIV:
	    case CXt_LOOP_LAZYSV:
	    case CXt_LOOP_FOR:
	    case CXt_LOOP_PLAIN:
		gotoprobe = cx->blk_oldcop->op_sibling;
		break;
	    case CXt_SUBST:
		continue;
	    case CXt_BLOCK:
		if (ix) {
		    gotoprobe = cx->blk_oldcop->op_sibling;
		    in_block = TRUE;
		} else
		    gotoprobe = PL_main_root;
		break;
	    case CXt_SUB:
		if (CvDEPTH(cx->blk_sub.cv) && !CxMULTICALL(cx)) {
		    gotoprobe = CvROOT(cx->blk_sub.cv);
		    break;
		}
		/* FALL THROUGH */
	    case CXt_NULL:
		DIE(aTHX_ "Can't \"goto\" out of a pseudo block");
	    default:
		if (ix)
		    DIE(aTHX_ "panic: goto");
		gotoprobe = PL_main_root;
		break;
	    }
	    if (gotoprobe) {
		retop = dofindlabel(gotoprobe, label,
				    enterops, enterops + GOTO_DEPTH);
		if (retop)
		    break;
	    }
	    PL_lastgotoprobe = gotoprobe;
	}
	if (!retop)
	    DIE(aTHX_ "Can't find label %s", label);

	/* if we're leaving an eval, check before we pop any frames
           that we're not going to punt, otherwise the error
	   won't be caught */

	if (leaving_eval && *enterops && enterops[1]) {
	    I32 i;
            for (i = 1; enterops[i]; i++)
                if (enterops[i]->op_type == OP_ENTERITER)
                    DIE(aTHX_ "Can't \"goto\" into the middle of a foreach loop");
	}

	/* pop unwanted frames */

	if (ix < cxstack_ix) {
	    I32 oldsave;

	    if (ix < 0)
		ix = 0;
	    dounwind(ix);
	    TOPBLOCK(cx);
	    oldsave = PL_scopestack[PL_scopestack_ix];
	    LEAVE_SCOPE(oldsave);
	}

	/* push wanted frames */

	if (*enterops && enterops[1]) {
	    OP * const oldop = PL_op;
	    ix = enterops[1]->op_type == OP_ENTER && in_block ? 2 : 1;
	    for (; enterops[ix]; ix++) {
		PL_op = enterops[ix];
		/* Eventually we may want to stack the needed arguments
		 * for each op.  For now, we punt on the hard ones. */
		if (PL_op->op_type == OP_ENTERITER)
		    DIE(aTHX_ "Can't \"goto\" into the middle of a foreach loop");
		CALL_FPTR(PL_op->op_ppaddr)(aTHX);
	    }
	    PL_op = oldop;
	}
    }

    if (do_dump) {
#ifdef VMS
	if (!retop) retop = PL_main_start;
#endif
	PL_restartop = retop;
	PL_do_undump = TRUE;

	my_unexec();

	PL_restartop = 0;		/* hmm, must be GNU unexec().. */
	PL_do_undump = FALSE;
    }

    RETURNOP(retop);
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

STATIC void
S_save_lines(pTHX_ AV *array, SV *sv)
{
    const char *s = SvPVX_const(sv);
    const char * const send = SvPVX_const(sv) + SvCUR(sv);
    I32 line = 1;

    PERL_ARGS_ASSERT_SAVE_LINES;

    while (s && s < send) {
	const char *t;
	SV * const tmpstr = newSV_type(SVt_PVMG);

	t = strchr(s, '\n');
	if (t)
	    t++;
	else
	    t = send;

	sv_setpvn(tmpstr, s, t - s);
	av_store(array, line++, tmpstr);
	s = t;
    }
}

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
	assert(CxTYPE(&cxstack[cxstack_ix]) == CXt_EVAL);
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
	assert(CxTYPE(&cxstack[cxstack_ix+1]) == CXt_EVAL);

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
Perl_sv_compile_2op(pTHX_ SV *sv, OP** startop, const char *code, PAD** padp)
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

    PERL_ARGS_ASSERT_SV_COMPILE_2OP;

    ENTER;
    lex_start(sv, NULL, FALSE);
    SAVETMPS;
    /* switch to eval mode */

    if (IN_PERL_COMPILETIME) {
	SAVECOPSTASH_FREE(&PL_compiling);
	CopSTASH_set(&PL_compiling, PL_curstash);
    }
    if (PERLDB_NAMEEVAL && CopLINE(PL_curcop)) {
	SV * const sv = sv_newmortal();
	Perl_sv_setpvf(aTHX_ sv, "_<(%.10seval %lu)[%s:%"IVdf"]",
		       code, (unsigned long)++PL_evalseq,
		       CopFILE(PL_curcop), (IV)CopLINE(PL_curcop));
	tmpbuf = SvPVX(sv);
	len = SvCUR(sv);
    }
    else
	len = my_snprintf(tmpbuf, sizeof(tbuf), "_<(%.10s_eval %lu)", code,
			  (unsigned long)++PL_evalseq);
    SAVECOPFILE_FREE(&PL_compiling);
    CopFILE_set(&PL_compiling, tmpbuf+2);
    SAVECOPLINE(&PL_compiling);
    CopLINE_set(&PL_compiling, 1);
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

    PL_op = &dummy;
    PL_op->op_type = OP_ENTEREVAL;
    PL_op->op_flags = 0;			/* Avoid uninit warning. */
    PUSHBLOCK(cx, CXt_EVAL|(IN_PERL_COMPILETIME ? 0 : CXp_REAL), SP);
    PUSHEVAL(cx, 0);

    if (runtime)
	(void) doeval(G_SCALAR, startop, runcv, PL_curcop->cop_seq);
    else
	(void) doeval(G_SCALAR, startop, PL_compcv, PL_cop_seqmax);
    POPBLOCK(cx,PL_curpm);
    POPEVAL(cx);

    (*startop)->op_type = OP_NULL;
    (*startop)->op_ppaddr = PL_ppaddr[OP_NULL];
    lex_end();
    /* XXX DAPM do this properly one year */
    *padp = (AV*)SvREFCNT_inc_simple(PL_comppad);
    LEAVE;
    if (IN_PERL_COMPILETIME)
	CopHINTS_set(&PL_compiling, PL_hints);
#ifdef OP_IN_REGISTER
    op = PL_opsave;
#endif
    PERL_UNUSED_VAR(newsp);
    PERL_UNUSED_VAR(optype);

    return PL_eval_start;
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
		/* skip DB:: code */
		if (db_seqp && PL_debstash && CvSTASH(cv) == PL_debstash) {
		    *db_seqp = cx->blk_oldcop->cop_seq;
		    continue;
		}
		return cv;
	    }
	    else if (CxTYPE(cx) == CXt_EVAL && !CxTRYBLOCK(cx))
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
S_doeval(pTHX_ int gimme, OP** startop, CV* outside, U32 seq)
{
    dVAR; dSP;
    OP * const saveop = PL_op;

    if (PL_parser->error_count) {
	/* were are inside an eval which already has compile errors */
	Perl_croak(aTHX_ "%"SVf"%s compilation aborted.\n",
		   SVfARG(ERRSV), OutCopFILE(PL_curcop));
    }

    PL_in_eval = ((saveop && saveop->op_type == OP_REQUIRE)
		  ? (EVAL_INREQUIRE | (PL_in_eval & EVAL_INEVAL))
		  : EVAL_INEVAL);

    PUSHMARK(SP);

    SAVESPTR(PL_compcv);
    SVcpNULL(PL_compcv);
    PL_compcv = (CV*)newSV_type(SVt_PVCV);
    CvEVAL_on(PL_compcv);
    assert(CxTYPE(&cxstack[cxstack_ix]) == CXt_EVAL);
    cxstack[cxstack_ix].blk_eval.cv = PL_compcv;

    CvOUTSIDE_SEQ(PL_compcv) = seq;
    CvOUTSIDE(PL_compcv) = (CV*)SvREFCNT_inc_simple(outside);

    /* set up a scratch pad */

    CvPADLIST(PL_compcv) = pad_new(padnew_SAVE);
    PL_op = NULL; /* avoid PL_op and PL_curpad referring to different CVs */


    if (!PL_madskills)
	SAVEMORTALIZESV(PL_compcv);	/* must remain until end of current statement */

    /* make sure we compile in the right package */

    if (CopSTASH_ne(PL_curcop, PL_curstash)) {
	SAVESPTR(PL_curstash);
	SVcpREPLACE(PL_curstash, CopSTASH(PL_curcop));
    }
    /* XXX:ajgo do we really need to alloc an AV for begin/checkunit */
    SAVESPTR(PL_beginav);
    PL_beginav = newAV();
    SAVEFREESV(PL_beginav);
    SAVESPTR(PL_unitcheckav);
    PL_unitcheckav = newAV();
    SAVEFREESV(PL_unitcheckav);

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
	if (PL_eval_root) {
	    op_free(PL_eval_root);
	    PL_eval_root = NULL;
	}
	SP = PL_stack_base + POPMARK;		/* pop original mark */
	if (!startop) {
	    POPBLOCK(cx,PL_curpm);
	    POPEVAL(cx);
	}
	lex_end();
	LEAVE;

	msg = SvPVx_nolen_const(ERRSV);
	if (optype == OP_REQUIRE) {
	    const SV * const nsv = cx->blk_eval.old_namesv;
	    (void)hv_store(GvHVn(PL_incgv), SvPVX_const(nsv), SvCUR(nsv),
                          &PL_sv_undef, 0);
	    Perl_croak(aTHX_ "%sCompilation failed in require",
		       *msg ? msg : "Unknown error\n");
	}
	else if (startop) {
	    POPBLOCK(cx,PL_curpm);
	    POPEVAL(cx);
	    Perl_croak(aTHX_ "%sCompilation failed in regexp",
		       (*msg ? msg : "Unknown error\n"));
	}
	else {
	    SV *msv;

	    dSP;
	    ENTER;
	    PUSHSTACKi(PERLSI_DIEHOOK);

	    PUSHMARK(SP);
	    XPUSHs(ERRSV);
	    PUTBACK;
	    call_sv(PL_errorcreatehook, G_SCALAR);
	    SPAGAIN;
	    msv = SvREFCNT_inc(POPs);
	    SvREFCNT_dec(ERRSV);
	    ERRSV = msv;
	    PUTBACK;

	    POPSTACK;
	    LEAVE;
	}
	PERL_UNUSED_VAR(newsp);
	PUSHs(&PL_sv_undef);
	PUTBACK;
	return FALSE;
    }
    CopLINE_set(&PL_compiling, 0);
    if (startop) {
	*startop = PL_eval_root;
    } else
	SAVEFREEOP(PL_eval_root);

    /* Set the context for this new optree.
     * If the last op is an OP_REQUIRE, force scalar context.
     * Otherwise, propagate the context from the eval(). */
    if (PL_eval_root->op_type == OP_LEAVEEVAL
	    && cUNOPx(PL_eval_root)->op_first->op_type == OP_LINESEQ
	    && cLISTOPx(cUNOPx(PL_eval_root)->op_first)->op_last->op_type
	    == OP_REQUIRE)
	scalar(PL_eval_root);
    else if ((gimme & G_WANT) == G_VOID)
	scalarvoid(PL_eval_root);
    else if ((gimme & G_WANT) == G_ARRAY)
	list(PL_eval_root);
    else
	scalar(PL_eval_root);

    DEBUG_x(dump_eval());

    /* Register with debugger: */
    if (PERLDB_INTER && saveop && saveop->op_type == OP_REQUIRE) {
	CV * const cv = get_cv("DB::postponed", FALSE);
	if (cv) {
	    dSP;
	    PUSHMARK(SP);
	    XPUSHs((SV*)CopFILEGV(&PL_compiling));
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
	char *const pmc = SvPVX(pmcsv);
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

    sv = POPs;
    name = SvPV_const(sv, len);
    if (!(name && len > 0 && *name))
	DIE(aTHX_ "Null filename used");
    TAINT_PROPER("require");


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
	SV * const * const svp = hv_fetch(GvHVn(PL_incgv),
					  unixname, unixlen, 0);
	if ( svp ) {
	    if (*svp != &PL_sv_undef)
		RETPUSHYES;
	    else
		DIE(aTHX_ "Attempt to reload %s aborted.\n"
			    "Compilation failed in require", unixname);
	}
    }

    /* prepare to compile file */

    if (path_is_absolute(name)) {
	tryname = name;
	tryrsfp = doopen_pm(name, len);
    }
#ifdef MACOS_TRADITIONAL
    if (!tryrsfp) {
	char newname[256];

	MacPerl_CanonDir(name, newname, 1);
	if (path_is_absolute(newname)) {
	    tryname = newname;
	    tryrsfp = doopen_pm(newname, strlen(newname));
	}
    }
#endif
    if (!tryrsfp) {
	AV * const ar = GvAVn(PL_incgv);
	I32 i;
	if (!SvAVOK(ar)) 
	    Perl_croak(aTHX_ "@INC must be an array not a %s", SvDESC((SV*)ar));
#ifdef VMS
	if (vms_unixname)
#endif
	{
	    namesv = newSV_type(SVt_PV);
	    for (i = 0; i <= AvFILL(ar); i++) {
		SV * const dirsv = *av_fetch(ar, i, TRUE);

		if (SvTIED_mg((SV*)ar, PERL_MAGIC_tied))
		    mg_get(dirsv);
		if (SvROK(dirsv)) {
		    int count;
		    SV **svp;
		    SV *loader = dirsv;

		    if (SvTYPE(SvRV(loader)) == SVt_PVAV
			&& !sv_isobject(loader))
		    {
			loader = *av_fetch((AV *)SvRV(loader), 0, TRUE);
		    }

		    Perl_sv_setpvf(aTHX_ namesv, "/loader/0x%"UVxf"/%s",
				   PTR2UV(SvRV(dirsv)), name);
		    tryname = SvPVX_const(namesv);
		    tryrsfp = NULL;

		    ENTER;
		    SAVETMPS;
		    EXTEND(SP, 2);

		    PUSHMARK(SP);
		    PUSHs(dirsv);
		    PUSHs(sv);
		    PUTBACK;
		    if (sv_isobject(loader))
			count = call_method("INC", G_ARRAY);
		    else
			count = call_sv(loader, G_ARRAY);
		    SPAGAIN;

		    /* Adjust file name if the hook has set an %INC entry */
		    svp = hv_fetch(GvHVn(PL_incgv), name, len, 0);
		    if (svp)
			tryname = SvPVX_const(*svp);

		    if (count > 0) {
			int i = 0;
			SV *arg;

			SP -= count - 1;
			arg = SP[i++];

			if (SvROK(arg) && (SvTYPE(SvRV(arg)) <= SVt_PVLV)
			    && !isGV_with_GP(SvRV(arg))) {
			    filter_cache = SvRV(arg);
			    SvREFCNT_inc_simple_void_NN(filter_cache);

			    if (i < count) {
				arg = SP[i++];
			    }
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

			    if (i < count) {
				arg = SP[i++];
			    }
			}

			if (SvROK(arg) && SvTYPE(SvRV(arg)) == SVt_PVCV) {
			    filter_sub = arg;
			    SvREFCNT_inc_simple_void_NN(filter_sub);

			    if (i < count) {
				filter_state = SP[i];
				SvREFCNT_inc_simple_void(filter_state);
			    }
			}

			if (!tryrsfp && (filter_cache || filter_sub)) {
			    tryrsfp = PerlIO_open(BIT_BUCKET,
						  PERL_SCRIPT_MODE);
			}
			SP--;
		    }

		    PUTBACK;
		    FREETMPS;
		    LEAVE;

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
		  if (!path_is_absolute(name)
#ifdef MACOS_TRADITIONAL
			/* We consider paths of the form :a:b ambiguous and interpret them first
			   as global then as local
			*/
			|| (*name == ':' && name[1] != ':' && strchr(name+2, ':'))
#endif
		  ) {
		    const char *dir = SvOK(dirsv) ? SvPV_nolen_const(dirsv) : "";
#ifdef MACOS_TRADITIONAL
		    char buf1[256];
		    char buf2[256];

		    MacPerl_CanonDir(name, buf2, 1);
		    Perl_sv_setpvf(aTHX_ namesv, "%s%s", MacPerl_CanonDir(dir, buf1, 0), buf2+(buf2[0] == ':'));
#else
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
#endif
		    TAINT_PROPER("require");
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
    SAVECOPFILE_FREE(&PL_compiling);
    CopFILE_set(&PL_compiling, tryrsfp ? tryname : name);
    SvREFCNT_dec(namesv);
    if (!tryrsfp) {
	if (PL_op->op_type == OP_REQUIRE) {
	    const char *msgstr = name;
	    if(errno == EMFILE) {
		SV * const msg
		    = sv_2mortal(Perl_newSVpvf(aTHX_ "%s:   %s", msgstr,
					       Strerror(errno)));
		msgstr = SvPV_nolen_const(msg);
	    } else {
	        if (namesv) {			/* did we lookup @INC? */
		    AV * const ar = GvAVn(PL_incgv);
		    I32 i;
		    SV * const msg = sv_2mortal(Perl_newSVpvf(aTHX_ 
			"%s in @INC (@INC contains:", msgstr));
		    
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
    /* Check whether a hook in @INC has already filled %INC */
    if (!hook_sv) {
	(void)hv_store(GvHVn(PL_incgv),
		       unixname, unixlen, newSVpv(CopFILE(&PL_compiling),0),0);
    } else {
	SV** const svp = hv_fetch(GvHVn(PL_incgv), unixname, unixlen, 0);
	if (!svp)
	    (void)hv_store(GvHVn(PL_incgv),
			   unixname, unixlen, SvREFCNT_inc_simple(hook_sv), 0 );
    }

    ENTER;
    SAVETMPS;
    lex_start(NULL, tryrsfp, TRUE);

    SAVEHINTS();
    PL_hints = DEFAULT_HINTS;
    if (PL_compiling.cop_hints_hash) {
	SvREFCNT_dec(PL_compiling.cop_hints_hash);
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

    SAVECOPLINE(&PL_compiling);
    CopLINE_set(&PL_compiling, 0);

    PUTBACK;

    if (doeval(gimme, NULL, NULL, PL_curcop->cop_seq))
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
    mXPUSHs((SV*)Perl_hv_copy_hints_hv(aTHX_ (HV*)cSVOP_sv));
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

    TAINT_IF(SvTAINTED(sv));
    TAINT_PROPER("eval");

    ENTER;
    lex_start(sv, NULL, FALSE);
    SAVETMPS;

    /* switch to eval mode */

    if (PERLDB_NAMEEVAL && CopLINE(PL_curcop)) {
	SV * const temp_sv = sv_newmortal();
	Perl_sv_setpvf(aTHX_ temp_sv, "_<(eval %lu)[%s:%"IVdf"]",
		       (unsigned long)++PL_evalseq,
		       CopFILE(PL_curcop), (IV)CopLINE(PL_curcop));
	tmpbuf = SvPVX(temp_sv);
	len = SvCUR(temp_sv);
    }
    else
	len = my_snprintf(tmpbuf, sizeof(tbuf), "_<(eval %lu)", (unsigned long)++PL_evalseq);
    SAVECOPFILE_FREE(&PL_compiling);
    CopFILE_set(&PL_compiling, tmpbuf+2);
    SAVECOPLINE(&PL_compiling);
    CopLINE_set(&PL_compiling, 1);
    /* XXX For C<eval "...">s within BEGIN {} blocks, this ends up
       deleting the eval's FILEGV from the stash before gv_check() runs
       (i.e. before run-time proper). To work around the coredump that
       ensues, we always turn GvMULTI_on for any globals that were
       introduced within evals. See force_ident(). GSAR 96-10-12 */
    safestr = savepvn(tmpbuf, len);
    SAVEDELETE(PL_defstash, safestr, len);
    SAVEHINTS();
    PL_hints = PL_op->op_targ;
    if (saved_hh)
	GvHV(PL_hintgv) = saved_hh;

    SAVESPTR(PL_diehook);
    PL_diehook = SvREFCNT_inc(PERL_DIEHOOK_IGNORE);

    SAVECOMPILEWARNINGS();
    PL_compiling.cop_warnings = DUP_WARNINGS(PL_curcop->cop_warnings);
    if (PL_curcop->cop_hints_hash) {
	HINTS_REFCNT_LOCK;
	SvREFCNT_inc(PL_curcop->cop_hints_hash);
	HINTS_REFCNT_UNLOCK;
    }
    if (PL_compiling.cop_hints_hash) {
	HINTS_REFCNT_LOCK;
	SvREFCNT_dec(PL_compiling.cop_hints_hash);
	HINTS_REFCNT_UNLOCK;
    }
    PL_compiling.cop_hints_hash = PL_curcop->cop_hints_hash;
    /* special case: an eval '' executed within the DB package gets lexically
     * placed in the first non-DB CV rather than the current CV - this
     * allows the debugger to execute code, find lexicals etc, in the
     * scope of the code being debugged. Passing &seq gets find_runcv
     * to do the dirty work for us */
    runcv = find_runcv(&seq);

    PUSHBLOCK(cx, (CXt_EVAL|CXp_REAL), SP);
    PUSHEVAL(cx, 0);
    cx->blk_eval.retop = PL_op->op_next;

    /* prepare to compile string */

    if (PERLDB_LINE && PL_curstash != PL_debstash)
	save_lines(CopFILEAV(&PL_compiling), PL_parser->linestr);
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
    I32 optype;

    POPBLOCK(cx,newpm);
    POPEVAL(cx);
    retop = cx->blk_eval.retop;

    TAINT_NOT;
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
		TAINT_NOT;	/* Each item is independent */
	    }
	}
    }
    PL_curpm = newpm;	/* Don't pop $1 et al till now */

#ifdef DEBUGGING
    assert(CvDEPTH(PL_compcv) == 1);
#endif
    CvDEPTH(PL_compcv) = 0;
    lex_end();

    LEAVE;
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
    LEAVE;
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
	
    ENTER;
    SAVETMPS;

    PUSHBLOCK(cx, (CXt_EVAL|CXp_TRYBLOCK), PL_stack_sp);
    PUSHEVAL(cx, 0);

    PL_in_eval = EVAL_INEVAL;
    if (flags & G_KEEPERR)
	PL_in_eval |= EVAL_KEEPERR;
    else
	sv_setpvn(ERRSV,"",0);
    if (flags & G_FAKINGEVAL) {
	PL_eval_root = PL_op; /* Only needed so that goto works right. */
    }
    return cx;
}
    
PP(pp_entertry)
{
    dVAR;
    PERL_CONTEXT * const cx = create_eval_scope(0);

    SAVESPTR(PL_diehook);
    PL_diehook = SvREFCNT_inc(PERL_DIEHOOK_IGNORE);

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

    TAINT_NOT;
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
		TAINT_NOT;	/* Each item is independent */
	    }
	}
    }
    PL_curpm = newpm;	/* Don't pop $1 et al till now */

    LEAVE;
    sv_setpvn(ERRSV,"",0);
    RETURN;
}

PP(pp_entergiven)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    const I32 gimme = GIMME_V;
    
    ENTER;
    SAVETMPS;

    if (PL_op->op_targ == 0) {
	SV ** const defsv_p = &GvSV(PL_defgv);
	*defsv_p = newSVsv(POPs);
	SAVECLEARSV(*defsv_p);
    }
    else
    	sv_setsv(PAD_SV(PL_op->op_targ), POPs);

    PUSHBLOCK(cx, CXt_GIVEN, SP);
    PUSHGIVEN(cx);

    RETURN;
}

PP(pp_leavegiven)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    I32 gimme;
    SV **newsp;
    PMOP *newpm;
    PERL_UNUSED_CONTEXT;

    POPBLOCK(cx,newpm);
    assert(CxTYPE(cx) == CXt_GIVEN);

    SP = newsp;
    PUTBACK;

    PL_curpm = newpm;   /* pop $1 et al */

    LEAVE;

    return NORMAL;
}

/* Helper routines used by pp_smartmatch */
STATIC PMOP *
S_make_matcher(pTHX_ REGEXP *re)
{
    dVAR;
    PMOP *matcher = (PMOP *) newPMOP(OP_MATCH, OPf_WANT_SCALAR | OPf_STACKED);

    PERL_ARGS_ASSERT_MAKE_MATCHER;

    PM_SETRE(matcher, ReREFCNT_inc(re));

    SAVEFREEOP((OP *) matcher);
    ENTER; SAVETMPS;
    SAVEOP();
    return matcher;
}

STATIC bool
S_matcher_matches_sv(pTHX_ PMOP *matcher, SV *sv)
{
    dVAR;
    dSP;

    PERL_ARGS_ASSERT_MATCHER_MATCHES_SV;
    
    PL_op = (OP *) matcher;
    XPUSHs(sv);
    PUTBACK;
    (void) pp_match();
    SPAGAIN;
    return (SvTRUEx(POPs));
}

STATIC void
S_destroy_matcher(pTHX_ PMOP *matcher)
{
    dVAR;

    PERL_ARGS_ASSERT_DESTROY_MATCHER;
    PERL_UNUSED_ARG(matcher);

    FREETMPS;
    LEAVE;
}

/* Do a smart match */
PP(pp_smartmatch)
{
    return do_smartmatch(NULL, NULL);
}

/* This version of do_smartmatch() implements the
 * table of smart matches that is found in perlsyn.
 */
STATIC OP *
S_do_smartmatch(pTHX_ HV *seen_this, HV *seen_other)
{
    dVAR;
    dSP;
    
    SV *e = TOPs;	/* e is for 'expression' */
    SV *d = TOPm1s;	/* d is for 'default', as in PL_defgv */
    SV *This, *Other;	/* 'This' (and Other to match) to play with C++ */
    REGEXP *this_regex, *other_regex;

#   define NOT_EMPTY_PROTO(cv) (!SvPOK(cv) || SvCUR(cv) == 0)

#   define SM_REF(type) ( \
	   (SvROK(d) && (SvTYPE(This = SvRV(d)) == SVt_##type) && (Other = e)) \
	|| (SvROK(e) && (SvTYPE(This = SvRV(e)) == SVt_##type) && (Other = d)))

#   define SM_CV_NEP   /* Find a code ref without an empty prototype */ \
	((SvROK(d) && (SvTYPE(This = SvRV(d)) == SVt_PVCV)		\
	    && NOT_EMPTY_PROTO(This) && (Other = e))			\
	|| (SvROK(e) && (SvTYPE(This = SvRV(e)) == SVt_PVCV)		\
	    && NOT_EMPTY_PROTO(This) && (Other = d)))

#   define SM_REGEX ( \
	   (SvROK(d) && (SvTYPE(This = SvRV(d)) == SVt_REGEXP)		\
	&& (this_regex = (REGEXP*) This)				\
	&& (Other = e))							\
    ||									\
	   (SvROK(e) && (SvTYPE(This = SvRV(e)) == SVt_REGEXP)		\
	&& (this_regex = (REGEXP*) This)				\
	&& (Other = d))	)
	

#   define SM_OTHER_REF(type) \
	(SvROK(Other) && SvTYPE(SvRV(Other)) == SVt_##type)

#   define SM_OTHER_REGEX (SvROK(Other)					\
	&& (SvTYPE(SvRV(Other)) == SVt_REGEXP)				\
	&& (other_regex = (REGEXP*) SvRV(Other)))


#   define SM_SEEN_THIS(sv) hv_exists_ent(seen_this, \
	sv_2mortal(newSViv(PTR2IV(sv))), 0)

#   define SM_SEEN_OTHER(sv) hv_exists_ent(seen_other, \
	sv_2mortal(newSViv(PTR2IV(sv))), 0)

    tryAMAGICbinSET(smart, 0);
    
    SP -= 2;	/* Pop the values */

    /* Take care only to invoke mg_get() once for each argument. 
     * Currently we do this by copying the SV if it's magical. */
    if (d) {
	if (SvGMAGICAL(d))
	    d = sv_mortalcopy(d);
    }
    else
	d = &PL_sv_undef;

    assert(e);
    if (SvGMAGICAL(e))
	e = sv_mortalcopy(e);

    if (SM_CV_NEP) {
	I32 c;
	
	if ( SM_OTHER_REF(PVCV) && NOT_EMPTY_PROTO(SvRV(Other)) )
	{
	    if (This == SvRV(Other))
		RETPUSHYES;
	    else
		RETPUSHNO;
	}
	
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	PUSHs(Other);
	PUTBACK;
	c = call_sv(This, G_SCALAR);
	SPAGAIN;
	if (c == 0)
	    PUSHs(&PL_sv_no);
	else if (SvTEMP(TOPs))
	    SvREFCNT_inc_void(TOPs);
	FREETMPS;
	LEAVE;
	RETURN;
    }
    else if (SM_REF(PVHV)) {
	if (SM_OTHER_REF(PVHV)) {
	    /* Check that the key-sets are identical */
	    HE *he;
	    HV *other_hv = (HV *) SvRV(Other);
	    bool tied = FALSE;
	    bool other_tied = FALSE;
	    U32 this_key_count  = 0,
	        other_key_count = 0;
	    
	    /* Tied hashes don't know how many keys they have. */
	    if (SvTIED_mg(This, PERL_MAGIC_tied)) {
		tied = TRUE;
	    }
	    else if (SvTIED_mg((SV *) other_hv, PERL_MAGIC_tied)) {
		HV * const temp = other_hv;
		other_hv = (HV *) This;
		This  = (SV *) temp;
		tied = TRUE;
	    }
	    if (SvTIED_mg((SV *) other_hv, PERL_MAGIC_tied))
		other_tied = TRUE;
	    
	    if (!tied && HvUSEDKEYS((HV *) This) != HvUSEDKEYS(other_hv))
	    	RETPUSHNO;

	    /* The hashes have the same number of keys, so it suffices
	       to check that one is a subset of the other. */
	    (void) hv_iterinit((HV *) This);
	    while ( (he = hv_iternext((HV *) This)) ) {
	    	I32 key_len;
		char * const key = hv_iterkey(he, &key_len);
	    	
	    	++ this_key_count;
	    	
	    	if(!hv_exists(other_hv, key, key_len)) {
	    	    (void) hv_iterinit((HV *) This);	/* reset iterator */
		    RETPUSHNO;
	    	}
	    }
	    
	    if (other_tied) {
		(void) hv_iterinit(other_hv);
		while ( hv_iternext(other_hv) )
		    ++other_key_count;
	    }
	    else
		other_key_count = HvUSEDKEYS(other_hv);
	    
	    if (this_key_count != other_key_count)
		RETPUSHNO;
	    else
		RETPUSHYES;
	}
	else if (SM_OTHER_REF(PVAV)) {
	    AV * const other_av = (AV *) SvRV(Other);
	    const I32 other_len = av_len(other_av) + 1;
	    I32 i;

	    for (i = 0; i < other_len; ++i) {
		SV ** const svp = av_fetch(other_av, i, FALSE);
		char *key;
		STRLEN key_len;

		if (svp) {	/* ??? When can this not happen? */
		    key = SvPV(*svp, key_len);
		    if (hv_exists((HV *) This, key, key_len))
		        RETPUSHYES;
		}
	    }
	    RETPUSHNO;
	}
	else if (SM_OTHER_REGEX) {
	    PMOP * const matcher = make_matcher(other_regex);
	    HE *he;

	    (void) hv_iterinit((HV *) This);
	    while ( (he = hv_iternext((HV *) This)) ) {
		if (matcher_matches_sv(matcher, hv_iterkeysv(he))) {
		    (void) hv_iterinit((HV *) This);
		    destroy_matcher(matcher);
		    RETPUSHYES;
		}
	    }
	    destroy_matcher(matcher);
	    RETPUSHNO;
	}
	else {
	    if (hv_exists_ent((HV *) This, Other, 0))
		RETPUSHYES;
	    else
		RETPUSHNO;
	}
    }
    else if (SM_REF(PVAV)) {
	if (SM_OTHER_REF(PVAV)) {
	    AV *other_av = (AV *) SvRV(Other);
	    if (av_len((AV *) This) != av_len(other_av))
		RETPUSHNO;
	    else {
	    	I32 i;
	    	const I32 other_len = av_len(other_av);

		if (NULL == seen_this) {
		    seen_this = newHV();
		    (void) sv_2mortal((SV *) seen_this);
		}
		if (NULL == seen_other) {
		    seen_this = newHV();
		    (void) sv_2mortal((SV *) seen_other);
		}
		for(i = 0; i <= other_len; ++i) {
		    SV * const * const this_elem = av_fetch((AV *)This, i, FALSE);
		    SV * const * const other_elem = av_fetch(other_av, i, FALSE);

		    if (!this_elem || !other_elem) {
			if (this_elem || other_elem)
			    RETPUSHNO;
		    }
		    else if (SM_SEEN_THIS(*this_elem)
			 || SM_SEEN_OTHER(*other_elem))
		    {
			if (*this_elem != *other_elem)
			    RETPUSHNO;
		    }
		    else {
			(void)hv_store_ent(seen_this,
				sv_2mortal(newSViv(PTR2IV(*this_elem))),
				&PL_sv_undef, 0);
			(void)hv_store_ent(seen_other,
				sv_2mortal(newSViv(PTR2IV(*other_elem))),
				&PL_sv_undef, 0);
			PUSHs(*this_elem);
			PUSHs(*other_elem);
			
			PUTBACK;
			(void) do_smartmatch(seen_this, seen_other);
			SPAGAIN;
			
			if (!SvTRUEx(POPs))
			    RETPUSHNO;
		    }
		}
		RETPUSHYES;
	    }
	}
	else if (SM_OTHER_REGEX) {
	    PMOP * const matcher = make_matcher(other_regex);
	    const I32 this_len = av_len((AV *) This);
	    I32 i;

	    for(i = 0; i <= this_len; ++i) {
		SV * const * const svp = av_fetch((AV *)This, i, FALSE);
		if (svp && matcher_matches_sv(matcher, *svp)) {
		    destroy_matcher(matcher);
		    RETPUSHYES;
		}
	    }
	    destroy_matcher(matcher);
	    RETPUSHNO;
	}
	else if (SvIOK(Other) || SvNOK(Other)) {
	    I32 i;

	    for(i = 0; i <= AvFILL((AV *) This); ++i) {
		SV * const * const svp = av_fetch((AV *)This, i, FALSE);
		if (!svp)
		    continue;
		
		PUSHs(Other);
		PUSHs(*svp);
		PUTBACK;
		if (CopHINTS_get(PL_curcop) & HINT_INTEGER)
		    (void) pp_i_eq();
		else
		    (void) pp_eq();
		SPAGAIN;
		if (SvTRUEx(POPs))
		    RETPUSHYES;
	    }
	    RETPUSHNO;
	}
	else if (SvPOK(Other)) {
	    const I32 this_len = av_len((AV *) This);
	    I32 i;

	    for(i = 0; i <= this_len; ++i) {
		SV * const * const svp = av_fetch((AV *)This, i, FALSE);
		if (!svp)
		    continue;
		
		PUSHs(Other);
		PUSHs(*svp);
		PUTBACK;
		(void) pp_seq();
		SPAGAIN;
		if (SvTRUEx(POPs))
		    RETPUSHYES;
	    }
	    RETPUSHNO;
	}
	RETPUSHNO;
    }
    else if (!SvOK(d) || !SvOK(e)) {
	if (!SvOK(d) && !SvOK(e))
	    RETPUSHYES;
	else
	    RETPUSHNO;
    }
    else if (SM_REGEX) {
	PMOP * const matcher = make_matcher(this_regex);

	PUTBACK;
	PUSHs(matcher_matches_sv(matcher, Other)
	    ? &PL_sv_yes
	    : &PL_sv_no);
	destroy_matcher(matcher);
	RETURN;
    }
    else if (SM_REF(PVCV)) {
	I32 c;
	/* This must be a null-prototyped sub, because we
	   already checked for the other kind. */
	
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	PUTBACK;
	c = call_sv(This, G_SCALAR);
	SPAGAIN;
	if (c == 0)
	    PUSHs(&PL_sv_undef);
	else if (SvTEMP(TOPs))
	    SvREFCNT_inc_void(TOPs);

	if (SM_OTHER_REF(PVCV)) {
	    /* This one has to be null-proto'd too.
	       Call both of 'em, and compare the results */
	    PUSHMARK(SP);
	    c = call_sv(SvRV(Other), G_SCALAR);
	    SPAGAIN;
	    if (c == 0)
		PUSHs(&PL_sv_undef);
	    else if (SvTEMP(TOPs))
		SvREFCNT_inc_void(TOPs);
	    FREETMPS;
	    LEAVE;
	    PUTBACK;
	    return pp_eq();
	}
	
	FREETMPS;
	LEAVE;
	RETURN;
    }
    else if ( ((SvIOK(d) || SvNOK(d)) && (This = d) && (Other = e))
         ||   ((SvIOK(e) || SvNOK(e)) && (This = e) && (Other = d)) )
    {
	if (SvPOK(Other) && !looks_like_number(Other)) {
	    /* String comparison */
	    PUSHs(d); PUSHs(e);
	    PUTBACK;
	    return pp_seq();
	}
	/* Otherwise, numeric comparison */
	PUSHs(d); PUSHs(e);
	PUTBACK;
	if (CopHINTS_get(PL_curcop) & HINT_INTEGER)
	    (void) pp_i_eq();
	else
	    (void) pp_eq();
	SPAGAIN;
	if (SvTRUEx(POPs))
	    RETPUSHYES;
	else
	    RETPUSHNO;
    }
    else if ( SvROK(d) && SvROK(e) ) {
	PUSHs(boolSV(SvRV(d) == SvRV(e)));
	RETURN;
    }
    else if ( SvROK(d) || SvROK(e) ) {
	RETPUSHNO;
    }
    
    /* As a last resort, use string comparison */
    PUSHs(d); PUSHs(e);
    PUTBACK;
    return pp_seq();
}

PP(pp_enterwhen)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    const I32 gimme = GIMME_V;

    /* This is essentially an optimization: if the match
       fails, we don't want to push a context and then
       pop it again right away, so we skip straight
       to the op that follows the leavewhen.
    */
    if ((0 == (PL_op->op_flags & OPf_SPECIAL)) && !SvTRUEx(POPs))
	return cLOGOP->op_other->op_next;

    ENTER;
    SAVETMPS;

    PUSHBLOCK(cx, CXt_WHEN, SP);
    PUSHWHEN(cx);

    RETURN;
}

PP(pp_leavewhen)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    I32 gimme;
    SV **newsp;
    PMOP *newpm;

    POPBLOCK(cx,newpm);
    assert(CxTYPE(cx) == CXt_WHEN);

    SP = newsp;
    PUTBACK;

    PL_curpm = newpm;   /* pop $1 et al */

    LEAVE;
    return NORMAL;
}

PP(pp_continue)
{
    dVAR;   
    I32 cxix;
    register PERL_CONTEXT *cx;
    I32 inner;
    
    cxix = dopoptowhen(cxstack_ix); 
    if (cxix < 0)   
	DIE(aTHX_ "Can't \"continue\" outside a when block");
    if (cxix < cxstack_ix)
        dounwind(cxix);
    
    /* clear off anything above the scope we're re-entering */
    inner = PL_scopestack_ix;
    TOPBLOCK(cx);
    if (PL_scopestack_ix < inner)
        leave_scope(PL_scopestack[PL_scopestack_ix]);
    PL_curcop = cx->blk_oldcop;
    return cx->blk_givwhen.leave_op;
}

PP(pp_break)
{
    dVAR;   
    I32 cxix;
    register PERL_CONTEXT *cx;
    I32 inner;
    
    cxix = dopoptogiven(cxstack_ix); 
    if (cxix < 0) {
	if (PL_op->op_flags & OPf_SPECIAL)
	    DIE(aTHX_ "Can't use when() outside a topicalizer");
	else
	    DIE(aTHX_ "Can't \"break\" outside a given block");
    }
    if (CxFOREACH(&cxstack[cxix]) && (0 == (PL_op->op_flags & OPf_SPECIAL)))
	DIE(aTHX_ "Can't \"break\" in a loop topicalizer");

    if (cxix < cxstack_ix)
        dounwind(cxix);
    
    /* clear off anything above the scope we're re-entering */
    inner = PL_scopestack_ix;
    TOPBLOCK(cx);
    if (PL_scopestack_ix < inner)
        leave_scope(PL_scopestack[PL_scopestack_ix]);
    PL_curcop = cx->blk_oldcop;

    if (CxFOREACH(cx))
	return CX_LOOP_NEXTOP_GET(cx);
    else
	return cx->blk_givwhen.leave_op;
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
    bool read_from_cache = FALSE;
    STRLEN umaxlen;

    PERL_ARGS_ASSERT_RUN_USER_FILTER;

    assert(maxlen >= 0);
    umaxlen = maxlen;

    /* I was having segfault trouble under Linux 2.2.5 after a
       parse error occured.  (Had to hack around it with a test
       for PL_parser->error_count == 0.)  Solaris doesn't segfault --
       not sure where the trouble is yet.  XXX */

    if (NULL) { /* IoFMT_GV(datasv)) { */
	SV *const cache = NULL; /* (SV *)IoFMT_GV(datasv); */
	if (SvOK(cache)) {
	    STRLEN cache_len;
	    const char *cache_p = SvPV(cache, cache_len);
	    STRLEN take = 0;

	    if (umaxlen) {
		/* Running in block mode and we have some cached data already.
		 */
		if (cache_len >= umaxlen) {
		    /* In fact, so much data we don't even need to call
		       filter_read.  */
		    take = umaxlen;
		}
	    } else {
		const char *const first_nl =
		    (const char *)memchr(cache_p, '\n', cache_len);
		if (first_nl) {
		    take = first_nl + 1 - cache_p;
		}
	    }
	    if (take) {
		sv_catpvn(buf_sv, cache_p, take);
		sv_chop(cache, cache_p + take);
		/* Definately not EOF  */
		return 1;
	    }

	    sv_catsv(buf_sv, cache);
	    if (umaxlen) {
		umaxlen -= cache_len;
	    }
	    SvOK_off(cache);
	    read_from_cache = TRUE;
	}
    }

    /* Filter API says that the filter appends to the contents of the buffer.
       Usually the buffer is "", so the details don't matter. But if it's not,
       then clearly what it contains is already filtered by this filter, so we
       don't want to pass it in a second time.
       I'm going to use a mortal in case the upstream filter croaks.  */
    upstream = ((SvOK(buf_sv) && sv_len(buf_sv)) || SvGMAGICAL(buf_sv))
	? sv_newmortal() : buf_sv;
    SvUPGRADE(upstream, SVt_PV);
	
    if (filter_has_file) {
	status = FILTER_READ(idx+1, upstream, 0);
    }

    if (filter_sub && status >= 0) {
	dSP;
	int count;

	ENTER;
	SAVE_DEFSV;
	SAVETMPS;
	EXTEND(SP, 2);

	DEFSV = upstream;
	PUSHMARK(SP);
	mPUSHi(0);
	if (filter_state) {
	    PUSHs(filter_state);
	}
	PUTBACK;
	count = call_sv(filter_sub, G_SCALAR);
	SPAGAIN;

	if (count > 0) {
	    SV *out = POPs;
	    if (SvOK(out)) {
		status = SvIV(out);
	    }
	}

	PUTBACK;
	FREETMPS;
	LEAVE;
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
#ifdef MACOS_TRADITIONAL
	|| (*name == ':')
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
