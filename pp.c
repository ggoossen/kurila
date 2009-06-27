/*    pp.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * "It's a big house this, and very peculiar.  Always a bit more to discover,
 * and no knowing what you'll find around a corner.  And Elves, sir!" --Samwise
 */

/* This file contains general pp ("push/pop") functions that execute the
 * opcodes that make up a perl program. A typical pp function expects to
 * find its arguments on the stack, and usually pushes its results onto
 * the stack, hence the 'pp' terminology. Each OP structure contains
 * a pointer to the relevant pp_foo() function.
 */

#include "EXTERN.h"
#define PERL_IN_PP_C
#include "perl.h"
#include "keywords.h"

#include "reentr.h"

/* XXX I can't imagine anyone who doesn't have this actually _needs_
   it, since pid_t is an integral type.
   --AD  2/20/1998
*/
#ifdef NEED_GETPID_PROTO
extern Pid_t getpid (void);
#endif

/*
 * Some BSDs and Cygwin default to POSIX math instead of IEEE.
 * This switches them over to IEEE.
 */
#if defined(LIBM_LIB_VERSION)
    _LIB_VERSION_TYPE _LIB_VERSION = _IEEE_;
#endif

/* variations on pp_null */

PP(pp_stub)
{
    dVAR;
    dSP;
    if (GIMME_V == G_SCALAR)
	XPUSHs(&PL_sv_undef);
    RETURN;
}

PP(pp_logassign_assign)
{
    dVAR;
    dSP;
    SV* src = POPs;
    sv_setsv_mg(TOPs, src);
    RETURN;
}

/* Translations. */

PP(pp_rv2gv)
{
    dVAR; dSP;
    SV* sv = POPs;
    const OPFLAGS op_flags = PL_op->op_flags;

    if (SvROK(sv)) {
      wasref:
	sv = SvRV(sv);
	if (SvTYPE(sv) == SVt_PVIO) {
	    GV * const gv = (GV*) sv_newmortal();
	    gv_init(gv, 0, "", 0, 0);
	    GvIOp(gv) = (IO *)sv;
	    SvREFCNT_inc_void_NN(sv);
	    sv = (SV*) gv;
	}
	else if (SvTYPE(sv) != SVt_PVGV)
	    DIE(aTHX_ "Not a GLOB reference");
    }
    else {
	if (SvTYPE(sv) != SVt_PVGV) {
	    if (!SvOK(sv) && sv != &PL_sv_undef) {
		/* If this is a 'my' scalar and flag is set then vivify
		 * NI-S 1999/05/07
		 */
		if (SvREADONLY(sv))
		    Perl_croak(aTHX_ PL_no_modify);
		if (PL_op->op_private & OPpDEREF) {
		    GV *gv;
		    if (cUNOP->op_targ) {
			STRLEN len;
			SV * const namesv = PAD_SV(cUNOP->op_targ);
			const char * const name = SvPV(namesv, len);
			gv = (GV*)newSV(0);
			gv_init(gv, CopSTASH(PL_curcop), name, len, 0);
		    }
		    else {
			const char * const name = CopSTASHPV(PL_curcop);
			gv = GvREFCNT_inc(newGVgen(name));
		    }
		    prepare_SV_for_RV(sv);
		    SvRV_set(sv, (SV*)gv);
		    SvROK_on(sv);
		    SvSETMAGIC(sv);
		    goto wasref;
		}
		DIE(aTHX_ PL_no_usym, "a symbol");
	    }
	    DIE(aTHX_ PL_no_symref_sv, sv, "a symbol");
	}
    }

    if (PL_op->op_private & OPpLVAL_INTRO)
       save_gp((GV*)sv, !(PL_op->op_flags & OPf_SPECIAL));
    if (op_flags & OPf_ASSIGN) {
	if (op_flags & OPf_ASSIGN_PART) {
	    SV* src;
	    if (PL_stack_base + TOPMARK >= SP) {
		if ( ! (op_flags & OPf_OPTIONAL) )
		    Perl_croak(aTHX_ "Missing required assignment value");
		src = &PL_sv_undef;
	    } 
	    else
		src = POPs;
	    sv_setsv_mg(sv, src);
	    RETURN;
	}
	sv_setsv_mg(sv, POPs);
    }
    PUSHs(sv);
    RETURN;
}

PP(pp_rv2sv)
{
    dVAR; dSP;
    SV *sv = POPs;
    GV *gv = NULL;
    const bool is_pp_rv2sv = PL_op->op_type == OP_RV2SV;
    const bool is_pp_rv2av = PL_op->op_type == OP_RV2AV;
    const OPFLAGS op_flags = PL_op->op_flags;
    static const char an_array[] = "an ARRAY";
    static const char a_hash[] = "a HASH";
    static const char a_scalar[] = "a SCALAR";

    if (SvROK(sv)) {
	sv = SvRV(sv);
    }
    else {
	gv = (GV*)sv;

	if (SvTYPE(gv) != SVt_PVGV) {
	    Perl_croak(aTHX_ "Can't use %s as %s REF", Ddesc(sv), is_pp_rv2sv ? a_scalar : is_pp_rv2av ? an_array : a_hash);
	}

	sv = is_pp_rv2sv ? GvSVn(gv) : is_pp_rv2av ? (SV*)GvAVn(gv) : (SV*)GvHVn(gv);
    }
    if ( ! is_pp_rv2sv ) {
	if (is_pp_rv2av) {
	    if ( SvOK(sv) && ! SvAVOK(sv) )
		Perl_croak(aTHX_ "Expected an ARRAY reference but got a %s reference",
		    Ddesc(sv));
	}
	else {
	    if ( SvOK(sv) && ! SvHVOK(sv) )
		Perl_croak(aTHX_ "Expected a HASH reference but got a %s reference",
		    Ddesc(sv));
	}
    }
    if (PL_op->op_private & OPpLVAL_INTRO) {
	if (gv)
	    sv = is_pp_rv2sv ? save_scalar(gv) : is_pp_rv2av ? (SV*)save_ary(gv) : (SV*)save_hash(gv);
	else {
	    /* ignore localization of refs */
/* 	    Perl_croak(aTHX_ PL_no_localize_ref); */
	}
    }
    if (op_flags & OPf_ASSIGN) {
	if (op_flags & OPf_ASSIGN_PART) {
	    SV* src;
	    if (PL_stack_base + TOPMARK >= SP) {
		if ( ! (op_flags & OPf_OPTIONAL) )
		    Perl_croak(aTHX_ "Missing required assignment value");
		src = &PL_sv_undef;
	    } 
	    else
		src = POPs;
	    sv_setsv_mg(sv, src);
	    RETURN;
	}
	sv_setsv_mg(sv, POPs);
    }
    PUSHs(sv);
    RETURN;
}

PP(pp_pos)
{
    dVAR; dSP; dTARGET; dPOPss;

    do_arg_check(SP - MAXARG + 1);

    if (MAXARG > 1) {
	SSize_t pos;
	STRLEN len;
	STRLEN ulen = 0;
	MAGIC* found;
	SV* lsv = POPs;

	if (SvTYPE(lsv) >= SVt_PVMG && SvMAGIC(lsv))
	    found = mg_find(lsv, PERL_MAGIC_regex_global);
	else
	    found = NULL;
	if (!found) {
	    if (!SvOK(sv))
		RETPUSHUNDEF;
#ifdef PERL_OLD_COPY_ON_WRITE
	    if (SvIsCOW(lsv))
		sv_force_normal_flags(lsv, 0);
#endif
	    found = sv_magicext(lsv, NULL, PERL_MAGIC_regex_global, &PL_vtbl_mglob,
		NULL, 0);
	}
	else if (!SvOK(sv)) {
	    found->mg_len = -1;
	    RETPUSHUNDEF;
	}
	len = SvPOK(lsv) ? SvCUR(lsv) : sv_len(lsv);

	pos = SvIV(sv);

	if (IN_CODEPOINTS) {
	    ulen = sv_len_utf8(lsv);
	    if (ulen)
		len = ulen;
	}

	if (pos < 0) {
	    pos += len;
	    if (pos < 0)
		pos = 0;
	}
	else if (pos > (SSize_t)len)
	    pos = len;

	if (ulen) {
	    I32 p = pos;
	    sv_pos_u2b(lsv, &p, 0);
	    pos = p;
	}

	found->mg_len = pos;
	found->mg_flags &= ~MGf_MINMATCH;

	PUSHi(pos);
	RETURN;
    }
    else {
	if (SvTYPE(sv) >= SVt_PVMG && SvMAGIC(sv)) {
	    const MAGIC * const mg = mg_find(sv, PERL_MAGIC_regex_global);
	    if (mg && mg->mg_len >= 0) {
		I32 i = mg->mg_len;
		if (DO_UTF8(sv))
		    sv_pos_b2u(sv, &i);
		PUSHi(i);
		RETURN;
	    }
	}
	RETPUSHUNDEF;
    }
}

PP(pp_rv2cv)
{
    dVAR; dSP;
    GV *gv;
    const I32 flags = (PL_op->op_flags & OPf_SPECIAL)
	? 0
	: GV_ADD;
    /* We usually try to add a non-existent subroutine in case of AUTOLOAD. */
    /* (But not in defined().) */

    CV *cv = sv_2cv(TOPs, &gv, flags);
    if (cv) {
	if (CvCLONE(cv))
	    cv = svTcv(sv_mortalcopy(cvTsv(cv)));
    }
    else if ((flags == (GV_ADD|GV_NOEXPAND)) && gv && SvROK(gv)) {
	cv = (CV*)gv;
    }    
    else
	cv = (CV*)&PL_sv_undef;
    SETs((SV*)cv);
    RETURN;
}

PP(pp_prototype)
{
    dVAR; dSP;
    CV *cv;
    GV *gv;
    SV *ret = &PL_sv_undef;

    if (SvPOK(TOPs) && SvCUR(TOPs) >= 7) {
	const char * s = SvPVX_const(TOPs);
	if (strnEQ(s, "CORE::", 6)) {
	    const int code = keyword(s + 6, SvCUR(TOPs) - 6);
	    if (code < 0) {	/* Overridable. */
#define MAX_ARGS_OP ((sizeof(I32) - 1) * 2)
		int i = 0, n = 0, seen_question = 0, defgv = 0;
		I32 oa;
		char str[ MAX_ARGS_OP * 2 + 2 ]; /* One ';', one '\0' */

		if (code == -KEY_chop || code == -KEY_chomp
			|| code == -KEY_exec || code == -KEY_system)
		    goto set;
		if (code == -KEY_mkdir) {
		    ret = newSVpvs_flags("_;$", SVs_TEMP);
		    goto set;
		}
		if (code == -KEY_readpipe) {
		    s = "CORE::backtick";
		}
		while (i < MAXO) {	/* The slow way. */
		    if (strEQ(s + 6, PL_op_name[i])
			|| strEQ(s + 6, PL_op_desc[i]))
		    {
			goto found;
		    }
		    i++;
		}
		goto nonesuch;		/* Should not happen... */
	      found:
		defgv = PL_opargs[i] & OA_DEFGV;
		oa = PL_opargs[i] >> OASHIFT;
		while (oa) {
		    if (oa & OA_OPTIONAL && !seen_question && !defgv) {
			seen_question = 1;
			str[n++] = ';';
		    }
		    if ((oa & (OA_OPTIONAL - 1)) >= OA_AVREF
			&& (oa & (OA_OPTIONAL - 1)) <= OA_SCALARREF
			/* But globs are already references (kinda) */
			&& (oa & (OA_OPTIONAL - 1)) != OA_FILEREF
		    ) {
			str[n++] = '\\';
		    }
		    str[n++] = ("?$@@%&*$")[oa & (OA_OPTIONAL - 1)];
		    oa = oa >> 4;
		}
		if (defgv && str[n - 1] == '$')
		    str[n - 1] = '_';
		str[n++] = '\0';
		ret = newSVpvn_flags(str, n - 1, SVs_TEMP);
		goto set;
	    }
	    else if (code)		/* Non-Overridable */
		goto set;
	    else {			/* None such */
	      nonesuch:
		DIE(aTHX_ "Can't find an opnumber for \"%s\"", s+6);
	    }
	}
    }
    cv = sv_2cv(TOPs, &gv, 0);
    if (cv && SvPOK(cv))
	ret = newSVpvn_flags(SvPVX_const((SV*)cv), SvCUR(cv), SVs_TEMP);
  set:
    SETs(ret);
    RETURN;
}

PP(pp_anoncode)
{
    dVAR; dSP;
    CV* cv = (CV*)PAD_SV(PL_op->op_targ);
    if ( CvPADLIST(cv) && 
	( SvIV(PADLIST_NAMESV(CvPADLIST(cv), PAD_FLAGS_INDEX)) & PADf_CLONE ) )
	cv = svTcv(sv_mortalcopy(cvTsv(cv)));
    EXTEND(SP,1);
    PUSHs((SV*)cv);
    RETURN;
}

PP(pp_srefgen)
{
    dVAR; dSP;
    *SP = refto(*SP);
    RETURN;
}

PP(pp_refgen)
{
    dVAR; dSP; dMARK;
    if (GIMME != G_ARRAY) {
	if (++MARK <= SP)
	    *MARK = *SP;
	else
	    *MARK = &PL_sv_undef;
	*MARK = refto(*MARK);
	SP = MARK;
	RETURN;
    }
    EXTEND_MORTAL(SP - MARK);
    while (++MARK <= SP)
	*MARK = refto(*MARK);
    RETURN;
}

STATIC SV*
S_refto(pTHX_ SV *sv)
{
    dVAR;
    SV* rv;

    PERL_ARGS_ASSERT_REFTO;

    if (SvTYPE(sv) == SVt_PVAV) {
	if (!AvREAL((AV*)sv) && AvREIFY((AV*)sv))
	    av_reify((AV*)sv);
	SvTEMP_off(sv);
	SvREFCNT_inc_void_NN(sv);
    }
    else if (SvPADTMP(sv) && !IS_PADGV(sv))
        sv = newSVsv(sv);
    else {
	SvTEMP_off(sv);
	SvREFCNT_inc_void_NN(sv);
    }
    rv = sv_newmortal();
    sv_upgrade(rv, SVt_IV);
    SvRV_set(rv, sv);
    SvROK_on(rv);
    return rv;
}

PP(pp_ref)
{
    dVAR; dSP; dTARGET;
    const char *pv;
    SV * const sv = POPs;

    if (!sv || !SvROK(sv))
	RETPUSHNO;

    pv = sv_reftype(SvRV(sv),TRUE);
    PUSHp(pv, strlen(pv));
    RETURN;
}

PP(pp_bless)
{
    dVAR; dSP;
    HV *stash;

    if (MAXARG == 1)
	stash = CopSTASH(PL_curcop);
    else {
	SV * const ssv = POPs;
	STRLEN len;
	const char *ptr;

	if (ssv && SvROK(ssv))
	    Perl_croak(aTHX_ "Attempt to bless into a reference");
	ptr = SvPV_const(ssv,len);
	if (len == 0)
	    Perl_croak(aTHX_ "Attempt to bless to ''");
	stash = gv_stashpvn(ptr, len, GV_ADD);
    }

    (void)sv_bless(TOPs, stash);
    RETURN;
}

PP(pp_gelem)
{
    dVAR; dSP;

    SV *sv = POPs;
    const char * const elem = SvPV_nolen_const(sv);
    GV * const gv = (GV*)POPs;
    SV * tmpRef = NULL;

    sv = NULL;
    if (elem) {
	/* elem will always be NUL terminated.  */
	const char * const second_letter = elem + 1;
	switch (*elem) {
	case 'A':
	    if (strEQ(second_letter, "RRAY"))
		tmpRef = (SV*)GvAV(gv);
	    break;
	case 'C':
	    if (strEQ(second_letter, "ODE"))
		tmpRef = (SV*)GvCVu(gv);
	    break;
	case 'F':
	    if (strEQ(second_letter, "ILEHANDLE")) {
		/* finally deprecated in 5.8.0 */
		deprecate("*glob{FILEHANDLE}");
		tmpRef = (SV*)GvIOp(gv);
	    }
	    break;
	case 'G':
	    if (strEQ(second_letter, "LOB"))
		tmpRef = (SV*)gv;
	    break;
	case 'H':
	    if (strEQ(second_letter, "ASH"))
		tmpRef = (SV*)GvHV(gv);
	    break;
	case 'I':
	    if (*second_letter == 'O' && !elem[2])
		tmpRef = (SV*)GvIOp(gv);
	    break;
	case 'N':
	    if (strEQ(second_letter, "AME"))
		sv = newSVhek(GvNAME_HEK(gv));
	    break;
	case 'P':
	    if (strEQ(second_letter, "ACKAGE")) {
		const HV * const stash = GvSTASH(gv);
		const HEK * const hek = stash ? HvNAME_HEK(stash) : NULL;
		sv = hek ? newSVhek(hek) : newSVpvs("__ANON__");
	    }
	    break;
	case 'S':
	    if (strEQ(second_letter, "CALAR"))
		tmpRef = GvSVn(gv);
	    break;
	}
    }
    if (tmpRef)
	sv = newRV(tmpRef);
    if (sv)
	sv_2mortal(sv);
    else
	sv = &PL_sv_undef;
    XPUSHs(sv);
    RETURN;
}

/* Pattern matching */

