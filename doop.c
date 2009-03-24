/*    doop.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2002, 2004, 2005, 2006, 2007, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * "'So that was the job I felt I had to do when I started,' thought Sam."
 */

/* This file contains some common functions needed to carry out certain
 * ops. For example both pp_schomp() and pp_chomp() - scalar and array
 * chomp operations - call the function do_chomp() found in this file.
 */

#include "EXTERN.h"
#define PERL_IN_DOOP_C
#include "perl.h"

#ifndef PERL_MICRO
#include <signal.h>
#endif

void
Perl_do_join(pTHX_ register SV *sv, SV *delim, register SV *av)
{
    dVAR;
    register I32 items;
    register STRLEN len;
    register SV** mark;
    STRLEN delimlen;

    PERL_ARGS_ASSERT_DO_JOIN;

    (void) SvPV_const(delim, delimlen); /* stringify and get the delimlen */
    /* SvCUR assumes it's SvPOK() and woe betide you if it's not. */

    if ( ! SvAVOK(av) ) {
	Perl_croak(aTHX_ "%s expected an ARRAY but got %s", OP_DESC(PL_op), Ddesc(av));
    }
    items = av_len(svTav(av)) + 1;

    mark = AvARRAY(svTav(av));

    len = (items > 0 ? (delimlen * (items - 1) ) : 0);
    SvUPGRADE(sv, SVt_PV);
    if (SvLEN(sv) < len + items) {	/* current length is way too short */
	while (items-- > 0) {
	    if (*mark && SvOK(*mark)) {
		STRLEN tmplen;
		SvPV_const(*mark, tmplen);
		len += tmplen;
	    }
	    mark++;
	}
	SvGROW(sv, len + 1);		/* so try to pre-extend */

	mark = AvARRAY(av);
	items = av_len(svTav(av)) + 1;
    }

    sv_setpvn(sv, "", 0);

    if (items-- > 0) {
	if (*mark)
	    sv_catsv(sv, *mark);
	mark++;
    }

    if (delimlen) {
	for (; items > 0; items--,mark++) {
	    sv_catsv(sv,delim);
	    sv_catsv(sv,*mark);
	}
    }
    else {
	for (; items > 0; items--,mark++)
	    sv_catsv(sv,*mark);
    }
    SvSETMAGIC(sv);
}

void
Perl_do_sprintf(pTHX_ SV *sv, I32 len, SV **sarg)
{
    dVAR;
    STRLEN patlen;
    const char * const pat = SvPV_const(*sarg, patlen);
    bool do_taint = FALSE;

    PERL_ARGS_ASSERT_DO_SPRINTF;

    sv_vsetpvfn(sv, pat, patlen, NULL, sarg + 1, len - 1, &do_taint);
    SvSETMAGIC(sv);
}

