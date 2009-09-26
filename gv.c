/*    gv.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000,
 *    2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 *   'Mercy!' cried Gandalf.  'If the giving of information is to be the cure
 * of your inquisitiveness, I shall spend all the rest of my days in answering
 * you.  What more do you want to know?'
 *   'The names of all the stars, and of all living things, and the whole
 * history of Middle-earth and Over-heaven and of the Sundering Seas,'
 * laughed Pippin.
 *
 *     [p.599 of _The Lord of the Rings_, III/xi: "The Palant�r"]
 */

/*
=head1 GV Functions

A GV is a structure which corresponds to to a Perl typeglob, ie *foo.
It is a structure that holds a pointer to a scalar, an array, a hash etc,
corresponding to $foo, @foo, %foo.

GVs are usually found as values in stashes (symbol table hashes) where
Perl stores its global variables.

=cut
*/

#include "EXTERN.h"
#define PERL_IN_GV_C
#include "perl.h"

GV *
Perl_gv_add_by_type(pTHX_ GV *gv, svtype type)
{
    SV **where;

    if (!gv || SvTYPE((const SV *)gv) != SVt_PVGV) {
	const char *what;
	if (type == SVt_PVIO) {
	    /*
	     * if it walks like a dirhandle, then let's assume that
	     * this is a dirhandle.
	     */
	    what = PL_op->op_type ==  OP_READDIR ||
		PL_op->op_type ==  OP_TELLDIR ||
		PL_op->op_type ==  OP_SEEKDIR ||
		PL_op->op_type ==  OP_REWINDDIR ||
		PL_op->op_type ==  OP_CLOSEDIR ?
		"dirhandle" : "filehandle";
	    /* diag_listed_as: Bad symbol for filehandle */
	} else if (type == SVt_PVHV) {
	    what = "hash";
	} else {
	    what = type == SVt_PVAV ? "array" : "scalar";
	}
	Perl_croak(aTHX_ "Bad symbol for %s", what);
    }

    if (type == SVt_PVHV) {
	where = (SV **)&GvHV(gv);
    } else if (type == SVt_PVAV) {
	where = (SV **)&GvAV(gv);
    } else if (type == SVt_PVIO) {
	where = (SV **)&GvIOp(gv);
    } else {
	where = &GvSV(gv);
    }

    if (!*where)
	*where = newSV_type(type);
    return gv;
}

GV *
Perl_gv_fetchfile(pTHX_ const char *name)
{
    PERL_ARGS_ASSERT_GV_FETCHFILE;
    return gv_fetchfile_flags(name, strlen(name), 0);
}

GV *
Perl_gv_fetchfile_flags(pTHX_ const char *const name, const STRLEN namelen,
			const U32 flags)
{
    dVAR;
    char smallbuf[128];
    char *tmpbuf;
    const STRLEN tmplen = namelen + 2;
    GV *gv;

    PERL_ARGS_ASSERT_GV_FETCHFILE_FLAGS;
    PERL_UNUSED_ARG(flags);

    if (!PL_defstash)
	return NULL;

    if (tmplen <= sizeof smallbuf)
	tmpbuf = smallbuf;
    else
	Newx(tmpbuf, tmplen, char);
    /* This is where the debugger's %{"::_<$filename"} hash is created */
    tmpbuf[0] = '_';
    tmpbuf[1] = '<';
    memcpy(tmpbuf + 2, name, namelen);
    gv = *(GV**)hv_fetch(PL_defstash, tmpbuf, tmplen, TRUE);
    if (!isGV(gv)) {
	gv_init(gv, PL_defstash, tmpbuf, tmplen, FALSE);
#ifdef PERL_DONT_CREATE_GVSV
	GvSV(gv) = newSVpvn(name, namelen);
#else
	sv_setpvn(GvSV(gv), name, namelen);
#endif
	if (PERLDB_LINE)
	    hv_magic(GvHVn(gv_AVadd(gv)), NULL, PERL_MAGIC_dbfile);
    }
    if (tmpbuf != smallbuf)
	Safefree(tmpbuf);
    return gv;
}

GP *
Perl_newGP(pTHX_ GV *const gv)
{
    GP *gp;
    U32 hash;
    SV *const temp_sv = LocationFilename(PL_curcop->op_location);
    const char *file;
    STRLEN len;

    PERL_ARGS_ASSERT_NEWGP;

    if (temp_sv) {
	file = SvPVX_const(temp_sv);
	len = SvCUR(temp_sv);
    } else {
	file = "";
	len = 0;
    }

    PERL_HASH(hash, file, len);

    Newxz(gp, 1, GP);

#ifndef PERL_DONT_CREATE_GVSV
    gp->gp_sv = newSV(0);
#endif

    gp->gp_egv = gv;
    gp->gp_refcnt = 1;

    return gp;
}