PP(pp_study)
{
    dVAR; dSP; dPOPss;
    register unsigned char *s;
    register I32 pos;
    register I32 ch;
    register I32 *sfirst;
    register I32 *snext;
    STRLEN len;

    do_arg_check(SP-1);

    if (sv == PL_lastscream) {
	if (SvSCREAM(sv))
	    RETPUSHYES;
    }
    s = (unsigned char*)(SvPV(sv, len));
    pos = len;
    if (pos <= 0 || !SvPOK(sv)) {
	/* No point in studying a zero length string, and not safe to study
	   anything that doesn't appear to be a simple scalar (and hence might
	   change between now and when the regexp engine runs without our set
	   magic ever running) such as a reference to an object with overloaded
	   stringification.  */
	RETPUSHNO;
    }

    if (PL_lastscream) {
	SvSCREAM_off(PL_lastscream);
	SvREFCNT_dec(PL_lastscream);
    }
    PL_lastscream = SvREFCNT_inc(sv);

    s = (unsigned char*)(SvPV(sv, len));
    pos = len;
    if (pos <= 0)
	RETPUSHNO;
    if (pos > PL_maxscream) {
	if (PL_maxscream < 0) {
	    PL_maxscream = pos + 80;
	    Newx(PL_screamfirst, 256, I32);
	    Newx(PL_screamnext, PL_maxscream, I32);
	}
	else {
	    PL_maxscream = pos + pos / 4;
	    Renew(PL_screamnext, PL_maxscream, I32);
	}
    }

    sfirst = PL_screamfirst;
    snext = PL_screamnext;

    if (!sfirst || !snext)
	DIE(aTHX_ "do_study: out of memory");

    for (ch = 256; ch; --ch)
	*sfirst++ = -1;
    sfirst -= 256;

    while (--pos >= 0) {
	register const I32 ch = s[pos];
	if (sfirst[ch] >= 0)
	    snext[pos] = sfirst[ch] - pos;
	else
	    snext[pos] = -pos;
	sfirst[ch] = pos;
    }

    SvSCREAM_on(sv);
    /* piggyback on m//g magic */
    sv_magic(sv, NULL, PERL_MAGIC_regex_global, NULL, 0);
    RETPUSHYES;
}

/* Lvalue operators. */

PP(pp_chop)
{
    dVAR; dSP; dTARGET;
    do_arg_check(SP-1);
    do_chop(TARG, TOPs);
    SETTARG;
    RETURN;
}

PP(pp_chomp)
{
    dVAR; dSP; dTARGET;
    do_arg_check(SP-1);
    SETi(do_chomp(TOPs));
    RETURN;
}

PP(pp_undef)
{
    dVAR; dSP;
    SV *sv;

    if (!PL_op->op_private) {
	EXTEND(SP, 1);
	RETPUSHUNDEF;
    }

    sv = POPs;
    if (!sv)
	RETPUSHUNDEF;

    SV_CHECK_THINKFIRST_COW_DROP(sv);

    switch (SvTYPE(sv)) {
    case SVt_NULL:
	break;
    case SVt_PVAV:
	av_undef((AV*)sv);
	break;
    case SVt_PVHV:
	hv_undef((HV*)sv);
	break;
    case SVt_PVCV:
	cv_undef((CV*)sv);
	break;
    case SVt_PVGV:
	if (SvFAKE(sv))
	    SvSetMagicSV(sv, &PL_sv_undef);
	else {
	    GP *gp;
            HV *stash;

            /* undef *Foo:: */
            if((stash = GvHV((GV*)sv)) && HvNAME_get(stash))
                mro_isa_changed_in(stash);
            /* undef *Pkg::meth_name ... */
            else if(GvCVu((GV*)sv) && (stash = GvSTASH((GV*)sv)) && HvNAME_get(stash))
                mro_method_changed_in(stash);

	    gp_free((GV*)sv);
	    Newxz(gp, 1, GP);
	    GvGP(sv) = gp_ref(gp);
	    GvSV(sv) = newSV(0);
	    GvEGV(sv) = (GV*)sv;
	    GvMULTI_on(sv);
	}
	break;
    default:
	if (SvTYPE(sv) >= SVt_PV && SvPVX_const(sv) && SvLEN(sv)) {
	    SvPV_free(sv);
	    SvPV_set(sv, NULL);
	    SvLEN_set(sv, 0);
	}
	SvOK_off(sv);
	SvSETMAGIC(sv);
    }

    RETPUSHUNDEF;
}

PP(pp_predec)
{
    dVAR; dSP;
    if (SvTYPE(TOPs) >= SVt_PVGV)
	DIE(aTHX_ PL_no_modify);
    if (!SvREADONLY(TOPs) && SvIOK_notUV(TOPs) && !SvNOK(TOPs) && !SvPOK(TOPs)
        && SvIVX(TOPs) != IV_MIN)
    {
	SvIV_set(TOPs, SvIVX(TOPs) - 1);
	SvFLAGS(TOPs) &= ~(SVp_NOK|SVp_POK);
    }
    else
	sv_dec(TOPs);
    SvSETMAGIC(TOPs);
    return NORMAL;
}

PP(pp_postinc)
{
    dVAR; dSP; dTARGET;
    if ( SvOK(TOPs) && ! SvPVOK(TOPs) )
	Perl_croak(aTHX_ "increment (++) does not work on a %s", Ddesc(TOPs));
    sv_setsv(TARG, TOPs);
    if (!SvREADONLY(TOPs) && SvIOK_notUV(TOPs) && !SvNOK(TOPs) && !SvPOK(TOPs)
        && SvIVX(TOPs) != IV_MAX)
    {
	SvIV_set(TOPs, SvIVX(TOPs) + 1);
	SvFLAGS(TOPs) &= ~(SVp_NOK|SVp_POK);
    }
    else
	sv_inc(TOPs);
    SvSETMAGIC(TOPs);
    /* special case for undef: see thread at 2003-03/msg00536.html in archive */
    if (!SvOK(TARG))
	sv_setiv(TARG, 0);
    SETs(TARG);
    return NORMAL;
}

PP(pp_postdec)
{
    dVAR; dSP; dTARGET;
    if (SvTYPE(TOPs) >= SVt_PVGV)
	DIE(aTHX_ PL_no_modify);
    sv_setsv(TARG, TOPs);
    if (!SvREADONLY(TOPs) && SvIOK_notUV(TOPs) && !SvNOK(TOPs) && !SvPOK(TOPs)
        && SvIVX(TOPs) != IV_MIN)
    {
	SvIV_set(TOPs, SvIVX(TOPs) - 1);
	SvFLAGS(TOPs) &= ~(SVp_NOK|SVp_POK);
    }
    else
	sv_dec(TOPs);
    SvSETMAGIC(TOPs);
    SETs(TARG);
    return NORMAL;
}

/* Ordinary operators. */

PP(pp_pow)
{
    dVAR; dSP; dATARGET; SV *svl, *svr;
#ifdef PERL_PRESERVE_IVUV
    bool is_int = 0;
#endif
    svl = sv_2num(TOPm1s);
    svr = sv_2num(TOPs);
#ifdef PERL_PRESERVE_IVUV
    /* For integer to integer power, we do the calculation by hand wherever
       we're sure it is safe; otherwise we call pow() and try to convert to
       integer afterwards. */
    {
	if (SvIOK(svr)) {
	    if (SvIOK(svl)) {
		UV power;
		bool baseuok;
		UV baseuv;

		if (SvUOK(svr)) {
		    power = SvUVX(svr);
		} else {
		    const IV iv = SvIVX(svr);
		    if (iv >= 0) {
			power = iv;
		    } else {
			goto float_it; /* Can't do negative powers this way.  */
		    }
		}

		baseuok = SvUOK(svl);
		if (baseuok) {
		    baseuv = SvUVX(svl);
		} else {
		    const IV iv = SvIVX(svl);
		    if (iv >= 0) {
			baseuv = iv;
			baseuok = TRUE; /* effectively it's a UV now */
		    } else {
			baseuv = -iv; /* abs, baseuok == false records sign */
		    }
		}
                /* now we have integer ** positive integer. */
                is_int = 1;

                /* foo & (foo - 1) is zero only for a power of 2.  */
                if (!(baseuv & (baseuv - 1))) {
                    /* We are raising power-of-2 to a positive integer.
                       The logic here will work for any base (even non-integer
                       bases) but it can be less accurate than
                       pow (base,power) or exp (power * log (base)) when the
                       intermediate values start to spill out of the mantissa.
                       With powers of 2 we know this can't happen.
                       And powers of 2 are the favourite thing for perl
                       programmers to notice ** not doing what they mean. */
                    NV result = 1.0;
                    NV base = baseuok ? baseuv : -(NV)baseuv;

		    if (power & 1) {
			result *= base;
		    }
		    while (power >>= 1) {
			base *= base;
			if (power & 1) {
			    result *= base;
			}
		    }
                    SP--;
                    SETn( result );
                    RETURN;
		} else {
		    register unsigned int highbit = 8 * sizeof(UV);
		    register unsigned int diff = 8 * sizeof(UV);
		    while (diff >>= 1) {
			highbit -= diff;
			if (baseuv >> highbit) {
			    highbit += diff;
			}
		    }
		    /* we now have baseuv < 2 ** highbit */
		    if (power * highbit <= 8 * sizeof(UV)) {
			/* result will definitely fit in UV, so use UV math
			   on same algorithm as above */
			register UV result = 1;
			register UV base = baseuv;
			const bool odd_power = (bool)(power & 1);
			if (odd_power) {
			    result *= base;
			}
			while (power >>= 1) {
			    base *= base;
			    if (power & 1) {
				result *= base;
			    }
			}
			SP--;
			if (baseuok || !odd_power)
			    /* answer is positive */
			    SETu( result );
			else if (result <= (UV)IV_MAX)
			    /* answer negative, fits in IV */
			    SETi( -(IV)result );
			else if (result == (UV)IV_MIN) 
			    /* 2's complement assumption: special case IV_MIN */
			    SETi( IV_MIN );
			else
			    /* answer negative, doesn't fit */
			    SETn( -(NV)result );
			RETURN;
		    } 
		}
	    }
	}
    }
  float_it:
#endif    
    {
	NV right = SvNV(svr);
	NV left  = SvNV(svl);
	(void)POPs;

#if defined(USE_LONG_DOUBLE) && defined(HAS_AIX_POWL_NEG_BASE_BUG)
    /*
    We are building perl with long double support and are on an AIX OS
    afflicted with a powl() function that wrongly returns NaNQ for any
    negative base.  This was reported to IBM as PMR #23047-379 on
    03/06/2006.  The problem exists in at least the following versions
    of AIX and the libm fileset, and no doubt others as well:

	AIX 4.3.3-ML10      bos.adt.libm 4.3.3.50
	AIX 5.1.0-ML04      bos.adt.libm 5.1.0.29
	AIX 5.2.0           bos.adt.libm 5.2.0.85

    So, until IBM fixes powl(), we provide the following workaround to
    handle the problem ourselves.  Our logic is as follows: for
    negative bases (left), we use fmod(right, 2) to check if the
    exponent is an odd or even integer:

	- if odd,  powl(left, right) == -powl(-left, right)
	- if even, powl(left, right) ==  powl(-left, right)

    If the exponent is not an integer, the result is rightly NaNQ, so
    we just return that (as NV_NAN).
    */

	if (left < 0.0) {
	    NV mod2 = Perl_fmod( right, 2.0 );
	    if (mod2 == 1.0 || mod2 == -1.0) {	/* odd integer */
		SETn( -Perl_pow( -left, right) );
	    } else if (mod2 == 0.0) {		/* even integer */
		SETn( Perl_pow( -left, right) );
	    } else {				/* fractional power */
		SETn( NV_NAN );
	    }
	} else {
	    SETn( Perl_pow( left, right) );
	}
#else
	SETn( Perl_pow( left, right) );
#endif  /* HAS_AIX_POWL_NEG_BASE_BUG */

	RETURN;
    }
}

PP(pp_multiply)
{
    dVAR; dSP; dATARGET; SV *svl, *svr;
    svl = sv_2num(TOPm1s);
    svr = sv_2num(TOPs);
#ifdef PERL_PRESERVE_IVUV
    if (SvIOK(svr)) {
	/* Unless the left argument is integer in range we are going to have to
	   use NV maths. Hence only attempt to coerce the right argument if
	   we know the left is integer.  */
	/* Left operand is defined, so is it IV? */
	if (SvIOK(svl)) {
	    bool auvok = SvUOK(svl);
	    bool buvok = SvUOK(svr);
	    const UV topmask = (~ (UV)0) << (4 * sizeof (UV));
	    const UV botmask = ~((~ (UV)0) << (4 * sizeof (UV)));
	    UV alow;
	    UV ahigh;
	    UV blow;
	    UV bhigh;

	    if (auvok) {
		alow = SvUVX(svl);
	    } else {
		const IV aiv = SvIVX(svl);
		if (aiv >= 0) {
		    alow = aiv;
		    auvok = TRUE; /* effectively it's a UV now */
		} else {
		    alow = -aiv; /* abs, auvok == false records sign */
		}
	    }
	    if (buvok) {
		blow = SvUVX(svr);
	    } else {
		const IV biv = SvIVX(svr);
		if (biv >= 0) {
		    blow = biv;
		    buvok = TRUE; /* effectively it's a UV now */
		} else {
		    blow = -biv; /* abs, buvok == false records sign */
		}
	    }

	    /* If this does sign extension on unsigned it's time for plan B  */
	    ahigh = alow >> (4 * sizeof (UV));
	    alow &= botmask;
	    bhigh = blow >> (4 * sizeof (UV));
	    blow &= botmask;
	    if (ahigh && bhigh) {
		NOOP;
		/* eg 32 bit is at least 0x10000 * 0x10000 == 0x100000000
		   which is overflow. Drop to NVs below.  */
	    } else if (!ahigh && !bhigh) {
		/* eg 32 bit is at most 0xFFFF * 0xFFFF == 0xFFFE0001
		   so the unsigned multiply cannot overflow.  */
		const UV product = alow * blow;
		if (auvok == buvok) {
		    /* -ve * -ve or +ve * +ve gives a +ve result.  */
		    SP--;
		    SETu( product );
		    RETURN;
		} else if (product <= (UV)IV_MIN) {
		    /* 2s complement assumption that (UV)-IV_MIN is correct.  */
		    /* -ve result, which could overflow an IV  */
		    SP--;
		    SETi( -(IV)product );
		    RETURN;
		} /* else drop to NVs below. */
	    } else {
		/* One operand is large, 1 small */
		UV product_middle;
		if (bhigh) {
		    /* swap the operands */
		    ahigh = bhigh;
		    bhigh = blow; /* bhigh now the temp var for the swap */
		    blow = alow;
		    alow = bhigh;
		}
		/* now, ((ahigh * blow) << half_UV_len) + (alow * blow)
		   multiplies can't overflow. shift can, add can, -ve can.  */
		product_middle = ahigh * blow;
		if (!(product_middle & topmask)) {
		    /* OK, (ahigh * blow) won't lose bits when we shift it.  */
		    UV product_low;
		    product_middle <<= (4 * sizeof (UV));
		    product_low = alow * blow;

		    /* as for pp_add, UV + something mustn't get smaller.
		       IIRC ANSI mandates this wrapping *behaviour* for
		       unsigned whatever the actual representation*/
		    product_low += product_middle;
		    if (product_low >= product_middle) {
			/* didn't overflow */
			if (auvok == buvok) {
			    /* -ve * -ve or +ve * +ve gives a +ve result.  */
			    SP--;
			    SETu( product_low );
			    RETURN;
			} else if (product_low <= (UV)IV_MIN) {
			    /* 2s complement assumption again  */
			    /* -ve result, which could overflow an IV  */
			    SP--;
			    SETi( -(IV)product_low );
			    RETURN;
			} /* else drop to NVs below. */
		    }
		} /* product_middle too large */
	    } /* ahigh && bhigh */
	} /* SvIOK(svl) */
    } /* SvIOK(svr) */
#endif
    {
      NV right = SvNV(svr);
      NV left  = SvNV(svl);
      (void)POPs;
      SETn( left * right );
      RETURN;
    }
}