/* currently converts input to bytes if possible, but doesn't sweat failure */
UV
Perl_do_vecget(pTHX_ SV *sv, I32 offset, I32 size)
{
    dVAR;
    STRLEN srclen, len, uoffset, bitoffs = 0;
    const unsigned char *s = (const unsigned char *) SvPV_const(sv, srclen);
    UV retnum = 0;

    PERL_ARGS_ASSERT_DO_VECGET;

    if (offset < 0)
	return 0;
    if (size < 1 || (size & (size-1))) /* size < 1 or not a power of two */
	Perl_croak(aTHX_ "Illegal number of bits in vec");

    if (size < 8) {
	bitoffs = ((offset%8)*size)%8;
	uoffset = offset/(8/size);
    }
    else if (size > 8)
	uoffset = offset*(size/8);
    else
	uoffset = offset;

    len = uoffset + (bitoffs + size + 7)/8;	/* required number of bytes */
    if (len > srclen) {
	if (size <= 8)
	    retnum = 0;
	else {
	    if (size == 16) {
		if (uoffset >= srclen)
		    retnum = 0;
		else
		    retnum = (UV) s[uoffset] <<  8;
	    }
	    else if (size == 32) {
		if (uoffset >= srclen)
		    retnum = 0;
		else if (uoffset + 1 >= srclen)
		    retnum =
			((UV) s[uoffset    ] << 24);
		else if (uoffset + 2 >= srclen)
		    retnum =
			((UV) s[uoffset    ] << 24) +
			((UV) s[uoffset + 1] << 16);
		else
		    retnum =
			((UV) s[uoffset    ] << 24) +
			((UV) s[uoffset + 1] << 16) +
			(     s[uoffset + 2] <<  8);
	    }
#ifdef UV_IS_QUAD
	    else if (size == 64) {
		if (ckWARN(WARN_PORTABLE))
		    Perl_warner(aTHX_ packWARN(WARN_PORTABLE),
				"Bit vector size > 32 non-portable");
		if (uoffset >= srclen)
		    retnum = 0;
		else if (uoffset + 1 >= srclen)
		    retnum =
			(UV) s[uoffset     ] << 56;
		else if (uoffset + 2 >= srclen)
		    retnum =
			((UV) s[uoffset    ] << 56) +
			((UV) s[uoffset + 1] << 48);
		else if (uoffset + 3 >= srclen)
		    retnum =
			((UV) s[uoffset    ] << 56) +
			((UV) s[uoffset + 1] << 48) +
			((UV) s[uoffset + 2] << 40);
		else if (uoffset + 4 >= srclen)
		    retnum =
			((UV) s[uoffset    ] << 56) +
			((UV) s[uoffset + 1] << 48) +
			((UV) s[uoffset + 2] << 40) +
			((UV) s[uoffset + 3] << 32);
		else if (uoffset + 5 >= srclen)
		    retnum =
			((UV) s[uoffset    ] << 56) +
			((UV) s[uoffset + 1] << 48) +
			((UV) s[uoffset + 2] << 40) +
			((UV) s[uoffset + 3] << 32) +
			(     s[uoffset + 4] << 24);
		else if (uoffset + 6 >= srclen)
		    retnum =
			((UV) s[uoffset    ] << 56) +
			((UV) s[uoffset + 1] << 48) +
			((UV) s[uoffset + 2] << 40) +
			((UV) s[uoffset + 3] << 32) +
			((UV) s[uoffset + 4] << 24) +
			((UV) s[uoffset + 5] << 16);
		else
		    retnum =
			((UV) s[uoffset    ] << 56) +
			((UV) s[uoffset + 1] << 48) +
			((UV) s[uoffset + 2] << 40) +
			((UV) s[uoffset + 3] << 32) +
			((UV) s[uoffset + 4] << 24) +
			((UV) s[uoffset + 5] << 16) +
			(     s[uoffset + 6] <<  8);
	    }
#endif
	}
    }
    else if (size < 8)
	retnum = (s[uoffset] >> bitoffs) & ((1 << size) - 1);
    else {
	if (size == 8)
	    retnum = s[uoffset];
	else if (size == 16)
	    retnum =
		((UV) s[uoffset] <<      8) +
		      s[uoffset + 1];
	else if (size == 32)
	    retnum =
		((UV) s[uoffset    ] << 24) +
		((UV) s[uoffset + 1] << 16) +
		(     s[uoffset + 2] <<  8) +
		      s[uoffset + 3];
#ifdef UV_IS_QUAD
	else if (size == 64) {
	    if (ckWARN(WARN_PORTABLE))
		Perl_warner(aTHX_ packWARN(WARN_PORTABLE),
			    "Bit vector size > 32 non-portable");
	    retnum =
		((UV) s[uoffset    ] << 56) +
		((UV) s[uoffset + 1] << 48) +
		((UV) s[uoffset + 2] << 40) +
		((UV) s[uoffset + 3] << 32) +
		((UV) s[uoffset + 4] << 24) +
		((UV) s[uoffset + 5] << 16) +
		(     s[uoffset + 6] <<  8) +
		      s[uoffset + 7];
	}
#endif
    }

    return retnum;
}

