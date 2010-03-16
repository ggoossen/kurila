/*    pp_hot.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000,
 *    2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * Then he heard Merry change the note, and up went the Horn-cry of Buckland,
 * shaking the air.
 *
 *                  Awake!  Awake!  Fear, Fire, Foes!  Awake!
 *                               Fire, Foes!  Awake!
 *
 *     [p.1007 of _The Lord of the Rings_, VI/viii: "The Scouring of the Shire"]
 */

/* This file contains 'hot' pp ("push/pop") functions that
 * execute the opcodes that make up a perl program. A typical pp function
 * expects to find its arguments on the stack, and usually pushes its
 * results onto the stack, hence the 'pp' terminology. Each OP structure
 * contains a pointer to the relevant pp_foo() function.
 *
 * By 'hot', we mean common ops whose execution speed is critical.
 * By gathering them together into a single file, we encourage
 * CPU cache hits on hot code. Also it could be taken as a warning not to
 * change any code in this file unless you're sure it won't affect
 * performance.
 */

#include "EXTERN.h"
#define PERL_IN_PP_HOT_C
#include "perl.h"

/* Hot code. */

PP(pp_const)
{
    dVAR;
    dSP;
    XPUSHs(cSVOP_sv);
    RETURN;
}

PP(pp_nextstate)
{
    dVAR;
    PL_curcop = (COP*)PL_op;
    PL_stack_sp = PL_stack_base + cxstack[cxstack_ix].blk_oldsp;
    FREETMPS;
    return NORMAL;
}

PP(pp_gvsv)
{
    dVAR;
    dSP;
    SV* sv;
    OPFLAGS op_flags = PL_op->op_flags;
    if (PL_op->op_private & OPpLVAL_INTRO)
	sv = save_scalar(cGVOP_gv);
    else
	sv = GvSVn(cGVOP_gv);
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
    XPUSHs(sv);
    RETURN;
}

PP(pp_null)
{
    dVAR;
    return NORMAL;
}

PP(pp_pushmark)
{
    dVAR;
    PUSHMARK(PL_stack_sp);
    return NORMAL;
}

PP(pp_stringify)
{
    dVAR; dSP; dTARGET;
    sv_copypv(TARG,TOPs);
    SETTARG;
    RETURN;
}

PP(pp_gv)
{
    dVAR; dSP;
    XPUSHs(MUTABLE_SV(cGVOP_gv));
    RETURN;
}

PP(pp_and)
{
    dVAR; dSP;
    if (!SvTRUE(TOPs))
	RETURN;
    else {
        if (PL_op->op_type == OP_AND)
	    --SP;
	RETURNOP(cLOGOP->op_other);
    }
}

PP(pp_sassign)
{
    dVAR; dSP;
    RETURN;
}

PP(pp_cond_expr)
{
    dVAR; dSP;
    if (SvTRUE(POPs))
	RETURNOP(cLOGOP->op_other);
    else
	RETURNOP(cLOGOP->op_next);
}

PP(pp_unstack)
{
    dVAR;
    I32 oldsave;
    PL_stack_sp = PL_stack_base + cxstack[cxstack_ix].blk_oldsp;
    FREETMPS;
    oldsave = PL_scopestack[PL_scopestack_ix - 1];
    LEAVE_SCOPE(oldsave);
    return NORMAL;
}

PP(pp_concat)
{
  dVAR; dSP; dATARGET;
  {
    dPOPTOPssrl;
    STRLEN rlen;
    const char *rpv = NULL;
    bool rcopied = FALSE;

    if (TARG == right && right != left) {
	rpv = SvPV_const(right, rlen);
	right = newSVpvn_flags(rpv, rlen, SVs_TEMP);
	rpv = SvPV_const(right, rlen);	/* no point setting UTF-8 here */
	rcopied = TRUE;
    }

    if (TARG != left) {
        STRLEN llen;
        const char* const lpv = SvPV_const(left, llen);
	sv_setpvn(TARG, lpv, llen);
    }
    else { /* TARG == left */
        STRLEN llen;
	if (!SvOK(TARG)) {
	    if (left == right && ckWARN(WARN_UNINITIALIZED))
		report_uninit(right);
	    sv_setpvs(left, "");
	}
	(void)SvPV_const(left, llen);    /* Needed to set UTF8 flag */
    }

    if (!rcopied) {
	rpv = SvPV_const(right, rlen);
    }
    sv_catpvn_nomg(TARG, rpv, rlen);

    SETTARG;
    RETURN;
  }
}

PP(pp_padsv)
{
    dVAR; dSP; dTARGET;
    const I32 gimme = GIMME_V;
    const OPFLAGS op_flags = PL_op->op_flags;
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
	    sv_setsv_mg(TARG, src);
	    if (PL_op->op_private & OPpLVAL_INTRO)
		SAVECLEARSV(PAD_SVl(PL_op->op_targ));
	    RETURN;
	}
	sv_setsv_mg(TARG, POPs);
    }
    if (gimme != G_VOID)
	XPUSHs(TARG);
    if (PL_op->op_flags & OPf_MOD) {
	if (PL_op->op_private & OPpLVAL_INTRO)
	    SAVECLEARSV(PAD_SVl(PL_op->op_targ));
    }
    RETURN;
}

PP(pp_magicsv)
{
    dVAR; dSP;
    const I32 gimme = GIMME_V;
    const OPFLAGS op_flags = PL_op->op_flags;
    const char* name = SvPVX_const(cSVOP_sv);
    if (PL_op->op_private & OPpLVAL_INTRO) {
	Perl_save_set_magicsv(aTHX_ cSVOP_sv);
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
	    magic_set(name, src);
	    RETURN;
	}
	magic_set(name, POPs);
    }
    if (gimme != G_VOID) {
	SV* sv = sv_2mortal(newSV(0));
	magic_get(name, sv);
	SvREADONLY_on(sv);
	XPUSHs(sv);
    }

    RETURN;
}

PP(pp_readline)
{
    dVAR;
    SV* sv;
    sv = *PL_stack_sp--;
    if (SvTYPE(sv) != SVt_PVGV) {
	if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVGV)
	    sv = SvRV(sv);
	else {
	    dSP;
            XPUSHs(sv);
            PUTBACK;
            pp_rv2gv();
            sv = *PL_stack_sp--;
	}
    }
    return do_readline((GV*)(sv));
}

