
#include "EXTERN.h"
#define PERL_IN_PP_RE_C
#include "perl.h"

PP(pp_match)
{
    dVAR; dSP; dTARG;
    register PMOP *pm = cPMOP;
    PMOP *dynpm = pm;
    register const char *t;
    register const char *s;
    const char *strend;
    I32 global;
    U8 r_flags = REXEC_CHECKED;
    const char *truebase;			/* Start of string  */
    register REGEXP *rx = PM_GETRE(pm);
    const I32 gimme = GIMME;
    STRLEN len;
    I32 minmatch = 0;
    const I32 oldsave = PL_savestack_ix;
    I32 update_minmatch = 1;
    I32 had_zerolen = 0;
    I32 gpos = 0;

    if (PL_op->op_flags & OPf_STACKED)
	TARG = POPs;
    else if (PL_op->op_flags & OPf_TARGET_MY)
	GETTARGET;
    else {
	TARG = DEFSV;
	EXTEND(SP,1);
    }

    PUTBACK;				/* EVAL blocks need stack_sp. */
    s = SvPV_const(TARG, len);
    if (!s)
	DIE(aTHX_ "panic: pp_match");
    strend = s + len;

    /* PMdf_USED is set after a ?? matches once */
    if (0) {
      failure:
	if (gimme == G_ARRAY)
	    RETURN;
	RETPUSHNO;
    }


    /* empty pattern special-cased to use last successful pattern if possible */
    if (!RX_PRELEN(rx) && PL_curpm) {
	pm = PL_curpm;
	rx = PM_GETRE(pm);
    }

    if (RX_MINLEN(rx) > (I32)len)
	goto failure;

    truebase = t = s;

    /* XXXX What part of this is needed with true \G-support? */
    if ((global = dynpm->op_pmflags & PMf_GLOBAL)) {
	RX_OFFS(rx)[0].start = -1;
	if (SvTYPE(TARG) >= SVt_PVMG && SvMAGIC(TARG)) {
	    MAGIC* const mg = mg_find(TARG, PERL_MAGIC_regex_global);
	    if (mg && mg->mg_len >= 0) {
		if (!(RX_EXTFLAGS(rx) & RXf_GPOS_SEEN))
		    RX_OFFS(rx)[0].end = RX_OFFS(rx)[0].start = mg->mg_len;
		else if (RX_EXTFLAGS(rx) & RXf_ANCH_GPOS) {
		    r_flags |= REXEC_IGNOREPOS;
		    RX_OFFS(rx)[0].end = RX_OFFS(rx)[0].start = mg->mg_len;
		} else if (RX_EXTFLAGS(rx) & RXf_GPOS_FLOAT) 
		    gpos = mg->mg_len;
		else 
		    RX_OFFS(rx)[0].end = RX_OFFS(rx)[0].start = mg->mg_len;
		minmatch = (mg->mg_flags & MGf_MINMATCH) ? RX_GOFS(rx) + 1 : 0;
		update_minmatch = 0;
	    }
	}
    }
    /* XXX: comment out !global get safe $1 vars after a
       match, BUT be aware that this leads to dramatic slowdowns on
       /g matches against large strings.  So far a solution to this problem
       appears to be quite tricky.
       Test for the unsafe vars are TODO for now. */
    if (( /* !global  && */ RX_NPARENS(rx)) 
	    || SvTEMP(TARG) ||
	    (RX_EXTFLAGS(rx) & (RXf_EVAL_SEEN|RXf_PMf_KEEPCOPY)))
	r_flags |= REXEC_COPY_STR;
    if (SvSCREAM(TARG))
	r_flags |= REXEC_SCREAM;

play_it_again:
    if (global && RX_OFFS(rx)[0].start != -1) {
	t = s = RX_OFFS(rx)[0].end + truebase - RX_GOFS(rx);
	if ((s + RX_MINLEN(rx)) > strend || s < truebase)
	    goto nope;
	if (update_minmatch++)
	    minmatch = had_zerolen;
    }
    if (RX_EXTFLAGS(rx) & RXf_USE_INTUIT) {
	/* FIXME - can PL_bostr be made const char *?  */
	PL_bostr = (char *)truebase;
	s = CALLREG_INTUIT_START(rx, TARG, (char *)s, (char *)strend, r_flags, NULL);

	if (!s)
	    goto nope;
	if ( (RX_EXTFLAGS(rx) & RXf_CHECK_ALL)
	     && !(RX_EXTFLAGS(rx) & RXf_PMf_KEEPCOPY)
	     && ((RX_EXTFLAGS(rx) & RXf_NOSCAN)
		 || !((RX_EXTFLAGS(rx) & RXf_INTUIT_TAIL)
		      && (r_flags & REXEC_SCREAM)))
	     && !SvROK(TARG))	/* Cannot trust since INTUIT cannot guess ^ */
	    goto yup;
    }
    if (CALLREGEXEC(rx, (char*)s, (char *)strend, (char*)truebase,
                    minmatch, TARG, NUM2PTR(void*, gpos), r_flags))
    {
	PL_curpm = pm;
	goto gotcha;
    }
    else
	goto ret_no;
    /*NOTREACHED*/

  gotcha:
    if (gimme == G_ARRAY) {
	const I32 nparens = RX_NPARENS(rx);
	I32 i = (global && !nparens) ? 1 : 0;

	SPAGAIN;			/* EVAL blocks could move the stack. */
	EXTEND(SP, nparens + i);
	EXTEND_MORTAL(nparens + i);
	for (i = !i; i <= nparens; i++) {
	    PUSHs(sv_newmortal());
	    if ((RX_OFFS(rx)[i].start != -1) && RX_OFFS(rx)[i].end != -1 ) {
		const I32 len = RX_OFFS(rx)[i].end - RX_OFFS(rx)[i].start;
		s = RX_OFFS(rx)[i].start + truebase;
	        if (RX_OFFS(rx)[i].end < 0 || RX_OFFS(rx)[i].start < 0 ||
		    len < 0 || len > strend - s)
		    DIE(aTHX_ "panic: pp_match start/end pointers");
		sv_setpvn(*SP, s, len);
	    }
	}
	if (global) {
	    if (dynpm->op_pmflags & PMf_CONTINUE) {
		MAGIC* mg = NULL;
		if (SvTYPE(TARG) >= SVt_PVMG && SvMAGIC(TARG))
		    mg = mg_find(TARG, PERL_MAGIC_regex_global);
		if (!mg) {
#ifdef PERL_OLD_COPY_ON_WRITE
		    if (SvIsCOW(TARG))
			sv_force_normal_flags(TARG, 0);
#endif
		    mg = sv_magicext(TARG, NULL, PERL_MAGIC_regex_global,
				     &PL_vtbl_mglob, NULL, 0);
		}
		if (RX_OFFS(rx)[0].start != -1) {
		    mg->mg_len = RX_OFFS(rx)[0].end;
		    if (RX_OFFS(rx)[0].start + RX_GOFS(rx) == (UV)RX_OFFS(rx)[0].end)
			mg->mg_flags |= MGf_MINMATCH;
		    else
			mg->mg_flags &= ~MGf_MINMATCH;
		}
	    }
	    had_zerolen = (RX_OFFS(rx)[0].start != -1
			   && (RX_OFFS(rx)[0].start + RX_GOFS(rx)
			       == (UV)RX_OFFS(rx)[0].end));
	    PUTBACK;			/* EVAL blocks may use stack */
	    r_flags |= REXEC_IGNOREPOS | REXEC_NOT_FIRST;
	    goto play_it_again;
	}
	else if (!nparens)
	    XPUSHs(&PL_sv_yes);
	LEAVE_SCOPE(oldsave);
	RETURN;
    }
    else {
	if (global) {
	    MAGIC* mg;
	    if (SvTYPE(TARG) >= SVt_PVMG && SvMAGIC(TARG))
		mg = mg_find(TARG, PERL_MAGIC_regex_global);
	    else
		mg = NULL;
	    if (!mg) {
#ifdef PERL_OLD_COPY_ON_WRITE
		if (SvIsCOW(TARG))
		    sv_force_normal_flags(TARG, 0);
#endif
		mg = sv_magicext(TARG, NULL, PERL_MAGIC_regex_global,
				 &PL_vtbl_mglob, NULL, 0);
	    }
	    if (RX_OFFS(rx)[0].start != -1) {
		mg->mg_len = RX_OFFS(rx)[0].end;
		if (RX_OFFS(rx)[0].start + RX_GOFS(rx) == (UV)RX_OFFS(rx)[0].end)
		    mg->mg_flags |= MGf_MINMATCH;
		else
		    mg->mg_flags &= ~MGf_MINMATCH;
	    }
	}
	LEAVE_SCOPE(oldsave);
	RETPUSHYES;
    }

yup:					/* Confirmed by INTUIT */
    PL_curpm = pm;
    if (RX_MATCH_COPIED(rx))
	Safefree(RX_SUBBEG(rx));
    RX_MATCH_COPIED_off(rx);
    RX_SUBBEG(rx) = NULL;
    if (global) {
	/* FIXME - should rx->subbeg be const char *?  */
	RX_SUBBEG(rx) = (char *) truebase;
	RX_OFFS(rx)[0].start = s - truebase;
	RX_OFFS(rx)[0].end = s - truebase + RX_MINLENRET(rx);
	RX_SUBLEN(rx) = strend - truebase;
	goto gotcha;
    }
    if (RX_EXTFLAGS(rx) & RXf_PMf_KEEPCOPY) {
	I32 off;
#ifdef PERL_OLD_COPY_ON_WRITE
	if (SvIsCOW(TARG) || (SvFLAGS(TARG) & CAN_COW_MASK) == CAN_COW_FLAGS) {
	    if (DEBUG_C_TEST) {
		PerlIO_printf(Perl_debug_log,
			      "Copy on write: pp_match $& capture, type %d, truebase=%p, t=%p, difference %d\n",
			      (int) SvTYPE(TARG), (void*)truebase, (void*)t,
			      (int)(t-truebase));
	    }
	    RX_SAVED_COPY(rx) = sv_setsv_cow(RX_SAVED_COPY(rx), TARG);
	    RX_SUBBEG(rx)
		= (char *) SvPVX_const(RX_SAVED_COPY(rx)) + (t - truebase);
	    assert (SvPOKp(RX_SAVED_COPY(rx)));
	} else
#endif
	{

	    RX_SUBBEG(rx) = savepvn(t, strend - t);
#ifdef PERL_OLD_COPY_ON_WRITE
	    RX_SAVED_COPY(rx) = NULL;
#endif
	}
	RX_SUBLEN(rx) = strend - t;
	RX_MATCH_COPIED_on(rx);
	off = RX_OFFS(rx)[0].start = s - t;
	RX_OFFS(rx)[0].end = off + RX_MINLENRET(rx);
    }
    else {			/* startp/endp are used by @- @+. */
	RX_OFFS(rx)[0].start = s - truebase;
	RX_OFFS(rx)[0].end = s - truebase + RX_MINLENRET(rx);
    }
    /* including RX_NPARENS(rx) in the below code seems highly suspicious.
       -dmq */
    RX_NPARENS(rx) = RX_LASTPAREN(rx) = RX_LASTCLOSEPAREN(rx) = 0;	/* used by @-, @+, and $^N */
    LEAVE_SCOPE(oldsave);
    RETPUSHYES;

nope:
ret_no:
    if (global && !(dynpm->op_pmflags & PMf_CONTINUE)) {
	if (SvTYPE(TARG) >= SVt_PVMG && SvMAGIC(TARG)) {
	    MAGIC* const mg = mg_find(TARG, PERL_MAGIC_regex_global);
	    if (mg)
		mg->mg_len = -1;
	}
    }
    LEAVE_SCOPE(oldsave);
    if (gimme == G_ARRAY)
	RETURN;
    RETPUSHNO;
}