PP(pp_divide)
{
    dVAR; dSP; dATARGET; SV *svl, *svr;
    svl = sv_2num(TOPm1s);
    svr = sv_2num(TOPs);
    /* Only try to do UV divide first
       if ((SLOPPYDIVIDE is true) or
           (PERL_PRESERVE_IVUV is true and one or both SV is a UV too large
            to preserve))
       The assumption is that it is better to use floating point divide
       whenever possible, only doing integer divide first if we can't be sure.
       If NV_PRESERVES_UV is true then we know at compile time that no UV
       can be too large to preserve, so don't need to compile the code to
       test the size of UVs.  */

#ifdef SLOPPYDIVIDE
#  define PERL_TRY_UV_DIVIDE
    /* ensure that 20./5. == 4. */
#else
#  ifdef PERL_PRESERVE_IVUV
#    ifndef NV_PRESERVES_UV
#      define PERL_TRY_UV_DIVIDE
#    endif
#  endif
#endif

#ifdef PERL_TRY_UV_DIVIDE
    if (SvIOK(svr)) {
        if (SvIOK(svl)) {
            bool left_non_neg = SvUOK(svl);
            bool right_non_neg = SvUOK(svr);
            UV left;
            UV right;

            if (right_non_neg) {
                right = SvUVX(svr);
            }
	    else {
		const IV biv = SvIVX(svr);
                if (biv >= 0) {
                    right = biv;
                    right_non_neg = TRUE; /* effectively it's a UV now */
                }
		else {
                    right = -biv;
                }
            }
            /* historically undef()/0 gives a "Use of uninitialized value"
               warning before dieing, hence this test goes here.
               If it were immediately before the second SvIV_please, then
               DIE() would be invoked before left was even inspected, so
               no inpsection would give no warning.  */
            if (right == 0)
                DIE(aTHX_ "Illegal division by zero");

            if (left_non_neg) {
                left = SvUVX(svl);
            }
	    else {
		const IV aiv = SvIVX(svl);
                if (aiv >= 0) {
                    left = aiv;
                    left_non_neg = TRUE; /* effectively it's a UV now */
                }
		else {
                    left = -aiv;
                }
            }

            if (left >= right
#ifdef SLOPPYDIVIDE
                /* For sloppy divide we always attempt integer division.  */
#else
                /* Otherwise we only attempt it if either or both operands
                   would not be preserved by an NV.  If both fit in NVs
                   we fall through to the NV divide code below.  However,
                   as left >= right to ensure integer result here, we know that
                   we can skip the test on the right operand - right big
                   enough not to be preserved can't get here unless left is
                   also too big.  */

                && (left > ((UV)1 << NV_PRESERVES_UV_BITS))
#endif
                ) {
                /* Integer division can't overflow, but it can be imprecise.  */
		const UV result = left / right;
                if (result * right == left) {
                    SP--; /* result is valid */
                    if (left_non_neg == right_non_neg) {
                        /* signs identical, result is positive.  */
                        SETu( result );
                        RETURN;
                    }
                    /* 2s complement assumption */
                    if (result <= (UV)IV_MIN)
                        SETi( -(IV)result );
                    else {
                        /* It's exact but too negative for IV. */
                        SETn( -(NV)result );
                    }
                    RETURN;
                } /* tried integer divide but it was not an integer result */
            } /* else (PERL_ABS(result) < 1.0) or (both UVs in range for NV) */
        } /* left wasn't SvIOK */
    } /* right wasn't SvIOK */
#endif /* PERL_TRY_UV_DIVIDE */
    {
	NV right = SvNV(svr);
	NV left  = SvNV(svl);
	(void)POPs;(void)POPs;
#if defined(NAN_COMPARE_BROKEN) && defined(Perl_isnan)
	if (! Perl_isnan(right) && right == 0.0)
#else
	if (right == 0.0)
#endif
	    DIE(aTHX_ "Illegal division by zero");
	PUSHn( left / right );
	RETURN;
    }
}

PP(pp_modulo)
{
    dVAR; dSP; dATARGET;
    {
	UV left  = 0;
	UV right = 0;
	bool left_neg = FALSE;
	bool right_neg = FALSE;
	bool use_double = FALSE;
	bool dright_valid = FALSE;
	NV dright = 0.0;
	NV dleft  = 0.0;
        SV * svl;
        SV * const svr = sv_2num(TOPs);
        if (SvIOK(svr)) {
            right_neg = !SvUOK(svr);
            if (!right_neg) {
                right = SvUVX(svr);
            } else {
		const IV biv = SvIVX(svr);
                if (biv >= 0) {
                    right = biv;
                    right_neg = FALSE; /* effectively it's a UV now */
                } else {
                    right = -biv;
                }
            }
        }
        else {
	    dright = SvNV(svr);
	    right_neg = dright < 0;
	    if (right_neg)
		dright = -dright;
            if (dright < UV_MAX_P1) {
                right = U_V(dright);
                dright_valid = TRUE; /* In case we need to use double below.  */
            } else {
                use_double = TRUE;
            }
	}
	sp--;

        /* At this point use_double is only true if right is out of range for
           a UV.  In range NV has been rounded down to nearest UV and
           use_double false.  */
        svl = sv_2num(TOPs);
	if (!use_double && SvIOK(svl)) {
            if (SvIOK(svl)) {
                left_neg = !SvUOK(svl);
                if (!left_neg) {
                    left = SvUVX(svl);
                } else {
		    const IV aiv = SvIVX(svl);
                    if (aiv >= 0) {
                        left = aiv;
                        left_neg = FALSE; /* effectively it's a UV now */
                    } else {
                        left = -aiv;
                    }
                }
            }
        }
	else {
	    dleft = SvNV(svl);
	    left_neg = dleft < 0;
	    if (left_neg)
		dleft = -dleft;

            /* This should be exactly the 5.6 behaviour - if left and right are
               both in range for UV then use U_V() rather than floor.  */
	    if (!use_double) {
                if (dleft < UV_MAX_P1) {
                    /* right was in range, so is dleft, so use UVs not double.
                     */
                    left = U_V(dleft);
                }
                /* left is out of range for UV, right was in range, so promote
                   right (back) to double.  */
                else {
                    /* The +0.5 is used in 5.6 even though it is not strictly
                       consistent with the implicit +0 floor in the U_V()
                       inside the #if 1. */
                    dleft = Perl_floor(dleft + 0.5);
                    use_double = TRUE;
                    if (dright_valid)
                        dright = Perl_floor(dright + 0.5);
                    else
                        dright = right;
                }
            }
        }
	sp--;
	if (use_double) {
	    NV dans;

	    if (!dright)
		DIE(aTHX_ "Illegal modulus zero");

	    dans = Perl_fmod(dleft, dright);
	    if ((left_neg != right_neg) && dans)
		dans = dright - dans;
	    if (right_neg)
		dans = -dans;
	    sv_setnv(TARG, dans);
	}
	else {
	    UV ans;

	    if (!right)
		DIE(aTHX_ "Illegal modulus zero");

	    ans = left % right;
	    if ((left_neg != right_neg) && ans)
		ans = right - ans;
	    if (right_neg) {
		/* XXX may warn: unary minus operator applied to unsigned type */
		/* could change -foo to be (~foo)+1 instead	*/
		if (ans <= ~((UV)IV_MAX)+1)
		    sv_setiv(TARG, ~ans+1);
		else
		    sv_setnv(TARG, -(NV)ans);
	    }
	    else
		sv_setuv(TARG, ans);
	}
	PUSHTARG;
	RETURN;
    }
}

PP(pp_repeat)
{
  dVAR; dSP; dATARGET;
  {
    register IV count;
    dPOPss;
    if (SvIOKp(sv)) {
	 if (SvUOK(sv)) {
	      const UV uv = SvUV(sv);
	      if (uv > IV_MAX)
		   count = IV_MAX; /* The best we can do? */
	      else
		   count = uv;
	 } else {
	      const IV iv = SvIV(sv);
	      if (iv < 0)
		   count = 0;
	      else
		   count = iv;
	 }
    }
    else if (SvNOKp(sv)) {
	 const NV nv = SvNV(sv);
	 if (nv < 0.0)
	      count = 0;
	 else
	      count = (IV)nv;
    }
    else
	 count = SvIV(sv);
    if (SvAVOK(TOPs)) {
	AV* src = svTav(POPs);
	AV* dst = av_2mortal(newAV());
	const IV len = av_len(src);
	IV i;
	for ( ; count > 0 ; count--) {
	    for (i=0; i<=len; i++) {
		av_push(dst, newSVsv(*av_fetch(src, i, 0)));
	    }
	}
	PUSHs(avTsv(dst));
    }
    else {	/* Note: mark already snarfed by pp_list */
	SV * const tmpstr = POPs;
	STRLEN len;
	bool isutf;
	static const char oom_string_extend[] =
	  "Out of memory during string extend";

	SvSetSV(TARG, tmpstr);
	SvPV_force(TARG, len);
	isutf = DO_UTF8(TARG);
	if (count != 1) {
	    if (count < 1)
		SvCUR_set(TARG, 0);
	    else {
		const STRLEN max = (UV)count * len;
		if (len > MEM_SIZE_MAX / count)
		     Perl_croak(aTHX_ oom_string_extend);
	        MEM_WRAP_CHECK_1(max, char, oom_string_extend);
		SvGROW(TARG, max + 1);
		repeatcpy(SvPVX_mutable(TARG) + len, SvPVX_mutable(TARG), len, count - 1);
		SvCUR_set(TARG, SvCUR(TARG) * count);
	    }
	    *SvEND(TARG) = '\0';
	}
	(void)SvPOK_only(TARG);

	if (PL_op->op_private & OPpREPEAT_DOLIST) {
	    /* The parser saw this as a list repeat, and there
	       are probably several items on the stack. But we're
	       in scalar context, and there's no pp_list to save us
	       now. So drop the rest of the items -- robin@kitsite.com
	     */
	    dMARK;
	    SP = MARK;
	}
	PUSHTARG;
    }
    RETURN;
  }
}

PP(pp_subtract)
{
    dVAR; dSP; dATARGET; bool useleft; SV *svl, *svr;
    svl = sv_2num(TOPm1s);
    svr = sv_2num(TOPs);
    useleft = USE_LEFT(svl);
#ifdef PERL_PRESERVE_IVUV
    /* See comments in pp_add (in pp_hot.c) about Overflow, and how
       "bad things" happen if you rely on signed integers wrapping.  */
    if (SvIOK(svr)) {
	/* Unless the left argument is integer in range we are going to have to
	   use NV maths. Hence only attempt to coerce the right argument if
	   we know the left is integer.  */
	register UV auv = 0;
	bool auvok = FALSE;
	bool a_valid = 0;

	if (!useleft) {
	    auv = 0;
	    a_valid = auvok = 1;
	    /* left operand is undef, treat as zero.  */
	} else {
	    /* Left operand is defined, so is it IV? */
	    if (SvIOK(svl)) {
		if ((auvok = SvUOK(svl)))
		    auv = SvUVX(svl);
		else {
		    register const IV aiv = SvIVX(svl);
		    if (aiv >= 0) {
			auv = aiv;
			auvok = 1;	/* Now acting as a sign flag.  */
		    } else { /* 2s complement assumption for IV_MIN */
			auv = (UV)-aiv;
		    }
		}
		a_valid = 1;
	    }
	}
	if (a_valid) {
	    bool result_good = 0;
	    UV result;
	    register UV buv;
	    bool buvok = SvUOK(svr);
	
	    if (buvok)
		buv = SvUVX(svr);
	    else {
		register const IV biv = SvIVX(svr);
		if (biv >= 0) {
		    buv = biv;
		    buvok = 1;
		} else
		    buv = (UV)-biv;
	    }
	    /* ?uvok if value is >= 0. basically, flagged as UV if it's +ve,
	       else "IV" now, independent of how it came in.
	       if a, b represents positive, A, B negative, a maps to -A etc
	       a - b =>  (a - b)
	       A - b => -(a + b)
	       a - B =>  (a + b)
	       A - B => -(a - b)
	       all UV maths. negate result if A negative.
	       subtract if signs same, add if signs differ. */

	    if (auvok ^ buvok) {
		/* Signs differ.  */
		result = auv + buv;
		if (result >= auv)
		    result_good = 1;
	    } else {
		/* Signs same */
		if (auv >= buv) {
		    result = auv - buv;
		    /* Must get smaller */
		    if (result <= auv)
			result_good = 1;
		} else {
		    result = buv - auv;
		    if (result <= buv) {
			/* result really should be -(auv-buv). as its negation
			   of true value, need to swap our result flag  */
			auvok = !auvok;
			result_good = 1;
		    }
		}
	    }
	    if (result_good) {
		SP--;
		if (auvok)
		    SETu( result );
		else {
		    /* Negate result */
		    if (result <= (UV)IV_MIN)
			SETi( -(IV)result );
		    else {
			/* result valid, but out of range for IV.  */
			SETn( -(NV)result );
		    }
		}
		RETURN;
	    } /* Overflow, drop through to NVs.  */
	}
    }
#endif
    {
	NV value = SvNV(svr);
	(void)POPs;

	if (!useleft) {
	    /* left operand is undef, treat as zero - value */
	    SETn(-value);
	    RETURN;
	}
	SETn( SvNV(svl) - value );
	RETURN;
    }
}

PP(pp_left_shift)
{
    dVAR; dSP; dATARGET;
    {
      const IV shift = POPi;
      if (PL_op->op_private & HINT_INTEGER) {
	const IV i = TOPi;
	SETi(i << shift);
      }
      else {
	const UV u = TOPu;
	SETu(u << shift);
      }
      RETURN;
    }
}

PP(pp_right_shift)
{
    dVAR; dSP; dATARGET;
    {
      const IV shift = POPi;
      if (PL_op->op_private & HINT_INTEGER) {
	const IV i = TOPi;
	SETi(i >> shift);
      }
      else {
	const UV u = TOPu;
	SETu(u >> shift);
      }
      RETURN;
    }
}

PP(pp_lt)
{
    dVAR; dSP;
#ifdef PERL_PRESERVE_IVUV
    if (SvIOK(TOPs)) {
	if (SvIOK(TOPm1s)) {
	    bool auvok = SvUOK(TOPm1s);
	    bool buvok = SvUOK(TOPs);
	
	    if (!auvok && !buvok) { /* ## IV < IV ## */
		const IV aiv = SvIVX(TOPm1s);
		const IV biv = SvIVX(TOPs);
		
		SP--;
		SETs(boolSV(aiv < biv));
		RETURN;
	    }
	    if (auvok && buvok) { /* ## UV < UV ## */
		const UV auv = SvUVX(TOPm1s);
		const UV buv = SvUVX(TOPs);
		
		SP--;
		SETs(boolSV(auv < buv));
		RETURN;
	    }
	    if (auvok) { /* ## UV < IV ## */
		UV auv;
		const IV biv = SvIVX(TOPs);
		SP--;
		if (biv < 0) {
		    /* As (a) is a UV, it's >=0, so it cannot be < */
		    SETs(&PL_sv_no);
		    RETURN;
		}
		auv = SvUVX(TOPs);
		SETs(boolSV(auv < (UV)biv));
		RETURN;
	    }
	    { /* ## IV < UV ## */
		const IV aiv = SvIVX(TOPm1s);
		UV buv;
		
		if (aiv < 0) {
		    /* As (b) is a UV, it's >=0, so it must be < */
		    SP--;
		    SETs(&PL_sv_yes);
		    RETURN;
		}
		buv = SvUVX(TOPs);
		SP--;
		SETs(boolSV((UV)aiv < buv));
		RETURN;
	    }
	}
    }
#endif
    {
#if defined(NAN_COMPARE_BROKEN) && defined(Perl_isnan)
      dPOPTOPnnrl;
      if (Perl_isnan(left) || Perl_isnan(right))
	  RETSETNO;
      SETs(boolSV(left < right));
#else
      dPOPnv;
      SETs(boolSV(TOPn < value));
#endif
      RETURN;
    }
}

PP(pp_gt)
{
    dVAR; dSP;
#ifdef PERL_PRESERVE_IVUV
    if (SvIOK(TOPs)) {
	if (SvIOK(TOPm1s)) {
	    bool auvok = SvUOK(TOPm1s);
	    bool buvok = SvUOK(TOPs);
	
	    if (!auvok && !buvok) { /* ## IV > IV ## */
		const IV aiv = SvIVX(TOPm1s);
		const IV biv = SvIVX(TOPs);

		SP--;
		SETs(boolSV(aiv > biv));
		RETURN;
	    }
	    if (auvok && buvok) { /* ## UV > UV ## */
		const UV auv = SvUVX(TOPm1s);
		const UV buv = SvUVX(TOPs);
		
		SP--;
		SETs(boolSV(auv > buv));
		RETURN;
	    }
	    if (auvok) { /* ## UV > IV ## */
		UV auv;
		const IV biv = SvIVX(TOPs);

		SP--;
		if (biv < 0) {
		    /* As (a) is a UV, it's >=0, so it must be > */
		    SETs(&PL_sv_yes);
		    RETURN;
		}
		auv = SvUVX(TOPs);
		SETs(boolSV(auv > (UV)biv));
		RETURN;
	    }
	    { /* ## IV > UV ## */
		const IV aiv = SvIVX(TOPm1s);
		UV buv;
		
		if (aiv < 0) {
		    /* As (b) is a UV, it's >=0, so it cannot be > */
		    SP--;
		    SETs(&PL_sv_no);
		    RETURN;
		}
		buv = SvUVX(TOPs);
		SP--;
		SETs(boolSV((UV)aiv > buv));
		RETURN;
	    }
	}
    }
#endif
    {
#if defined(NAN_COMPARE_BROKEN) && defined(Perl_isnan)
      dPOPTOPnnrl;
      if (Perl_isnan(left) || Perl_isnan(right))
	  RETSETNO;
      SETs(boolSV(left > right));
#else
      dPOPnv;
      SETs(boolSV(TOPn > value));
#endif
      RETURN;
    }
}

PP(pp_le)
{
    dVAR; dSP;
#ifdef PERL_PRESERVE_IVUV
    if (SvIOK(TOPs)) {
	if (SvIOK(TOPm1s)) {
	    bool auvok = SvUOK(TOPm1s);
	    bool buvok = SvUOK(TOPs);
	
	    if (!auvok && !buvok) { /* ## IV <= IV ## */
		const IV aiv = SvIVX(TOPm1s);
		const IV biv = SvIVX(TOPs);
		
		SP--;
		SETs(boolSV(aiv <= biv));
		RETURN;
	    }
	    if (auvok && buvok) { /* ## UV <= UV ## */
		UV auv = SvUVX(TOPm1s);
		UV buv = SvUVX(TOPs);
		
		SP--;
		SETs(boolSV(auv <= buv));
		RETURN;
	    }
	    if (auvok) { /* ## UV <= IV ## */
		UV auv;
		const IV biv = SvIVX(TOPs);

		SP--;
		if (biv < 0) {
		    /* As (a) is a UV, it's >=0, so a cannot be <= */
		    SETs(&PL_sv_no);
		    RETURN;
		}
		auv = SvUVX(TOPs);
		SETs(boolSV(auv <= (UV)biv));
		RETURN;
	    }
	    { /* ## IV <= UV ## */
		const IV aiv = SvIVX(TOPm1s);
		UV buv;

		if (aiv < 0) {
		    /* As (b) is a UV, it's >=0, so a must be <= */
		    SP--;
		    SETs(&PL_sv_yes);
		    RETURN;
		}
		buv = SvUVX(TOPs);
		SP--;
		SETs(boolSV((UV)aiv <= buv));
		RETURN;
	    }
	}
    }
#endif
    {
#if defined(NAN_COMPARE_BROKEN) && defined(Perl_isnan)
      dPOPTOPnnrl;
      if (Perl_isnan(left) || Perl_isnan(right))
	  RETSETNO;
      SETs(boolSV(left <= right));
#else
      dPOPnv;
      SETs(boolSV(TOPn <= value));
#endif
      RETURN;
    }
}