PP(pp_eq)
{
    dVAR; dSP;
#ifdef PERL_PRESERVE_IVUV

    {
	SV* sva = sv_2num(TOPm1s);
	SV* svb = sv_2num(TOPs);

	if (SvIOK(svb)) {
	    /* Unless the left argument is integer in range we are going
	       to have to use NV maths. Hence only attempt to coerce the
	       right argument if we know the left is integer.  */
	    if (SvIOK(sva)) {
		const bool auvok = SvUOK(sva);
		const bool buvok = SvUOK(svb);
	
		if (auvok == buvok) { /* ## IV == IV or UV == UV ## */
		    /* Casting IV to UV before comparison isn't going to matter
		       on 2s complement. On 1s complement or sign&magnitude
		       (if we have any of them) it could to make negative zero
		       differ from normal zero. As I understand it. (Need to
		       check - is negative zero implementation defined behaviour
		       anyway?). NWC  */
		    const UV buv = SvUVX(POPs);
		    const UV auv = SvUVX(TOPs);
		
		    SETs(boolSV(auv == buv));
		    RETURN;
		}
		{			/* ## Mixed IV,UV ## */
		    SV *ivp, *uvp;
		    IV iv;
		
		    /* == is commutative so doesn't matter which is left or right */
		    if (auvok) {
			/* top of stack (b) is the iv */
			ivp = *SP;
			uvp = *--SP;
		    } else {
			uvp = *SP;
			ivp = *--SP;
		    }
		    iv = SvIV(ivp);
		    if (iv < 0)
			/* As uv is a UV, it's >0, so it cannot be == */
			SETs(&PL_sv_no);
		    else
			/* we know iv is >= 0 */
			SETs(boolSV((UV)iv == SvUVX(uvp)));
		    RETURN;
		}
	    }
	}
    }
#endif
    {
#if defined(NAN_COMPARE_BROKEN) && defined(Perl_isnan)
      dPOPTOPnnrl;
      if (Perl_isnan(left) || Perl_isnan(right))
	  RETSETNO;
      SETs(boolSV(left == right));
#else
      dPOPnv;
      SETs(boolSV(TOPn == value));
#endif
      RETURN;
    }
}

PP(pp_preinc)
{
    dVAR; dSP;
    if ( SvOK(TOPs) && ! SvPVOK(TOPs) )
	Perl_croak(aTHX_ "increment (++) does not work on a %s", Ddesc(TOPs));
    if (!SvREADONLY(TOPs) && SvIOK_notUV(TOPs) && !SvNOK(TOPs) && !SvPOK(TOPs)
        && SvIV(TOPs) != IV_MAX)
    {
	SvIV_set(TOPs, SvIV(TOPs) + 1);
	SvFLAGS(TOPs) &= ~(SVp_NOK|SVp_POK);
    }
    else /* Do all the PERL_PRESERVE_IVUV conditionals in sv_inc */
	sv_inc(TOPs);
    SvSETMAGIC(TOPs);
    return NORMAL;
}

PP(pp_or)
{
    dVAR; dSP;
    if (SvTRUE(TOPs))
	RETURN;
    else {
	if (PL_op->op_type == OP_OR)
            --SP;
	RETURNOP(cLOGOP->op_other);
    }
}

PP(pp_defined)
{
    dVAR; dSP;
    register SV* sv;
    bool defined;
    const int op_type = PL_op->op_type;
    const bool is_dor = (op_type == OP_DOR || op_type == OP_DORASSIGN);

    if (is_dor) {
        sv = TOPs;
        if (!sv || !SvANY(sv)) {
	    if (op_type == OP_DOR)
		--SP;
            RETURNOP(cLOGOP->op_other);
        }
    }
    else {
	/* OP_DEFINED */
        sv = POPs;
        if (!sv || !SvANY(sv))
            RETPUSHNO;
    }

    defined = FALSE;
    if (SvTYPE(sv) == SVt_PVCV) {
	if (CvROOT(sv) || CvXSUB(sv))
	    defined = TRUE;
    }
    else {
	if (SvOK(sv))
	    defined = TRUE;
    }

    if (is_dor) {
        if(defined) 
            RETURN; 
        if(op_type == OP_DOR)
            --SP;
        RETURNOP(cLOGOP->op_other);
    }
    /* assuming OP_DEFINED */
    if(defined) 
        RETPUSHYES;
    RETPUSHNO;
}

PP(pp_add)
{
    dVAR; dSP; dATARGET; bool useleft; SV *svl, *svr;
    svl = sv_2num(TOPm1s);
    svr = sv_2num(TOPs);
    useleft = USE_LEFT(svl);
#ifdef PERL_PRESERVE_IVUV
    /* We must see if we can perform the addition with integers if possible,
       as the integer code detects overflow while the NV code doesn't.
       If either argument hasn't had a numeric conversion yet attempt to get
       the IV. It's important to do this now, rather than just assuming that
       it's not IOK as a PV of "9223372036854775806" may not take well to NV
       addition, and an SV which is NOK, NV=6.0 ought to be coerced to
       integer in case the second argument is IV=9223372036854775806
       We can (now) rely on sv_2iv to do the right thing, only setting the
       public IOK flag if the value in the NV (or PV) slot is truly integer.

       A side effect is that this also aggressively prefers integer maths over
       fp maths for integer values.

       How to detect overflow?

       C 99 section 6.2.6.1 says

       The range of nonnegative values of a signed integer type is a subrange
       of the corresponding unsigned integer type, and the representation of
       the same value in each type is the same. A computation involving
       unsigned operands can never overflow, because a result that cannot be
       represented by the resulting unsigned integer type is reduced modulo
       the number that is one greater than the largest value that can be
       represented by the resulting type.

       (the 9th paragraph)

       which I read as "unsigned ints wrap."

       signed integer overflow seems to be classed as "exception condition"

       If an exceptional condition occurs during the evaluation of an
       expression (that is, if the result is not mathematically defined or not
       in the range of representable values for its type), the behavior is
       undefined.

       (6.5, the 5th paragraph)

       I had assumed that on 2s complement machines signed arithmetic would
       wrap, hence coded pp_add and pp_subtract on the assumption that
       everything perl builds on would be happy.  After much wailing and
       gnashing of teeth it would seem that irix64 knows its ANSI spec well,
       knows that it doesn't need to, and doesn't.  Bah.  Anyway, the all-
       unsigned code below is actually shorter than the old code. :-)
    */

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
	    /* left operand is undef, treat as zero. + 0 is identity,
	       Could SETi or SETu right now, but space optimise by not adding
	       lots of code to speed up what is probably a rarish case.  */
	} else {
	    /* Left operand is defined, so is it IV? */
	    if (SvIOK(svl)) {
		if ((auvok = SvUOK(svl)))
		    auv = SvUVX(svl);
		else {
		    register const IV aiv = SvIV(svl);
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
		register const IV biv = SvIV(svr);
		if (biv >= 0) {
		    buv = biv;
		    buvok = 1;
		} else
		    buv = (UV)-biv;
	    }
	    /* ?uvok if value is >= 0. basically, flagged as UV if it's +ve,
	       else "IV" now, independent of how it came in.
	       if a, b represents positive, A, B negative, a maps to -A etc
	       a + b =>  (a + b)
	       A + b => -(a - b)
	       a + B =>  (a - b)
	       A + B => -(a + b)
	       all UV maths. negate result if A negative.
	       add if signs same, subtract if signs differ. */

	    if (auvok ^ buvok) {
		/* Signs differ.  */
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
	    } else {
		/* Signs same */
		result = auv + buv;
		if (result >= auv)
		    result_good = 1;
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
	    /* left operand is undef, treat as zero. + 0.0 is identity. */
	    SETn(value);
	    RETURN;
	}
	SETn( value + SvNV(svl) );
	RETURN;
    }
}

