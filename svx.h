
#define Dtype(sv) inlineDtype(aTHX_ sv)
static __inline__ datatype inlineDtype(pTHX_ SV *sv) {
    if(!SvOK(sv))
        return Dt_UNDEF;
    else if (SvAVOK(sv))
        return Dt_ARRAY;
    else if (SvHVOK(sv))
        return Dt_HASH;
    else if (SvTYPE(sv) == SVt_PVGV)
        return Dt_GLOB;
    else if (SvROK(sv))
        return Dt_REF;
    else if (SvPVOK(sv))
        return Dt_PLAIN;
    else if (SvIOOK(sv))
        return Dt_IO;
    else
        return Dt_COMPLEX;
}


#define Ddesc(sv) inlineDdesc(aTHX_ sv)
static __inline__ const char* inlineDdesc(pTHX_ SV *sv) {
    switch (Dtype(sv)) {
    case Dt_UNDEF: return "UNDEF";
    case Dt_ARRAY: return "ARRAY";
    case Dt_HASH: return "HASH";
    case Dt_REF: return "REF";
    case Dt_PLAIN: return "PLAINVALUE";
    case Dt_IO: return "IO";
    case Dt_GLOB: return "GLOB";
    case Dt_COMPLEX: return "COMPLEX";
    }
    return "COMPLEX";
}


/* Let us hope that bitmaps for UV and IV are the same */
#define SvIV(sv) iiSvIV(aTHX_ sv)
#define SvUV(sv) iiSvUV(aTHX_ sv)
#define SvNV(sv) iiSvNV(aTHX_ sv)
static __inline__ IV iiSvIV(pTHX_ SV *sv) { return SvIOK(sv) ? SvIVX(sv) : sv_2iv(sv); }
static __inline__ UV iiSvUV(pTHX_ SV *sv) { return SvIOK(sv) ? SvUVX(sv) : sv_2uv(sv); }
static __inline__ NV iiSvNV(pTHX_ SV *sv) { return SvNOK(sv) ? SvNVX(sv) : sv_2nv(sv); }

#define SvIV_nomg(sv) (SvIOK(sv) ? SvIVX(sv) : sv_2iv_flags(sv, 0))
#define SvUV_nomg(sv) (SvIOK(sv) ? SvUVX(sv) : sv_2uv_flags(sv, 0))

#define SvPVx(sv, lp) iiSvPVx(aTHX_ sv, lp)
static __inline__ char* iiSvPVx(pTHX_ SV *sv, STRLEN *lp) { return SvPV(sv, *lp); }

#define SvPVx_const(sv, lp) iiSvPVx_const(aTHX_ sv, lp)
static __inline__ const char* iiSvPVx_const(pTHX_ SV *sv, STRLEN *lp) { return SvPV_const(sv, *lp); }

#define SvPVx_nolen(sv) iiSvPVx_nolen(aTHX_ sv)
static __inline__ char* iiSvPVx_nolen(pTHX_ SV* sv) {return SvPV_nolen(sv); }

#define SvPVx_nolen_const(sv) iiSvPVx_nolen_const(aTHX_ sv)
static __inline__ const char* iiSvPVx_nolen_const(pTHX_ SV *sv) {return SvPV_nolen_const(sv); }

#define SvTRUE(sv) iiSvTRUE(aTHX_ sv)
static __inline__ bool iiSvTRUE(pTHX_ SV *sv) {
    if (!sv)
        return 0;
    if (SvPOK(sv)) {
	XPV *nxpv = (XPV*)SvANY(sv);
        return (nxpv &&
                (nxpv->xpv_cur > 1 ||
                 (nxpv->xpv_cur && *(sv)->sv_u.svu_pv != '0')))
            ? 1						
            : 0;
    }					
    if (SvIOK(sv)) {
        return SvIVX(sv) != 0;
    }
    if (SvNOK(sv))
        return SvNVX(sv) != 0.0;
    return sv_2bool(sv);
}

/* static __inline__ bool SvTRUEx(pTHX_ SV *sv) {return SvTRUE(sv); } */
#define SvTRUEx SvTRUE

static __inline__ void iiSvIOKp_on(pTHX_ SV *sv) {
    assert_not_glob(sv)
    SvRELEASE_IVX_(sv)
    SvFLAGS(sv) |= SVp_IOK;
    assert((SvTYPE(sv) == SVt_IV) || (SvTYPE(sv) >= SVt_PVIV));
}
#define SvIOKp_on(sv) iiSvIOKp_on(aTHX_ sv)


#define av_2mortal(av) inline_av_2mortal(aTHX_ av)
static __inline__ AV* inline_av_2mortal(pTHX_ AV *av) {
    return (AV*)sv_2mortal((SV*)av);
}


#define SVcpREPLACE(sv_d, sv_s) inline_SVcpREPLACE(&sv_d, sv_s)
static __inline__ void inline_SVcpREPLACE(pTHX_ SV**sv_d, SV*sv_s) {
  SvREFCNT_inc(sv_s);
  SvREFCNT_dec(*sv_d);
  *sv_d = sv_s;
}

#define SVcpNULL(sv) { SvREFCNT_dec(sv); sv = NULL; }
#define SVcpSTEAL(sv_d, sv_s) { SvREFCNT_dec(sv_d); sv_d = sv_s; }


#define XVcpREPLACE(XV) \
    static __inline__ void inline_cpREPLACE_##XV( XV **sv_d, XV *sv_s) { \
        inline_SVcpREPLACE(aTHX_ (SV**)sv_d, (SV*)sv_s);                \
    }
#define call_XVcpREPLACE(XV, sv_d, sv_s) inline_cpREPLACE_##XV(&sv_d, sv_s)


XVcpREPLACE(HV)
#define HVcpREPLACE(sv_d, sv_s) call_XVcpREPLACE(HV, sv_d, sv_s)
XVcpREPLACE(GV)
#define GVcpREPLACE(sv_d, sv_s) call_XVcpREPLACE(GV, sv_d, sv_s)
XVcpREPLACE(AV)
#define AVcpREPLACE(sv_d, sv_s) call_XVcpREPLACE(AV, sv_d, sv_s)
XVcpREPLACE(CV)
#define CVcpREPLACE(sv_d, sv_s) call_XVcpREPLACE(CV, sv_d, sv_s)