void
Perl_gv_init(pTHX_ GV *gv, HV *stash, const char *name, STRLEN len, int multi)
{
    dVAR;
    const U32 old_type = SvTYPE(gv);
    const bool doproto = old_type > SVt_NULL;
    char * const proto = (doproto && SvPOK(gv)) ? SvPVX_mutable((SV*)gv) : NULL;
    const STRLEN protolen = proto ? SvCUR(gvTsv(gv)) : 0;
    SV *const has_constant = doproto && SvROK(gv) ? SvRV(gv) : NULL;
    const U32 exported_constant = has_constant ? SvPCS_IMPORTED(gv) : 0;

    PERL_ARGS_ASSERT_GV_INIT;
    assert (!(proto && has_constant));
    assert( ! stash || (SvTYPE(stash) == SVt_PVHV) );

    if (has_constant) {
	/* The constant has to be a simple scalar type.  */
	switch (SvTYPE(has_constant)) {
	case SVt_PVAV:
	case SVt_PVHV:
	case SVt_PVCV:
	case SVt_PVIO:
            Perl_croak(aTHX_ "Cannot convert a reference to %s to typeglob",
		       sv_reftype(has_constant, 0));
	default: NOOP;
	}
	SvRV_set(gv, NULL);
	SvROK_off(gv);
    }


    if (old_type < SVt_PVGV) {
	if (old_type >= SVt_PV)
	    SvCUR_set(gvTsv(gv), 0);
	sv_upgrade((SV*)gv, SVt_PVGV);
    }
    if (SvLEN(gv)) {
	if (proto) {
	    SvPV_set(gv, NULL);
	    SvLEN_set(gv, 0);
	    SvPOK_off(gv);
	} else
	    Safefree(SvPVX_mutable((SV*)gv));
    }
    SvIOK_off(gv);
    isGV_with_GP_on(gv);

    GvGP(gv) = Perl_newGP(aTHX_ gv);
    GvSTASH(gv) = stash;
    if (stash)
	Perl_sv_add_backref(aTHX_ MUTABLE_SV(stash), MUTABLE_SV(gv));
    gv_name_set(gv, name, len, GV_ADD);
    if (multi || doproto)              /* doproto means it _was_ mentioned */
	GvMULTI_on(gv);
    if (doproto) {			/* Replicate part of newSUB here. */
	ENTER_named("gv_init");
	SAVESPTR(PL_curstash);
	HVcpREPLACE(PL_curstash, stash);
	if (has_constant) {
	    /* newCONSTSUB takes ownership of the reference from us.  */
	    GvCV(gv) = newCONSTSUB(name, has_constant);
	    /* If this reference was a copy of another, then the subroutine
	       must have been "imported", by a Perl space assignment to a GV
	       from a reference to CV.  */
	    if (exported_constant)
		GvIMPORTED_CV_on(gv);
	} else {
	    Perl_croak(aTHX_ "creating subroutine %s", name);
	    (void) start_subparse(0);	/* Create empty CV in compcv. */
	    GvCV(gv) = (CV*)SvREFCNT_inc((SV*)PL_compcv);
	}
	LEAVE_named("gv_init");

        mro_method_changed_in(GvSTASH(gv)); /* sub Foo::bar($) { (shift) } sub ASDF::baz($); *ASDF::baz = \&Foo::bar */
	assert(SvTYPE(GvCV(gv)) == SVt_PVCV);
	SVcpREPLACE(SvLOCATION(GvCV(gv)), PL_curcop->op_location);
	if (proto) {
	    sv_usepvn_flags(MUTABLE_SV(GvCV(gv)), proto, protolen,
			    SV_HAS_TRAILING_NUL);
	}
    }
}

STATIC void
S_gv_init_sv(pTHX_ GV *gv, const svtype sv_type)
{
    PERL_ARGS_ASSERT_GV_INIT_SV;

    switch (sv_type) {
    case SVt_PVIO:
	(void)GvIOn(gv);
	break;
    case SVt_PVAV:
	(void)GvAVn(gv);
	break;
    case SVt_PVHV:
	(void)GvHVn(gv);
	break;
#ifdef PERL_DONT_CREATE_GVSV
    case SVt_NULL:
    case SVt_PVCV:
    case SVt_PVGV:
	break;
    default:
	if(GvSVn(gv)) {
	    /* Work round what appears to be a bug in Sun C++ 5.8 2005/10/13
	       If we just cast GvSVn(gv) to void, it ignores evaluating it for
	       its side effect */
	}
#endif
    }
}