PP(pp_aelemfast)
{
    dVAR; dSP;
    OPFLAGS const op_flags = PL_op->op_flags;
    AV * const av = op_flags & OPf_SPECIAL ?
		(AV*)PAD_SV(PL_op->op_targ) : GvAV(cGVOP_gv);
    const U32 lval = op_flags & OPf_MOD;
    const I32 elem = PL_op->op_private;
    if (!SvAVOK(av)) {
	if (lval && ! SvOK(av)) {
	    if (SvREADONLY(av))
		Perl_croak(aTHX_ PL_no_modify);
	    sv_upgrade((SV*)av, SVt_PVAV);
	}
	else
	    bad_arg(1, "array", PL_op_desc[PL_op->op_type], (SV*)av);
    }
    {
	SV** svp = av_fetch(av, elem, 0);
	EXTEND(SP, 1);
	if ( ! svp ) {
	    DIE(aTHX_ "Required array element %"IVdf" does not exists", elem);
	}
	if (lval && *svp == &PL_sv_undef)
	    svp = av_store(av, elem, newSV(0));
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
		sv_setsv_mg(*svp, src);
		RETURN;
	    }
	    sv_setsv_mg(*svp, POPs);
	}
	PUSHs(*svp);
    }
    RETURN;
}

PP(pp_join)
{
    dVAR; dSP; dMARK; dTARGET;
    MARK++;
    do_join(TARG, *MARK, MARK[1]);
    SP = MARK;
    SETs(TARG);
    RETURN;
}

PP(pp_pushre)
{
    dVAR; dSP;
    XPUSHs((SV*)PL_op);
    RETURN;
}

/* Oversized hot code. */

PP(pp_print)
{
    dVAR; dSP; dMARK; dORIGMARK;
    IO *io;
    register PerlIO *fp;
    GV * const gv = (GV*)*++MARK;
    if ( ! isGV(gv) )
	Perl_croak(aTHX_ "First argument to %s must be a filehandle but a %s",
	    OP_DESC(PL_op), Ddesc((SV*)gv));

    if (!(io = GvIO(gv))) {
	if (ckWARN2(WARN_UNOPENED,WARN_CLOSED))
	    report_evil_fh(io, PL_op->op_type);
	SETERRNO(EBADF,RMS_IFI);
	goto just_say_no;
    }
    else if (!(fp = IoOFP(io))) {
	if (ckWARN2(WARN_CLOSED, WARN_IO))  {
	    if (IoIFP(io))
		report_evil_fh(io, OP_phoney_INPUT_ONLY);
	    else if (ckWARN2(WARN_UNOPENED,WARN_CLOSED))
		report_evil_fh(io, PL_op->op_type);
	}
	SETERRNO(EBADF,IoIFP(io)?RMS_FAC:RMS_IFI);
	goto just_say_no;
    }
    else {
	MARK++;
	if (PL_ofs_sv && SvOK(PL_ofs_sv)) {
	    while (MARK <= SP) {
		if (!do_print(*MARK, fp))
		    break;
		MARK++;
		if (MARK <= SP) {
		    if (!do_print(PL_ofs_sv, fp)) { /* $, */
			MARK--;
			break;
		    }
		}
	    }
	}
	else {
	    while (MARK <= SP) {
		if (!do_print(*MARK, fp))
		    break;
		MARK++;
	    }
	}
	if (MARK <= SP)
	    goto just_say_no;
	else {
	    if (IoFLAGS(io) & IOf_FLUSH)
		if (PerlIO_flush(fp) == EOF)
		    goto just_say_no;
	}
    }
    SP = ORIGMARK;
    XPUSHs(&PL_sv_yes);
    RETURN;

  just_say_no:
    SP = ORIGMARK;
    XPUSHs(&PL_sv_undef);
    RETURN;
}