PP(pp_subst)
{
    dVAR; dSP; dTARG;
    register PMOP *pm = cPMOP;
    PMOP *rpm = pm;
    register char *s;
    char *strend;
    register char *m;
    const char *c;
    register char *d;
    STRLEN clen;
    I32 iters = 0;
    I32 maxiters;
    register I32 i;
    bool once;
    char *orig;
    U8 r_flags;
    register REGEXP *rx = PM_GETRE(pm);
    STRLEN len;
    int force_on_match = 0;
    const I32 oldsave = PL_savestack_ix;
    I32 matched;
#ifdef PERL_OLD_COPY_ON_WRITE
    bool is_cow;
#endif

    /* known replacement string? */
    register SV *dstr = (pm->op_pmflags & PMf_CONST) ? POPs : NULL;
    if (PL_op->op_flags & OPf_STACKED)
	TARG = POPs;
    else if (PL_op->op_flags & OPf_TARGET_MY)
	GETTARGET;
    else {
	TARG = DEFSV;
	EXTEND(SP,1);
    }

    if ( SvOK(TARG) && ! SvPVOK(TARG) ) {
	DIE(aTHX_ "substitute expected a plain value but got %s", Ddesc(TARG));
    }

#ifdef PERL_OLD_COPY_ON_WRITE
    /* Awooga. Awooga. "bool" types that are actually char are dangerous,
       because they make integers such as 256 "false".  */
    is_cow = SvIsCOW(TARG) ? TRUE : FALSE;
#else
    if (SvIsCOW(TARG))
	sv_force_normal_flags(TARG,0);
#endif
    if (
#ifdef PERL_OLD_COPY_ON_WRITE
	!is_cow &&
#endif
	(SvREADONLY(TARG)
	 || ( ((SvTYPE(TARG) == SVt_PVGV && isGV_with_GP(TARG))
	       || SvTYPE(TARG) > SVt_PVGV)
	     && !(SvTYPE(TARG) == SVt_PVGV && SvFAKE(TARG)))))
	DIE(aTHX_ PL_no_modify);
    PUTBACK;

    s = SvPV_mutable(TARG, len);
    if (!SvPOKp(TARG) || SvTYPE(TARG) == SVt_PVGV)
	force_on_match = 1;

  force_it:
    if (!pm || !s)
	DIE(aTHX_ "panic: pp_subst");

    strend = s + len;
    maxiters = 2 * len + 10;	/* We can match twice at each
				   position, once with zero-length,
				   second time with non-zero. */

    if (!RX_PRELEN(rx) && PL_curpm) {
	pm = PL_curpm;
	rx = PM_GETRE(pm);
    }
    r_flags = (RX_NPARENS(rx) || SvTEMP(TARG)
	    || (RX_EXTFLAGS(rx) & (RXf_EVAL_SEEN|RXf_PMf_KEEPCOPY)) )
	       ? REXEC_COPY_STR : 0;
    if (SvSCREAM(TARG))
	r_flags |= REXEC_SCREAM;

    orig = m = s;
    if (RX_EXTFLAGS(rx) & RXf_USE_INTUIT) {
	PL_bostr = orig;
	s = CALLREG_INTUIT_START(rx, TARG, s, strend, r_flags, NULL);

	if (!s)
	    goto nope;
	/* How to do it in subst? */
/*	if ( (RX_EXTFLAGS(rx) & RXf_CHECK_ALL)
	     && !(RX_EXTFLAGS(rx) & RXf_KEEPCOPY)
	     && ((RX_EXTFLAGS(rx) & RXf_NOSCAN)
		 || !((RX_EXTFLAGS(rx) & RXf_INTUIT_TAIL)
		      && (r_flags & REXEC_SCREAM))))
	    goto yup;
*/
    }

    /* only replace once? */
    once = !(rpm->op_pmflags & PMf_GLOBAL);
    matched = CALLREGEXEC(rx, s, strend, orig, 0, TARG, NULL,
			 r_flags | REXEC_CHECKED);
    /* known replacement string? */
    if (dstr) {
	c = SvPV_const(dstr, clen);
    }
    else {
	c = NULL;
    }
    
    /* can do inplace substitution? */
    if (c
#ifdef PERL_OLD_COPY_ON_WRITE
	&& !is_cow
#endif
	&& (I32)clen <= RX_MINLENRET(rx) && (once || !(r_flags & REXEC_COPY_STR))
	&& !(RX_EXTFLAGS(rx) & RXf_LOOKBEHIND_SEEN)) {
	if (!matched)
	{
	    SPAGAIN;
	    PUSHs(&PL_sv_no);
	    LEAVE_SCOPE(oldsave);
	    RETURN;
	}
#ifdef PERL_OLD_COPY_ON_WRITE
	if (SvIsCOW(TARG)) {
	    assert (!force_on_match);
	    goto have_a_cow;
	}
#endif
	if (force_on_match) {
	    force_on_match = 0;
	    s = SvPV_force(TARG, len);
	    goto force_it;
	}
	d = s;
	PL_curpm = pm;
	SvSCREAM_off(TARG);	/* disable possible screamer */
	if (once) {
	    m = orig + RX_OFFS(rx)[0].start;
	    d = orig + RX_OFFS(rx)[0].end;
	    s = orig;
	    if (m - s > strend - d) {  /* faster to shorten from end */
		if (clen) {
		    Copy(c, m, clen, char);
		    m += clen;
		}
		i = strend - d;
		if (i > 0) {
		    Move(d, m, i, char);
		    m += i;
		}
		*m = '\0';
		SvCUR_set(TARG, m - s);
	    }
	    else if ((i = m - s)) {	/* faster from front */
		d -= clen;
		m = d;
		Move(s, d - i, i, char);
		sv_chop(TARG, d-i);
		if (clen)
		    Copy(c, m, clen, char);
	    }
	    else if (clen) {
		d -= clen;
		sv_chop(TARG, d);
		Copy(c, d, clen, char);
	    }
	    else {
		sv_chop(TARG, d);
	    }
	    SPAGAIN;
	    PUSHs(&PL_sv_yes);
	}
	else {
	    do {
		if (iters++ > maxiters)
		    DIE(aTHX_ "Substitution loop");
		m = RX_OFFS(rx)[0].start + orig;
		if ((i = m - s)) {
		    if (s != d)
			Move(s, d, i, char);
		    d += i;
		}
		if (clen) {
		    Copy(c, d, clen, char);
		    d += clen;
		}
		s = RX_OFFS(rx)[0].end + orig;
	    } while (CALLREGEXEC(rx, s, strend, orig, s == m,
				 TARG, NULL,
				 /* don't match same null twice */
				 REXEC_NOT_FIRST|REXEC_IGNOREPOS));
	    if (s != d) {
		i = strend - s;
		SvCUR_set(TARG, d - SvPVX_const(TARG) + i);
		Move(s, d, i+1, char);		/* include the NUL */
	    }
	    SPAGAIN;
	    mPUSHi((I32)iters);
	}
	(void)SvPOK_only(TARG);
	if (SvSMAGICAL(TARG)) {
	    PUTBACK;
	    mg_set(TARG);
	    SPAGAIN;
	}
	LEAVE_SCOPE(oldsave);
	RETURN;
    }

    if (matched)
    {
	if (force_on_match) {
	    force_on_match = 0;
	    s = SvPV_force(TARG, len);
	    goto force_it;
	}
#ifdef PERL_OLD_COPY_ON_WRITE
      have_a_cow:
#endif
	dstr = newSVpvn(m, s-m);
	SAVEFREESV(dstr);
	PL_curpm = pm;
	if (!c) {
	    register PERL_CONTEXT *cx;
	    SPAGAIN;
	    PUSHSUBST(cx);
	    RETURNOP(cPMOP->op_pmreplrootu.op_pmreplroot);
	}
	r_flags |= REXEC_IGNOREPOS | REXEC_NOT_FIRST;
	do {
	    if (iters++ > maxiters)
		DIE(aTHX_ "Substitution loop");
	    if (RX_MATCH_COPIED(rx) && RX_SUBBEG(rx) != orig) {
		m = s;
		s = orig;
		orig = RX_SUBBEG(rx);
		s = orig + (m - s);
		strend = s + (strend - m);
	    }
	    m = RX_OFFS(rx)[0].start + orig;
	    sv_catpvn(dstr, s, m-s);
	    s = RX_OFFS(rx)[0].end + orig;
	    if (clen)
		sv_catpvn(dstr, c, clen);
	    if (once)
		break;
	} while (CALLREGEXEC(rx, s, strend, orig, s == m,
			     TARG, NULL, r_flags));
	sv_catpvn(dstr, s, strend - s);

#ifdef PERL_OLD_COPY_ON_WRITE
	/* The match may make the string COW. If so, brilliant, because that's
	   just saved us one malloc, copy and free - the regexp has donated
	   the old buffer, and we malloc an entirely new one, rather than the
	   regexp malloc()ing a buffer and copying our original, only for
	   us to throw it away here during the substitution.  */
	if (SvIsCOW(TARG)) {
	    sv_force_normal_flags(TARG, SV_COW_DROP_PV);
	} else
#endif
	{
	    SvPV_free(TARG);
	}
	SvPV_set(TARG, SvPVX_mutable(dstr));
	SvCUR_set(TARG, SvCUR(dstr));
	SvLEN_set(TARG, SvLEN(dstr));
	SvPV_set(dstr, NULL);

	SPAGAIN;
	mPUSHi((I32)iters);

	(void)SvPOK_only(TARG);
	SvSETMAGIC(TARG);
	LEAVE_SCOPE(oldsave);
	RETURN;
    }
    goto ret_no;

nope:
ret_no:
    SPAGAIN;
    PUSHs(&PL_sv_no);
    LEAVE_SCOPE(oldsave);
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

#ifdef PERL_OLD_COPY_ON_WRITE
	    if (SvIsCOW(targ)) {
		sv_force_normal_flags(targ, SV_COW_DROP_PV);
	    } else
#endif
	    {
		SvPV_free(targ);
	    }
	    SvPV_set(targ, SvPVX_mutable(dstr));
	    SvCUR_set(targ, SvCUR(dstr));
	    SvLEN_set(targ, SvLEN(dstr));
	    SvPV_set(dstr, NULL);

	    mPUSHi(saviters - 1);

	    (void)SvPOK_only(targ);
	    SvSETMAGIC(targ);

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
    rxres_save(&cx->sb_rxres, rx);
    RETURNOP(pm->op_pmstashstartu.op_pmreplstart);
}