PP(pp_ge)
{
    dVAR; dSP;
#ifdef PERL_PRESERVE_IVUV
    if (SvIOK(TOPs)) {
	if (SvIOK(TOPm1s)) {
	    bool auvok = SvUOK(TOPm1s);
	    bool buvok = SvUOK(TOPs);
	
	    if (!auvok && !buvok) { /* ## IV >= IV ## */
		const IV aiv = SvIVX(TOPm1s);
		const IV biv = SvIVX(TOPs);

		SP--;
		SETs(boolSV(aiv >= biv));
		RETURN;
	    }
	    if (auvok && buvok) { /* ## UV >= UV ## */
		const UV auv = SvUVX(TOPm1s);
		const UV buv = SvUVX(TOPs);

		SP--;
		SETs(boolSV(auv >= buv));
		RETURN;
	    }
	    if (auvok) { /* ## UV >= IV ## */
		UV auv;
		const IV biv = SvIVX(TOPs);

		SP--;
		if (biv < 0) {
		    /* As (a) is a UV, it's >=0, so it must be >= */
		    SETs(&PL_sv_yes);
		    RETURN;
		}
		auv = SvUVX(TOPs);
		SETs(boolSV(auv >= (UV)biv));
		RETURN;
	    }
	    { /* ## IV >= UV ## */
		const IV aiv = SvIVX(TOPm1s);
		UV buv;

		if (aiv < 0) {
		    /* As (b) is a UV, it's >=0, so a cannot be >= */
		    SP--;
		    SETs(&PL_sv_no);
		    RETURN;
		}
		buv = SvUVX(TOPs);
		SP--;
		SETs(boolSV((UV)aiv >= buv));
		RETURN;
	    }
	}
    }
#endif
    {
#if defined(NAN_COMPARE_BROKEN) && defined(Perl_isnan)
      dPOPTOPnnrl;
      if (Perl_isnan(left) || Perl_isnan(right))
	  RETSETNO;
      SETs(boolSV(left >= right));
#else
      dPOPnv;
      SETs(boolSV(TOPn >= value));
#endif
      RETURN;
    }
}

PP(pp_ne)
{
    dVAR; dSP;
#ifdef PERL_PRESERVE_IVUV
    if (SvIOK(TOPs)) {
	if (SvIOK(TOPm1s)) {
	    const bool auvok = SvUOK(TOPm1s);
	    const bool buvok = SvUOK(TOPs);
	
	    if (auvok == buvok) { /* ## IV == IV or UV == UV ## */
                /* Casting IV to UV before comparison isn't going to matter
                   on 2s complement. On 1s complement or sign&magnitude
                   (if we have any of them) it could make negative zero
                   differ from normal zero. As I understand it. (Need to
                   check - is negative zero implementation defined behaviour
                   anyway?). NWC  */
		const UV buv = SvUVX(POPs);
		const UV auv = SvUVX(TOPs);

		SETs(boolSV(auv != buv));
		RETURN;
	    }
	    {			/* ## Mixed IV,UV ## */
		IV iv;
		UV uv;
		
		/* != is commutative so swap if needed (save code) */
		if (auvok) {
		    /* swap. top of stack (b) is the iv */
		    iv = SvIVX(TOPs);
		    SP--;
		    if (iv < 0) {
			/* As (a) is a UV, it's >0, so it cannot be == */
			SETs(&PL_sv_yes);
			RETURN;
		    }
		    uv = SvUVX(TOPs);
		} else {
		    iv = SvIVX(TOPm1s);
		    SP--;
		    if (iv < 0) {
			/* As (b) is a UV, it's >0, so it cannot be == */
			SETs(&PL_sv_yes);
			RETURN;
		    }
		    uv = SvUVX(*(SP+1)); /* Do I want TOPp1s() ? */
		}
		SETs(boolSV((UV)iv != uv));
		RETURN;
	    }
	}
    }
#endif
    {
#if defined(NAN_COMPARE_BROKEN) && defined(Perl_isnan)
      dPOPTOPnnrl;
      if (Perl_isnan(left) || Perl_isnan(right))
	  RETSETYES;
      SETs(boolSV(left != right));
#else
      dPOPnv;
      SETs(boolSV(TOPn != value));
#endif
      RETURN;
    }
}

PP(pp_ncmp)
{
    dVAR; dSP; dTARGET;
#ifdef PERL_PRESERVE_IVUV
    /* Fortunately it seems NaN isn't IOK */
    if (SvIOK(TOPs)) {
	if (SvIOK(TOPm1s)) {
	    const bool leftuvok = SvUOK(TOPm1s);
	    const bool rightuvok = SvUOK(TOPs);
	    I32 value;
	    if (!leftuvok && !rightuvok) { /* ## IV <=> IV ## */
		const IV leftiv = SvIVX(TOPm1s);
		const IV rightiv = SvIVX(TOPs);
		
		if (leftiv > rightiv)
		    value = 1;
		else if (leftiv < rightiv)
		    value = -1;
		else
		    value = 0;
	    } else if (leftuvok && rightuvok) { /* ## UV <=> UV ## */
		const UV leftuv = SvUVX(TOPm1s);
		const UV rightuv = SvUVX(TOPs);
		
		if (leftuv > rightuv)
		    value = 1;
		else if (leftuv < rightuv)
		    value = -1;
		else
		    value = 0;
	    } else if (leftuvok) { /* ## UV <=> IV ## */
		const IV rightiv = SvIVX(TOPs);
		if (rightiv < 0) {
		    /* As (a) is a UV, it's >=0, so it cannot be < */
		    value = 1;
		} else {
		    const UV leftuv = SvUVX(TOPm1s);
		    if (leftuv > (UV)rightiv) {
			value = 1;
		    } else if (leftuv < (UV)rightiv) {
			value = -1;
		    } else {
			value = 0;
		    }
		}
	    } else { /* ## IV <=> UV ## */
		const IV leftiv = SvIVX(TOPm1s);
		if (leftiv < 0) {
		    /* As (b) is a UV, it's >=0, so it must be < */
		    value = -1;
		} else {
		    const UV rightuv = SvUVX(TOPs);
		    if ((UV)leftiv > rightuv) {
			value = 1;
		    } else if ((UV)leftiv < rightuv) {
			value = -1;
		    } else {
			value = 0;
		    }
		}
	    }
	    SP--;
	    SETi(value);
	    RETURN;
	}
    }
#endif
    {
      dPOPTOPnnrl;
      I32 value;

#ifdef Perl_isnan
      if (Perl_isnan(left) || Perl_isnan(right)) {
	  SETs(&PL_sv_undef);
	  RETURN;
       }
      value = (left > right) - (left < right);
#else
      if (left == right)
	value = 0;
      else if (left < right)
	value = -1;
      else if (left > right)
	value = 1;
      else {
	SETs(&PL_sv_undef);
	RETURN;
      }
#endif
      SETi(value);
      RETURN;
    }
}

PP(pp_seq)
{
    dVAR; dSP;
    {
      dPOPTOPssrl;
      SETs(boolSV(sv_eq(left, right)));
      RETURN;
    }
}

PP(pp_sne)
{
    dVAR; dSP;
    {
      dPOPTOPssrl;
      SETs(boolSV(!sv_eq(left, right)));
      RETURN;
    }
}

PP(pp_scmp)
{
    dVAR; dSP; dTARGET;
    {
      dPOPTOPssrl;
      const int cmp = sv_cmp(left, right);
      SETi( cmp );
      RETURN;
    }
}

PP(pp_bit_and)
{
    dVAR; dSP; dATARGET;
    {
      dPOPTOPssrl;
      if (SvNIOKp(left) || SvNIOKp(right)) {
	if (PL_op->op_private & HINT_INTEGER) {
	  const IV i = SvIV_nomg(left) & SvIV_nomg(right);
	  SETi(i);
	}
	else {
	  const UV u = SvUV_nomg(left) & SvUV_nomg(right);
	  SETu(u);
	}
      }
      else {
	do_vop(PL_op->op_type, TARG, left, right);
	SETTARG;
      }
      RETURN;
    }
}

PP(pp_bit_or)
{
    dVAR; dSP; dATARGET;
    const int op_type = PL_op->op_type;

    {
      dPOPTOPssrl;
      if (SvNIOKp(left) || SvNIOKp(right)) {
	if (PL_op->op_private & HINT_INTEGER) {
	  const IV l = (USE_LEFT(left) ? SvIV_nomg(left) : 0);
	  const IV r = SvIV_nomg(right);
	  const IV result = op_type == OP_BIT_OR ? (l | r) : (l ^ r);
	  SETi(result);
	}
	else {
	  const UV l = (USE_LEFT(left) ? SvUV_nomg(left) : 0);
	  const UV r = SvUV_nomg(right);
	  const UV result = op_type == OP_BIT_OR ? (l | r) : (l ^ r);
	  SETu(result);
	}
      }
      else {
	do_vop(op_type, TARG, left, right);
	SETTARG;
      }
      RETURN;
    }
}

PP(pp_negate)
{
    dVAR; dSP; dTARGET;
    {
	SV * const sv = sv_2num(TOPs);
	const int flags = SvFLAGS(sv);
	if ((flags & SVf_IOK) || ((flags & (SVp_IOK | SVp_NOK)) == SVp_IOK)) {
	    /* It's publicly an integer, or privately an integer-not-float */
	oops_its_an_int:
	    if (SvIsUV(sv)) {
		if (SvIVX(sv) == IV_MIN) {
		    /* 2s complement assumption. */
		    SETi(SvIVX(sv));	/* special case: -((UV)IV_MAX+1) == IV_MIN */
		    RETURN;
		}
		else if (SvUVX(sv) <= IV_MAX) {
		    SETi(-SvIVX(sv));
		    RETURN;
		}
	    }
	    else if (SvIVX(sv) != IV_MIN) {
		SETi(-SvIVX(sv));
		RETURN;
	    }
#ifdef PERL_PRESERVE_IVUV
	    else {
		SETu((UV)IV_MIN);
		RETURN;
	    }
#endif
	}
	if (SvNIOKp(sv))
	    SETn(-SvNV(sv));
	else if (SvPOKp(sv)) {
	    STRLEN len;
	    const char * const s = SvPV_const(sv, len);
	    if (*s == '+' || *s == '-') {
		sv_setsv(TARG, sv);
		*SvPV_force(TARG, len) = *s == '-' ? '+' : '-';
	    }
	    else {
		if (SvIOK(sv))
		  goto oops_its_an_int;
		sv_setnv(TARG, -SvNV(sv));
	    }
	    SETTARG;
	}
	else
	    SETn(-SvNV(sv));
    }
    RETURN;
}

PP(pp_not)
{
    dVAR;
    *PL_stack_sp = boolSV(!SvTRUE(*PL_stack_sp));
    return NORMAL;
}

PP(pp_complement)
{
    dVAR; dSP; dTARGET;
    {
      dTOPss;
      if (SvNIOKp(sv)) {
	if (PL_op->op_private & HINT_INTEGER) {
	  const IV i = ~SvIV_nomg(sv);
	  SETi(i);
	}
	else {
	  const UV u = ~SvUV_nomg(sv);
	  SETu(u);
	}
      }
      else {
	register char *tmps;
	register I32 anum;
	STRLEN len;

	(void)SvPV_const(sv,len); /* force check for uninit var */
	sv_setsv_nomg(TARG, sv);
	tmps = SvPV_force(TARG, len);
	anum = len;
#ifdef LIBERAL
	{
	    register long *tmpl;
	    for ( ; anum && (unsigned long)tmps % sizeof(long); anum--, tmps++)
		*tmps = ~*tmps;
	    tmpl = (long*)tmps;
	    for ( ; anum >= (I32)sizeof(long); anum -= (I32)sizeof(long), tmpl++)
		*tmpl = ~*tmpl;
	    tmps = (char*)tmpl;
	}
#endif
	for ( ; anum > 0; anum--, tmps++)
	    *tmps = ~*tmps;

	SETs(TARG);
      }
      RETURN;
    }
}

/* integer versions of some of the above */

PP(pp_i_multiply)
{
    dVAR; dSP; dATARGET;
    {
      dPOPTOPiirl;
      SETi( left * right );
      RETURN;
    }
}

PP(pp_i_divide)
{
    IV num;
    dVAR; dSP; dATARGET;
    {
      dPOPiv;
      if (value == 0)
	  DIE(aTHX_ "Illegal division by zero");
      num = POPi;

      /* avoid FPE_INTOVF on some platforms when num is IV_MIN */
      if (value == -1)
          value = - num;
      else
          value = num / value;
      PUSHi( value );
      RETURN;
    }
}

#if defined(__GLIBC__) && IVSIZE == 8
STATIC
PP(pp_i_modulo_0)
#else
PP(pp_i_modulo)
#endif
{
     /* This is the vanilla old i_modulo. */
     dVAR; dSP; dATARGET;
     {
	  dPOPTOPiirl;
	  if (!right)
	       DIE(aTHX_ "Illegal modulus zero");
	  /* avoid FPE_INTOVF on some platforms when left is IV_MIN */
	  if (right == -1)
	      SETi( 0 );
	  else
	      SETi( left % right );
	  RETURN;
     }
}

#if defined(__GLIBC__) && IVSIZE == 8
STATIC
PP(pp_i_modulo_1)

{
     /* This is the i_modulo with the workaround for the _moddi3 bug
      * in (at least) glibc 2.2.5 (the PERL_ABS() the workaround).
      * See below for pp_i_modulo. */
     dVAR; dSP; dATARGET;
     {
	  dPOPTOPiirl;
	  if (!right)
	       DIE(aTHX_ "Illegal modulus zero");
	  /* avoid FPE_INTOVF on some platforms when left is IV_MIN */
	  if (right == -1)
	      SETi( 0 );
	  else
	      SETi( left % PERL_ABS(right) );
	  RETURN;
     }
}

PP(pp_i_modulo)
{
     dVAR; dSP; dATARGET;
     {
	  dPOPTOPiirl;
	  if (!right)
	       DIE(aTHX_ "Illegal modulus zero");
	  /* The assumption is to use hereafter the old vanilla version... */
	  PL_op->op_ppaddr =
	       PL_ppaddr[OP_I_MODULO] =
	           Perl_pp_i_modulo_0;
	  /* .. but if we have glibc, we might have a buggy _moddi3
	   * (at least glicb 2.2.5 is known to have this bug), in other
	   * words our integer modulus with negative quad as the second
	   * argument might be broken.  Test for this and re-patch the
	   * opcode dispatch table if that is the case, remembering to
	   * also apply the workaround so that this first round works
	   * right, too.  See [perl #9402] for more information. */
	  {
	       IV l =   3;
	       IV r = -10;
	       /* Cannot do this check with inlined IV constants since
		* that seems to work correctly even with the buggy glibc. */
	       if (l % r == -3) {
		    /* Yikes, we have the bug.
		     * Patch in the workaround version. */
		    PL_op->op_ppaddr =
			 PL_ppaddr[OP_I_MODULO] =
			     &Perl_pp_i_modulo_1;
		    /* Make certain we work right this time, too. */
		    right = PERL_ABS(right);
	       }
	  }
	  /* avoid FPE_INTOVF on some platforms when left is IV_MIN */
	  if (right == -1)
	      SETi( 0 );
	  else
	      SETi( left % right );
	  RETURN;
     }
}
#endif

PP(pp_i_add)
{
    dVAR; dSP; dATARGET;
    {
      dPOPTOPiirl_ul;
      SETi( left + right );
      RETURN;
    }
}

PP(pp_i_subtract)
{
    dVAR; dSP; dATARGET;
    {
      dPOPTOPiirl_ul;
      SETi( left - right );
      RETURN;
    }
}

PP(pp_i_lt)
{
    dVAR; dSP;
    {
      dPOPTOPiirl;
      SETs(boolSV(left < right));
      RETURN;
    }
}

PP(pp_i_gt)
{
    dVAR; dSP;
    {
      dPOPTOPiirl;
      SETs(boolSV(left > right));
      RETURN;
    }
}

PP(pp_i_le)
{
    dVAR; dSP;
    {
      dPOPTOPiirl;
      SETs(boolSV(left <= right));
      RETURN;
    }
}

PP(pp_i_ge)
{
    dVAR; dSP;
    {
      dPOPTOPiirl;
      SETs(boolSV(left >= right));
      RETURN;
    }
}

PP(pp_i_eq)
{
    dVAR; dSP;
    {
      dPOPTOPiirl;
      SETs(boolSV(left == right));
      RETURN;
    }
}

PP(pp_i_ne)
{
    dVAR; dSP;
    {
      dPOPTOPiirl;
      SETs(boolSV(left != right));
      RETURN;
    }
}

PP(pp_i_ncmp)
{
    dVAR; dSP; dTARGET;
    {
      dPOPTOPiirl;
      I32 value;

      if (left > right)
	value = 1;
      else if (left < right)
	value = -1;
      else
	value = 0;
      SETi(value);
      RETURN;
    }
}

PP(pp_i_negate)
{
    dVAR; dSP; dTARGET;
    SETi(-TOPi);
    RETURN;
}

/* High falutin' math. */

