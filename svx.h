
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