PP(pp_qr)
{
    dVAR; dSP;
    register PMOP * const pm = cPMOP;
    REGEXP * rx = PM_GETRE(pm);
    SV * const pkg = rx ? sv_2mortal(CALLREG_PACKAGE(rx)) : NULL;
    SV * const rv = sv_newmortal();

    SvUPGRADE(rv, SVt_IV);
    /* This RV is about to own a reference to the regexp. (In addition to the
       reference already owned by the PMOP.  */
    ReREFCNT_inc(rx);
    SvRV_set(rv, (SV*) rx);
    SvROK_on(rv);

    if (pkg) {
	HV* const stash = gv_stashpv(SvPV_nolen(pkg), GV_ADD);
	(void)sv_bless(rv, stash);
    }

    XPUSHs(rv);
    RETURN;
}

PP(pp_regcreset)
{
    dVAR;
    /* XXXX Should store the old value to allow for tie/overload - and
       restore in regcomp, where marked with XXXX. */
    PL_reginterp_cnt = 0;
    return NORMAL;
}

PP(pp_regcomp)
{
    dVAR;
    dSP;
    register PMOP *pm = (PMOP*)cLOGOP->op_other;
    SV *tmpstr;
    REGEXP *re = NULL;

    if (PL_op->op_flags & OPf_STACKED) {
	/* multiple args; concatentate them */
	dMARK; dORIGMARK;
	tmpstr = PAD_SV(ARGTARG);
	sv_setpvn(tmpstr, "", 0);
	while (++MARK <= SP) {
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
		PM_SETRE(pm, NULL);	/* crucial if regcomp aborts */
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

    if (!RX_PRELEN(PM_GETRE(pm)) && PL_curpm)
	pm = PL_curpm;


    /* can't change the optree at runtime either */
    /* PMf_KEEP is handled differently under threads to avoid these problems */
    if (pm->op_pmflags & PMf_KEEP) {
	pm->op_private &= ~OPpRUNTIME;	/* no point compiling again */
	cLOGOP->op_first->op_next = PL_op->op_next;
    }
    RETURN;
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