PP(pp_atan2)
{
    dVAR; dSP; dTARGET;
    {
      dPOPTOPnnrl;
      SETn(Perl_atan2(left, right));
      RETURN;
    }
}

PP(pp_sin)
{
    dVAR; dSP; dTARGET;
    int amg_type = sin_amg;
    const char *neg_report = NULL;
    NV (*func)(NV) = Perl_sin;
    const int op_type = PL_op->op_type;

    switch (op_type) {
    case OP_COS:
	amg_type = cos_amg;
	func = Perl_cos;
	break;
    case OP_EXP:
	amg_type = exp_amg;
	func = Perl_exp;
	break;
    case OP_LOG:
	amg_type = log_amg;
	func = Perl_log;
	neg_report = "log";
	break;
    case OP_SQRT:
	amg_type = sqrt_amg;
	func = Perl_sqrt;
	neg_report = "sqrt";
	break;
    }

    {
      const NV value = POPn;
      if (neg_report) {
	  if (op_type == OP_LOG ? (value <= 0.0) : (value < 0.0)) {
	      SET_NUMERIC_STANDARD();
	      DIE(aTHX_ "Can't take %s of %"NVgf, neg_report, value);
	  }
      }
      XPUSHn(func(value));
      RETURN;
    }
}

/* Support Configure command-line overrides for rand() functions.
   After 5.005, perhaps we should replace this by Configure support
   for drand48(), random(), or rand().  For 5.005, though, maintain
   compatibility by calling rand() but allow the user to override it.
   See INSTALL for details.  --Andy Dougherty  15 July 1998
*/
/* Now it's after 5.005, and Configure supports drand48() and random(),
   in addition to rand().  So the overrides should not be needed any more.
   --Jarkko Hietaniemi	27 September 1998
 */

#ifndef HAS_DRAND48_PROTO
extern double drand48 (void);
#endif

PP(pp_rand)
{
    dVAR; dSP; dTARGET;
    NV value;
    if (MAXARG < 1)
	value = 1.0;
    else
	value = POPn;
    if (value == 0.0)
	value = 1.0;
    if (!PL_srand_called) {
	(void)seedDrand01((Rand_seed_t)seed());
	PL_srand_called = TRUE;
    }
    value *= Drand01();
    XPUSHn(value);
    RETURN;
}

PP(pp_srand)
{
    dVAR; dSP;
    const UV anum = (MAXARG < 1) ? seed() : POPu;
    (void)seedDrand01((Rand_seed_t)anum);
    PL_srand_called = TRUE;
    EXTEND(SP, 1);
    RETPUSHYES;
}

PP(pp_int)
{
    dVAR; dSP; dTARGET;
    {
      SV * const sv = sv_2num(TOPs);
      const IV iv = SvIV(sv);
      /* XXX it's arguable that compiler casting to IV might be subtly
	 different from modf (for numbers inside (IV_MIN,UV_MAX)) in which
	 else preferring IV has introduced a subtle behaviour change bug. OTOH
	 relying on floating point to be accurate is a bug.  */

      if (!SvOK(sv)) {
        SETu(0);
      }
      else if (SvIOK(sv)) {
	if (SvIsUV(sv))
	    SETu(SvUV(sv));
	else
	    SETi(iv);
      }
      else {
	  const NV value = SvNV(sv);
	  if (value >= 0.0) {
	      if (value < (NV)UV_MAX + 0.5) {
		  SETu(U_V(value));
	      } else {
		  SETn(Perl_floor(value));
	      }
	  }
	  else {
	      if (value > (NV)IV_MIN - 0.5) {
		  SETi(I_V(value));
	      } else {
		  SETn(Perl_ceil(value));
	      }
	  }
      }
    }
    RETURN;
}

PP(pp_abs)
{
    dVAR; dSP; dTARGET;
    {
      SV * const sv = sv_2num(TOPs);
      /* This will cache the NV value if string isn't actually integer  */
      const IV iv = SvIV(sv);

      if (!SvOK(sv)) {
        SETu(0);
      }
      else if (SvIOK(sv)) {
	/* IVX is precise  */
	if (SvIsUV(sv)) {
	  SETu(SvUV(sv));	/* force it to be numeric only */
	} else {
	  if (iv >= 0) {
	    SETi(iv);
	  } else {
	    if (iv != IV_MIN) {
	      SETi(-iv);
	    } else {
	      /* 2s complement assumption. Also, not really needed as
		 IV_MIN and -IV_MIN should both be %100...00 and NV-able  */
	      SETu(IV_MIN);
	    }
	  }
	}
      } else{
	const NV value = SvNV(sv);
	if (value < 0.0)
	  SETn(-value);
	else
	  SETn(value);
      }
    }
    RETURN;
}

PP(pp_oct)
{
    dVAR; dSP; dTARGET;
    const char *tmps;
    I32 flags = PERL_SCAN_ALLOW_UNDERSCORES;
    STRLEN len;
    NV result_nv;
    UV result_uv;
    SV* const sv = POPs;

    tmps = (SvPV_const(sv, len));
    if (PL_op->op_type == OP_HEX)
	goto hex;

    while (*tmps && len && isSPACE(*tmps))
        tmps++, len--;
    if (*tmps == '0')
        tmps++, len--;
    if (*tmps == 'x') {
    hex:
        result_uv = grok_hex (tmps, &len, &flags, &result_nv);
    }
    else if (*tmps == 'b')
        result_uv = grok_bin (tmps, &len, &flags, &result_nv);
    else
        result_uv = grok_oct (tmps, &len, &flags, &result_nv);

    if (flags & PERL_SCAN_GREATER_THAN_UV_MAX) {
        XPUSHn(result_nv);
    }
    else {
        XPUSHu(result_uv);
    }
    RETURN;
}

/* String stuff. */

PP(pp_length)
{
    dVAR; dSP; dTARGET;
    SV * const sv = TOPs;

    if (SvOK(sv)) {
	/* Neither magic nor overloaded.  */
	if (IN_CODEPOINTS)
	    SETi(sv_len_utf8(sv));
	else
	    SETi(sv_len(sv));
    } else {
	SETs(&PL_sv_undef);
    }
    RETURN;
}

PP(pp_substr)
{
    dVAR; dSP; dTARGET;
    SV *sv;
    I32 len = 0;
    STRLEN curlen;
    I32 pos;
    I32 rem;
    I32 fail;
    const char *tmps;
    SV *repl_sv = NULL;
    const char *repl = NULL;
    STRLEN repl_len;
    const int num_args = PL_op->op_private & 7;
    bool has_len = FALSE;

    if (num_args > 2) {
	if (num_args > 3) {
	    repl_sv = POPs;
	    repl = SvPV_const(repl_sv, repl_len);
	}
	if (SvOK(TOPs)) {
	    len = POPi;
	    has_len = TRUE;
	}
	else {
	    (void)POPs;
	}
    }
    pos = POPi;
    sv = POPs;
    PUTBACK;
    tmps = SvPV_const(sv, curlen);

    if (IN_CODEPOINTS)
	curlen = sv_len_utf8(sv);

    if (pos >= 0) {
	rem = curlen-pos;
	fail = rem;
	if (has_len) {
	    if (len < 0) {
		rem += len;
		if (rem < 0)
		    rem = 0;
	    }
	    else if (rem > len)
		     rem = len;
	}
    }
    else {
	pos += curlen;
	if ( ! has_len )
	    rem = curlen;
	else if (len >= 0) {
	    rem = pos+len;
	    if (rem > (I32)curlen)
		rem = curlen;
	}
	else {
	    rem = curlen+len;
	    if (rem < pos)
		rem = pos;
	}
	if (pos < 0)
	    pos = 0;
	fail = rem;
	rem -= pos;
    }
    if (fail < 0) {
	if (repl)
	    Perl_croak(aTHX_ "substr outside of string");
	if (ckWARN(WARN_SUBSTR))
	    Perl_warner(aTHX_ packWARN(WARN_SUBSTR), "substr outside of string");
	RETPUSHUNDEF;
    }
    else {
	if (IN_CODEPOINTS)
	    sv_pos_u2b(sv, &pos, &rem);
	tmps += pos;

	sv_setpvn(TARG, tmps, rem);
	if (repl) {
	    SV* repl_sv_copy = NULL;

	    sv_insert(sv, pos, rem, repl, repl_len);
	    if (repl_sv_copy)
		SvREFCNT_dec(repl_sv_copy);
	}
    }
    SPAGAIN;
    PUSHs(TARG);		/* avoid SvSETMAGIC here */
    RETURN;
}

PP(pp_vec)
{
    dVAR; dSP; dTARGET;

    if (MAXARG > 3) {			/* it's an lvalue! */
	do_vecset();      /* XXX slurp this routine */
    }
    else {
	register const IV size   = POPi;
	register const IV offset = POPi;
	register SV * const src = POPs;
	sv_setuv(TARG, do_vecget(src, offset, size));
	PUSHs(TARG);
    }
    RETURN;
}

PP(pp_index)
{
    dVAR; dSP; dTARGET;
    SV *big;
    SV *little;
    SV *temp = NULL;
    STRLEN biglen;
    STRLEN llen = 0;
    I32 offset;
    I32 retval;
    const char *big_p;
    const char *little_p;
    const bool is_index = PL_op->op_type == OP_INDEX;

    if (MAXARG >= 3) {
	offset = POPi;
    }
    little = POPs;
    big = POPs;
    big_p = SvPV_const(big, biglen);
    little_p = SvPV_const(little, llen);

    if (is_index && !SvOK(little)) {
	/* index && SvOK() is a hack. fbm_instr() calls SvPV_const, which will
	   warn on undef, and we've already triggered a warning with the
	   SvPV_const some lines above. We can't remove that, as we need to
	   call some SvPV to trigger overloading early and find out if the
	   string is UTF-8.
	   This is all getting to messy. The API isn't quite clean enough,
	   because data access has side effects.
	*/
	little = newSVpvn_flags(little_p, llen, SVs_TEMP);
	little_p = SvPVX_mutable(little);
    }

    if (MAXARG < 3)
	offset = is_index ? 0 : biglen;
    else {
	if (IN_CODEPOINTS && offset > 0)
	    sv_pos_u2b(big, &offset, 0);
	if (!is_index)
	    offset += llen;
    }
    if (offset < 0)
	offset = 0;
    else if (offset > (I32)biglen)
	offset = biglen;
    if (!(little_p = is_index
	  ? fbm_instr((char*)big_p + offset,
		      (char*)big_p + biglen, little, 0)
	  : rninstr(big_p,  big_p  + offset,
		    little_p, little_p + llen)))
	retval = -1;
    else {
	retval = little_p - big_p;
	if (retval > 0 && IN_CODEPOINTS)
	    sv_pos_b2u(big, &retval);
    }
    if (temp)
	SvREFCNT_dec(temp);
    PUSHi(retval);
    RETURN;
}

PP(pp_sprintf)
{
    dVAR; dSP; dMARK; dORIGMARK; dTARGET;
    do_sprintf(TARG, SP-MARK, MARK+1);
    SP = ORIGMARK;
    PUSHTARG;
    RETURN;
}

PP(pp_ord)
{
    dVAR; dSP; dTARGET;

    SV *argsv = POPs;
    STRLEN len;
    const char *s = SvPV_const(argsv, len);

    XPUSHu(IN_CODEPOINTS ?
	   utf8n_to_uvchr(s, UTF8_MAXBYTES, 0, UTF8_ALLOW_ANYUV) :
	   (UV)((U8)*s & 0xff));

    RETURN;
}

PP(pp_chr)
{
    dVAR; dSP; dTARGET;
    char *tmps;
    UV value;

    if (((SvIOK_notUV(TOPs) && SvIV(TOPs) < 0)
	 ||
	 (SvNOK(TOPs) && SvNV(TOPs) < 0.0))) {
	if ( ! IN_CODEPOINTS ) {
	    value = POPu; /* chr(-1) eq chr(0xff), etc. */
	} else {
	    (void) POPs; /* Ignore the argument value. */
	    value = UNICODE_REPLACEMENT;
	}
    } else {
	value = POPu;
    }

    SvUPGRADE(TARG,SVt_PV);

    if (IN_CODEPOINTS) {
	SvGROW(TARG, (STRLEN)UNISKIP(value)+1);
	tmps = uvchr_to_utf8_flags(SvPVX_mutable(TARG), value, 0);
	SvCUR_set(TARG, tmps - SvPVX_const(TARG));
	*tmps = '\0';
	(void)SvPOK_only(TARG);
	XPUSHs(TARG);
	RETURN;
    } else if ( ! IN_BYTES ) {
	if ( ! UNI_IS_INVARIANT(value) )
	    Perl_warner(aTHX_ packWARN(WARN_MISC),
			"chr() ambiguous with highbit without use bytes or use utf8");
    }

    SvGROW(TARG,2);
    SvCUR_set(TARG, 1);
    tmps = SvPVX_mutable(TARG);
    *tmps++ = (char)value;
    *tmps = '\0';
    (void)SvPOK_only(TARG);

    XPUSHs(TARG);
    RETURN;
}

PP(pp_crypt)
{
#ifdef HAS_CRYPT
    dVAR; dSP; dTARGET;
    dPOPTOPssrl;
    STRLEN len;
    const char *tmps = SvPV_const(left, len);

#   ifdef FCRYPT
    sv_setpv(TARG, fcrypt(tmps, SvPV_nolen_const(right)));
#   else
    sv_setpv(TARG, PerlProc_crypt(tmps, SvPV_nolen_const(right)));
#   endif
    SETs(TARG);
    RETURN;
#else
    DIE(aTHX_
      "The crypt() function is unimplemented due to excessive paranoia.");
#endif
}

PP(pp_ucfirst)
{
    dVAR;
    dSP;
    SV *source = TOPs;
    STRLEN slen;
    STRLEN need;
    SV *dest;
    bool inplace = TRUE;
    const int op_type = PL_op->op_type;
    const char *s;
    char *d;
    char tmpbuf[UTF8_MAXBYTES_CASE+1];
    STRLEN ulen;
    STRLEN tculen;

    if (SvOK(source)) {
	s = SvPV_const(source, slen);
    } else {
	if (ckWARN(WARN_UNINITIALIZED))
	    report_uninit(source);
	s = "";
	slen = 0;
    }

    if (IN_CODEPOINTS) {
	if (slen) {
	    UV u = utf8n_to_uvuni(s, slen, &ulen, 0);
	    if (u == 0) {
		/* invalid unicode character, keep it */
		ulen = 0;
		tculen = 0;
	    } else {
		if (op_type == OP_UCFIRST) {
		    toTITLE_utf8(s, tmpbuf, &tculen);
		} else {
		    toLOWER_utf8(s, tmpbuf, &tculen);
		}
	    }
	} else {
	    ulen = 0;
	    tculen = 0;
	}
	/* If the two differ, we definately cannot do inplace.  */
	inplace = (ulen == tculen);
	need = slen + 1 - ulen + tculen;
    } else {
	need = slen + 1;
    }

    {
	dTARGET;

	dest = TARG;

	SvUPGRADE(dest, SVt_PV);
	d = SvGROW(dest, need);
	(void)SvPOK_only(dest);

	SETs(dest);

	inplace = FALSE;
    }


    if (IN_CODEPOINTS) {
	if(!inplace) {
	    /* slen is the byte length of the whole SV.
	     * ulen is the byte length of the original Unicode character
	     * stored as UTF-8 at s.
	     * tculen is the byte length of the freshly titlecased (or
	     * lowercased) Unicode character stored as UTF-8 at tmpbuf.
	     * We first set the result to be the titlecased (/lowercased)
	     * character, and then append the rest of the SV data. */
	    sv_setpvn(dest, (char*)tmpbuf, tculen);
	    if (slen > ulen)
	        sv_catpvn(dest, (char*)(s + ulen), slen - ulen);
	}
	else {
	    Copy(tmpbuf, d, tculen, char);
	    SvCUR_set(dest, need - 1);
	}
    }
    else {
	if (*s) {
	    *d = (op_type == OP_UCFIRST) ? toUPPER(*s) : toLOWER(*s);
	} else {
	    /* See bug #39028  */
	    *d = *s;
	}

	if (!inplace) {
	    /* This will copy the trailing NUL  */
	    Copy(s + 1, d + 1, slen, char);
	    SvCUR_set(dest, need - 1);
	}
    }
    SvSETMAGIC(dest);
    RETURN;
}

/* There's so much setup/teardown code common between uc and lc, I wonder if
   it would be worth merging the two, and just having a switch outside each
   of the three tight loops.  */
PP(pp_uc)
{
    dVAR;
    dSP;
    SV *source = TOPs;
    STRLEN len;
    STRLEN min;
    SV *dest;
    const char *s;
    char *d;

    {
	dTARGET;

	dest = TARG;

	/* The old implementation would copy source into TARG at this point.
	   This had the side effect that if source was undef, TARG was now
	   an undefined SV with PADTMP set, and they don't warn inside
	   sv_2pv_flags(). However, we're now getting the PV direct from
	   source, which doesn't have PADTMP set, so it would warn. Hence the
	   little games.  */

	if (SvOK(source)) {
	    s = SvPV_const(source, len);
	} else {
	    if (ckWARN(WARN_UNINITIALIZED))
		report_uninit(source);
	    s = "";
	    len = 0;
	}
	min = len + 1;

	SvUPGRADE(dest, SVt_PV);
	d = SvGROW(dest, min);
	(void)SvPOK_only(dest);

	SETs(dest);
    }

    if (IN_CODEPOINTS) {
	const char *const send = s + len;
	char tmpbuf[UTF8_MAXBYTES+1];

	while (s < send) {
	    const STRLEN u = UTF8SKIP(s);
	    STRLEN ulen;

	    toUPPER_utf8(s, tmpbuf, &ulen);
	    if (ulen > u && (SvLEN(dest) < (min += ulen - u))) {
		/* If the eventually required minimum size outgrows
		 * the available space, we need to grow. */
		const UV o = d - SvPVX_const(dest);

		/* If someone uppercases one million U+03B0s we SvGROW() one
		 * million times.  Or we could try guessing how much to
		 allocate without allocating too much.  Such is life. */
		SvGROW(dest, min);
		d = SvPVX_mutable(dest) + o;
	    }
	    Copy(tmpbuf, d, ulen, char);
	    d += ulen;
	    s += u;
	}
	*d = '\0';
	SvCUR_set(dest, d - SvPVX_const(dest));
    } else {
	if (len) {
	    const char *const send = s + len;
	    for (; s < send; d++, s++)
		*d = toUPPER(*s);
	}
	if (source != dest) {
	    *d = '\0';
	    SvCUR_set(dest, d - SvPVX_const(dest));
	}
    }
    SvSETMAGIC(dest);
    RETURN;
}