/*
=for apidoc gv_fetchmeth

Returns the glob with the given C<name> and a defined subroutine or
C<NULL>.  The glob lives in the given C<stash>, or in the stashes
accessible via @ISA and UNIVERSAL::.

The argument C<level> should be either 0 or -1.  If C<level==0>, as a
side-effect creates a glob with the given C<name> in the given C<stash>
which in the case of success contains an alias for the subroutine, and sets
up caching info for this glob.

This function grants C<"SUPER"> token as a postfix of the stash name. The
GV returned from C<gv_fetchmeth> may be a method cache entry, which is not
visible to Perl code.  So when calling C<call_sv>, you should not use
the GV directly; instead, you should use the method's CV, which can be
obtained from the GV with the C<GvCV> macro.

=cut
*/

/* NOTE: No support for tied ISA */

CV *
Perl_gv_fetchmeth(pTHX_ HV *stash, const char *name, STRLEN len, I32 level)
{
    dVAR;
    GV** gvp;
    AV* linear_av;
    SV** linear_svp;
    SV* linear_sv;
    HV* cstash;
    CV* old_cv;
    GV* topgv = NULL;
    const char *hvname;
    I32 create = (level >= 0) ? 1 : 0;
    I32 items;
    STRLEN packlen;
    U32 topgen_cmp;

    PERL_ARGS_ASSERT_GV_FETCHMETH;

    /* UNIVERSAL methods should be callable without a stash */
    if (!stash) {
	create = 0;  /* probably appropriate */
	if(!(stash = gv_stashpvs("UNIVERSAL", 0)))
	    return NULL;
    }

    assert(stash);

    hvname = HvNAME_get(stash);
    if (!hvname)
      Perl_croak(aTHX_ "Can't use anonymous symbol table for method lookup");

    assert(hvname);
    assert(name);

    DEBUG_o( Perl_deb(aTHX_ "Looking for method %s in package %s\n",name,hvname) );

    topgen_cmp = HvMROMETA(stash)->cache_gen + PL_sub_generation;

    /* check locally for a real method or a cache entry */
    gvp = (GV**)hv_fetch(stash, name, len, create);
    if(gvp) {
	CV* cand_cv;
        topgv = *gvp;
        assert(topgv);
        if (SvTYPE(topgv) != SVt_PVGV)
            gv_init(topgv, stash, name, len, TRUE);
        if ((cand_cv = GvCV(topgv))) {
            /* If genuine method or valid cache entry, use it */
            if (!GvCVGEN(topgv) || GvCVGEN(topgv) == topgen_cmp) {
                return GvCV(topgv);
            }
            else {
                /* stale cache entry, junk it and move on */
	        CvREFCNT_dec(cand_cv);
	        GvCV(topgv) = cand_cv = NULL;
	        GvCVGEN(topgv) = 0;
            }
        }
        else if (GvCVGEN(topgv) == topgen_cmp) {
            /* cache indicates no such method definitively */
            return NULL;
        }
    }

    packlen = HvNAMELEN_get(stash);
    if (packlen >= 7 && strEQ(hvname + packlen - 7, "::SUPER")) {
        HV* basestash;
        packlen -= 7;
        basestash = gv_stashpvn(hvname, packlen, GV_ADD);
        linear_av = mro_get_linear_isa(basestash);
    }
    else {
        linear_av = mro_get_linear_isa(stash); /* has ourselves at the top of the list */
    }

    linear_svp = AvARRAY(linear_av) + 1; /* skip over self */
    items = AvFILLp(linear_av); /* no +1, to skip over self */
    while (items--) {
	GV* candidate;
	CV* cand_cv;
        linear_sv = *linear_svp++;
        assert(linear_sv);
        cstash = gv_stashsv(linear_sv, 0);

        if (!cstash) {
            if (ckWARN(WARN_SYNTAX))
                Perl_warner(aTHX_ packWARN(WARN_SYNTAX), "Can't locate package %"SVf" for @%s::ISA",
                    SVfARG(linear_sv), hvname);
            continue;
        }

        assert(cstash);

        gvp = (GV**)hv_fetch(cstash, name, len, 0);
        if (!gvp) continue;
        candidate = *gvp;
        assert(candidate);
        if (SvTYPE(candidate) != SVt_PVGV)
	    gv_init(candidate, cstash, name, len, TRUE);
        if (SvTYPE(candidate) == SVt_PVGV && (cand_cv = GvCV(candidate))
	    && !GvCVGEN(candidate)) {
            /*
             * Found real method, cache method in topgv if:
             *  1. topgv has no synonyms (else inheritance crosses wires)
             *  2. method isn't a stub (else AUTOLOAD fails spectacularly)
             */
            if (topgv && (GvREFCNT(topgv) == 1) && (CvROOT(cand_cv) || CvXSUB(cand_cv))) {
                  if ((old_cv = GvCV(topgv))) CvREFCNT_dec(old_cv);
                  SvREFCNT_inc_void_NN(cand_cv);
                  GvCV(topgv) = cand_cv;
                  GvCVGEN(topgv) = topgen_cmp;
            }
	    return GvCV(candidate);
        }
    }

    /* Check UNIVERSAL without caching */
    if(level == 0 || level == -1) {
        CV* cand_cv = gv_fetchmeth(NULL, name, len, 1);
        if(cand_cv) {
            if (topgv && (GvREFCNT(topgv) == 1) && (CvROOT(cand_cv) || CvXSUB(cand_cv))) {
                  if ((old_cv = GvCV(topgv))) CvREFCNT_dec(old_cv);
                  SvREFCNT_inc_void_NN(cand_cv);
                  GvCV(topgv) = cand_cv;
                  GvCVGEN(topgv) = topgen_cmp;
            }
            return cand_cv;
        }
    }

    if (topgv && GvREFCNT(topgv) == 1) {
        /* cache the fact that the method is not defined */
        GvCVGEN(topgv) = topgen_cmp;
    }

    return 0;
}