OP *
Perl_do_readline(pTHX_ GV* gv)
{
    dVAR; dSP; dTARGETSTACKED;
    register SV *sv;
    STRLEN tmplen = 0;
    STRLEN offset;
    PerlIO *fp;
    register IO * const io = GvIO(gv);
    register const I32 type = PL_op->op_type;
    const I32 gimme = GIMME_V;
    PERL_ARGS_ASSERT_DO_READLINE;

    fp = NULL;
    if (io) {
	fp = IoIFP(io);
	if (!fp) {
	    if (IoFLAGS(io) & IOf_ARGV) {
		if (IoFLAGS(io) & IOf_START) {
		    IoLINES(io) = 0;
		    if (av_len(GvAVn(gv)) < 0) {
			IoFLAGS(io) &= ~IOf_START;
			do_openn(io,"-",1,FALSE,O_RDONLY,0,NULL,NULL,0);
			sv_setpvn(GvSVn(gv), "-", 1);
			SvSETMAGIC(GvSV(gv));
			fp = IoIFP(io);
			goto have_fp;
		    }
		}
		fp = nextargv(gv);
		if (!fp) { /* Note: fp != IoIFP(io) */
		    (void)do_close(gv, FALSE); /* now it does*/
		}
	    }
	}
	else if (ckWARN(WARN_IO) && IoTYPE(io) == IoTYPE_WRONLY) {
	    report_evil_fh(io, OP_phoney_OUTPUT_ONLY);
	}
    }
    if (!fp) {
	if ((!io || !(IoFLAGS(io) & IOf_START))
	    && ckWARN2(WARN_GLOB, WARN_CLOSED))
	{
	    if (type == OP_GLOB)
		Perl_warner(aTHX_ packWARN(WARN_GLOB),
			    "glob failed (can't start child: %s)",
			    Strerror(errno));
	    else
		report_evil_fh(io, PL_op->op_type);
	}
	if (gimme == G_SCALAR) {
	    /* undef TARG, and push that undefined value */
	    if (type != OP_RCATLINE) {
		SV_CHECK_THINKFIRST_COW_DROP(TARG);
		if ( ! SvPVOK(TARG) )
		    sv_upgrade(TARG, SVt_PV);
		SvOK_off(TARG);
	    }
	    PUSHTARG;
	}
	RETURN;
    }
  have_fp:
    if (gimme == G_SCALAR) {
	sv = TARG;
	if (type == OP_RCATLINE) {
	    NOOP;
	}
	else {
	    if ( SvOK(sv) && ! SvPVOK(sv) )
		sv_clear_body(sv);
	}
	if (SvROK(sv)) {
	    if (type == OP_RCATLINE)
		SvPV_force_nolen(sv);
	    else
		sv_unref(sv);
	}
	else if (isGV_with_GP(sv)) {
	    SvPV_force_nolen(sv);
	}
	SvUPGRADE(sv, SVt_PV);
	tmplen = SvLEN(sv);	/* remember if already alloced */
	if (!tmplen && !SvREADONLY(sv))
	    Sv_Grow(sv, 80);	/* try short-buffering it */
	offset = 0;
	if (type == OP_RCATLINE && SvOK(sv)) {
	    if (!SvPOK(sv)) {
		SvPV_force_nolen(sv);
	    }
	    offset = SvCUR(sv);
	}
    }
    else {
	sv = sv_2mortal(newSV(80));
	offset = 0;
    }

/* delay EOF state for a snarfed empty file */
#define SNARF_EOF(gimme,rs,io,sv) \
    (gimme != G_SCALAR || SvCUR(sv)					\
     || (IoFLAGS(io) & IOf_NOLINE) || !RsSNARF(rs))

    for (;;) {
	PUTBACK;
	if (!sv_gets(sv, fp, offset)
	    && (type == OP_GLOB
		|| SNARF_EOF(gimme, PL_rs, io, sv)
		|| PerlIO_error(fp)))
	{
	    PerlIO_clearerr(fp);
	    if (IoFLAGS(io) & IOf_ARGV) {
		fp = nextargv(gv);
		if (fp)
		    continue;
		(void)do_close(gv, FALSE);
	    }
	    else if (type == OP_GLOB) {
		if (!do_close(gv, FALSE) && ckWARN(WARN_GLOB)) {
		    Perl_warner(aTHX_ packWARN(WARN_GLOB),
			   "glob failed (child exited with status %d%s)",
			   (int)(STATUS_CURRENT >> 8),
			   (STATUS_CURRENT & 0x80) ? ", core dumped" : "");
		}
	    }
	    if (gimme == G_SCALAR) {
		if (type != OP_RCATLINE) {
		    SV_CHECK_THINKFIRST_COW_DROP(TARG);
		    SvOK_off(TARG);
		}
		SPAGAIN;
		PUSHTARG;
	    }
	    RETURN;
	}
	IoLINES(io)++;
	IoFLAGS(io) |= IOf_NOLINE;
	SvSETMAGIC(sv);
	SPAGAIN;
	XPUSHs(sv);
	if (type == OP_GLOB) {
	    const char *t1;

	    if (SvCUR(sv) > 0 && SvCUR(PL_rs) > 0) {
		char * const tmps = SvEND(sv) - 1;
		if (*tmps == *SvPVX_const(PL_rs)) {
		    *tmps = '\0';
		    SvCUR_set(sv, SvCUR(sv) - 1);
		}
	    }
	    for (t1 = SvPVX_const(sv); *t1; t1++)
		if (!isALPHA(*t1) && !isDIGIT(*t1) &&
		    strchr("$&*(){}[]'\";\\|?<>~`", *t1))
			break;
	    if (*t1 && PerlLIO_lstat(SvPVX_const(sv), &PL_statbuf) < 0) {
		(void)POPs;		/* Unmatched wildcard?  Chuck it... */
		continue;
	    }
	} else if (PerlIO_isutf8(fp)) { /* OP_READLINE, OP_RCATLINE */
	     if (ckWARN(WARN_UTF8)) {
		const char * const s = SvPVX_const(sv) + offset;
		const STRLEN len = SvCUR(sv) - offset;
		const char *f;

		if (!is_utf8_string_loc(s, len, &f))
		    /* Emulate :encoding(utf8) warning in the same case. */
		    Perl_warner(aTHX_ packWARN(WARN_UTF8),
				"utf8 \"\\x%02X\" does not map to Unicode",
				f < SvEND(sv) ? (U8)*f : 0);
	     }
	}
	if (gimme == G_ARRAY) {
	    if (SvLEN(sv) - SvCUR(sv) > 20) {
		SvPV_shrink_to_cur(sv);
	    }
	    sv = sv_2mortal(newSV(80));
	    continue;
	}
	else if (gimme == G_SCALAR && !tmplen && SvLEN(sv) - SvCUR(sv) > 80) {
	    /* try to reclaim a bit of scalar space (only on 1st alloc) */
	    const STRLEN new_len
		= SvCUR(sv) < 60 ? 80 : SvCUR(sv)+40; /* allow some slop */
	    SvPV_renew(sv, new_len);
	}
	RETURN;
    }
}

PP(pp_enter)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    I32 gimme = OP_GIMME(PL_op, -1);

    if (gimme == -1) {
	if (cxstack_ix >= 0) {
	    /* If this flag is set, we're just inside a return, so we should
	     * store the caller's context */
	    gimme = (PL_op->op_flags & OPf_SPECIAL)
		? block_gimme()
		: cxstack[cxstack_ix].blk_gimme;
	} else
	    gimme = G_SCALAR;
    }

    ENTER_named("block");

    SAVETMPS;
    PUSHBLOCK(cx, CXt_BLOCK, SP);

    RETURN;
}