PP(pp_lc)
{
    dVAR;
    dSP;
    SV *source = TOPs;
    STRLEN len;
    STRLEN min;
    SV *dest;
    const char *s;
    char *d;

    {
	dTARGET;

	dest = TARG;

	/* The old implementation would copy source into TARG at this point.
	   This had the side effect that if source was undef, TARG was now
	   an undefined SV with PADTMP set, and they don't warn inside
	   sv_2pv_flags(). However, we're now getting the PV direct from
	   source, which doesn't have PADTMP set, so it would warn. Hence the
	   little games.  */

	if (SvOK(source)) {
	    s = SvPV_const(source, len);
	} else {
	    if (ckWARN(WARN_UNINITIALIZED))
		report_uninit(source);
	    s = "";
	    len = 0;
	}
	min = len + 1;

	SvUPGRADE(dest, SVt_PV);
	d = SvGROW(dest, min);
	(void)SvPOK_only(dest);

	SETs(dest);
    }

    /* Overloaded values may have toggled the UTF-8 flag on source, so we need
       to check DO_UTF8 again here.  */

    if (IN_CODEPOINTS) {
	const char *const send = s + len;
	char tmpbuf[UTF8_MAXBYTES_CASE+1];

	while (s < send) {
	    const STRLEN u = UTF8SKIP(s);
	    STRLEN ulen;
	    const UV uv = toLOWER_utf8(s, tmpbuf, &ulen);

#define GREEK_CAPITAL_LETTER_SIGMA 0x03A3 /* Unicode U+03A3 */
	    if (uv == GREEK_CAPITAL_LETTER_SIGMA) {
		NOOP;
		/*
		 * Now if the sigma is NOT followed by
		 * /$ignorable_sequence$cased_letter/;
		 * and it IS preceded by /$cased_letter$ignorable_sequence/;
		 * where $ignorable_sequence is [\x{2010}\x{AD}\p{Mn}]*
		 * and $cased_letter is [\p{Ll}\p{Lo}\p{Lt}]
		 * then it should be mapped to 0x03C2,
		 * (GREEK SMALL LETTER FINAL SIGMA),
		 * instead of staying 0x03A3.
		 * "should be": in other words, this is not implemented yet.
		 * See lib/unicore/SpecialCasing.txt.
		 */
	    }
	    if (ulen > u && (SvLEN(dest) < (min += ulen - u))) {
		/* If the eventually required minimum size outgrows
		 * the available space, we need to grow. */
		const UV o = d - SvPVX_const(dest);

		/* If someone lowercases one million U+0130s we SvGROW() one
		 * million times.  Or we could try guessing how much to
		 allocate without allocating too much.  Such is life. */
		SvGROW(dest, min);
		d = SvPVX_mutable(dest) + o;
	    }
	    Copy(tmpbuf, d, ulen, char);
	    d += ulen;
	    s += u;
	}
	*d = '\0';
	SvCUR_set(dest, d - SvPVX_const(dest));
    } else {
	if (len) {
	    const char *const send = s + len;
	    for (; s < send; d++, s++)
		*d = toLOWER(*s);
	}
	if (source != dest) {
	    *d = '\0';
	    SvCUR_set(dest, d - SvPVX_const(dest));
	}
    }
    SvSETMAGIC(dest);
    RETURN;
}

PP(pp_quotemeta)
{
    dVAR; dSP; dTARGET;
    SV * const sv = TOPs;
    STRLEN len;
    register const char *s = SvPV_const(sv,len);

    if (len) {
	register char *d;
	SvUPGRADE(TARG, SVt_PV);
	SvGROW(TARG, (len * 2) + 1);
	d = SvPVX_mutable(TARG);
	if (IN_CODEPOINTS) {
	    while (len) {
		if (UTF8_IS_CONTINUED(*s)) {
		    STRLEN ulen = UTF8SKIP(s);
		    if (ulen > len)
			ulen = len;
		    len -= ulen;
		    while (ulen--)
			*d++ = *s++;
		}
		else {
		    if (!isALNUM(*s))
			*d++ = '\\';
		    *d++ = *s++;
		    len--;
		}
	    }
	}
	else {
	    while (len--) {
		if (!isALNUM(*s))
		    *d++ = '\\';
		*d++ = *s++;
	    }
	}
	*d = '\0';
	SvCUR_set(TARG, d - SvPVX_const(TARG));
	(void)SvPOK_only(TARG);
    }
    else
	sv_setpvn(TARG, s, len);
    SETs(TARG);
    if (SvSMAGICAL(TARG))
	mg_set(TARG);
    RETURN;
}

/* Arrays. */

PP(pp_aslice)
{
    dVAR; dSP;
    register AV* const av = (AV*)POPs;
    register AV* slice = (AV*)POPs;
    const OPFLAGS op_flags = PL_op->op_flags;
    register const I32 lval = (op_flags & OPf_MOD);
    const bool assign = (op_flags & OPf_ASSIGN) ? 1 : 0;
    SV **sliceitem;
    SV **slicemax;
    AV *src;

    if (SvTYPE(av) != SVt_PVAV)
	Perl_croak(aTHX_ "can't take an array slice from an %s", Ddesc((SV*)av));

    if (SvTYPE(slice) != SVt_PVAV)
	Perl_croak(aTHX_ "array slice indices must be an ARRAY not %s",
	    Ddesc((SV*)slice));

    if (assign) {
	SV* svsrc = POPs;
	if ( ! SvAVOK(svsrc) )
	    Perl_croak(aTHX_ "source must be the ARRAY not %s", Ddesc(svsrc));
	src = svTav(svsrc);
    }

    slice = av_mortalcopy(slice);

    if ( ! ( op_flags & OPf_ASSIGN_PART ) )
	XPUSHs(avTsv(slice));

    sliceitem = AvARRAY(slice);

    if ( ! sliceitem )
	RETURN;

    slicemax = AvARRAY(slice) + av_len(slice);

    if (lval && PL_op->op_private & OPpLVAL_INTRO) {
	register SV **svp;
	I32 max = -1;
	for (svp = AvARRAY(slice); svp <= slicemax; svp++) {
	    const I32 elem = SvIV(*svp);
	    if (elem > max)
		max = elem;
	}
	if (max > AvMAX(av))
	    av_extend(av, max);
    }
    while (sliceitem <= slicemax) {
	register SV **svp;
	I32 elem = SvIV(*sliceitem);
	
	svp = av_fetch(av, elem, lval);
	if (lval) {
	    if (!svp || *svp == &PL_sv_undef)
		DIE(aTHX_ PL_no_aelem, elem);
	    if (PL_op->op_private & OPpLVAL_INTRO)
		save_aelem(av, elem, svp);
	}
	SVcpREPLACE(*sliceitem, svp ? *svp : &PL_sv_undef );
        sliceitem++;
    }

    if (assign) {
	SV** srcitem = AvARRAY(src);
	SV** srcitemmax = srcitem + av_len(src);
	sliceitem = AvARRAY(slice);
	while (sliceitem <= slicemax && srcitem <= srcitemmax) {
	    sv_setsv(*sliceitem, *srcitem);
	    srcitem++;
	    sliceitem++;
	}
    }

    RETURN;
}

/* Associative arrays. */

PP(pp_each)
{
    dVAR;
    dSP;
    HV * hash = (HV*)POPs;
    HE *entry;
    const I32 gimme = GIMME_V;

    if ( ! SvHVOK(hash) ) {
	if ( ! SvOK(hash) ) {
	    if (gimme == G_SCALAR)
		RETPUSHUNDEF;
	    RETURN;
	}
	bad_arg(1, "hash", PL_op_desc[PL_op->op_type], (SV*)hash);
	/* not reached */
    }
    PUTBACK;
    /* might clobber stack_sp */
    entry = hv_iternext(hash);
    SPAGAIN;

    EXTEND(SP, 2);
    if (entry) {
	SV* const sv = hv_iterkeysv(entry);
	PUSHs(sv);	/* won't clobber stack_sp */
	if (gimme == G_ARRAY) {
	    SV *val;
	    PUTBACK;
	    /* might clobber stack_sp */
	    val = hv_iterval(hash, entry);
	    SPAGAIN;
	    PUSHs(val);
	}
    }
    else if (gimme == G_SCALAR)
	RETPUSHUNDEF;

    RETURN;
}

PP(pp_delete)
{
    dVAR;
    dSP;
    const I32 gimme = GIMME_V;
    const I32 discard = (gimme == G_VOID) ? G_DISCARD : 0;

    if (PL_op->op_private & OPpSLICE) {
	SV * const sv = POPs;
	SV* slice = POPs;
	AV* slicecopy;
	SV** items;
	I32 avlen;

	if ( ! SvAVOK(slice) )
	    Perl_croak(aTHX_ "slice expected an array as slice index, but got %s", Ddesc(slice));

	slicecopy = av_mortalcopy(svTav(slice));
	items = AvARRAY(slicecopy);
	avlen = av_len(slicecopy);

	if (PL_op->op_flags & OPf_SPECIAL) {                  /* array element */
	    int i;

	    if ( ! SvAVOK(sv) ) 
		Perl_croak(aTHX_ "array slice expected an array but got a %s", Ddesc(sv));

	    for (i = 0; i <= avlen; i++) {
		SV * const delsv = av_delete(svTav(sv), SvIV(items[i]), 0);
		SVcpREPLACE(items[i], delsv ? delsv : &PL_sv_undef );
	    }
	}
	else {			/* hash element */
	    int i;
	    if ( ! SvHVOK(sv) )
		Perl_croak(aTHX_ "hash slice expected an array but got a %s", Ddesc(sv));

	    for (i = 0; i <= avlen; i++) {
		SV * const delsv = hv_delete_ent(svThv(sv), items[i], 0, 0);
		SVcpREPLACE(items[i], delsv ? delsv : &PL_sv_undef );
	    }
	}

	if ( ! discard)
	    XPUSHs(avTsv(slicecopy));
    }
    else {
	SV *keysv = POPs;
	HV * const hv = (HV*)POPs;
	SV *sv;
	if (SvTYPE(hv) == SVt_PVHV)
	    sv = hv_delete_ent(hv, keysv, discard, 0);
	else if (SvTYPE(hv) == SVt_PVAV) {
	    if (PL_op->op_flags & OPf_SPECIAL)
		sv = av_delete((AV*)hv, SvIV(keysv), discard);
	    else
		DIE(aTHX_ "panic: avhv_delete no longer supported");
	}
	else if (!SvOK(hv)) {
	    if (!(PL_op->op_private & OPpELEM_OPTIONAL))
		DIE(aTHX_ "%s expects a HASH not %s", OP_DESC(PL_op), Ddesc(hvTsv(hv)));
	    sv = NULL;
	}
	else
	    DIE(aTHX_ "%s expects a HASH not %s", OP_DESC(PL_op), Ddesc(hvTsv(hv)));
	if (!sv)
	    sv = &PL_sv_undef;
	if (!discard)
	    PUSHs(sv);
    }
    RETURN;
}

PP(pp_exists)
{
    dVAR;
    dSP;
    SV *tmpsv;
    SV *sv;

    if (PL_op->op_private & OPpEXISTS_SUB) {
	SV * const cvsv = POPs;
	if (cvsv && SvOK(cvsv))
	    RETPUSHYES;
	RETPUSHNO;
    }
    tmpsv = POPs;
    sv = POPs;

    if (SvTYPE(sv) == SVt_PVHV) {
	if (hv_exists_ent((HV*)sv, tmpsv, 0))
	    RETPUSHYES;
    }
    else if (SvTYPE(sv) == SVt_PVAV) {
	if (PL_op->op_flags & OPf_SPECIAL) {		/* array element */
	    if (av_exists((AV*)sv, SvIV(tmpsv)))
		RETPUSHYES;
	}
    }
    else if ( ! SvOK(sv) ) {
	RETPUSHNO;
    }
    else {
	DIE(aTHX_ "exists expected an ARRAY or a HASH but got a %s", Ddesc(sv));
    }
    RETPUSHNO;
}

PP(pp_hslice)
{
    dVAR; dSP;
    register HV * const hv = (HV*)POPs;
    AV * slice = (AV*)POPs;
    const OPFLAGS op_flags = PL_op->op_flags;
    register const I32 lval = (op_flags & OPf_MOD);
    const bool localizing = PL_op->op_private & OPpLVAL_INTRO;
    const bool add = (PL_op->op_private & OPpELEM_ADD) != 0;
    const bool optional = (PL_op->op_private & OPpELEM_OPTIONAL) != 0;
    bool other_magic = FALSE;
    SV ** sliceitem;
    SV ** slicemax;

    if ( ! SvAVOK(slice) )
	Perl_croak(aTHX_ "%s expected an ARRAY but got %s",
	    OP_DESC(PL_op), Ddesc(avTsv(slice)));

    if ( ! SvOK(hv) ) {
	if (optional) {
	    AV* res = newAV();
	    int i;
	    for (i=SvLEN(res); i>=0; --i)
		av_push(res, newSV(0));
	    mXPUSHs(avTsv(res));
	    RETURN;
	}
	if (!add)
	    Perl_croak(aTHX_ "%s expects a HASH but got UNDEF", OP_DESC(PL_op));
	if (SvREADONLY(hv))
	    Perl_croak(aTHX_ PL_no_modify);
	sv_upgrade(hvTsv(hv), SVt_PVHV);
    }
    else if ( ! SvHVOK(hv) )
	Perl_croak(aTHX_ "Not a HASH");

    if (op_flags & OPf_ASSIGN) {
	SV* newv;
	AV* newav;
	AV* ret;
	IV i;
	bool partial = (op_flags & OPf_ASSIGN_PART) ? 1 : 0;
	if (partial) {
	    if (PL_stack_base + TOPMARK >= SP) {
		if ( ! (op_flags & OPf_OPTIONAL) )
		    Perl_croak(aTHX_ "Missing required assignment value");
		newv = &PL_sv_undef;
	    } 
	    else
		newv = POPs;
	}
	else {
	    newv = POPs;
	}
	if ( ! SvAVOK(newv))
	    Perl_croak(aTHX_ "Value of hash slice must be ARRAY not %s",
		Ddesc(newv));
	newav = svTav(newv);

	if ( ! partial) {
	    ret = av_2mortal(newAV());
	}
	sliceitem = AvARRAY(slice);
	if (!sliceitem)
	    RETURN;
	slicemax = sliceitem + av_len(slice);

	i = 0;
	while (sliceitem <= slicemax) {
	    SV** newitem = av_fetch(newav, i, 0);
	    SV* keysv = *sliceitem;

            if (localizing) {
		HE* he = hv_fetch_ent(hv, keysv, 0, 0);
		SV** svp = he ? &HeVAL(he) : NULL;
		if (HvNAME_get(hv) && isGV(*svp))
		    Perl_croak(aTHX_ "can't localize glob");
		else {
		    if (svp)
			save_helem(hv, keysv, svp);
		    else {
			STRLEN keylen;
			const char * const key = SvPV_const(keysv, keylen);
			SAVEDELETE(hv, savepvn(key,keylen), (I32)keylen);
		    }
		}
            }

	    hv_store_ent(hv, keysv,
		newSVsv(newitem ? *newitem : &PL_sv_undef),
		0);
	    if ( ! partial) {
		av_push(ret, newSVsv(newitem ? *newitem : &PL_sv_undef));
	    }
	    i++;
	    sliceitem++;
	}
	if ( ! partial)
	    XPUSHs(avTsv(ret));
	RETURN;
    }

    slice = av_mortalcopy(slice);
    XPUSHs(avTsv(slice));

    sliceitem = AvARRAY(slice);
    if (!sliceitem)
	RETURN;
    slicemax = sliceitem + av_len(slice);

    while (sliceitem <= slicemax) {
        SV * const keysv = *sliceitem;
        SV **svp;
        HE *he;
        bool preeminent = FALSE;

        if (localizing) {
            preeminent = SvRMAGICAL(hv) && !other_magic ? 1 :
                hv_exists_ent(hv, keysv, 0);
        }

        he = hv_fetch_ent(hv, keysv, lval, 0);
        svp = he ? &HeVAL(he) : NULL;

        if (lval) {
            if (!svp || *svp == &PL_sv_undef) {
                DIE(aTHX_ PL_no_helem_sv, SVfARG(keysv));
            }
            if (localizing) {
		if (HvNAME_get(hv) && isGV(*svp))
		    Perl_croak(aTHX_ "can't localize glob");
		else {
		    if (preeminent)
			save_helem(hv, keysv, svp);
		    else {
			STRLEN keylen;
			const char * const key = SvPV_const(keysv, keylen);
			SAVEDELETE(hv, savepvn(key,keylen), (I32)keylen);
		    }
		}
            }
        }
        SVcpREPLACE(*sliceitem, svp ? *svp : newSV(0) );
	sliceitem++;
    }
    RETURN;
}