/*
=for apidoc gv_fetchmethod

Returns the glob which contains the subroutine to call to invoke the method
on the C<stash>.

These functions grant C<"SUPER"> token as a prefix of the method name.

These functions have the same side-effects and as C<gv_fetchmeth> with
C<level==0>.  C<name> should be writable if contains C<':'> or C<'
''>. The warning against passing the GV returned by C<gv_fetchmeth> to
C<call_sv> apply equally to these functions.

=cut
*/

STATIC HV*
S_gv_get_super_pkg(pTHX_ const char* name, I32 namelen)
{
    AV* superisa;
    GV** gvp;
    GV* gv;
    HV* stash;

    PERL_ARGS_ASSERT_GV_GET_SUPER_PKG;

    stash = gv_stashpvn(name, namelen, 0);
    if(stash) return stash;

    /* If we must create it, give it an @ISA array containing
       the real package this SUPER is for, so that it's tied
       into the cache invalidation code correctly */
    stash = gv_stashpvn(name, namelen, GV_ADD);
    gvp = (GV**)hv_fetchs(stash, "ISA", TRUE);
    gv = *gvp;
    gv_init(gv, stash, "ISA", 3, TRUE);
    superisa = GvAVn(gv);
    assert(SvTYPE(superisa) == SVt_PVAV);
    GvMULTI_on(gv);
    sv_magic((SV*)superisa, (SV*)gv, PERL_MAGIC_isa, NULL, 0);
    av_push(superisa, newSVhek(CopSTASH(PL_curcop)
			       ? HvNAME_HEK(CopSTASH(PL_curcop)) : NULL));

    return stash;
}

CV *
Perl_gv_fetchmethod(pTHX_ HV *stash, const char *name)
{
    return gv_fetchmethod_flags(stash, name, 0);
}

/* Don't merge this yet, as it's likely to get a len parameter, and possibly
   even a U32 hash */
CV *
Perl_gv_fetchmethod_flags(pTHX_ HV *stash, const char *name, U32 flags)
{
    dVAR;
    register const char *nend;
    const char *nsplit = NULL;
    CV* cv;
    HV* ostash = stash;
    const char * const origname = name;
    SV *const error_report = hvTsv(stash);
    const U32 do_croak = flags & GV_CROAK;

    PERL_ARGS_ASSERT_GV_FETCHMETHOD;

    if (stash && SvTYPE(stash) < SVt_PVHV)
	stash = NULL;

    for (nend = name; *nend; nend++) {
	if (*nend == ':' && *(nend + 1) == ':')
	    nsplit = ++nend;
    }
    if (nsplit) {
	const char * const origname = name;
	name = nsplit + 1;
	--nsplit;
	if ((nsplit - origname) == 5 && strnEQ(origname, "SUPER", 5)) {
	    /* ->SUPER::method should really be looked up in original stash */
	    SV * const tmpstr = sv_2mortal(Perl_newSVpvf(aTHX_ "%s::SUPER",
						  CopSTASHPV(PL_curcop)));
	    /* __PACKAGE__::SUPER stash should be autovivified */
	    stash = gv_get_super_pkg(SvPVX_const(tmpstr), SvCUR(tmpstr));
	    DEBUG_o( Perl_deb(aTHX_ "Treating %s as %s::%s\n",
			 origname, HvNAME_get(stash), name) );
	}
	else {
            /* don't autovifify if ->NoSuchStash::method */
            stash = gv_stashpvn(origname, nsplit - origname, 0);

	    /* however, explicit calls to Pkg::SUPER::method may
	       happen, and may require autovivification to work */
	    if (!stash && (nsplit - origname) >= 7 &&
		strnEQ(nsplit - 7, "::SUPER", 7) &&
		gv_stashpvn(origname, nsplit - origname - 7, 0))
	      stash = gv_get_super_pkg(origname, nsplit - origname);
	}
	ostash = stash;
    }

    cv = gv_fetchmeth(stash, name, nend - name, 0);
    if (!cv) {
	if (strEQ(name,"import") || strEQ(name,"unimport"))
	    cv = (CV*)&PL_sv_yes;

	if (!cv && do_croak) {
	    /* Right now this is exclusively for the benefit of S_method_common
	       in pp_hot.c  */
	    if (stash) {
		Perl_croak(aTHX_
			   "Can't locate object method \"%s\" via package \"%.*s\"",
			   name, (int)HvNAMELEN_get(stash), HvNAME_get(stash));
	    }
	    else {
		STRLEN packlen;
		const char *packname;

		if (nsplit) {
		    packlen = nsplit - origname;
		    packname = origname;
		} else {
		    packname = SvPV_const(error_report, packlen);
		}

		Perl_croak(aTHX_
			   "Can't locate object method \"%s\" via package \"%.*s\""
			   " (perhaps you forgot to load \"%.*s\"?)",
			   name, (int)packlen, packname, (int)packlen, packname);
	    }
	}
    }

    return cv;
}