PP(pp_helem)
{
    dVAR; dSP;
    HE* he;
    SV **svp;
    SV * const keysv = POPs;
    HV * const hv = (HV*)POPs;
    const OPFLAGS op_flags = PL_op->op_flags;
    const U32 optional = PL_op->op_private & OPpELEM_OPTIONAL;
    const U32 add = PL_op->op_private & OPpELEM_ADD;
    SV *sv;
    U32 hash;
    I32 preeminent = 0;

    if ( ! SvHVOK(hv) ) {
	if ( SvOK(hv) ) {
	    Perl_croak(aTHX_ "Expected a HASH not %s", Ddesc(hvTsv(hv)));
	}

	/* hv must be "undef" */

	if ( optional ) {
	    RETPUSHUNDEF;
	}

	if ( ! add )
	    Perl_croak(aTHX_ "Can not use UNDEF as a HASH");
	if (SvREADONLY(hv))
	    Perl_croak(aTHX_ PL_no_modify);

	sv_upgrade((SV*)hv, SVt_PVHV);
    }

    hash = (SvIsCOW_shared_hash(keysv)) ? SvSHARED_HASH(keysv) : 0;

    if (PL_op->op_private & OPpLVAL_INTRO) {
	/* does the element we're localizing already exist? */
	preeminent = hv_exists_ent(hv, keysv, 0);
    }
    he = hv_fetch_ent(hv, keysv, 0, hash);
    svp = he ? &HeVAL(he) : NULL;
    if ( ! svp || *svp == &PL_sv_undef ) {
	if ( optional ) {
	    RETPUSHUNDEF;
	}
	if ( ! add )
	    Perl_croak(aTHX_ "Missing hash key '%s'", SvPVX_const(keysv));
	sv = newSV(0);
	hv_store_ent(hv, keysv, sv, hash);
	svp = &sv;
    }

    if (PL_op->op_private & OPpLVAL_INTRO) {
	if (HvNAME_get(hv) && isGV(*svp))
	    Perl_croak(aTHX_ "can't localize a glob");
	else {
	    if (!preeminent) {
		SAVEHDELETE(hv, keysv);
	    } else
		save_helem(hv, keysv, svp);
	}
    }

    sv = (svp ? *svp : &PL_sv_undef);
    /* This makes C<local $tied{foo} = $tied{foo}> possible.
     * Pushing the magical RHS on to the stack is useless, since
     * that magic is soon destined to be misled by the local(),
     * and thus the later pp_sassign() will fail to mg_get() the
     * old value.  This should also cure problems with delayed
     * mg_get()s.  GSAR 98-07-03 */
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

PP(pp_leave)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    SV **newsp;
    PMOP *newpm;
    U8 gimme;

    if (PL_op->op_flags & OPf_SPECIAL) {
	cx = &cxstack[cxstack_ix];
	cx->blk_oldpm = PL_curpm;	/* fake block should preserve $1 et al */
    }

    POPBLOCK(cx,newpm);

    gimme = OP_GIMME(PL_op, (cxstack_ix >= 0) ? gimme : G_SCALAR);

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
	} else {
	    MEXTEND(mark,0);
	    *MARK = &PL_sv_undef;
	}
	SP = MARK;
    }
    else if (gimme == G_ARRAY) {
	/* in case LEAVE wipes old return values */
	register SV **mark;
	for (mark = newsp + 1; mark <= SP; mark++) {
	    if (!(SvFLAGS(*mark) & (SVs_PADTMP|SVs_TEMP))) {
		*mark = sv_mortalcopy(*mark);
	    }
	}
    }
    PL_curpm = newpm;	/* Don't pop $1 et al till now */

    LEAVE_named("block");

    RETURN;
}

PP(pp_iter)
{
    dVAR; dSP;
    register PERL_CONTEXT *cx;
    SV *sv, *oldsv;
    SV **itersvp;
    AV *av = NULL; /* used for LOOP_FOR on arrays and the stack */

    EXTEND(SP, 1);
    cx = &cxstack[cxstack_ix];
    if (!CxTYPE_is_LOOP(cx))
	DIE(aTHX_ "panic: pp_iter");

    itersvp = CxITERVAR(cx);
    if (CxTYPE(cx) == CXt_LOOP_LAZYIV) {
	/* integer increment */
	if (cx->blk_loop.state_u.lazyiv.cur > cx->blk_loop.state_u.lazyiv.end)
	    RETPUSHNO;

	/* don't risk potential race */
	if (SvREFCNT(*itersvp) == 1 && !SvMAGICAL(*itersvp)) {
	    /* safe to reuse old SV */
	    sv_setiv(*itersvp, cx->blk_loop.state_u.lazyiv.cur++);
	}
	else
	{
	    /* we need a fresh SV every time so that loop body sees a
	     * completely new SV for closures/references to work as they
	     * used to */
	    oldsv = *itersvp;
	    *itersvp = newSViv(cx->blk_loop.state_u.lazyiv.cur++);
	    SvREFCNT_dec(oldsv);
	}

	/* Handle end of range at IV_MAX */
	if ((cx->blk_loop.state_u.lazyiv.cur == IV_MIN) &&
	    (cx->blk_loop.state_u.lazyiv.end == IV_MAX))
	{
	    cx->blk_loop.state_u.lazyiv.cur++;
	    cx->blk_loop.state_u.lazyiv.end++;
	}

	RETPUSHYES;
    }

    /* iterate array */
    assert(CxTYPE(cx) == CXt_LOOP_FOR);
    av = cx->blk_loop.state_u.ary.ary;
    if (! SvAVOK(av)) {
	RETPUSHNO;
    }
    if (PL_op->op_private & OPpITER_REVERSED) {
	if (cx->blk_loop.state_u.ary.ix <= 0)
	    RETPUSHNO;

	if (SvMAGICAL(av) || AvREIFY(av)) {
	    SV * const * const svp = av_fetch(av, --cx->blk_loop.state_u.ary.ix, FALSE);
	    sv = svp ? *svp : NULL;
	}
	else {
	    sv = AvARRAY(av)[--cx->blk_loop.state_u.ary.ix];
	}
    }
    else {
	if (cx->blk_loop.state_u.ary.ix >= AvFILL(av))
	    RETPUSHNO;

	if (SvMAGICAL(av) || AvREIFY(av)) {
	    SV * const * const svp = av_fetch(av, ++cx->blk_loop.state_u.ary.ix, FALSE);
	    sv = svp ? *svp : NULL;
	}
	else {
	    sv = AvARRAY(av)[++cx->blk_loop.state_u.ary.ix];
	}
    }

    if (sv && SvIS_FREED(sv)) {
	*itersvp = NULL;
	Perl_croak(aTHX_ "Use of freed value in iteration");
    }

    if (sv == &PL_sv_undef) {
	sv = newSV(0);
	av_store(av, cx->blk_loop.state_u.ary.ix, sv);
    }

    SvTEMP_off(sv);
    SvREFCNT_inc_void_NN(sv);

    oldsv = *itersvp;
    *itersvp = sv;
    SvREFCNT_dec(oldsv);

    RETPUSHYES;
}

PP(pp_grepwhile)
{
    dVAR; dSP;
    const I32 gimme = GIMME_V;
    SV* newitem;
    AV* src;
    SV* dst;
    SV** cvp;
    SV* value;

    newitem = POPs;
    value = POPs;
    cvp = SP;
    src = svTav(SP[-1]);
    dst = SP[-2];

    if (SvTRUE(newitem)) {
	av_push(svTav(dst), SvREFCNT_inc(value));
    }

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
	XPUSHs(srcitem);
	PUSHMARK(SP);
	mXPUSHs(srcitem);
	XPUSHs(*cvp);
	PUTBACK;

	RETURNOP(cLOGOP->op_other);
    }
}