/* List operators. */

PP(pp_list)
{
    dVAR; dSP; dMARK;
    if (GIMME != G_ARRAY) {
#ifndef PERL_MAD
	if (GIMME_V == G_SCALAR)
	    Perl_croak(aTHX_ "list may not be used in scalar context");
#endif /* PERL_MAD */
	if (++MARK <= SP)
	    *MARK = *SP;		/* unwanted list, return last item */
	else
	    *MARK = &PL_sv_undef;
	SP = MARK;
    }
    RETURN;
}

PP(pp_listlast)
{
    dVAR; dSP; dMARK;
    if (++MARK <= SP)
	*MARK = *SP;		/* unwanted list, return last item */
    else
	*MARK = &PL_sv_undef;
    SP = MARK;
    RETURN;
}

PP(pp_listfirst)
{
    dVAR; dSP; dMARK;
    if ( ! (++MARK <= SP) )
	*MARK = &PL_sv_undef;
    SP = MARK;
    RETURN;
}

PP(pp_lslice)
{
    dVAR;
    dSP;
    SV ** const lastrelem = PL_stack_sp;
    SV ** const lastlelem = PL_stack_base + POPMARK;
    SV ** const firstlelem = PL_stack_base + POPMARK + 1;
    register SV ** const firstrelem = lastlelem + 1;
    I32 is_something_there = FALSE;

    register const I32 max = lastrelem - lastlelem;
    register SV **lelem;

    if (GIMME != G_ARRAY) {
	I32 ix = SvIV(*lastlelem);
	if (ix < 0)
	    ix += max;
	if (ix < 0 || ix >= max)
	    *firstlelem = &PL_sv_undef;
	else
	    *firstlelem = firstrelem[ix];
	SP = firstlelem;
	RETURN;
    }

    if (max == 0) {
	SP = firstlelem - 1;
	RETURN;
    }

    for (lelem = firstlelem; lelem <= lastlelem; lelem++) {
	I32 ix = SvIV(*lelem);
	if (ix < 0)
	    ix += max;
	if (ix < 0 || ix >= max)
	    *lelem = &PL_sv_undef;
	else {
	    is_something_there = TRUE;
	    if (!(*lelem = firstrelem[ix]))
		*lelem = &PL_sv_undef;
	}
    }
    if (is_something_there)
	SP = lastlelem;
    else
	SP = firstlelem - 1;
    RETURN;
}

PP(pp_anonscalar)
{
    dVAR; dSP;
    SV * const sv = POPs;
    mXPUSHs( newSVsv(sv) );
    RETURN;
}

PP(pp_enter_anonarray_assign)
{
    dSP;
    SV* sv = POPs;
    AV* av;
    I32 len, i;
    if ( ! SvAVOK(sv) )
	Perl_croak(aTHX_ "Expected ARRAY but got %s", Ddesc(sv));
    if ( ! ( PL_op->op_flags & OPf_ASSIGN_PART ) )
	XPUSHs(sv_mortalcopy(sv));
    av = svTav(sv);
    len = av_len(av);
    PUSHMARK(SP);
    for (i = len; i >= 0; i--) {
	SV** isv = av_fetch(av, i, FALSE);
	XPUSHs( isv ? *isv : &PL_sv_undef );
    }
    RETURN;
}

PP(pp_anonarray)
{
    dVAR; dSP; dMARK;
    const I32 items = SP - MARK;

    if (PL_op->op_flags & OPf_ASSIGN) {
	if (items)
	    Perl_croak(aTHX_ "Got extra value(s) in %s assignment", OP_DESC(PL_op));
	RETURN;
    }

    {
	dORIGMARK;
	SV * const av = (SV *) av_make(items, MARK+1);
	SP = ORIGMARK;		/* av_make() might realloc stack_sp */

	mXPUSHs( av );
    }
    RETURN;
}

PP(pp_enter_anonhash_assign)
{
    /* The stack: 
       Before:
	 keyX_is_optional
	 keyX
         ...            
	 key2_is_optional
	 key2
	 key1_is_optional
	 key1
	 value  <- MARK
	 XXX
       
       After:
         subj1
	 subj2
	 ...
	 subjX
	 XXX   <- MARK
    */
    dSP;
    dMARK;
    SV* value_sv = *MARK;
    HV* value;
    SV **key;
    AV *elem_values = av_2mortal(newAV());
    if ( ! SvHVOK(value_sv) )
	Perl_croak(aTHX_ "%s expects a HASH but got %s", OP_DESC(PL_op), Ddesc(value_sv));
    if ( ! ( PL_op->op_flags & OPf_ASSIGN_PART ) )
	*MARK = sv_mortalcopy(value_sv);
    value = svThv(sv_mortalcopy(value_sv));
    for (key = SP; key > MARK; key -= 2) {
	SV *elem_value = hv_delete_ent(value, *key, FALSE, 0);
	bool is_optional = (key[-1] == &PL_sv_yes);
	if ( ! ( elem_value || is_optional ) ) {
	    DIE("required key '%s' is missing", SvPVX_const(*key));
	}
	av_push(elem_values, elem_value ? elem_value : &PL_sv_undef);
    }
    if ( ! ( PL_op->op_flags & OPf_ASSIGN_PART ) )
	SP = MARK;
    else
	SP = MARK - 1;
    PUSHMARK(SP);

    /* push remaining keys */
    {
	register HE *entry;
	PUTBACK;
	(void)hv_iterinit(value);
	while ((entry = hv_iternext(value))) {
	    SV* sv;
	    SPAGAIN;
	    sv = hv_iterkeysv(entry);
	    XPUSHs(hv_iterval(value,entry));
	    XPUSHs(sv);
	    PUTBACK;
	}
    }

    /* push matching values */
    {
	SV** ary = AvARRAY(elem_values);
	SV** ary_last = ary + av_len(elem_values);
	for ( ; ary && (ary <= ary_last); ary++ )
	    PUSHs(SvREFCNT_inc(*ary));
    }
    RETURN;
}

PP(pp_anonhash)
{
    dVAR; dSP; dMARK;

    if (PL_op->op_flags & OPf_ASSIGN) {
	if (MARK != SP)
	    Perl_croak(aTHX_ "Got extra value(s) in %s assignment", OP_DESC(PL_op));
	RETURN;
    }

    {
	dORIGMARK;
	HV* hv;
	hv = newHV();

	while (MARK < SP) {
	    SV * const key = *++MARK;
	    SV * const val = newSV(0);
	    if (MARK < SP)
		sv_setsv(val, *++MARK);
	    else if (ckWARN(WARN_MISC))
		Perl_warner(aTHX_ packWARN(WARN_MISC), "Odd number of elements in anonymous hash");
	    (void)hv_store_ent(hv,key,val,0);
	}
	SP = ORIGMARK;

	mXPUSHs( (SV*)hv );

	RETURN;
    }
}

PP(pp_expand)
{
    dSP;
    if (SvHVOK(TOPs))
	return Perl_pp_hashexpand();
    else
	return Perl_pp_arrayexpand();
}

PP(pp_enter_arrayexpand_assign)
{
    dSP;
    SV** base = PL_stack_base + TOPMARK;
    IV items = SP - base;
    AV* av = av_2mortal(newAV());
    IV i;
    
    for (i = 0; i < items ; i++) {
	av_push(av, SvREFCNT_inc(POPs));
    }

    PUSHMARK(SP);
    XPUSHs(avTsv(av));

    RETURN;
}

PP(pp_enter_hashexpand_assign)
{
    dSP;
    const I32 gimme = GIMME_V;
    SV** base = PL_stack_base + TOPMARK;
    HV* hv = svThv(sv_2mortal(hvTsv(newHV())));
    IV duplicates = 0;
    
    while (SP > base) {	/* gobble up all the rest */
	SV* sv = POPs;
	SV* tmpstr = newSV(0);
	if (SP > base)
	    sv_setsv(tmpstr, POPs);	/* value */
	else
	    if (ckWARN(WARN_MISC)) {
		const char *err = "Odd number of elements in hash assignment";
		Perl_warner(aTHX_ packWARN(WARN_MISC), err);
	    }

	if (gimme != G_VOID && hv_exists_ent(hv, sv, 0))
	    /* key overwrites an existing entry */
	    duplicates += 2;
	hv_store_ent(hv,sv,tmpstr,0);
    }

    PUSHMARK(SP);
    XPUSHs(hvTsv(hv));

    RETURN;
}

PP(pp_arrayexpand)
{
    dVAR; dSP;
    OPFLAGS op_flags = PL_op->op_flags;

    if (op_flags & OPf_ASSIGN) {
	dMARK;
	if ( MARK != SP )
	    Perl_croak(aTHX_ "Array expansion assignment failed");
	RETURN;
    }

    {
	dTOPss;
	const I32 gimme = GIMME_V;

	do_arg_check(SP);

	if (gimme == G_SCALAR)
	    Perl_croak(aTHX_ "expand operator may not be used in scalar context");

	if ( ! (SvAVOK(sv) ) ) {
	    if ( SvOK(sv) )
		Perl_croak(aTHX_ "expand operator may not be used upon a %s", Ddesc(sv));
	    (void)POPs;
	    RETURN;
	}

	if (PL_op->op_flags & OPf_MOD && PL_op->op_flags & OPf_SPECIAL) {
	    /* lhs of an assignment is handled by pp_aassign */
	    RETURN;
	}

	if (gimme == G_ARRAY) {
	    AV *const av = (AV*)sv;
	    const I32 maxarg = AvFILL(av) + 1;
	    (void)POPs;			/* XXXX May be optimized away? */
	    EXTEND(SP, maxarg);
	    Copy(AvARRAY(av), SP+1, maxarg, SV*);
	    SP += maxarg;
	}
    }

    RETURN;
}

PP(pp_hashexpand)
{
    dVAR; dSP;
    OPFLAGS op_flags = PL_op->op_flags;
    if (op_flags & OPf_ASSIGN) {
	dMARK;
	if ( MARK != SP )
	    Perl_croak(aTHX_ "Array expansion assignment failed");
	RETURN;
    }

    {
	dTOPss;
	const I32 gimme = GIMME_V;

	do_arg_check(SP);

	if (gimme == G_SCALAR)
	    Perl_croak(aTHX_ "expand operator may not be used in scalar context");

	if ( ! SvHVOK(sv) ) {
	    if ( SvOK(sv) )
		Perl_croak(aTHX_ "%s operator may not be used upon a %s",
		    OP_DESC(PL_op), Ddesc(sv));
	    (void)POPs;
	    RETURN;
	}

	if (PL_op->op_flags & OPf_MOD && PL_op->op_flags & OPf_SPECIAL) {
	    /* lhs of an assignment is handled by pp_aassign */
	    RETURN;
	}

	if (gimme == G_ARRAY) {
	    HV* const hv = (HV*)sv;
	    register HE *entry;

	    (void)POPs;			/* XXXX May be optimized away? */

	    (void)hv_iterinit(hv);	/* reset iterator */

	    EXTEND(SP, HvKEYS(hv) * 2);

	    PUTBACK;	/* hv_iternext and hv_iterval might clobber stack_sp */
	    while ((entry = hv_iternext(hv))) {
		SV *tmpstr;
		SPAGAIN;
		XPUSHs(hv_iterkeysv(entry)); /* won't extend stack */
		PUTBACK;
		tmpstr = hv_iterval(hv,entry);
		SPAGAIN;
		XPUSHs(tmpstr);
		PUTBACK;
	    }
	}
    }

    RETURN;
}

PP(pp_nelems)
{
    dVAR; dSP;
    dTOPss;
    dTARGET;

    if ( ! SvOK(sv) ) {
	SETi(0);
	RETURN;
    }

    if (SvAVOK(sv)) {
	SETi( av_len((AV*)sv) + 1);
    }
    else if (SvHVOK(sv)) {
	SETi( 2 * HvKEYS((HV*)sv) );
    }
    else {
	Perl_croak(aTHX_ "nelems expected an array or hash but got %s", Ddesc(sv));
    }

    RETURN;
}

PP(pp_nkeys)
{
    dVAR; dSP;
    dTOPss;
    dTARGET;

    if ( ! SvOK(sv) ) {
	SETi(0);
	RETURN;
    }


    if (SvHVOK(sv)) {
	int i;
	HV* hv = (HV*)sv;
	(void)hv_iterinit(hv);	/* always reset iterator regardless */
	i = HvKEYS(hv);

	SETi( i );
    }
    else {
	Perl_croak(aTHX_ "nkeys expected a hash but got %s", Ddesc(sv));
    }

    RETURN;
}

PP(pp_splice)
{
    dVAR; dSP; dMARK; dORIGMARK;
    register AV *ary = (AV*)*++MARK;
    register SV **src;
    register SV **dst;
    register I32 i;
    register I32 offset;
    register I32 length;
    I32 newlen;
    I32 after;
    I32 diff;

    do_arg_check(MARK);

    SP++;

    if (++MARK < SP) {
	offset = i = SvIV(*MARK);
	if (offset < 0)
	    offset += AvFILLp(ary) + 1;
	if (offset < 0)
	    DIE(aTHX_ PL_no_aelem, i);
	if (++MARK < SP) {
	    length = SvIV(*MARK++);
	    if (length < 0) {
		length += AvFILLp(ary) - offset + 1;
		if (length < 0)
		    length = 0;
	    }
	}
	else
	    length = AvMAX(ary) + 1;		/* close enough to infinity */
    }
    else {
	offset = 0;
	length = AvMAX(ary) + 1;
    }
    if (offset > AvFILLp(ary) + 1) {
	if (ckWARN(WARN_MISC))
	    Perl_warner(aTHX_ packWARN(WARN_MISC), "splice() offset past end of array" );
	offset = AvFILLp(ary) + 1;
    }
    after = AvFILLp(ary) + 1 - (offset + length);
    if (after < 0) {				/* not that much array */
	length += after;			/* offset+length now in array */
	after = 0;
	if (!AvALLOC(ary))
	    av_extend(ary, 0);
    }

    /* At this point, MARK .. SP-1 is our new LIST */

    newlen = SP - MARK;
    diff = newlen - length;
    if (newlen && !AvREAL(ary) && AvREIFY(ary))
	av_reify(ary);

    /* make new elements SVs now: avoid problems if they're from the array */
    for (dst = MARK, i = newlen; i; i--) {
        SV * const h = *dst;
	*dst++ = newSVsv(h);
    }

    if (diff < 0) {				/* shrinking the area */
	SV **tmparyval = NULL;
	if (newlen) {
	    Newx(tmparyval, newlen, SV*);	/* so remember insertion */
	    Copy(MARK, tmparyval, newlen, SV*);
	}

	MARK = ORIGMARK + 1;
	if (GIMME == G_ARRAY) {			/* copy return vals to stack */
	    MEXTEND(MARK, length);
	    Copy(AvARRAY(ary)+offset, MARK, length, SV*);
	    if (AvREAL(ary)) {
		EXTEND_MORTAL(length);
		for (i = length, dst = MARK; i; i--) {
		    sv_2mortal(*dst);	/* free them eventualy */
		    dst++;
		}
	    }
	    MARK += length - 1;
	}
	else {
	    *MARK = AvARRAY(ary)[offset+length-1];
	    if (AvREAL(ary)) {
		sv_2mortal(*MARK);
		for (i = length - 1, dst = &AvARRAY(ary)[offset]; i > 0; i--)
		    SvREFCNT_dec(*dst++);	/* free them now */
	    }
	}
	AvFILLp(ary) += diff;

	/* pull up or down? */

	if (offset < after) {			/* easier to pull up */
	    if (offset) {			/* esp. if nothing to pull */
		src = &AvARRAY(ary)[offset-1];
		dst = src - diff;		/* diff is negative */
		for (i = offset; i > 0; i--)	/* can't trust Copy */
		    *dst-- = *src--;
	    }
	    dst = AvARRAY(ary);
	    AvARRAY(ary) = AvARRAY(ary) - diff; /* diff is negative */
	    AvMAX(ary) += diff;
	}
	else {
	    if (after) {			/* anything to pull down? */
		src = AvARRAY(ary) + offset + length;
		dst = src + diff;		/* diff is negative */
		Move(src, dst, after, SV*);
	    }
	    dst = &AvARRAY(ary)[AvFILLp(ary)+1];
						/* avoid later double free */
	}
	i = -diff;
	while (i)
	    dst[--i] = &PL_sv_undef;
	
	if (newlen) {
 	    Copy( tmparyval, AvARRAY(ary) + offset, newlen, SV* );
	    Safefree(tmparyval);
	}
    }
    else {					/* no, expanding (or same) */
	SV** tmparyval = NULL;
	if (length) {
	    Newx(tmparyval, length, SV*);	/* so remember deletion */
	    Copy(AvARRAY(ary)+offset, tmparyval, length, SV*);
	}

	if (diff > 0) {				/* expanding */
	    /* push up or down? */
	    if (offset < after && diff <= AvARRAY(ary) - AvALLOC(ary)) {
		if (offset) {
		    src = AvARRAY(ary);
		    dst = src - diff;
		    Move(src, dst, offset, SV*);
		}
		AvARRAY(ary) = AvARRAY(ary) - diff;/* diff is positive */
		AvMAX(ary) += diff;
		AvFILLp(ary) += diff;
	    }
	    else {
		if (AvFILLp(ary) + diff >= AvMAX(ary))	/* oh, well */
		    av_extend(ary, AvFILLp(ary) + diff);
		AvFILLp(ary) += diff;

		if (after) {
		    dst = AvARRAY(ary) + AvFILLp(ary);
		    src = dst - diff;
		    for (i = after; i; i--) {
			*dst-- = *src--;
		    }
		}
	    }
	}

	if (newlen) {
	    Copy( MARK, AvARRAY(ary) + offset, newlen, SV* );
	}

	MARK = ORIGMARK + 1;
	if (GIMME == G_ARRAY) {			/* copy return vals to stack */
	    if (length) {
		Copy(tmparyval, MARK, length, SV*);
		if (AvREAL(ary)) {
		    EXTEND_MORTAL(length);
		    for (i = length, dst = MARK; i; i--) {
			sv_2mortal(*dst);	/* free them eventualy */
			dst++;
		    }
		}
	    }
	    MARK += length - 1;
	}
	else if (length--) {
	    *MARK = tmparyval[length];
	    if (AvREAL(ary)) {
		sv_2mortal(*MARK);
		while (length-- > 0)
		    SvREFCNT_dec(tmparyval[length]);
	    }
	}
	else
	    *MARK = &PL_sv_undef;
	Safefree(tmparyval);
    }
    SP = MARK;
    RETURN;
}