/*
=for apidoc gv_stashpv

Returns a pointer to the stash for a specified package.  Uses C<strlen> to
determine the length of C<name>, then calls C<gv_stashpvn()>.

=cut
*/

HV*
Perl_gv_stashpv(pTHX_ const char *name, I32 create)
{
    PERL_ARGS_ASSERT_GV_STASHPV;
    return gv_stashpvn(name, strlen(name), create);
}

/*
=for apidoc gv_stashpvn

Returns a pointer to the stash for a specified package.  The C<namelen>
parameter indicates the length of the C<name>, in bytes.  C<flags> is passed
to C<gv_fetchpvn_flags()>, so if set to C<GV_ADD> then the package will be
created if it does not already exist.  If the package does not exist and
C<flags> is 0 (or any other setting that does not create packages) then NULL
is returned.


=cut
*/

HV*
Perl_gv_stashpvn(pTHX_ const char *name, U32 namelen, I32 flags)
{
    char smallbuf[128];
    char *tmpbuf;
    HV *stash;
    GV *tmpgv;
    U32 tmplen = namelen + 2;

    PERL_ARGS_ASSERT_GV_STASHPVN;

    if (tmplen <= sizeof smallbuf)
	tmpbuf = smallbuf;
    else
	Newx(tmpbuf, tmplen, char);
    Copy(name, tmpbuf, namelen, char);
    tmpbuf[namelen]   = ':';
    tmpbuf[namelen+1] = ':';
    tmpgv = gv_fetchpvn_flags(tmpbuf, tmplen, flags, SVt_PVHV);
    if (tmpbuf != smallbuf)
	Safefree(tmpbuf);
    if (!tmpgv)
	return NULL;
    if (!GvHV(tmpgv))
	GvHV(tmpgv) = newHV();
    stash = GvHV(tmpgv);
    assert(SvTYPE(stash) == SVt_PVHV);
    if (!HvNAME_get(stash))
	hv_name_set(stash, name, namelen, 0);
    return stash;
}

/*
=for apidoc gv_stashsv

Returns a pointer to the stash for a specified package.  See C<gv_stashpvn>.

=cut
*/

HV*
Perl_gv_stashsv(pTHX_ SV *sv, I32 flags)
{
    STRLEN len;
    const char * const ptr = SvPV_const(sv,len);

    PERL_ARGS_ASSERT_GV_STASHSV;

    return gv_stashpvn(ptr, len, flags);
}


GV *
Perl_gv_fetchpv(pTHX_ const char *nambeg, I32 add, const svtype sv_type) {
    PERL_ARGS_ASSERT_GV_FETCHPV;
    return gv_fetchpvn_flags(nambeg, strlen(nambeg), add, sv_type);
}

GV *
Perl_gv_fetchsv(pTHX_ SV *name, I32 flags, const svtype sv_type) {
    STRLEN len;
    const char * const nambeg = SvPV_const(name, len);
    PERL_ARGS_ASSERT_GV_FETCHSV;
    return gv_fetchpvn_flags(nambeg, len, flags, sv_type);
}

