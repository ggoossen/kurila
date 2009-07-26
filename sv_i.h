
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
    else if (SvTYPE(sv) == SVt_REGEXP)
        return Dt_REGEXP;
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
    case Dt_REGEXP: return "REGEXP";
    case Dt_REF: return "REF";
    case Dt_PLAIN: return "PLAINVALUE";
    case Dt_IO: return "IO";
    case Dt_GLOB: return "GLOB";
    case Dt_COMPLEX: return "COMPLEX";
    }
    return "COMPLEX";
}


/* Let us hope that bitmaps for UV and IV are the same */
IV
Perl_SvIV(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVIV;
    assert(SvTYPE(sv) != SVt_PVAV);
    assert(SvTYPE(sv) != SVt_PVHV);
    assert(SvTYPE(sv) != SVt_PVCV);
    assert(!isGV_with_GP(sv));
    return SvIOK(sv) ? I_SvIV(sv) : sv_2iv(sv);
}
UV
Perl_SvUV(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVUV;
    return SvIOK(sv) ? SvUVX(sv) : sv_2uv(sv);
}
NV
Perl_SvNV(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVNV;
    return SvNOK(sv) ? SvNVX(sv) : sv_2nv(sv);
}

#define SvIV_nomg(sv) (SvIOK(sv) ? I_SvIV(sv) : sv_2iv(sv))
#define SvUV_nomg(sv) (SvIOK(sv) ? SvUVX(sv) : sv_2uv(sv))

STRLEN
Perl_SvCUR(pTHX_ SV* sv) {
    assert(SvTYPE(sv) >= SVt_PV);
    assert(SvTYPE(sv) != SVt_PVAV);
    assert(SvTYPE(sv) != SVt_PVHV);
    assert(!isGV_with_GP(sv));
    return ((XPV*) SvANY(sv))->xpv_cur;
}

void
Perl_SvCUR_set(pTHX_ SV* sv, STRLEN len) {
    assert(SvTYPE(sv) >= SVt_PV);
    assert(SvTYPE(sv) != SVt_PVAV);
    assert(SvTYPE(sv) != SVt_PVHV);
    assert(!isGV_with_GP(sv));
    ((XPV*) SvANY(sv))->xpv_cur = len;
}

char* 
Perl_SvPVx_nolen(pTHX_ SV* sv) {
    PERL_ARGS_ASSERT_SVPVX_NOLEN;
    return SvPV_nolen(sv);
}

const char* 
Perl_SvPVx_nolen_const(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVPVX_NOLEN_CONST;
    return SvPV_nolen_const(sv);
}

bool
Perl_SvTRUE(pTHX_ SV *sv)
{
    PERL_ARGS_ASSERT_SVTRUE;
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
        return I_SvIV(sv) != 0;
    }
    if (SvNOK(sv))
        return SvNVX(sv) != 0.0;
    return sv_2bool(sv);
}

void
Perl_SvIOKp_on(pTHX_ SV *sv)
{
    PERL_ARGS_ASSERT_SVIOKP_ON;
    assert_not_glob(sv)
    SvRELEASE_IVX_(sv)
    SvFLAGS(sv) |= SVp_IOK;
    assert((SvTYPE(sv) == SVt_IV) || (SvTYPE(sv) >= SVt_PVIV));
}


/* XV to SV conversion "macros" */
SV* Perl_avTsv(pTHX_ AV *av) { return (SV*)av; }
SV* Perl_hvTsv(pTHX_ HV *hv) { return (SV*)hv; }
SV* Perl_cvTsv(pTHX_ CV *cv) { return (SV*)cv; }
SV* Perl_gvTsv(pTHX_ GV *gv) { return (SV*)gv; }
SV* Perl_reTsv(pTHX_ REGEXP *re) { return (SV*)re; }
SV* Perl_ioTsv(pTHX_ struct io *io) { return (SV*)io; }

SV** Perl_avpTsvp(pTHX_ AV **avp) { return (SV**)avp; }
SV** Perl_hvpTsvp(pTHX_ HV **hvp) { return (SV**)hvp; }
SV** Perl_cvpTsvp(pTHX_ CV **cvp) { return (SV**)cvp; }
SV** Perl_gvpTsvp(pTHX_ GV **gvp) { return (SV**)gvp; }
SV** Perl_repTsvp(pTHX_ REGEXP **rep) { return (SV**)rep; }
SV** Perl_iopTsvp(pTHX_ struct io **iop) { return (SV**)iop; }

AV* Perl_svTav(pTHX_ SV *sv) {
    assert(! sv || SvAVOK(sv));
    return (AV*)sv;
}