PP(pp_push)
{
    dVAR; dSP; dMARK; dORIGMARK;
    register AV * const ary = (AV*)*++MARK;

    do_arg_check(MARK);

    if ( ! SvAVOK(ary) ) {
	if ( SvOK(ary) )
	    Perl_croak(aTHX_ "First argument to %s must be an ARRAY not %s", 
		OP_DESC(PL_op), Ddesc(avTsv(ary)));

	if (SvREADONLY(ary))
	    Perl_croak(aTHX_ PL_no_modify);

	sv_upgrade(avTsv(ary), SVt_PVAV);
    }

    {
	PL_delaymagic = DM_DELAY;
	for (++MARK; MARK <= SP; MARK++) {
	    SV * const sv = newSV(0);
	    if (*MARK)
		sv_setsv(sv, *MARK);
	    av_store(ary, AvFILLp(ary)+1, sv);
	}
	if (PL_delaymagic & DM_ARRAY)
	    mg_set((SV*)ary);

	PL_delaymagic = 0;
	SP = ORIGMARK;
	mPUSHi( AvFILLp(ary) + 1 );
    }
    RETURN;
}

PP(pp_shift)
{
    dVAR;
    dSP;
    SV * const avsv = POPs;

    if( ! SvAVOK(avsv) )
	Perl_croak(aTHX "shift expected an ARRAY not %s", Ddesc(avsv));

    {
	AV* const av = svTav(avsv);
	SV * const sv = PL_op->op_type == OP_SHIFT ? av_shift(av) : av_pop(av);
	EXTEND(SP, 1);
	assert (sv);
	if (AvREAL(av))
	    (void)sv_2mortal(sv);
	PUSHs(sv);
	RETURN;
    }
}

PP(pp_unshift)
{
    dVAR; dSP; dMARK; dORIGMARK;
    register AV *ary = (AV*)*++MARK;

    if ( ! SvAVOK(ary) ) {
	if ( SvOK(ary) )
	    Perl_croak(aTHX_ "Can't %s a %s", OP_DESC(PL_op), Ddesc(avTsv(ary)));
	if (SvREADONLY(ary))
	    Perl_croak(aTHX_ PL_no_modify);
	sv_upgrade(avTsv(ary), SVt_PVAV);
    }

    {
	register I32 i = 0;
	av_unshift(ary, SP - MARK);
	while (MARK < SP) {
	    SV * const sv = newSVsv(*++MARK);
	    (void)av_store(ary, i++, sv);
	}
    }
    SP = ORIGMARK;
    mPUSHi( AvFILL(ary) + 1 );
    RETURN;
}

PP(pp_reverse)
{
    dVAR; dSP;
    SV * const av = sv_mortalcopy(POPs);
    SV ** ary;
    SV ** end;

    if ( ! SvAVOK(av) ) {
	Perl_croak(aTHX_ "%s expected an ARRAY but got %s", OP_DESC(PL_op), Ddesc(av));
    }

    ary = AvARRAY(av);
    end = ary + av_len(svTav(av));
    
    if (ary) {
	while (ary < end) {
	    register SV * const tmp = *ary;
	    *ary++ = *end;
	    *end-- = tmp;
	}
    }
    PUSHs(av);
    RETURN;
}

PP(pp_arrayjoin)
{
    dVAR; dSP;
    SV * const av = POPs;
    SV ** ary;
    SV ** end;
    AV * newav = av_2mortal(newAV());

    if ( ! SvAVOK(av) ) {
	Perl_croak(aTHX_ "%s expected an ARRAY but got %s", OP_DESC(PL_op), Ddesc(av));
    }

    ary = AvARRAY(av);
    end = ary + av_len(svTav(av));
    
    if (ary) {
	while (ary <= end) {
	    register SV * const tmp = *ary;
	    SV ** subary;
	    I32 sublen;
	    I32 i;
	    if ( ! SvAVOK(tmp) ) {
		Perl_croak(aTHX_ "%s expected an ARRAY but got %s",
		    OP_DESC(PL_op), Ddesc(tmp));
	    }
	    subary = AvARRAY(svTav(tmp));
	    sublen = av_len(svTav(tmp));
	    for (i=0; i<=sublen; i++)
		av_push(newav, newSVsv(subary[i])); 
	    ary++;
	}
    }
    PUSHs(avTsv(newav));
    RETURN;
}

PP(pp_hashjoin)
{
    dVAR; dSP;
    SV * const av = POPs;
    SV ** ary;
    SV ** end;
    HV * newhv = hv_2mortal(newHV());

    if ( ! SvAVOK(av) ) {
	Perl_croak(aTHX_ "%s expected an ARRAY but got %s", OP_DESC(PL_op), Ddesc(av));
    }

    ary = AvARRAY(av);
    end = ary + av_len(svTav(av));
    
    if (ary) {
	while (ary <= end) {
	    register HV * tmp;
	    register HE *entry;
	    if ( ! SvHVOK(*ary) ) {
		Perl_croak(aTHX_ "%s expected an ARRAY but got %s",
		    OP_DESC(PL_op), Ddesc(*ary));
	    }
	    tmp = svThv(*ary);
	    (void)hv_iterinit(tmp);

	    while ((entry = hv_iternext(tmp))) {
		SV* val = newSVsv(HeVAL(entry));
		hv_store(newhv, HeKEY(entry), HeKLEN(entry), val, HeHASH(entry));
	    }
	    ary++;
	}
    }
    PUSHs(hvTsv(newhv));
    RETURN;
}

PP(pp_emptyarray)
{
    dSP;
    mXPUSHs(avTsv(newAV()));
    RETURN;
}

PP(pp_emptyhash)
{
    dSP;
    mXPUSHs(hvTsv(newHV()));
    RETURN;
}

PP(pp_arrayconcat)
{
    dVAR; dSP;
    dPOPTOPssrl;
    SV ** ary;
    I32 i;
    I32 len;
    AV *res;

    if ( ! SvAVOK(right) ) {
	Perl_croak(aTHX_ "%s expected an ARRAY but got %s",
	    OP_DESC(PL_op), Ddesc(right));
    }
    if ( ! SvAVOK(left) ) {
	Perl_croak(aTHX_ "%s expected an ARRAY but got %s",
	    OP_DESC(PL_op), Ddesc(left));
    }

    res = svTav(sv_2mortal(newSVsv(left)));
    TOPs = avTsv(res);
    
    ary = AvARRAY(svTav(right));
    len = av_len(svTav(right));
    for (i=0; i<=len; i++)
	av_push(res, newSVsv(ary[i])); 

    RETURN;
}

PP(pp_hashconcat)
{
    dVAR; dSP;
    dPOPTOPssrl;
    HV* res;
    register HV *right_hv;
    register HE *entry;

    if ( ! SvHVOK(right) ) {
	Perl_croak(aTHX_ "%s expected a HASH but got %s",
	    OP_DESC(PL_op), Ddesc(right));
    }
    if ( ! SvHVOK(left) ) {
	Perl_croak(aTHX_ "%s expected a HASH but got %s",
	    OP_DESC(PL_op), Ddesc(left));
    }

    res = svThv(sv_2mortal(newSVsv(left)));
    TOPs = hvTsv(res);
    right_hv = svThv(right);

    (void)hv_iterinit(right_hv);
    
    while ((entry = hv_iternext(right_hv))) {
	SV* val = newSVsv(HeVAL(entry));
	hv_store(res, HeKEY(entry), HeKLEN(entry), val, HeHASH(entry));
    }

    RETURN;
}


PP(pp_split)
{
    dVAR; dSP;
    AV *av;
    register IV limit = POPi;			/* note, negative is forever */
    SV * const sv = POPs;
    STRLEN len;
    register const char *s = SvPV_const(sv, len);
    bool do_utf8;
    const char *strend = s + len;
    register PMOP *pm;
    register REGEXP *rx;
    register SV *dstr;
    register const char *m;
    I32 iters = 0;
    const STRLEN slen = (STRLEN)(strend - s);
    I32 maxiters = slen + 10;
    const char *orig;
    const I32 origlimit = limit;
    I32 base;
    const I32 oldsave = PL_savestack_ix;
    U32 make_mortal = 0;
    bool multiline = 0;

    pm = (PMOP*)POPs;
    if (!pm || !s)
	DIE(aTHX_ "panic: pp_split");
    rx = PM_GETRE(pm);

    do_utf8 = (RX_EXTFLAGS(rx) & RXf_PMf_UTF8) != 0;

    av = av_2mortal(newAV());

    base = SP - PL_stack_base;
    orig = s;
    if (RX_EXTFLAGS(rx) & RXf_SKIPWHITE) {
	if (do_utf8) {
	    while (*s == ' ' || is_utf8_space(s))
		s += UTF8SKIP(s);
	}
	else {
	    while (isSPACE(*s))
		s++;
	}
    }
    if (RX_EXTFLAGS(rx) & PMf_MULTILINE) {
	multiline = 1;
    }

    if (!limit)
	limit = maxiters + 2;
    if (RX_EXTFLAGS(rx) & RXf_WHITE) {
	while (--limit) {
	    m = s;
	    /* this one uses 'm' and is a negative test */
	    if (do_utf8) {
		while (m < strend && !( *m == ' ' || is_utf8_space(m) )) {
		    const int t = UTF8SKIP(m);
		    /* is_utf8_space returns FALSE for malform utf8 */
		    if (strend - m < t)
			m = strend;
		    else
			m += t;
		}
            } else {
                while (m < strend && !isSPACE(*m))
                    ++m;
            }  
	    if (m >= strend)
		break;

	    dstr = newSVpvn_flags(s, m-s, make_mortal);
	    av_push(av, dstr);

	    /* skip the whitespace found last */
	    if (do_utf8)
		s = m + UTF8SKIP(m);
	    else
		s = m + 1;

	    /* this one uses 's' and is a positive test */
	    if (do_utf8) {
		while (s < strend && ( *s == ' ' || is_utf8_space(s) ))
	            s +=  UTF8SKIP(s);
            } else {
                while (s < strend && isSPACE(*s))
                    ++s;
            } 	    
	}
    }
    else if (RX_EXTFLAGS(rx) & RXf_START_ONLY) {
	while (--limit) {
	    for (m = s; m < strend && *m != '\n'; m++)
		;
	    m++;
	    if (m >= strend)
		break;
	    dstr = newSVpvn_flags(s, m-s, make_mortal);
	    av_push(av, dstr);
	    s = m;
	}
    }
    else if ((RX_EXTFLAGS(rx) & RXf_USE_INTUIT) && !RX_NPARENS(rx)
	     && (RX_EXTFLAGS(rx) & RXf_CHECK_ALL)
	     && !(RX_EXTFLAGS(rx) & RXf_ANCH)) {
	const int tail = (RX_EXTFLAGS(rx) & RXf_INTUIT_TAIL);
	SV * const csv = CALLREG_INTUIT_STRING(rx);

	len = RX_MINLENRET(rx);
	if (len == 1 && !(do_utf8) && !tail) {
	    const char c = *SvPV_nolen_const(csv);
	    while (--limit) {
		for (m = s; m < strend && *m != c; m++)
		    ;
		if (m >= strend)
		    break;
		dstr = newSVpvn_flags(s, m-s, make_mortal);
		av_push(av, dstr);
		s = m + len; /* Fake \n at the end */
	    }
	}
	else {
	    while (s < strend && --limit &&
	      (m = fbm_instr((char*)s, (char*)strend,
			     csv, multiline ? FBMrf_MULTILINE : 0)) )
	    {
		dstr = newSVpvn_flags(s, m-s, make_mortal);
		av_push(av, dstr);
		s = m + len; /* Fake \n at the end */
	    }
	}
    }
    else {
	maxiters += slen * RX_NPARENS(rx);
	while (s < strend && --limit)
	{
	    I32 rex_return;
	    PUTBACK;
	    rex_return = CALLREGEXEC(rx, (char*)s, (char*)strend, (char*)orig, 1 ,
			    sv, NULL, 0);
	    SPAGAIN;
	    if (rex_return == 0)
		break;
	    if (RX_MATCH_COPIED(rx) && RX_SUBBEG(rx) != orig) {
		m = s;
		s = orig;
		orig = RX_SUBBEG(rx);
		s = orig + (m - s);
		strend = s + (strend - m);
	    }
	    m = RX_OFFS(rx)[0].start + orig;
	    dstr = newSVpvn_flags(s, m-s, make_mortal);
	    av_push(av, dstr);
	    if (RX_NPARENS(rx)) {
		I32 i;
		for (i = 1; i <= (I32)RX_NPARENS(rx); i++) {
		    s = RX_OFFS(rx)[i].start + orig;
		    m = RX_OFFS(rx)[i].end + orig;

		    /* japhy (07/27/01) -- the (m && s) test doesn't catch
		       parens that didn't match -- they should be set to
		       undef, not the empty string */
		    if (m >= orig && s >= orig) {
			dstr = newSVpvn_flags(s, m-s, make_mortal);
		    }
		    else
			dstr = &PL_sv_undef;  /* undef, not "" */
		    av_push(av, dstr);
		}
	    }
	    s = RX_OFFS(rx)[0].end + orig;
	}
    }

    iters = av_len(av) + 1;
    if (iters > maxiters)
	DIE(aTHX_ "Split loop");

    /* keep field after final delim? */
    if (s < strend || (iters && origlimit)) {
        const STRLEN l = strend - s;
	dstr = newSVpvn_flags(s, l, make_mortal);
	av_push(av, dstr);
	iters++;
    }
    else if (!origlimit) {
	SV** last = av_fetch(av, iters-1, 0);
	while (iters && (!last || !SvOK(*last) || SvCUR(*last) == 0)) {
	    SvREFCNT_dec(av_pop(av));
	    iters--;
	    last = av_fetch(av, iters-1, 0);
	}
    }

    PUTBACK;
    LEAVE_SCOPE(oldsave); /* may undo an earlier SWITCHSTACK */
    SPAGAIN;
    XPUSHs(avTsv(av));
    RETURN;
}

PP(pp_lock)
{
    dVAR;
    dSP;
    dTOPss;
    SV *retsv = sv;
    SvLOCK(sv);
    if (SvTYPE(retsv) == SVt_PVAV || SvTYPE(retsv) == SVt_PVHV
	|| SvTYPE(retsv) == SVt_PVCV) {
	retsv = refto(retsv);
    }
    SETs(retsv);
    RETURN;
}

PP(pp_ref_eq)
{
    dSP;

    if (! SvROK(TOPs))
	DIE(aTHX_ "Not a reference");
    if (! SvROK(TOPm1s))
	DIE(aTHX_ "Not a reference");

    SP--;
    SETs(boolSV(SvRV(TOPs) == SvRV(TOPp1s)));
    RETURN;
}

PP(pp_ref_ne)
{
    dSP;

    if (! SvROK(TOPs))
	DIE(aTHX_ "Not a reference");
    if (! SvROK(TOPm1s))
	DIE(aTHX_ "Not a reference");

    SP--;
    SETs(boolSV(SvRV(TOPs) != SvRV(TOPp1s)));
    RETURN;
}

PP(pp_compsub)
{
    dVAR;
    DIE(aTHX_ "panic: compsub should be replaced");
}


PP(unimplemented_op)
{
    dVAR;
    DIE(aTHX_ "panic: unimplemented op %s (#%d) called", OP_NAME(PL_op),
	PL_op->op_type);
}

PP(pp_dotdotdot)
{
    OPFLAGS op_flags = PL_op->op_flags;
    if ( ! ( op_flags & OPf_ASSIGN ) )
	DIE(aTHX_ "%s must be part of an assignment", OP_DESC(PL_op));
    {
	dSP;
	SP = PL_stack_base + TOPMARK;
	RETURN;
    }
}

PP(pp_placeholder)
{
    dSP;
    OPFLAGS op_flags = PL_op->op_flags;
    SV* sv;
    I32 gimme = GIMME_V;
    if ( ! ( op_flags & OPf_ASSIGN ) )
	DIE(aTHX_ "%s must be part of an assignment", OP_DESC(PL_op));
    if (op_flags & OPf_ASSIGN_PART) {
	if (PL_stack_base + TOPMARK >= SP) {
	    if ( ! (op_flags & OPf_OPTIONAL) )
		Perl_croak(aTHX_ "Missing required assignment value");
	} 
	else
	    SP--;
	RETURN;
    }
    if ( gimme != G_VOID )
	DIE(aTHX_ "%s must be used in void context", OP_DESC(PL_op));
    sv = POPs;
    RETURN;
}

PP(pp_dynascope)
{
    dSP;
    mXPUSHs(newRV(PL_dynamicscope));
    RETURN;
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