GV *
Perl_gv_fetchpvn_flags(pTHX_ const char *nambeg, STRLEN full_len, I32 flags,
		       const svtype sv_type)
{
    dVAR;
    register const char *name = nambeg;
    register GV *gv = NULL;
    GV**gvp;
    I32 len;
    register const char *name_cursor;
    HV *stash = NULL;
    const I32 no_init = flags & (GV_NOADD_NOINIT | GV_NOINIT);
    const I32 no_expand = flags & GV_NOEXPAND;
    const I32 add = flags & ~GV_NOADD_MASK;
    const char *const name_end = nambeg + full_len;
    const char *const name_em1 = name_end - 1;

    PERL_ARGS_ASSERT_GV_FETCHPVN_FLAGS;

    if (flags & GV_NOTQUAL) {
	/* Caller promised that there is no stash, so we can skip the check. */
	len = full_len;
	goto no_stash;
    }

    if (full_len > 2 && *name == '*' && isALPHA(name[1])) {
	/* accidental stringify on a GV? */
	name++;
    }

    for (name_cursor = name; name_cursor < name_end; name_cursor++) {
	if ((*name_cursor == ':' && name_cursor < name_em1
	     && name_cursor[1] == ':'))
	{
	    if (!stash)
		stash = PL_defstash;
	    if (!stash || !SvREFCNT(stash)) /* symbol table under destruction */
		return NULL;

	    len = name_cursor - name;
	    if (len > 0) {
		char smallbuf[128];
		char *tmpbuf;

		if (len + 3 <= (I32)sizeof (smallbuf))
		    tmpbuf = smallbuf;
		else
		    Newx(tmpbuf, len+3, char);
		Copy(name, tmpbuf, len, char);
		tmpbuf[len++] = ':';
		tmpbuf[len++] = ':';
		tmpbuf[len] = '\0';
		gvp = (GV**)hv_fetch(stash,tmpbuf,len,add);
		gv = gvp ? *gvp : NULL;
		if (gv && gv != (const GV *)&PL_sv_undef) {
		    if (SvTYPE(gv) != SVt_PVGV)
			gv_init(gv, stash, tmpbuf, len, (add & GV_ADDMULTI));
		    else
			GvMULTI_on(gv);
		}
		if (tmpbuf != smallbuf)
		    Safefree(tmpbuf);
		if (!gv || gv == (const GV *)&PL_sv_undef)
		    return NULL;

		if (!(stash = GvHV(gv)))
		    stash = GvHV(gv) = newHV();
		if ( ! SvHVOK(stash) ) {
		    Perl_croak(aTHX_ "stash '%s' is not a hash but %s", tmpbuf, Ddesc((SV*)stash));
		}

		if (!HvNAME_get(stash))
		    hv_name_set(stash, nambeg, name_cursor - nambeg, 0);
	    }

	    name_cursor+=2;
	    name = name_cursor;
	    if (name == name_end)
		return gv;
	}
    }
    len = name_cursor - name;

    /* No stash in name, so see how we can default */

    if (!stash) {
    no_stash:
	if (len && isIDFIRST_lazy(name)) {
	    bool global = FALSE;

	    switch (len) {
	    case 1:
		if (*name == '_')
		    global = TRUE;
		break;
	    case 4:
		if (name[0] == 'A' && name[1] == 'R' && name[2] == 'G'
		    && name[3] == 'V')
		    global = TRUE;
		break;
	    case 5:
		if (name[0] == 'S' && name[1] == 'T' && name[2] == 'D'
		    && name[3] == 'I' && name[4] == 'N')
		    global = TRUE;
		break;
	    case 6:
		if ((name[0] == 'S' && name[1] == 'T' && name[2] == 'D')
		    &&((name[3] == 'O' && name[4] == 'U' && name[5] == 'T')
		       ||(name[3] == 'E' && name[4] == 'R' && name[5] == 'R')))
		    global = TRUE;
		break;
	    case 7:
		if (name[0] == 'A' && name[1] == 'R' && name[2] == 'G'
		    && name[3] == 'V' && name[4] == 'O' && name[5] == 'U'
		    && name[6] == 'T')
		    global = TRUE;
		break;
	    }

	    if (global)
		stash = PL_defstash;
	    else if (IN_PERL_COMPILETIME) {
		stash = PL_curstash;
		if (add &&
		    !(flags & GV_NOTQUAL) &&
		    sv_type != SVt_PVCV &&
		    sv_type != SVt_PVGV &&
		    sv_type != SVt_PVIO &&
		    !(len == 1 && sv_type == SVt_PV &&
		      (*name == 'a' || *name == 'b')) )
		{
		    gvp = (GV**)hv_fetch(stash,name,len,0);
		    if (!gvp ||
			*gvp == (const GV *)&PL_sv_undef ||
			SvTYPE(*gvp) != SVt_PVGV)
		    {
			stash = NULL;
		    }
		    else if ((sv_type == SVt_PV   && !GvIMPORTED_SV(*gvp)) ||
			     (sv_type == SVt_PVAV && !GvIMPORTED_AV(*gvp)) ||
			     (sv_type == SVt_PVHV && !GvIMPORTED_HV(*gvp)) )
		    {
			stash = NULL;
		    }
		}
	    }
	    else
		stash = CopSTASH(PL_curcop);
	}
	else
	    stash = PL_defstash;
    }

    /* By this point we should have a stash and a name */

    if (!stash) {
	if (add) {
	    SV * const err = Perl_mess(aTHX_
		 "Global symbol \"%s%s\" requires explicit package name",
		 (sv_type == SVt_PV ? "$"
		  : sv_type == SVt_PVAV ? "@"
		  : sv_type == SVt_PVHV ? "%"
		  : ""), name);
	    GV *gv;
	    yyerror(SvPVX_const(err));
	    gv = gv_fetchpvn_flags("<none>::", 8, GV_ADDMULTI, SVt_PVHV);
	    if(!gv) {
		/* symbol table under destruction */
		return NULL;
	    }	
	    stash = GvHV(gv);
	}
	else
	    return NULL;
    }

    if (!SvREFCNT(stash))	/* symbol table under destruction */
	return NULL;

    gvp = (GV**)hv_fetch(stash,name,len,add);
    if (!gvp || *gvp == (const GV *)&PL_sv_undef)
	return NULL;
    gv = *gvp;
    if (SvTYPE(gv) == SVt_PVGV) {
	if (add) {
	    GvMULTI_on(gv);
	    gv_init_sv(gv, sv_type);
	}
	return gv;
    } else if (no_init) {
	return gv;
    } else if (no_expand && SvROK(gv)) {
	return gv;
    }

    /* Adding a new symbol */

    if (add & GV_ADDWARN && ckWARN_d(WARN_INTERNAL))
	Perl_warner(aTHX_ packWARN(WARN_INTERNAL), "Had to create %s unexpectedly", nambeg);
    gv_init(gv, stash, name, len, add & GV_ADDMULTI);
    gv_init_sv(gv, sv_type);

    if (isALPHA(name[0]) && ! (isLEXWARN_on ? ckWARN(WARN_ONCE)
			                    : (PL_dowarn & G_WARN_ON ) ) )
        GvMULTI_on(gv) ;

    /* set up magic where warranted */
    if (len > 1) {
#ifndef EBCDIC
	if (*name >= 'a' ) {
	    NOOP;
	    /* Nothing else to do.
	       The compiler will probably turn the switch statement into a
	       branch table. Make sure we avoid even that small overhead for
	       the common case of lower case variable names.  */
	} else
#endif
	{
	    const char * const name2 = name + 1;
	    switch (*name) {
	    case 'A':
		if (strEQ(name2, "RGV")) {
		    IoFLAGS(GvIOn(gv)) |= IOf_ARGV|IOf_START;
		}
		else if (strEQ(name2, "RGVOUT")) {
		    GvMULTI_on(gv);
		}
		break;
	    case 'E':
		if (strnEQ(name2, "XPORT", 5))
		    GvMULTI_on(gv);
		break;
	    case 'I':
		if (strEQ(name2, "SA")) {
		    AV* const av = GvAVn(gv);
		    GvMULTI_on(gv);
		    sv_magic(MUTABLE_SV(av), MUTABLE_SV(gv), PERL_MAGIC_isa,
			     NULL, 0);
		    /* NOTE: No support for tied ISA */
		}
		break;
	    case 'V':
		if (strEQ(name2, "ERSION"))
		    GvMULTI_on(gv);
		break;
	    }
	}
    } else {
	/* Names of length 1.  (Or 0. But name is NUL terminated, so that will
	   be case '\0' in this switch statement (ie a default case)  */
	switch (*name) {

	case '_':
	case 'a':
	case 'b':
	    break;

	case ']':
	case '0':
	case '*':
	case '#':
	case '(':
	case ')':
	case '[':
	case '$':
	case '@':
	case '"':
	case ',':
	case '\\':
	case '/':
	case '+':
	case '-':
	case '>':
	case '<':
	case '!':
	case '|':
	case '&':
	case '`':
	case '\'':
	case '.':
	case ';':
	case '?':
	    Perl_croak(aTHX_ "Unknown magic variable '%c%s'",
		       sv_type == SVt_PVAV ? '@' : sv_type == SVt_PVHV ? '%' : '$',
		       name);
	}
    }
    return gv;
}