PP(pp_leavesub)
{
    dVAR; dSP;
    SV **mark;
    SV **newsp;
    PMOP *newpm;
    I32 gimme;
    register PERL_CONTEXT *cx;
    SV *sv;

    if (CxMULTICALL(&cxstack[cxstack_ix]))
	return 0;

    POPBLOCK(cx,newpm);
    cxstack_ix++; /* temporarily protect top context */

    if (gimme == G_VOID) {
	MARK = newsp + 1;
	if (MARK <= SP) {
	    if (cx->blk_sub.cv && CvDEPTH(cx->blk_sub.cv) > 1) {
		FREETMPS;
	    }
	}
	MEXTEND(MARK, 0);
	*MARK = &PL_sv_undef;
	SP = MARK;
    }
    else if (gimme == G_SCALAR) {
	MARK = newsp + 1;
	if (MARK <= SP) {
	    if (cx->blk_sub.cv && CvDEPTH(cx->blk_sub.cv) > 1) {
		if (SvTEMP(TOPs)) {
		    *MARK = SvREFCNT_inc(TOPs);
		    FREETMPS;
		    sv_2mortal(*MARK);
		}
		else {
		    sv = SvREFCNT_inc(TOPs);	/* FREETMPS could clobber it */
		    FREETMPS;
		    *MARK = sv_mortalcopy(sv);
		    SvREFCNT_dec(sv);
		}
	    }
	    else
		*MARK = SvTEMP(TOPs) ? TOPs : sv_mortalcopy(TOPs);
	}
	else {
	    MEXTEND(MARK, 0);
	    *MARK = &PL_sv_undef;
	}
	SP = MARK;
    }
    else if (gimme == G_ARRAY) {
	for (MARK = newsp + 1; MARK <= SP; MARK++) {
	    if (!SvTEMP(*MARK)) {
		*MARK = sv_mortalcopy(*MARK);
	    }
	}
    }
    PUTBACK;

    LEAVE_named("sub");
    cxstack_ix--;
    POPSUB(cx,sv);	/* Stack values are safe: release CV and @_ ... */
    PL_curpm = newpm;	/* ... and pop $1 et al */

    return cx->blk_sub.retop;
}

PP(pp_entersub_save)
{
    dSP;
    AV* args = svTav(PAD_SVl(PL_op->op_targ));
    SV* new_value = TOPs;
    save_call_sv(args, new_value);
    if (PL_op->op_private & OPpENTERSUB_SAVE_DISCARD)
	SP--;
    RETURN;
}

PP(pp_entersub_targargs)
{
    dSP;
    SV* cv;
    SV* args = PAD_SVl(PL_op->op_targ);
    if ( ! SvAVOK(args) )
	Perl_croak(aTHX_ "panic: args is expected to be an array");
    PUSHMARK(SP);
    {
	AV *const av = svTav(args);
	const I32 maxarg = av_len(av);
	if (maxarg) {
	    EXTEND(SP, maxarg);
	    Copy(AvARRAY(av), SP+1, maxarg, SV*);
	    SP += maxarg;
	}
	cv = AvARRAY(av)[maxarg];
    }
    PUSHs(cv);
    PUTBACK;
    return pp_entersub();
}

