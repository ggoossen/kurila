
#define Dtype(sv) inlineDtype(aTHX_ sv)
static __inline__ datatype inlineDtype(pTHX_ SV *sv) {
    if(!SvOK(sv))
        return Dt_UNDEF;
    else if (SvAVOK(sv))
        return Dt_ARRAY;
    else if (SvHVOK(sv))
        return Dt_HASH;
    else if (SvCVOK(sv))
        return Dt_CODE;
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
    case Dt_CODE: return "CODE";
    case Dt_REF: return "REF";
    case Dt_PLAIN: return "PLAINVALUE";
    case Dt_IO: return "IO";
    case Dt_GLOB: return "GLOB";
    case Dt_COMPLEX: return "COMPLEX";
    }
    return "COMPLEX";
}


/* Let us hope that bitmaps for UV and IV are the same */
IV Perl_SvIV(pTHX_ SV *sv) { return SvIOK(sv) ? SvIVX(sv) : sv_2iv(sv); }
UV Perl_SvUV(pTHX_ SV *sv) { return SvIOK(sv) ? SvUVX(sv) : sv_2uv(sv); }
NV Perl_SvNV(pTHX_ SV *sv) { return SvNOK(sv) ? SvNVX(sv) : sv_2nv(sv); }

#define SvIV_nomg(sv) (SvIOK(sv) ? SvIVX(sv) : sv_2iv(sv))
#define SvUV_nomg(sv) (SvIOK(sv) ? SvUVX(sv) : sv_2uv(sv))

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


#define av_mortalcopy(av) inline_av_mortalcopy(aTHX_ av)
static __inline__ AV* inline_av_mortalcopy(pTHX_ AV *av) {
    return (AV*)sv_mortalcopy((SV*)av);
}

/* XV to SV conversion "macros" */
SV* Perl_AvSv(pTHX_ AV *av) { return (SV*)av; }
SV* Perl_HvSv(pTHX_ HV *hv) { return (SV*)hv; }
SV* Perl_CvSv(pTHX_ CV *cv) { return (SV*)cv; }
SV* Perl_GvSv(pTHX_ GV *gv) { return (SV*)gv; }
SV* Perl_ReSv(pTHX_ REGEXP *re) { return (SV*)re; }
SV* Perl_IoSv(pTHX_ struct io *io) { return (SV*)io; }


AV* Perl_SvAv(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVAV;
    assert(SvAVOK(sv));
    return (AV*)sv;
}

HV* Perl_SvHv(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVHV;
    assert(SvHVOK(sv));
    return (HV*)sv;
}

CV* Perl_SvCv(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVCV;
    assert(SvCVOK(sv));
    return (CV*)sv;
}

IO* Perl_SvIo(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVIO;
    assert(SvIOOK(sv));
    return (IO*)sv;
}

REGEXP* Perl_SvRe(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVRE;
    assert(SvTYPE(sv) == SVt_REGEXP);
    return (REGEXP*)sv;
}

#define CvREFCNT_inc(cv) inline_CvREFCNT_inc(aTHX_ cv)
static __inline__ CV* inline_CvREFCNT_inc(pTHX_ CV* cv) {
    return (CV*)SvREFCNT_inc((SV*)cv);
}

#define SVcpREPLACE(sv_d, sv_s) inline_SVcpREPLACE(&sv_d, sv_s)
static __inline__ void inline_SVcpREPLACE(pTHX_ SV**sv_d, SV*sv_s) {
  SvREFCNT_inc(sv_s);
  SvREFCNT_dec(*sv_d);
  *sv_d = sv_s;
}

#define SVcpNULL(sv) { SvREFCNT_dec(sv); sv = NULL; }
#define AVcpNULL(sv) { AvREFCNT_dec(sv); sv = NULL; }
#define HVcpNULL(sv) { HvREFCNT_dec(sv); sv = NULL; }
#define CVcpNULL(sv) { CvREFCNT_dec(sv); sv = NULL; }

#define SVcpSTEAL(sv_d, sv_s) { SvREFCNT_dec(sv_d); sv_d = sv_s; }
#define AVcpSTEAL(sv_d, sv_s) { AvREFCNT_dec(sv_d); sv_d = sv_s; }
#define HVcpSTEAL(sv_d, sv_s) { HvREFCNT_dec(sv_d); sv_d = sv_s; }
#define CVcpSTEAL(sv_d, sv_s) { CvREFCNT_dec(sv_d); sv_d = sv_s; }


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


/* Location retrieval */
SV* LocationFilename(pTHX_ SV *location) {
    SV** fn;
    if ( ! location || ! SvAVOK(location) )
        return NULL;
    fn = av_fetch(SvAv(location), 0, 0);
    if ( ! fn )
        return NULL;
    return *fn;
}

/* Location retrieval */
#define loc_desc(loc) inline_loc_desc(aTHX_ loc)
static __inline__ SV* inline_loc_desc(pTHX_ SV *loc) {
    SV * str = sv_2mortal(newSVpv("", 0));
    if (loc && SvAVOK(loc)) {
        SV ** loc0 = av_fetch((AV*)loc, 0, FALSE);
        SV ** loc1 = av_fetch((AV*)loc, 1, FALSE);
        SV ** loc2 = av_fetch((AV*)loc, 2, FALSE);
        Perl_sv_catpvf(aTHX_ str, "%s line %"IVdf" character %"IVdf".",
            (loc0 && SvPVOK(*loc0)) ? SvPVX_const(*loc0) : "",
            (loc1 && SvPVOK(*loc1)) ? SvIV(*loc1) : -1,
            (loc2 && SvPVOK(*loc2)) ? SvIV(*loc2) : -1
            );
    }
    return str;
}

#define LOC_NAME_INDEX 3

/* Location retrieval */
#define loc_name(loc) inline_loc_name(aTHX_ loc)
static __inline__ SV* inline_loc_name(pTHX_ SV *loc) {
    SV * str = sv_2mortal(newSVpv("", 0));
    if (loc && SvAVOK(loc)) {
        Perl_sv_catpvf(aTHX_ str, "%s",
                       SvPVX_const(*av_fetch((AV*)loc, LOC_NAME_INDEX, FALSE))
            );
    }
    return str;
}

#define SvNAME(sv) inline_SvNAME(aTHX_ sv)
static __inline__ SV* inline_SvNAME(pTHX_ SV *sv) {
    return loc_name(SvLOCATION(sv));
}

const char* Perl_SvPVX_const(pTHX_ SV *sv) {
    assert(SvTYPE(sv) >= SVt_PV);
    assert(SvTYPE(sv) != SVt_PVAV);
    assert(SvTYPE(sv) != SVt_PVHV);
    assert(!isGV_with_GP(sv));
    return I_SvPVX(sv);
}

char* Perl_SvPVX_mutable(pTHX_ SV *sv) {
    assert(SvTYPE(sv) >= SVt_PV);
    assert(SvTYPE(sv) != SVt_PVAV);
    assert(SvTYPE(sv) != SVt_PVHV);
    assert(!isGV_with_GP(sv));
    return I_SvPVX(sv);
}

void Perl_SvREFCNT_dec(pTHX_ SV *sv) {
    if (sv) {
        if (SvREFCNT(sv)) {
            if (--(SvREFCNT(sv)) == 0)
                Perl_sv_free2(aTHX_ sv);
        } else {
            sv_free(sv);
        }
    }
}

void Perl_SvTMPREFCNT_inc(pTHX_ SV *sv) {
    if (sv) {
        assert(SvTYPE(sv) != SVTYPEMASK);
        (SvTMPREFCNT(sv))++;
    }
}