/* currently converts input to bytes if possible but doesn't sweat failures,
 * although it does ensure that the string it clobbers is not marked as
 * utf8-valid any more
 */
void
Perl_do_vecset(pTHX)
{
    dVAR; dSP;
    register I32 bitoffs = 0;
    register unsigned char *s;
    I32 mask;
    STRLEN targlen;
    STRLEN len;
    UV lval = POPu;
    register const IV size   = POPi;
    register IV offset = POPi;
    register SV * const targ = POPs;

    if (!targ)
	return;
    s = (unsigned char*)SvPV_force(targ, targlen);

    (void)SvPOK_only(targ);
    if (offset < 0)
	Perl_croak(aTHX_ "Negative offset to vec in lvalue context");
    if (size < 1 || (size & (size-1))) /* size < 1 or not a power of two */
	Perl_croak(aTHX_ "Illegal number of bits in vec");

    if (size < 8) {
	bitoffs = ((offset%8)*size)%8;
	offset /= 8/size;
    }
    else if (size > 8)
	offset *= size/8;

    len = offset + (bitoffs + size + 7)/8;	/* required number of bytes */
    if (len > targlen) {
	s = (unsigned char*)SvGROW(targ, len + 1);
	(void)memzero((char *)(s + targlen), len - targlen + 1);
	SvCUR_set(targ, len);
    }

    if (size < 8) {
	mask = (1 << size) - 1;
	lval &= mask;
	s[offset] &= ~(mask << bitoffs);
	s[offset] |= lval << bitoffs;
    }
    else {
	if (size == 8)
	    s[offset  ] = (U8)( lval        & 0xff);
	else if (size == 16) {
	    s[offset  ] = (U8)((lval >>  8) & 0xff);
	    s[offset+1] = (U8)( lval        & 0xff);
	}
	else if (size == 32) {
	    s[offset  ] = (U8)((lval >> 24) & 0xff);
	    s[offset+1] = (U8)((lval >> 16) & 0xff);
	    s[offset+2] = (U8)((lval >>  8) & 0xff);
	    s[offset+3] = (U8)( lval        & 0xff);
	}
#ifdef UV_IS_QUAD
	else if (size == 64) {
	    if (ckWARN(WARN_PORTABLE))
		Perl_warner(aTHX_ packWARN(WARN_PORTABLE),
			    "Bit vector size > 32 non-portable");
	    s[offset  ] = (U8)((lval >> 56) & 0xff);
	    s[offset+1] = (U8)((lval >> 48) & 0xff);
	    s[offset+2] = (U8)((lval >> 40) & 0xff);
	    s[offset+3] = (U8)((lval >> 32) & 0xff);
	    s[offset+4] = (U8)((lval >> 24) & 0xff);
	    s[offset+5] = (U8)((lval >> 16) & 0xff);
	    s[offset+6] = (U8)((lval >>  8) & 0xff);
	    s[offset+7] = (U8)( lval        & 0xff);
	}
#endif
    }
    SvSETMAGIC(targ);
    PUSHs(targ);
}