PP(pp_entersub)
{
    dVAR; dSP; dPOPss;
    GV *gv;
    register CV *cv;
    register PERL_CONTEXT *cx;
    I32 gimme = GIMME_V;
    const OPFLAGS op_flags = PL_op->op_flags;
    const bool hasargs = (op_flags & OPf_STACKED) != 0;
    const bool is_assignment = (op_flags & OPf_ASSIGN) != 0;
    assert(hasargs);

    /* subs are always in scalar context */
    if (gimme == G_ARRAY) {
	gimme= G_SCALAR;
    }
    
    if (PL_op->op_private & OPpENTERSUB_SAVEARGS) {
	/* save argument to 'op_targ' */
	AV* args = newAV();
	SV** mark;
	SAVECLEARSV(PAD_SVl(PL_op->op_targ));
	PAD_SVl(PL_op->op_targ) = avTsv(args);
	for (mark=PL_stack_base+TOPMARK+1; mark <= SP; mark++)
	    av_push(args, newSVsv(*mark));
	av_push(args, SvREFCNT_inc(sv));
    }

    if (op_flags & OPf_ENTERSUB_EARLY_CV) {
	GV* gv = gv_fetchsv(sv, GV_NOADD_NOINIT, SVt_PVCV);
	if (! gv)
	    DIE(aTHX_ "Undefined subroutine &%"SVf" called", SVfARG(sv));
	if (! (cv = GvCVu(gv)))
	    DIE(aTHX_ "Undefined subroutine &%"SVf" called", SVfARG(sv));
    }
    else {
	if (!sv)
	    DIE(aTHX_ "Expected a CODE reference but got nothing");
	switch (SvTYPE(sv)) {
	    /* This is overwhelming the most common case:  */
	case SVt_PVGV:
	    if (!(cv = GvCVu((GV*)sv))) {
		cv = sv_2cv(sv, &gv, 0);
	    }
	    if (!cv) {
		SV* sub_name = sv_newmortal();
		gv_efullname3(sub_name, (GV*)sv, NULL);
		DIE(aTHX_ "Undefined subroutine &%"SVf" called", SVfARG(sub_name));
	    }
	    break;
	default:
	    if (sv == &PL_sv_yes && PL_op->op_flags & OPf_SPECIAL) {	/* unfound import, ignore */
		SP = PL_stack_base + POPMARK;
		if ( gimme != G_VOID )
		    XPUSHs(&PL_sv_undef);
		RETURN;
	    }
	    if (!SvROK(sv)) {
		const char *sym;
		STRLEN len;
		sym = SvPV_const(sv, len);
		if (!sym)
		    DIE(aTHX_ PL_no_usym, "a subroutine");
		DIE(aTHX_ PL_no_symref, sym, "a subroutine");
	    }
	    cv = (CV*)SvRV(sv);
	    if (SvTYPE(cv) == SVt_PVCV)
		break;
	    DIE(aTHX_ "Expected a CODE reference but got a %s reference", Ddesc(SvRV(sv)));
	case SVt_PVHV:
	case SVt_PVAV:
	    DIE(aTHX_ "Expected a CODE reference but got a %s", Ddesc(sv));
	    /* This is the second most common case:  */
	case SVt_PVCV:
	    cv = (CV*)sv;
	    break;
	}
    }

    ENTER_named("sub");
    SAVETMPS;

    if (!CvROOT(cv) && !CvXSUB(cv)) {
	DIE(aTHX_ "Undefined subroutine %s called",
	    SvPVX_const(loc_desc(SvLOCATION(cv))));
    }

    if ((PL_op->op_private & OPpENTERSUB_DB) && GvCV(PL_DBsub) && !CvNODEBUG(cv)) {
	 Perl_get_db_sub(aTHX_ &sv, cv);
	 if (CvISXSUB(cv))
	     PL_curcopdb = PL_curcop;
	 cv = GvCV(PL_DBsub);

	if (!cv || (!CvXSUB(cv) && !CvSTART(cv)))
	    DIE(aTHX_ "No DB::sub routine defined");
    }

    if ( ! cv_optassignarg_flag(cv) 
	&& ( is_assignment != cv_assignarg_flag(cv) ) ) {
	if (is_assignment)
	    Perl_croak(aTHX_ "%s can not be an assignee",
		SvPVX_const(loc_name(SvLOCATION(cv))));
	else
	    Perl_croak(aTHX_ "%s must be an assignee",
		SvPVX_const(loc_name(SvLOCATION(cv))));
    }

    if (!(CvISXSUB(cv))) {
	/* This path taken at least 75% of the time   */
	dMARK;
	register I32 items = SP - MARK;
	AV* padlist;
	if (CvCONST(cv)) {
	    if (items)
		Perl_croak(aTHX_ "constant subroutine does not expect any arguments");

	    XPUSHs(cv_const_sv(cv));
	    PUTBACK;

	    LEAVE_named("sub");
	    return NORMAL;
	}
	padlist = CvPADLIST(cv);
	PUSHBLOCK(cx, CXt_SUB, is_assignment ? MARK - 1 : MARK );
	PUSHSUB(cx);
	cx->blk_sub.retop = PL_op->op_next;
	CvDEPTH(cv)++;
	/* XXX This would be a natural place to set C<PL_compcv = cv> so
	 * that eval'' ops within this sub know the correct lexical space.
	 * Owing the speed considerations, we choose instead to search for
	 * the cv using find_runcv() when calling doeval().
	 */
	if (CvDEPTH(cv) >= 2) {
	    PERL_STACK_OVERFLOW_CHECK();
	    pad_push(padlist, CvDEPTH(cv));
	}
	SAVECOMPPAD();
	pad_set_cur_nosave(padlist, CvDEPTH(cv));

	if (CvFLAGS(cv) & CVf_BLOCK) {
	    SAVECLEARSV(PAD_SVl(PAD_ARGS_INDEX));
	    ++MARK;

	    if (items > 1)
		Perl_croak(aTHX_ "Too many arguments for block sub: %"IVdf"",
		    items);

	    if (items == 1) {
		SVcpREPLACE( PAD_SVl(PAD_ARGS_INDEX), *MARK );
		MARK++;
	    }
	    else
		SVcpSTEAL( PAD_SVl(PAD_ARGS_INDEX), newSV(0) );
	}
	else if ( CvFLAGS(cv) & CVf_PROTO) {
	    int i;
	    if (CvN_MAXARGS(cv) != -1 && items > CvN_MAXARGS(cv))
		Perl_croak_at(aTHX_ SvLOCATION(cv),
		    "Too many arguments for %s",
		    SvPVX_const(loc_name(SvLOCATION(cv))));
	    if (items < CvN_MINARGS(cv))
		Perl_croak_at(aTHX_ SvLOCATION(cv),
		    "Not enough arguments for %s",
		    SvPVX_const(loc_name(SvLOCATION(cv))));

	    ++MARK;
	    PUSHMARK(MARK-1);

	    /* reverse items on the stack */
	    for (i=0; i<items/2; i++) {
		SV* sv = MARK[i];
		MARK[i] = MARK[items-i-1];
		MARK[items-i-1] = sv;
	    }

	    if (is_assignment) {
		SV* rhs;
		if (cv_optassignarg_flag(cv)) {
		    XPUSHs(&PL_sv_yes);
		    ++items;
		}
		if (op_flags & OPf_ASSIGN_PART) {
		    if (PL_stack_base + TOPMARK >= MARK) {
			Perl_croak(aTHX_ "Missing required assignment value");
			rhs = &PL_sv_undef;
		    } 
		    else
			rhs = MARK[-1];
		}
		else {
		    rhs = MARK[-1];
		}
		XPUSHs(rhs);
		++items;
	    }
	    else if (cv_optassignarg_flag(cv)) {
		XPUSHs(&PL_sv_no);
		++items;
		XPUSHs(&PL_sv_undef);
		++items;
	    }
	}
	else if ( CvFLAGS(cv) & CVf_DEFARGS) {
	    AV* av;
	    SV* avsv = PAD_SVl(PAD_ARGS_INDEX);
	    sv_upgrade(avsv, SVt_PVAV);
	    av = svTav(avsv);
	    SAVECLEARSV(PAD_SVl(PAD_ARGS_INDEX));
	    AvREAL_on(av);
	    ++MARK;

	    if (items > AvMAX(av) + 1) {
		SV **ary = AvALLOC(av);
		if (AvARRAY(av) != ary) {
		    AvMAX(av) += AvARRAY(av) - AvALLOC(av);
		    AvARRAY(av) = ary;
		}
		if (items > AvMAX(av) + 1) {
		    AvMAX(av) = items - 1;
		    Renew(ary,items,SV*);
		    AvALLOC(av) = ary;
		    AvARRAY(av) = ary;
		}
	    }
	    Copy(MARK,AvARRAY(av),items,SV*);
	    AvFILLp(av) = items - 1;
	
	    while (items--) {
		if (*MARK) {
		    SvTEMP_off(*MARK);
		    SvREFCNT_inc(*MARK);
		}
		MARK++;
	    }
	}

	/* warning must come *after* we fully set up the context
	 * stuff so that __WARN__ handlers can safely dounwind()
	 * if they want to
	 */
	if (CvDEPTH(cv) == PERL_SUB_DEPTH_WARN && ckWARN(WARN_RECURSION)
	    && !(PERLDB_SUB && cv == GvCV(PL_DBsub)))
	    sub_crush_depth(cv);
	RETURNOP(CvSTART(cv));
    }
    else {
	I32 markix = TOPMARK;

	if (is_assignment)
	    --markix;

	PUTBACK;

	/* We assume first XSUB in &DB::sub is the called one. */
	if (PL_curcopdb) {
	    SAVEVPTR(PL_curcop);
	    PL_curcop = PL_curcopdb;
	    PL_curcopdb = NULL;
	}

	PUSHBLOCK(cx, CXt_XSSUB, PL_stack_base + markix );
	cx->blk_sub.cv = CvREFCNT_inc(cv);				\

	/* CvXSUB(cv) must not be NULL because newXS() refuses NULL xsub address */
	assert(CvXSUB(cv));
	CALL_FPTR(CvXSUB(cv))(aTHX_ cv);

	CvREFCNT_dec(cv);
	pop_block();
	(void)POPMARK;

	/* Enforce some sanity in scalar context. */
	if (gimme == G_SCALAR && ++markix != PL_stack_sp - PL_stack_base ) {
	    if (markix > PL_stack_sp - PL_stack_base)
		*(PL_stack_base + markix) = &PL_sv_undef;
	    else
		*(PL_stack_base + markix) = *PL_stack_sp;
	    PL_stack_sp = PL_stack_base + markix;
	}
	LEAVE_named("sub");
	return NORMAL;
    }
}

