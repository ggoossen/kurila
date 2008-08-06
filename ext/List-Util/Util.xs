/* Copyright (c) 1997-2000 Graham Barr <gbarr@pobox.com>. All rights reserved.
 * This program is free software; you can redistribute it and/or
 * modify it under the same terms as Perl itself.
 */

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "multicall.h"

#ifdef SVf_IVisUV
#  define slu_sv_value(sv) (SvIOK(sv)) ? (SvIOK_UV(sv)) ? (NV)(SvUVX(sv)) : (NV)(SvIVX(sv)) : (SvNV(sv))
#else
#  define slu_sv_value(sv) (SvIOK(sv)) ? (NV)(SvIVX(sv)) : (SvNV(sv))
#endif

#ifndef Drand01
#    define Drand01()		((rand() & 0x7FFF) / (double) ((unsigned long)1 << 15))
#endif

#ifndef GvSVn
#  define GvSVn GvSV
#endif

MODULE=List::Util	PACKAGE=List::Util

void
min(...)
PROTOTYPE: @
ALIAS:
    min = 0
    max = 1
CODE:
{
    int index;
    NV retval;
    SV *retsv;
    if(!items) {
	XSRETURN_UNDEF;
    }
    retsv = ST(0);
    retval = slu_sv_value(retsv);
    for(index = 1 ; index < items ; index++) {
	SV *stacksv = ST(index);
	NV val = slu_sv_value(stacksv);
	if(val < retval ? !ix : ix) {
	    retsv = stacksv;
	    retval = val;
	}
    }
    ST(0) = retsv;
    XSRETURN(1);
}



NV
sum(...)
PROTOTYPE: @
CODE:
{
    SV *sv;
    int index;
    if(!items) {
	XSRETURN_UNDEF;
    }
    sv = ST(0);
    RETVAL = slu_sv_value(sv);
    for(index = 1 ; index < items ; index++) {
	sv = ST(index);
	RETVAL += slu_sv_value(sv);
    }
}
OUTPUT:
    RETVAL


void
minstr(...)
PROTOTYPE: @
ALIAS:
    minstr = 2
    maxstr = 0
CODE:
{
    SV *left;
    int index;
    if(!items) {
	XSRETURN_UNDEF;
    }
    /*
      sv_cmp & sv_cmp_locale return 1,0,-1 for gt,eq,lt
      so we set ix to the value we are looking for
      xsubpp does not allow -ve values, so we start with 0,2 and subtract 1
    */
    ix -= 1;
    left = ST(0);
#ifdef OPpLOCALE
    if(MAXARG & OPpLOCALE) {
	for(index = 1 ; index < items ; index++) {
	    SV *right = ST(index);
	    if(sv_cmp_locale(left, right) == ix)
		left = right;
	}
    }
    else {
#endif
	for(index = 1 ; index < items ; index++) {
	    SV *right = ST(index);
	    if(sv_cmp(left, right) == ix)
		left = right;
	}
#ifdef OPpLOCALE
    }
#endif
    ST(0) = left;
    XSRETURN(1);
}



#ifdef dMULTICALL

void
reduce(block,...)
    SV * block
PROTOTYPE: &@
CODE:
{
    dVAR; dMULTICALL;
    SV *ret = sv_newmortal();
    int index;
    GV *agv,*bgv,*gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *cv;

    if(items <= 1) {
	XSRETURN_UNDEF;
    }
    cv = sv_2cv(block, &gv, 0);
    PUSH_MULTICALL(cv);
    agv = gv_fetchpv("a", TRUE, SVt_PV);
    bgv = gv_fetchpv("b", TRUE, SVt_PV);
    SAVESPTR(GvSV(agv));
    SAVESPTR(GvSV(bgv));
    SVcpREPLACE(GvSV(agv), ret);
    SvSetSV(ret, args[1]);
    for(index = 2 ; index < items ; index++) {
	SVcpREPLACE(GvSV(bgv), args[index]);
	MULTICALL;
	SvSetSV(ret, *PL_stack_sp);
    }
    POP_MULTICALL;
    ST(0) = ret;
    XSRETURN(1);
}

void
first(block,...)
    SV * block
PROTOTYPE: &@
CODE:
{
    dVAR; dMULTICALL;
    int index;
    GV *gv;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    CV *cv;

    if(items <= 1) {
	XSRETURN_UNDEF;
    }
    cv = sv_2cv(block, &gv, 0);
    PUSH_MULTICALL(cv);
    SAVESPTR(GvSV(PL_defgv));

    for(index = 1 ; index < items ; index++) {
	SVcpREPLACE(GvSV(PL_defgv), args[index]);
	MULTICALL;
	if (SvTRUE(*PL_stack_sp)) {
	  POP_MULTICALL;
	  ST(0) = ST(index);
	  XSRETURN(1);
	}
    }
    POP_MULTICALL;
    XSRETURN_UNDEF;
}