void
Perl_do_chop(pTHX_ register SV *astr, register SV *sv)
{
    dVAR;
    STRLEN len;
    char *s;

    PERL_ARGS_ASSERT_DO_CHOP;

    if (SvTYPE(sv) == SVt_PVAV) {
	register I32 i;
	AV* const av = (AV*)sv;
	const I32 max = AvFILL(av);

	for (i = 0; i <= max; i++) {
	    sv = (SV*)av_fetch(av, i, FALSE);
	    if (sv && ((sv = *(SV**)sv), sv != &PL_sv_undef))
		do_chop(astr, sv);
	}
        return;
    }
    else if (SvTYPE(sv) == SVt_PVHV) {
	HV* const hv = (HV*)sv;
	HE* entry;
        (void)hv_iterinit(hv);
        while ((entry = hv_iternext(hv)))
            do_chop(astr,hv_iterval(hv,entry));
        return;
    }
    else if (SvREADONLY(sv)) {
        if (SvFAKE(sv)) {
            /* SV is copy-on-write */
	    sv_force_normal_flags(sv, 0);
        }
        if (SvREADONLY(sv))
            Perl_croak(aTHX_ PL_no_modify);
    }

    s = SvPV(sv, len);
    if (len && !SvPOK(sv))
	s = SvPV_force(sv, len);
    if (IN_CODEPOINTS) {
	if (s && len) {
	    char * const send = s + len;
	    char * const start = s;
	    s = send - 1;
	    while (s > start && UTF8_IS_CONTINUATION(*s))
		s--;
	    if (is_utf8_string(s, send - s)) {
		sv_setpvn(astr, s, send - s);
		*s = '\0';
		SvCUR_set(sv, s - start);
		SvNIOK_off(sv);
	    }
	}
	else
	    sv_setpvn(astr, "", 0);
    }
    else if (s && len) {
	s += --len;
	sv_setpvn(astr, s, 1);
	*s = '\0';
	SvCUR_set(sv, len);
	SvNIOK_off(sv);
    }
    else
	sv_setpvn(astr, "", 0);
    SvSETMAGIC(sv);
}

I32
Perl_do_chomp(pTHX_ register SV *sv)
{
    dVAR;
    register I32 count;
    STRLEN len;
    char *s;
    char *temp_buffer = NULL;
    SV* svrecode = NULL;

    PERL_ARGS_ASSERT_DO_CHOMP;

    if (RsSNARF(PL_rs))
	return 0;
    if (RsRECORD(PL_rs))
      return 0;
    count = 0;
    if (SvTYPE(sv) == SVt_PVAV) {
	register I32 i;
	AV* const av = (AV*)sv;
	const I32 max = AvFILL(av);

	for (i = 0; i <= max; i++) {
	    sv = (SV*)av_fetch(av, i, FALSE);
	    if (sv && ((sv = *(SV**)sv), sv != &PL_sv_undef))
		count += do_chomp(sv);
	}
        return count;
    }
    else if (SvTYPE(sv) == SVt_PVHV) {
	HV* const hv = (HV*)sv;
	HE* entry;
        (void)hv_iterinit(hv);
        while ((entry = hv_iternext(hv)))
            count += do_chomp(hv_iterval(hv,entry));
        return count;
    }
    else if (SvREADONLY(sv)) {
        if (SvFAKE(sv)) {
            /* SV is copy-on-write */
	    sv_force_normal_flags(sv, 0);
        }
        if (SvREADONLY(sv))
            Perl_croak(aTHX_ PL_no_modify);
    }

    s = SvPV(sv, len);
    if (s && len) {
	s += --len;
	if (RsPARA(PL_rs)) {
	    if (*s != '\n')
		goto nope;
	    ++count;
	    while (len && s[-1] == '\n') {
		--len;
		--s;
		++count;
	    }
	}
	else {
	    STRLEN rslen, rs_charlen;
	    const char *rsptr = SvPV_const(PL_rs, rslen);

	    rs_charlen = IN_CODEPOINTS
		? sv_len_utf8(PL_rs)
		: rslen;

	    if (rslen == 1) {
		if (*s != *rsptr)
		    goto nope;
		++count;
	    }
	    else {
		if (len < rslen - 1)
		    goto nope;
		len -= rslen - 1;
		s -= rslen - 1;
		if (memNE(s, rsptr, rslen))
		    goto nope;
		count += rs_charlen;
	    }
	}
	s = SvPV_force_nolen(sv);
	SvCUR_set(sv, len);
	*SvEND(sv) = '\0';
	SvNIOK_off(sv);
	SvSETMAGIC(sv);
    }
  nope:

    if (svrecode)
	 SvREFCNT_dec(svrecode);

    Safefree(temp_buffer);
    return count;
}