void
Perl_sub_crush_depth(pTHX_ CV *cv)
{
    SV** name = NULL;
    SV* loc;

    PERL_ARGS_ASSERT_SUB_CRUSH_DEPTH;

    loc = SvLOCATION((SV*)cv);
    if (loc && SvAVOK(loc)) {
	name = av_fetch(svTav(loc), 3, FALSE);
    }
    Perl_warner(aTHX_ packWARN(WARN_RECURSION), 
	"Deep recursion on subroutine \"%s\"",
	(name ? SvPVX_const(*name) : "(unknown)" ));
}

PP(pp_aelem)
{
    dVAR; dSP;
    SV** svp;
    SV* const elemsv = POPs;
    IV elem = SvIV(elemsv);
    AV* const av = (AV*)POPs;
    const OPFLAGS op_flags = PL_op->op_flags;
    const OPFLAGS lval = op_flags & OPf_MOD;
    const OPFLAGS add = PL_op->op_private & OPpELEM_ADD;
    const OPFLAGS optional = PL_op->op_private & OPpELEM_OPTIONAL;
    SV *sv;

    if ( ! SvOK(av) ) {
	if (optional) {
	    XPUSHs(&PL_sv_undef);
	    RETURN;
	}
	if (!add)
	    Perl_croak(aTHX_ "Can't take an element from a %s", Ddesc((SV*)av));
	if (SvREADONLY(av))
	    Perl_croak(aTHX_ PL_no_modify);
	sv_upgrade(avTsv(av), SVt_PVAV);
    }
    else if ( ! SvAVOK(av) )
	Perl_croak(aTHX_ "Can't take an element from a %s", Ddesc((SV*)av));

    svp = av_fetch(av, elem, add);
    if (!svp) {
	if ( optional ) {
	    RETPUSHUNDEF;
	}
	if ( add )
	    DIE(aTHX_ "Required array element %"IVdf" could not be created", elem);
	else
	    DIE(aTHX_ "Required array element %"IVdf" does not exists", elem);
    }
    if (PL_op->op_private & OPpLVAL_INTRO)
	save_aelem(av, elem, svp);
    if (lval && *svp == &PL_sv_undef)
	svp = av_store(av, elem, newSV(0));
    sv = *svp;
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

PP(pp_method)
{
    dVAR; dSP;
    SV* const sv = TOPs;

    if (SvROK(sv)) {
	SV* const rsv = SvRV(sv);
	if (SvTYPE(rsv) == SVt_PVCV) {
	    SETs(rsv);
	    RETURN;
	}
    }

    SETs(method_common(sv, NULL));
    RETURN;
}

PP(pp_method_named)
{
    dVAR; dSP;
    SV* const sv = cSVOP_sv;
    U32 hash = SvSHARED_HASH(sv);

    XPUSHs(method_common(sv, &hash));
    RETURN;
}

STATIC SV *
S_method_common(pTHX_ SV* meth, U32* hashp)
{
    dVAR;
    SV* ob;
    CV* cv;
    HV* stash;
    const char* packname = NULL;
    SV *packsv = NULL;
    STRLEN packlen;
    SV * const sv = *(PL_stack_base + TOPMARK + 1);

    PERL_ARGS_ASSERT_METHOD_COMMON;

    if (!sv)
	Perl_croak(aTHX_ "Can't call method \"%"SVf"\" on an undefined value",
		   SVfARG(meth));

    if (SvROK(sv))
	ob = MUTABLE_SV(SvRV(sv));
    else {
	if ( ! SvPVOK(sv) )
	    Perl_croak(aTHX_ "Can't call method \"%"SVf"\" on %s", SVfARG(meth), Ddesc(sv));

	/* this isn't a reference */
        if(SvOK(sv) && (packname = SvPV_const(sv, packlen))) {
          const HE* const he = hv_fetch_ent(PL_stashcache, sv, 0, 0);
          if (he) { 
            stash = INT2PTR(HV*,SvIV(HeVAL(he)));
            goto fetch;
          }
        }

	/* assume it's a package name */
	stash = gv_stashpvn(packname, packlen, 0);
	if (!stash)
	    packsv = sv;
	else {
	    SV* const ref = newSViv(PTR2IV(stash));
	    hv_store(PL_stashcache, packname, packlen, ref, 0);
	}
	goto fetch;
    }

    /* if we got here, ob should be a reference or a glob */
    if (!ob || !(SvOBJECT(ob)
		 || (SvTYPE(ob) == SVt_PVGV 
		     && isGV_with_GP(ob)
		     && (ob = MUTABLE_SV(GvIO((const GV *)ob)))
		     && SvOBJECT(ob))))
    {
	const char * const name = SvPV_nolen_const(meth);
	Perl_croak(aTHX_ "Can't call method \"%s\" on unblessed reference",
		   (SvSCREAM(meth) && strEQ(name,"isa")) ? "DOES" :
		   name);
    }

    stash = SvSTASH(ob);

  fetch:
    /* NOTE: stash may be null, hope hv_fetch_ent and
       gv_fetchmethod can cope (it seems they can) */

    /* shortcut for simple names */
    if (hashp) {
	const HE* const he = hv_fetch_ent(stash, meth, 0, *hashp);
	if (he) {
	    GV* gv = MUTABLE_GV(HeVAL(he));
	    if (isGV(gv) && GvCV(gv) &&
		(!GvCVGEN(gv) || GvCVGEN(gv)
                  == (PL_sub_generation + HvMROMETA(stash)->cache_gen)))
		return MUTABLE_SV(GvCV(gv));
	}
    }

    cv = gv_fetchmethod_flags(stash ? stash : (HV*)packsv, SvPV_nolen_const(meth), GV_CROAK);

    return cvTsv(cv);
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