#endif

void
shuffle(...)
PROTOTYPE: @
CODE:
{
    dVAR;
    int index;
    AV* ret;
    /* Initialize Drand01 if rand() or srand() has
       not already been called
    */
    if (!PL_srand_called) {
        (void)seedDrand01((Rand_seed_t)Perl_seed(aTHX));
        PL_srand_called = TRUE;
    }

    ret = (AV*)sv_2mortal((SV*)newAV());

    for (index = items ; index > 0 ; ) {
	int swap = (int)(Drand01() * (double)(index--));
	SV *tmp = ST(swap);
	ST(swap) = ST(index);
	ST(index) = tmp;
        av_push(ret, SvREFCNT_inc(tmp));
    }
    SP -= items;
    PUSHs((SV*)ret);
    XSRETURN(1);
}


MODULE=List::Util	PACKAGE=Scalar::Util

void
dualvar(num,str)
    SV *	num
    SV *	str
PROTOTYPE: $$
CODE:
{
    STRLEN len;
    char *ptr = SvPV(str,len);
    ST(0) = sv_newmortal();
    (void)SvUPGRADE(ST(0),SVt_PVNV);
    sv_setpvn(ST(0),ptr,len);
    if(SvNOK(num) || SvPOK(num) || SvMAGICAL(num)) {
	SvNV_set(ST(0), SvNV(num));
	SvNOK_on(ST(0));
    }
#ifdef SVf_IVisUV
    else if (SvUOK(num)) {
	SvUV_set(ST(0), SvUV(num));
	SvIOK_on(ST(0));
	SvIsUV_on(ST(0));
    }
#endif
    else {
	SvIV_set(ST(0), SvIV(num));
	SvIOK_on(ST(0));
    }
    if(PL_tainting && (SvTAINTED(num) || SvTAINTED(str)))
	SvTAINTED_on(ST(0));
    XSRETURN(1);
}

char *
blessed(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(!sv_isobject(sv)) {
	XSRETURN_UNDEF;
    }
    RETVAL = (char*)sv_reftype(SvRV(sv),TRUE);
}
OUTPUT:
    RETVAL

char *
reftype(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(!SvROK(sv)) {
	XSRETURN_UNDEF;
    }
    RETVAL = (char*)sv_reftype(SvRV(sv),FALSE);
}
OUTPUT:
    RETVAL

UV
refaddr(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(!SvROK(sv)) {
	XSRETURN_UNDEF;
    }
    RETVAL = PTR2UV(SvRV(sv));
}
OUTPUT:
    RETVAL

void
weaken(sv)
	SV *sv
PROTOTYPE: $
CODE:
	sv_rvweaken(sv);

void
isweak(sv)
	SV *sv
PROTOTYPE: $
CODE:
	ST(0) = boolSV(SvROK(sv) && SvWEAKREF(sv));
	XSRETURN(1);

int
readonly(sv)
	SV *sv
PROTOTYPE: $
CODE:
  RETVAL = SvREADONLY(sv);
OUTPUT:
  RETVAL

int
tainted(sv)
	SV *sv
PROTOTYPE: $
CODE:
  RETVAL = SvTAINTED(sv);
OUTPUT:
  RETVAL

int
looks_like_number(sv)
	SV *sv
PROTOTYPE: $
CODE:
  RETVAL = looks_like_number(sv);
OUTPUT:
  RETVAL

void
set_prototype(subref, proto)
    SV *subref
    SV *proto
PROTOTYPE: &$
CODE:
{
    if (SvROK(subref)) {
	SV *sv = SvRV(subref);
	if (SvTYPE(sv) != SVt_PVCV) {
	    /* not a subroutine reference */
	    croak("set_prototype: not a subroutine reference");
	}
	if (SvPOK(proto)) {
	    /* set the prototype */
	    STRLEN len;
	    char *ptr = SvPV(proto, len);
	    sv_setpvn(sv, ptr, len);
	}
	else {
	    /* delete the prototype */
	    SvPOK_off(sv);
	}
    }
    else {
	croak("set_prototype: not a reference");
    }
    XSRETURN(1);
}

BOOT:
{
    HV *lu_stash = gv_stashpvn("List::Util", 10, TRUE);
    GV *rmcgv = *(GV**)hv_fetch(lu_stash, "REAL_MULTICALL", 14, TRUE);
    SV *rmcsv;
    if (SvTYPE(rmcgv) != SVt_PVGV)
	gv_init(rmcgv, lu_stash, "List::Util", 12, TRUE);
    rmcsv = GvSVn(rmcgv);
#ifdef REAL_MULTICALL
    sv_setsv(rmcsv, &PL_sv_yes);
#else
    sv_setsv(rmcsv, &PL_sv_no);
#endif
}