void
Perl_gv_fullname3(pTHX_ SV *sv, const GV *gv, const char *prefix)
{
    const char *name;
    STRLEN namelen;
    const HV * const hv = GvSTASH(gv);

    PERL_ARGS_ASSERT_GV_FULLNAME3;

    if (!hv) {
	SvPVOK_off(sv);
	return;
    }
    sv_setpv(sv, prefix ? prefix : "");

    name = HvNAME_get(hv);
    if (name) {
	namelen = HvNAMELEN_get(hv);
    } else {
	name = "__ANON__";
	namelen = 8;
    }

    sv_catpvn(sv,name,namelen);
    sv_catpvs(sv,"::");

    sv_catpvn(sv,GvNAME(gv),GvNAMELEN(gv));
}

void
Perl_gv_efullname3(pTHX_ SV *sv, const GV *gv, const char *prefix)
{
    const GV * const egv = GvEGV(gv);

    PERL_ARGS_ASSERT_GV_EFULLNAME3;

    gv_fullname3(sv, egv ? egv : gv, prefix);
}

void
Perl_gv_check(pTHX_ const HV *stash)
{
    dVAR;
    register I32 i;

    PERL_ARGS_ASSERT_GV_CHECK;

    if (!HvARRAY(stash))
	return;
    for (i = 0; i <= (I32) HvMAX(stash); i++) {
        const HE *entry;
	for (entry = HvARRAY(stash)[i]; entry; entry = HeNEXT(entry)) {
            register GV *gv;
            HV *hv;
	    if (HeKEY(entry)[HeKLEN(entry)-1] == ':' &&
		(gv = MUTABLE_GV(HeVAL(entry))) && isGV(gv) && (hv = GvHV(gv)))
	    {
		if (hv != PL_defstash && hv != stash)
		     gv_check(hv);              /* nested package */
	    }
	    else if (isALPHA(*HeKEY(entry))) {
		gv = (GV*)HeVAL(entry);
		if (SvTYPE(gv) != SVt_PVGV || GvMULTI(gv))
		    continue;
		Perl_warner(aTHX_ packWARN(WARN_ONCE),
			"Name \"%s::%s\" used only once: possible typo",
			HvNAME_get(stash), GvNAME(gv));
	    }
	}
    }
}

