
static __inline__ IV SvIVx(SV *sv) { return SvIV(sv); }
static __inline__ UV SvUVx(SV *sv) { return SvUV(sv); }
static __inline__ NV SvNVx(SV *sv) { return SvNV(sv); }
static __inline__ char* SvPVx(SV *sv, STRLEN *lp) { return SvPV(sv, *lp); }
static __inline__ const char* SvPVx_const(SV *sv, STRLEN *lp) { return SvPV_const(sv, *lp); }
static __inline__ char* SvPVx_nolen(SV* sv) {return SvPV_nolen(sv); }
static __inline__ const char* SvPVx_nolen_const(SV *sv) {return SvPV_nolen_const(sv); }
static __inline__ bool SvTRUE(SV *sv) {
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

static __inline__ bool SvTRUEx(SV *sv) {return SvTRUE(sv); }