void
Perl_do_vop(pTHX_ I32 optype, SV *sv, SV *left, SV *right)
{
    dVAR;
#ifdef LIBERAL
    register long *dl;
    register long *ll;
    register long *rl;
#endif
    register char *dc;
    STRLEN leftlen;
    STRLEN rightlen;
    register const char *lc;
    register const char *rc;
    register STRLEN len;
    STRLEN lensave;
    const char *lsave;
    const char *rsave;
    STRLEN needlen = 0;

    PERL_ARGS_ASSERT_DO_VOP;

    if (sv != left || (optype != OP_BIT_AND && !SvOK(sv)))
	sv_setpvn(sv, "", 0);	/* avoid undef warning on |= and ^= */
    lsave = lc = SvPV_const(left, leftlen);
    rsave = rc = SvPV_const(right, rightlen);

    /* This need to come after SvPV to ensure that string overloading has
       fired off.  */

    len = leftlen < rightlen ? leftlen : rightlen;
    lensave = len;
    SvCUR_set(sv, len);
    (void)SvPOK_only(sv);
    if (SvOK(sv) || SvTYPE(sv) > SVt_PVMG) {
	dc = SvPV_force_nomg_nolen(sv);
	if (SvLEN(sv) < len + 1) {
	    dc = SvGROW(sv, len + 1);
	    (void)memzero(dc + SvCUR(sv), len - SvCUR(sv) + 1);
	}
    }
    else {
	needlen = optype == OP_BIT_AND
		    ? len : (leftlen > rightlen ? leftlen : rightlen);
	Newxz(dc, needlen + 1, char);
	sv_usepvn_flags(sv, dc, needlen, SV_HAS_TRAILING_NUL);
	dc = SvPVX_mutable(sv);		/* sv_usepvn() calls Renew() */
    }
#ifdef LIBERAL
    if (len >= sizeof(long)*4 &&
	!((unsigned long)dc % sizeof(long)) &&
	!((unsigned long)lc % sizeof(long)) &&
	!((unsigned long)rc % sizeof(long)))	/* It's almost always aligned... */
    {
	const STRLEN remainder = len % (sizeof(long)*4);
	len /= (sizeof(long)*4);

	dl = (long*)dc;
	ll = (long*)lc;
	rl = (long*)rc;

	switch (optype) {
	case OP_BIT_AND:
	    while (len--) {
		*dl++ = *ll++ & *rl++;
		*dl++ = *ll++ & *rl++;
		*dl++ = *ll++ & *rl++;
		*dl++ = *ll++ & *rl++;
	    }
	    break;
	case OP_BIT_XOR:
	    while (len--) {
		*dl++ = *ll++ ^ *rl++;
		*dl++ = *ll++ ^ *rl++;
		*dl++ = *ll++ ^ *rl++;
		*dl++ = *ll++ ^ *rl++;
	    }
	    break;
	case OP_BIT_OR:
	    while (len--) {
		*dl++ = *ll++ | *rl++;
		*dl++ = *ll++ | *rl++;
		*dl++ = *ll++ | *rl++;
		*dl++ = *ll++ | *rl++;
	    }
	}

	dc = (char*)dl;
	lc = (char*)ll;
	rc = (char*)rl;

	len = remainder;
    }
#endif
    {
	switch (optype) {
	case OP_BIT_AND:
	    while (len--)
		*dc++ = *lc++ & *rc++;
	    *dc = '\0';
	    break;
	case OP_BIT_XOR:
	    while (len--)
		*dc++ = *lc++ ^ *rc++;
	    goto mop_up;
	case OP_BIT_OR:
	    while (len--)
		*dc++ = *lc++ | *rc++;
	  mop_up:
	    len = lensave;
	    if (rightlen > len)
		sv_catpvn(sv, rsave + len, rightlen - len);
	    else if (leftlen > (STRLEN)len)
		sv_catpvn(sv, lsave + len, leftlen - len);
	    else
		*SvEND(sv) = '\0';
	    break;
	}
    }
}