HV* Perl_svThv(pTHX_ SV *sv) {
    assert(!sv || SvHVOK(sv));
    return (HV*)sv;
}

CV* Perl_svTcv(pTHX_ SV *sv) {
    assert(!sv || SvCVOK(sv));
    return (CV*)sv;
}

GV* Perl_svTgv(pTHX_ SV *sv) {
    assert(!sv || SvTYPE(sv) == SVt_PVGV);
    return (GV*)sv;
}

IO* Perl_svTio(pTHX_ SV *sv) {
    assert(!sv || SvIOOK(sv));
    return (IO*)sv;
}

REGEXP* Perl_svTre(pTHX_ SV *sv) {
    assert(!sv || SvTYPE(sv) == SVt_REGEXP);
    return (REGEXP*)sv;
}

SV* SvREFCNT_inc(pTHX_ SV* sv) {
    if (sv) {
        assert(SvTYPE(sv) != SVTYPEMASK);
        (SvREFCNT(sv))++;
    }
    return sv;
}

#define SVcpNULL(sv) { SvREFCNT_dec(sv); sv = NULL; }
#define AVcpNULL(sv) { AvREFCNT_dec(sv); sv = NULL; }
#define HVcpNULL(sv) { HvREFCNT_dec(sv); sv = NULL; }
#define CVcpNULL(sv) { CvREFCNT_dec(sv); sv = NULL; }
#define IOcpNULL(sv) { IoREFCNT_dec(sv); sv = NULL; }

#define SVcpSTEAL(sv_d, sv_s) { SvREFCNT_dec(sv_d); sv_d = sv_s; }
#define AVcpSTEAL(sv_d, sv_s) { AvREFCNT_dec(sv_d); sv_d = sv_s; }
#define HVcpSTEAL(sv_d, sv_s) { HvREFCNT_dec(sv_d); sv_d = sv_s; }
#define CVcpSTEAL(sv_d, sv_s) { CvREFCNT_dec(sv_d); sv_d = sv_s; }
#define IOcpSTEAL(sv_d, sv_s) { IoREFCNT_dec(sv_d); sv_d = sv_s; }


void 
Perl_sv_cp_replace(pTHX_ SV** sv_d, SV* sv_s) {
    PERL_ARGS_ASSERT_SV_CP_REPLACE;
    SvREFCNT_inc(sv_s);
    SvREFCNT_dec(*sv_d);
    *sv_d = sv_s;
}

#define SVcpREPLACE(sv_d, sv_s) sv_cp_replace(&sv_d, sv_s)
#define HVcpREPLACE(sv_d, sv_s) hv_cp_replace(&sv_d, sv_s)
#define GVcpREPLACE(sv_d, sv_s) gv_cp_replace(&sv_d, sv_s)
#define AVcpREPLACE(sv_d, sv_s) av_cp_replace(&sv_d, sv_s)
#define CVcpREPLACE(sv_d, sv_s) cv_cp_replace(&sv_d, sv_s)
#define IOcpREPLACE(sv_d, sv_s) io_cp_replace(&sv_d, sv_s)


/* Location retrieval */
SV* 
Perl_LocationFilename(pTHX_ SV *location)
{
    SV** fn;
    if ( ! location || ! SvAVOK(location) )
        return NULL;
    fn = av_fetch(svTav(location), 0, 0);
    if ( ! fn )
        return NULL;
    return *fn;
}

/* Location retrieval */
SV* 
Perl_loc_desc(pTHX_ SV *loc) {
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
SV* 
Perl_loc_name(pTHX_ SV *loc) {
    SV * str = sv_2mortal(newSVpv("", 0));
    if (loc && SvAVOK(loc)) {
        Perl_sv_catpvf(aTHX_ str, "%s",
                       SvPVX_const(*av_fetch((AV*)loc, LOC_NAME_INDEX, FALSE))
            );
    }
    return str;
}

SV* 
Perl_SvNAME(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVNAME;
    return loc_name(SvLOCATION(sv));
}

const char* Perl_SvPVX_const(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVPVX_CONST;
    assert(SvTYPE(sv) >= SVt_PV);
    assert(SvTYPE(sv) != SVt_PVAV);
    assert(SvTYPE(sv) != SVt_PVHV);
    assert(!isGV_with_GP(sv));
    return I_SvPVX(sv);
}

char* Perl_SvPVX_mutable(pTHX_ SV *sv) {
    PERL_ARGS_ASSERT_SVPVX_MUTABLE;
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