GV *
Perl_newGVgen(pTHX_ const char *pack)
{
    dVAR;

    PERL_ARGS_ASSERT_NEWGVGEN;

    return gv_fetchpv(Perl_form(aTHX_ "%s::_GEN_%ld", pack, (long)PL_gensym++),
		      GV_ADD, SVt_PVGV);
}

/* hopefully this is only called on local symbol table entries */

GP*
Perl_gp_ref(pTHX_ GP *gp)
{
    dVAR;
    if (!gp)
	return NULL;
    gp->gp_refcnt++;
    if (gp->gp_cv) {
	if (gp->gp_cvgen) {
	    /* If the GP they asked for a reference to contains
               a method cache entry, clear it first, so that we
               don't infect them with our cached entry */
	    CvREFCNT_dec(gp->gp_cv);
	    gp->gp_cv = NULL;
	    gp->gp_cvgen = 0;
	}
    }
    return gp;
}

void
Perl_gp_free(pTHX_ GV *gv)
{
    dVAR;
    GP* gp;

    if (!gv || !isGV_with_GP(gv) || !(gp = GvGP(gv)))
	return;
    if (gp->gp_refcnt == 0) {
	if (ckWARN_d(WARN_INTERNAL))
	    Perl_warner(aTHX_ packWARN(WARN_INTERNAL),
			"Attempt to free unreferenced glob pointers"
                        pTHX__FORMAT pTHX__VALUE);
        return;
    }
    if (--gp->gp_refcnt > 0) {
	if (gp->gp_egv == gv)
	    gp->gp_egv = 0;
	GvGP(gv) = 0;
        return;
    }

    SvREFCNT_dec(gp->gp_sv);
    AvREFCNT_dec(gp->gp_av);
    /* FIXME - another reference loop GV -> symtab -> GV ?
       Somehow gp->gp_hv can end up pointing at freed garbage.  */
    if (gp->gp_hv && SvTYPE(gp->gp_hv) == SVt_PVHV) {
	const char *hvname = HvNAME_get(gp->gp_hv);
	if (PL_stashcache && hvname)
	    (void)hv_delete(PL_stashcache, hvname, HvNAMELEN_get(gp->gp_hv),
		      G_DISCARD);
	HvREFCNT_dec(gp->gp_hv);
    }
    IoREFCNT_dec(gp->gp_io);
    CvREFCNT_dec(gp->gp_cv);

    Safefree(gp);
    GvGP(gv) = 0;
}

void
Perl_gp_tmprefcnt(pTHX_ GP *gp)
{
    dVAR;

    PERL_ARGS_ASSERT_GP_TMPREFCNT;

    SvTMPREFCNT_inc(gp->gp_sv);
    AvTMPREFCNT_inc(gp->gp_av);
    HvTMPREFCNT_inc(gp->gp_hv);
    IoTMPREFCNT_inc(gp->gp_io);
    CvTMPREFCNT_inc(gp->gp_cv);
}

/* Updates and caches the CV's */

void
Perl_gv_name_set(pTHX_ GV *gv, const char *name, U32 len, U32 flags)
{
    dVAR;
    U32 hash;

    PERL_ARGS_ASSERT_GV_NAME_SET;
    PERL_UNUSED_ARG(flags);

    if (len > I32_MAX)
	Perl_croak(aTHX_ "panic: gv name too long (%"UVuf")", (UV) len);

    if (!(flags & GV_ADD) && GvNAME_HEK(gv)) {
	unshare_hek(GvNAME_HEK(gv));
    }

    PERL_HASH(hash, name, len);
    GvNAME_HEK(gv) = share_hek(name, len, hash);
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