OP *
Perl_do_kv(pTHX)
{
    dVAR;
    dSP;
    HV * const hv = (HV*)POPs;
    HV *keys;
    register HE *entry;
    const I32 gimme = GIMME_V;
    const I32 dokeys =   (PL_op->op_type == OP_KEYS);
    const I32 dovalues = (PL_op->op_type == OP_VALUES);
    AV * res = av_2mortal(newAV());

    if ( ! SvHVOK(hv) ) {
	if ( ! SvOK(hv) ) {
	    XPUSHs(&PL_sv_undef);
	    RETURN;
	}
	Perl_croak(aTHX_ "keys expected a hash but got %s", Ddesc((SV*)hv));
    }

    keys = hv;
    (void)hv_iterinit(keys);	/* always reset iterator regardless */

    if (gimme == G_VOID)
	RETURN;

    PUTBACK;	/* hv_iternext and hv_iterval might clobber stack_sp */
    while ((entry = hv_iternext(keys))) {
	SPAGAIN;
	if (dokeys) {
	    SV* const sv = hv_iterkeysv(entry);
	    av_push(res, newSVsv(sv));
	}
	if (dovalues) {
	    av_push(res, SvREFCNT_inc(hv_iterval(hv,entry)));
	}
	PUTBACK;
    }
    XPUSHs(avTsv(res));
    RETURN;
}

void
Perl_bad_arg(pTHX_ I32 n, const char *t, const char *name, SV *arg)
{
    PERL_ARGS_ASSERT_BAD_ARG;

    Perl_croak(aTHX_ "Type of arg %d to %s must be %s (not %s)",
	       (int)n, name, t, Ddesc(arg));
}

void
Perl_do_arg_check(pTHX_ SV** base)
{
    dSP;
    const int type = PL_op->op_type;
    register I32 opargs = PL_opargs[type];
    register I32 oa = opargs >> OASHIFT;
    SV** arg = base;
    I32 numargs = 0;

    PERL_ARGS_ASSERT_DO_ARG_CHECK;
/*     if (opargs & OA_MARK) { */
/* 	arg = PL_stack_base + TOPMARK; */
/*     } else { */
/* 	I32 xoa = oa; */
/* 	xoa >>= 4; */
/* 	while (xoa) { */
/* 	    arg--; */
/* 	    xoa >>= 4; */
/* 	} */
/*     } */

    while (oa) {
	if ( (oa & 7) == OA_LIST) {
	    assert(oa < 16);
	    break;
	}

	if (arg > SP) {
	    if ( ! (oa & OA_OPTIONAL) )
		Perl_croak(aTHX_ "Not enough arguments for %s", PL_op_desc[type]);
	    break;
	}

	numargs++;
	switch (oa & 7) {
	case OA_SCALAR:
	    break;
	case OA_AVREF:
	    if ( ! SvAVOK(*arg) && SvOK(*arg) )
		bad_arg(numargs, "array", PL_op_desc[type], *arg);
	    break;
	case OA_HVREF:
		if ( ! SvHVOK(*arg) )
		    bad_arg(numargs, "hash", PL_op_desc[type], *arg);
		break;
/* 	    case OA_CVREF: */
/* 		break; */
/* 	    case OA_FILEREF: */
/* 		break; */
/* 	    case OA_SCALARREF: */
/* 		if ( ! SvROK(*arg) || ! SvAVOK(SvRV(*arg)) ) */
/* 		    bad_arg(numargs, "array", SvDESC(arg)); */
/* 		break; */
	default:
	    Perl_croak(aTHX_ "panic: unknown expeced arugment type");
	}
	oa >>= 4;
	arg++;
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
