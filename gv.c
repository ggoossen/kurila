/*    gv.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 *   'Mercy!' cried Gandalf.  'If the giving of information is to be the cure
 * of your inquisitiveness, I shall spend all the rest of my days answering
 * you.  What more do you want to know?'
 *   'The names of all the stars, and of all living things, and the whole
 * history of Middle-earth and Over-heaven and of the Sundering Seas,'
 * laughed Pippin.
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
#include "overload.c"

#ifdef PERL_DONT_CREATE_GVSV
GV *
Perl_gv_SVadd(pTHX_ GV *gv)
{
    PERL_ARGS_ASSERT_GV_SVADD;

    assert( SvTYPE((SV*)gv) == SVt_PVGV );
    if (!GvSV(gv))
	GvSV(gv) = newSV(0);
    return gv;
}
#endif

GV *
Perl_gv_AVadd(pTHX_ register GV *gv)
{
    PERL_ARGS_ASSERT_GV_AVADD;

    assert( SvTYPE((SV*)gv) == SVt_PVGV );
    if (!GvAV(gv))
	GvAV(gv) = newAV();
    return gv;
}

GV *
Perl_gv_HVadd(pTHX_ register GV *gv)
{
    PERL_ARGS_ASSERT_GV_HVADD;

    assert( SvTYPE((SV*)gv) == SVt_PVGV );
    if (!GvHV(gv))
	GvHV(gv) = newHV();
    return gv;
}

GV *
Perl_gv_IOadd(pTHX_ register GV *gv)
{
    dVAR;

    PERL_ARGS_ASSERT_GV_IOADD;

    if (!gv || SvTYPE((SV*)gv) != SVt_PVGV) {

        /*
         * if it walks like a dirhandle, then let's assume that
         * this is a dirhandle.
         */
	const char * const fh =
			 PL_op->op_type ==  OP_READDIR ||
                         PL_op->op_type ==  OP_TELLDIR ||
                         PL_op->op_type ==  OP_SEEKDIR ||
                         PL_op->op_type ==  OP_REWINDDIR ||
                         PL_op->op_type ==  OP_CLOSEDIR ?
                         "dirhandle" : "filehandle";
        Perl_croak(aTHX_ "Bad symbol for %s", fh);
    }

    if (!GvIOp(gv)) {
#ifdef GV_UNIQUE_CHECK
        if (GvUNIQUE(gv)) {
            Perl_croak(aTHX_ "Bad symbol for filehandle (GV is unique)");
        }
#endif
	GvIOp(gv) = newIO();
    }
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
#ifdef USE_ITHREADS
    const char *const file
	= (PL_curcop && CopFILE(PL_curcop)) ? CopFILE(PL_curcop) : "";
    const STRLEN len = strlen(file);
#else
    SV *const temp_sv = CopFILESV(PL_curcop);
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
#endif

    PERL_HASH(hash, file, len);

    Newxz(gp, 1, GP);

#ifndef PERL_DONT_CREATE_GVSV
    gp->gp_sv = newSV(0);
#endif

    gp->gp_line = PL_curcop ? CopLINE(PL_curcop) : 0;
    gp->gp_file_hek = share_hek(file, len, hash);
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
    char * const proto = (doproto && SvPOK(gv)) ? SvPVX(gv) : NULL;
    const STRLEN protolen = proto ? SvCUR(gv) : 0;
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
	    SvCUR_set(gv, 0);
	sv_upgrade((SV*)gv, SVt_PVGV);
    }
    if (SvLEN(gv)) {
	if (proto) {
	    SvPV_set(gv, NULL);
	    SvLEN_set(gv, 0);
	    SvPOK_off(gv);
	} else
	    Safefree(SvPVX_mutable(gv));
    }
    SvIOK_off(gv);
    isGV_with_GP_on(gv);

    GvGP(gv) = Perl_newGP(aTHX_ gv);
    GvSTASH(gv) = stash;
    if (stash)
	Perl_sv_add_backref(aTHX_ (SV*)stash, (SV*)gv);
    gv_name_set(gv, name, len, GV_ADD);
    if (multi || doproto)              /* doproto means it _was_ mentioned */
	GvMULTI_on(gv);
    if (doproto) {			/* Replicate part of newSUB here. */
	ENTER;
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
	    (void) start_subparse(0);	/* Create empty CV in compcv. */
	    GvCV(gv) = (CV*)SvREFCNT_inc((SV*)PL_compcv);
	}
	LEAVE;

        mro_method_changed_in(GvSTASH(gv)); /* sub Foo::bar($) { (shift) } sub ASDF::baz($); *ASDF::baz = \&Foo::bar */
	assert(SvTYPE(GvCV(gv)) == SVt_PVCV);
	CvGV(GvCV(gv)) = gv;
	CvFILE_set_from_cop(GvCV(gv), PL_curcop);
	if (proto) {
	    sv_usepvn_flags((SV*)GvCV(gv), proto, protolen,
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

GV *
Perl_gv_fetchmeth(pTHX_ HV *stash, const char *name, STRLEN len, I32 level)
{
    dVAR;
    GV** gvp;
    AV* linear_av;
    SV** linear_svp;
    SV* linear_sv;
    HV* cstash;
    GV* candidate = NULL;
    CV* cand_cv = NULL;
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
	    return 0;
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
        topgv = *gvp;
        assert(topgv);
        if (SvTYPE(topgv) != SVt_PVGV)
            gv_init(topgv, stash, name, len, TRUE);
        if ((cand_cv = GvCV(topgv))) {
            /* If genuine method or valid cache entry, use it */
            if (!GvCVGEN(topgv) || GvCVGEN(topgv) == topgen_cmp) {
                return topgv;
            }
            else {
                /* stale cache entry, junk it and move on */
	        SvREFCNT_dec(cand_cv);
	        GvCV(topgv) = cand_cv = NULL;
	        GvCVGEN(topgv) = 0;
            }
        }
        else if (GvCVGEN(topgv) == topgen_cmp) {
            /* cache indicates no such method definitively */
            return 0;
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
        if (SvTYPE(candidate) != SVt_PVGV) gv_init(candidate, cstash, name, len, TRUE);
        if (SvTYPE(candidate) == SVt_PVGV && (cand_cv = GvCV(candidate)) && !GvCVGEN(candidate)) {
            /*
             * Found real method, cache method in topgv if:
             *  1. topgv has no synonyms (else inheritance crosses wires)
             *  2. method isn't a stub (else AUTOLOAD fails spectacularly)
             */
            if (topgv && (GvREFCNT(topgv) == 1) && (CvROOT(cand_cv) || CvXSUB(cand_cv))) {
                  if ((old_cv = GvCV(topgv))) SvREFCNT_dec(old_cv);
                  SvREFCNT_inc_simple_void_NN(cand_cv);
                  GvCV(topgv) = cand_cv;
                  GvCVGEN(topgv) = topgen_cmp;
            }
	    return candidate;
        }
    }

    /* Check UNIVERSAL without caching */
    if(level == 0 || level == -1) {
        candidate = gv_fetchmeth(NULL, name, len, 1);
        if(candidate) {
            cand_cv = GvCV(candidate);
            if (topgv && (GvREFCNT(topgv) == 1) && (CvROOT(cand_cv) || CvXSUB(cand_cv))) {
                  if ((old_cv = GvCV(topgv))) SvREFCNT_dec(old_cv);
                  SvREFCNT_inc_simple_void_NN(cand_cv);
                  GvCV(topgv) = cand_cv;
                  GvCVGEN(topgv) = topgen_cmp;
            }
            return candidate;
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
#ifdef USE_ITHREADS
    av_push(superisa, newSVpv(CopSTASHPV(PL_curcop), 0));
#else
    av_push(superisa, newSVhek(CopSTASH(PL_curcop)
			       ? HvNAME_HEK(CopSTASH(PL_curcop)) : NULL));
#endif

    return stash;
}

/* FIXME. If changing this function note the comment in pp_hot's
   S_method_common:

   This code tries to figure out just what went wrong with
   gv_fetchmethod.  It therefore needs to duplicate a lot of
   the internals of that function. ...

   I'd guess that with one more flag bit that could all be moved inside
   here.
*/

GV *
Perl_gv_fetchmethod(pTHX_ HV *stash, const char *name)
{
    dVAR;
    register const char *nend;
    const char *nsplit = NULL;
    GV* gv;
    HV* ostash = stash;

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

    gv = gv_fetchmeth(stash, name, nend - name, 0);
    if (!gv) {
	if (strEQ(name,"import") || strEQ(name,"unimport"))
	    gv = (GV*)&PL_sv_yes;
    }

    return gv;
}

/* require_tie_mod() internal routine for requiring a module
 * that implements the logic of automatical ties like %! and %-
 *
 * The "gv" parameter should be the glob.
 * "varpv" holds the name of the var, used for error messages.
 * "namesv" holds the module name. Its refcount will be decremented.
 * "methpv" holds the method name to test for to check that things
 *   are working reasonably close to as expected.
 * "flags": if flag & 1 then save the scalar before loading.
 * For the protection of $! to work (it is set by this routine)
 * the sv slot must already be magicalized.
 */
STATIC HV*
S_require_tie_mod(pTHX_ GV *gv, const char *varpv, SV* namesv, const char *methpv,const U32 flags)
{
    dVAR;
    HV* stash = gv_stashsv(namesv, 0);

    PERL_ARGS_ASSERT_REQUIRE_TIE_MOD;

    if (!stash || !(gv_fetchmethod(stash, methpv))) {
	SV *module = newSVsv(namesv);
	char varname = *varpv; /* varpv might be clobbered by load_module,
				  so save it. For the moment it's always
				  a single char. */
	dSP;
	ENTER;
	if ( flags & 1 )
	    save_scalar(gv);
	PUSHSTACKi(PERLSI_MAGIC);
	Perl_load_module(aTHX_ PERL_LOADMOD_NOIMPORT, module, NULL);
	POPSTACK;
	LEAVE;
	SPAGAIN;
	stash = gv_stashsv(namesv, 0);
	if (!stash)
	    Perl_croak(aTHX_ "panic: Can't use %%%c because %"SVf" is not available",
		    varname, SVfARG(namesv));
	else if (!gv_fetchmethod(stash, methpv))
	    Perl_croak(aTHX_ "panic: Can't use %%%c because %"SVf" does not support method %s",
		    varname, SVfARG(namesv), methpv);
    }
    SvREFCNT_dec(namesv);
    return stash;
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

    PERL_ARGS_ASSERT_GV_STASHPVN;

    if (namelen + 2 <= sizeof smallbuf)
	tmpbuf = smallbuf;
    else
	Newx(tmpbuf, namelen + 2, char);
    Copy(name,tmpbuf,namelen,char);
    tmpbuf[namelen++] = ':';
    tmpbuf[namelen++] = ':';
    tmpgv = gv_fetchpvn_flags(tmpbuf, namelen, flags, SVt_PVHV);
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

		if (len + 2 <= (I32)sizeof (smallbuf))
		    tmpbuf = smallbuf;
		else
		    Newx(tmpbuf, len+3, char);
		Copy(name, tmpbuf, len, char);
		tmpbuf[len++] = ':';
		tmpbuf[len++] = ':';
		tmpbuf[len] = '\0';
		gvp = (GV**)hv_fetch(stash,tmpbuf,len,add);
		gv = gvp ? *gvp : NULL;
		if (gv && gv != (GV*)&PL_sv_undef) {
		    if (SvTYPE(gv) != SVt_PVGV)
			gv_init(gv, stash, tmpbuf, len, (add & GV_ADDMULTI));
		    else
			GvMULTI_on(gv);
		}
		if (tmpbuf != smallbuf)
		    Safefree(tmpbuf);
		if (!gv || gv == (GV*)&PL_sv_undef)
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
	    case 3:
		if ((name[0] == 'I' && name[1] == 'N' && name[2] == 'C')
		    || (name[0] == 'E' && name[1] == 'N' && name[2] == 'V')
		    || (name[0] == 'S' && name[1] == 'I' && name[2] == 'G'))
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
			*gvp == (GV*)&PL_sv_undef ||
			SvTYPE(*gvp) != SVt_PVGV)
		    {
			stash = NULL;
		    }
		    else if ((sv_type == SVt_PV   && !GvIMPORTED_SV(*gvp)) ||
			     (sv_type == SVt_PVAV && !GvIMPORTED_AV(*gvp)) ||
			     (sv_type == SVt_PVHV && !GvIMPORTED_HV(*gvp)) )
		    {
			Perl_warn(aTHX_ "Variable \"%c%s\" is not imported",
			    sv_type == SVt_PVAV ? '@' :
			    sv_type == SVt_PVHV ? '%' : '$',
			    name);
			if (GvCVu(*gvp))
			    Perl_warn(aTHX_ "\t(Did you mean &%s instead?)\n", name);
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
    if (!gvp || *gvp == (GV*)&PL_sv_undef)
	return NULL;
    gv = *gvp;
    if (SvTYPE(gv) == SVt_PVGV) {
	if (add) {
	    GvMULTI_on(gv);
	    gv_init_sv(gv, sv_type);
	    if (len == 1 && (sv_type == SVt_PVHV || sv_type == SVt_PVGV)) {
	        if (*name == '!')
		    require_tie_mod(gv, "!", newSVpvs("Errno"), "TIEHASH", 1);
		else if (*name == '-' || *name == '+')
		    require_tie_mod(gv, name, newSVpvs("Tie::Hash::NamedCapture"), "TIEHASH", 0);
	    }
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
		    sv_magic((SV*)av, (SV*)gv, PERL_MAGIC_isa, NULL, 0);
		    /* NOTE: No support for tied ISA */
		}
		break;
	    case 'O':
		if (strEQ(name2, "VERLOAD")) {
		    HV* const hv = GvHVn(gv);
		    GvMULTI_on(gv);
		    hv_magic(hv, NULL, PERL_MAGIC_overload);
		}
		break;
	    case 'S':
		if (strEQ(name2, "IG")) {
		    HV *hv;
		    I32 i;
		    if (!PL_psig_ptr) {
			Newxz(PL_psig_ptr,  SIG_SIZE, SV*);
			Newxz(PL_psig_name, SIG_SIZE, SV*);
			Newxz(PL_psig_pend, SIG_SIZE, int);
		    }
		    GvMULTI_on(gv);
		    hv = GvHVn(gv);
		    hv_magic(hv, NULL, PERL_MAGIC_sig);
		    for (i = 1; i < SIG_SIZE; i++) {
			SV * const * const init = hv_fetch(hv, PL_sig_name[i], strlen(PL_sig_name[i]), 1);
			if (init)
			    sv_setsv(*init, &PL_sv_undef);
			PL_psig_ptr[i] = 0;
			PL_psig_name[i] = 0;
			PL_psig_pend[i] = 0;
		    }
		}
		break;
	    case 'V':
		if (strEQ(name2, "ERSION"))
		    GvMULTI_on(gv);
		break;
	    case '^':
		if (len > 2) {
		    switch (*name2) {
		    case 'C':        /* $^CHILD_ERROR_NATIVE */
			if (strEQ(name2, "CHILD_ERROR_NATIVE"))
			    goto magicalize;
			break;
		    case 'D':        /* $^DIE_HOOK */
			if (strEQ(name2, "DIE_HOOK"))
			    goto magicalize;
			break;
		    case 'E':	/* $^ENCODING  $^EGID */
			if (strEQ(name2, "ENCODING"))
			    goto magicalize;
			if (strEQ(name2, "EGID"))
			    goto magicalize;
			break;
		    case 'G':   /* $^GID */
			if (strEQ(name2, "GID"))
			    goto magicalize;
			break;
		    case 'M':        /* $^MATCH */
			if (strEQ(name2, "MATCH"))
			    goto magicalize;
		    case 'O':	/* $^OPEN */
			if (strEQ(name2, "OPEN"))
			    goto magicalize;
			break;
		    case 'P':        /* $^PREMATCH  $^POSTMATCH */
			if (strEQ(name2, "PREMATCH") || strEQ(name2, "POSTMATCH"))
			    goto magicalize;  
			break;
		    case 'R':        /* $^RE_TRIE_MAXBUF */
			if (strEQ(name2, "RE_TRIE_MAXBUF") || strEQ(name2, "RE_DEBUG_FLAGS"))
			    goto no_magicalize;
			break;
		    case 'T':	/* $^TAINT */
			if (strEQ(name2, "TAINT"))
			    goto ro_magicalize;
			break;
		    case 'U':	/* $^UNICODE, $^UTF8LOCALE, $^UTF8CACHE */
			if (strEQ(name2, "UNICODE"))
			    goto ro_magicalize;
			if (strEQ(name2, "UTF8LOCALE"))
			    goto ro_magicalize;
			if (strEQ(name2, "UTF8CACHE"))
			    goto magicalize;
			break;
		    case 'W':	/* $^WARNING_BITS, $^WARN_HOOK */
			if (strEQ(name2, "WARN_HOOK"))
			    goto magicalize;
			if (strEQ(name2, "WARNING_BITS"))
			    goto magicalize;
			break;
		    }
		    Perl_croak(aTHX_ "Unknown magic variable '$%s'", name);
		} else {
		    switch (*name2) {
		    case 'H':	/* $^H */
		    {
			HV *const hv = GvHVn(gv);
			hv_magic(hv, NULL, PERL_MAGIC_hints);
			goto magicalize;
		    }
		    case 'S':	/* $^S */
			goto ro_magicalize;
		    case 'C':	/* $^C */
		    case 'D':	/* $^D */
		    case 'E':	/* $^E */
		    case 'F':	/* $^F */
		    case 'I':	/* $^I */
		    case 'N':	/* $^N */
		    case 'O':	/* $^O */
		    case 'P':	/* $^P */
		    case 'T':	/* $^T */
		    case 'W':	/* $^W */
			goto magicalize;
		    case 'M':   /* $^M */
		    case 'R':   /* $^R */
		    case 'X':   /* $^X */
			goto no_magicalize;
		    case 'V':	/* $^V */
		    {
			SV * const sv = GvSVn(gv);
			sv_setsv(sv, PL_patchlevel);
			goto no_magicalize;
		    }
		    }
		    Perl_croak(aTHX_ "Unknown magic variable '%c%s'",
			       sv_type == SVt_PVAV ? '@' : sv_type == SVt_PVHV ? '%' : '$',
			       name);
		}
	    case '1':
	    case '2':
	    case '3':
	    case '4':
	    case '5':
	    case '6':
	    case '7':
	    case '8':
	    case '9':
	    {
		/* Ensures that we have an all-digit variable, ${"1foo"} fails
		   this test  */
		/* This snippet is taken from is_gv_magical */
		const char *end = name + len;
		while (--end > name) {
		    if (!isDIGIT(*end))	return gv;
		}
		goto magicalize;
	    }
	    }
	}
    } else {
	/* Names of length 1.  (Or 0. But name is NUL terminated, so that will
	   be case '\0' in this switch statement (ie a default case)  */
	switch (*name) {
	case ':':
	    sv_setpv(GvSVn(gv),PL_chopset);
	    goto magicalize;

	case '?':
#ifdef COMPLEX_STATUS
	    SvUPGRADE(GvSVn(gv), SVt_PVLV);
#endif
	    goto magicalize;

	case '!':
	    GvMULTI_on(gv);
	    /* If %! has been used, automatically load Errno.pm. */

	    sv_magic(GvSVn(gv), (SV*)gv, PERL_MAGIC_sv, name, len);

            /* magicalization must be done before require_tie_mod is called */
	    if (sv_type == SVt_PVHV || sv_type == SVt_PVGV)
		require_tie_mod(gv, "!", newSVpvs("Errno"), "TIEHASH", 1);

	    break;
	case '-':
	case '+':
	GvMULTI_on(gv); /* no used once warnings here */
        {
            AV* const av = GvAVn(gv);
	    SV* const avc = (*name == '+') ? (SV*)av : NULL;

	    sv_magic((SV*)av, avc, PERL_MAGIC_regdata, NULL, 0);
            sv_magic(GvSVn(gv), (SV*)gv, PERL_MAGIC_sv, name, len);
            if (avc)
                SvREADONLY_on(GvSVn(gv));
            SvREADONLY_on(av);

            if (sv_type == SVt_PVHV || sv_type == SVt_PVGV)
                require_tie_mod(gv, name, newSVpvs("Tie::Hash::NamedCapture"), "TIEHASH", 0);

            break;
	}
	case '|':
	    sv_setiv(GvSVn(gv), (IV)(IoFLAGS(GvIOp(PL_defoutgv)) & IOf_FLUSH) != 0);
	    goto magicalize;

	ro_magicalize:
	    SvREADONLY_on(GvSVn(gv));
	    /* FALL THROUGH */
	case '1':
	case '2':
	case '3':
	case '4':
	case '5':
	case '6':
	case '7':
	case '8':
	case '9':
	case '<':
	case '>':
	case ',':
	case '\\':
	case '/':
	magicalize:
	    sv_magic(GvSVn(gv), (SV*)gv, PERL_MAGIC_sv, name, len);

	case '$':
	case '@':
	case '"':
	case '0':
	case '_':
	case 'a':
	case 'b':
	no_magicalize:
	    break;

	case ';':
	    sv_setpvn(GvSVn(gv),"\034",1);
	    break;
	case ']':
	    Perl_croak(aTHX_ "$] is obsolete. Use $^V or $kurila::VERSION");
	case '*':
	case '#':
	case '(':
	case ')':
	case '[':
	case '&':
	case '`':
	case '\'':
	case '.':
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

IO *
Perl_newIO(pTHX)
{
    dVAR;
    GV *iogv;
    IO * const io = (IO*)newSV_type(SVt_PVIO);
    /* This used to read SvREFCNT(io) = 1;
       It's not clear why the reference count needed an explicit reset. NWC
    */
    assert (SvREFCNT(io) == 1);
    SvOBJECT_on(io);
    /* Clear the stashcache because a new IO could overrule a package name */
    hv_clear(PL_stashcache);
    iogv = gv_fetchpvs("FileHandle::", 0, SVt_PVHV);
    /* unless exists($main::{FileHandle}) and defined(%main::FileHandle::) */
    if (!(iogv && GvHV(iogv) && HvARRAY(GvHV(iogv))))
	iogv = gv_fetchpvs("IO::Handle::", GV_ADD, SVt_PVHV);
    SvSTASH_set(io, (HV*)SvREFCNT_inc(GvHV(iogv)));
    return io;
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
		(gv = (GV*)HeVAL(entry)) && isGV(gv) && (hv = GvHV(gv)))
	    {
		if (hv != PL_defstash && hv != stash)
		     gv_check(hv);              /* nested package */
	    }
	    else if (isALPHA(*HeKEY(entry))) {
                const char *file;
		gv = (GV*)HeVAL(entry);
		if (SvTYPE(gv) != SVt_PVGV || GvMULTI(gv))
		    continue;
		file = GvFILE(gv);
		CopLINE_set(PL_curcop, GvLINE(gv));
#ifdef USE_ITHREADS
		CopFILE(PL_curcop) = (char *)file;	/* set for warning */
#else
		CopFILEGV(PL_curcop)
		    = gv_fetchfile_flags(file, HEK_LEN(GvFILE_HEK(gv)), 0);
#endif
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
	    SvREFCNT_dec(gp->gp_cv);
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

    if (gp->gp_file_hek)
	unshare_hek(gp->gp_file_hek);
    SvREFCNT_dec(gp->gp_sv);
    SvREFCNT_dec(gp->gp_av);
    /* FIXME - another reference loop GV -> symtab -> GV ?
       Somehow gp->gp_hv can end up pointing at freed garbage.  */
    if (gp->gp_hv && SvTYPE(gp->gp_hv) == SVt_PVHV) {
	const char *hvname = HvNAME_get(gp->gp_hv);
	if (PL_stashcache && hvname)
	    (void)hv_delete(PL_stashcache, hvname, HvNAMELEN_get(gp->gp_hv),
		      G_DISCARD);
	SvREFCNT_dec(gp->gp_hv);
    }
    SvREFCNT_dec(gp->gp_io);
    SvREFCNT_dec(gp->gp_cv);

    Safefree(gp);
    GvGP(gv) = 0;
}

void
Perl_gp_tmprefcnt(pTHX_ GV *gv)
{
    dVAR;
    GP* gp;

    if (!gv || !isGV_with_GP(gv) || !(gp = GvGP(gv)))
	return;

    SvTMPREFCNT_inc(gp->gp_sv);
    SvTMPREFCNT_inc(gp->gp_av);
    SvTMPREFCNT_inc(gp->gp_hv);
    SvTMPREFCNT_inc(gp->gp_io);
    SvTMPREFCNT_inc(gp->gp_cv);
}

int
Perl_magic_freeovrld(pTHX_ SV *sv, MAGIC *mg)
{
    AMT * const amtp = (AMT*)mg->mg_ptr;
    PERL_UNUSED_ARG(sv);

    PERL_ARGS_ASSERT_MAGIC_FREEOVRLD;

    if (amtp && AMT_AMAGIC(amtp)) {
	int i;
	for (i = 1; i < NofAMmeth; i++) {
	    CV * const cv = amtp->table[i];
	    if (cv) {
		SvREFCNT_dec((SV *) cv);
		amtp->table[i] = NULL;
	    }
	}
    }
 return 0;
}

/* Updates and caches the CV's */

bool
Perl_Gv_AMupdate(pTHX_ HV *stash)
{
  dVAR;
  MAGIC* const mg = mg_find((SV*)stash, PERL_MAGIC_overload_table);
  AMT amt;
  const struct mro_meta* stash_meta = HvMROMETA(stash);
  U32 newgen;

  PERL_ARGS_ASSERT_GV_AMUPDATE;

  newgen = PL_sub_generation + stash_meta->pkg_gen + stash_meta->cache_gen;
  if (mg) {
      const AMT * const amtp = (AMT*)mg->mg_ptr;
      if (amtp->was_ok_am == PL_amagic_generation
	  && amtp->was_ok_sub == newgen) {
	  return (bool)AMT_OVERLOADED(amtp);
      }
      sv_unmagic((SV*)stash, PERL_MAGIC_overload_table);
  }

  DEBUG_o( Perl_deb(aTHX_ "Recalcing overload magic in package %s\n",HvNAME_get(stash)) );

  Zero(&amt,1,AMT);
  amt.was_ok_am = PL_amagic_generation;
  amt.was_ok_sub = newgen;
  amt.fallback = AMGfallNO;
  amt.flags = 0;

  {
    int filled = 0, have_ovl = 0;
    int i, lim = 1;

    /* Work with "fallback" key, which we assume to be first in PL_AMG_names */

    /* Try to find via inheritance. */
    GV *gv = gv_fetchmeth(stash, PL_AMG_names[0], 2, -1);
    SV * const sv = gv ? GvSV(gv) : NULL;
    CV* cv;

    if (!gv)
	lim = DESTROY_amg;		/* Skip overloading entries. */
#ifdef PERL_DONT_CREATE_GVSV
    else if (!sv) {
	NOOP;   /* Equivalent to !SvTRUE and !SvOK  */
    }
#endif
    else if (SvTRUE(sv))
	amt.fallback=AMGfallYES;
    else if (SvOK(sv))
	amt.fallback=AMGfallNEVER;

    for (i = 1; i < lim; i++)
	amt.table[i] = NULL;
    for (; i < NofAMmeth; i++) {
	const char * const cooky = PL_AMG_names[i];
	/* Human-readable form, for debugging: */
	const char * const cp = (i >= DESTROY_amg ? cooky : AMG_id2name(i));
	const STRLEN l = strlen(cooky);

	DEBUG_o( Perl_deb(aTHX_ "Checking overloading of \"%s\" in package \"%.256s\"\n",
		     cp, HvNAME_get(stash)) );
	/* don't fill the cache while looking up!
	   Creation of inheritance stubs in intermediate packages may
	   conflict with the logic of runtime method substitution.
	   Indeed, for inheritance A -> B -> C, if C overloads "+0",
	   then we could have created stubs for "(+0" in A and C too.
	   But if B overloads "bool", we may want to use it for
	   numifying instead of C's "+0". */
	if (i >= DESTROY_amg)
	    gv = Perl_gv_fetchmeth(aTHX_ stash, cooky, l, 0);
	else				/* Autoload taken care of below */
	    gv = Perl_gv_fetchmeth(aTHX_ stash, cooky, l, -1);
        cv = 0;
        if (gv && (cv = GvCV(gv))) {
	    DEBUG_o( Perl_deb(aTHX_ "Overloading \"%s\" in package \"%.256s\" via \"%.256s::%.256s\"\n",
			 cp, HvNAME_get(stash), HvNAME_get(GvSTASH(CvGV(cv))),
			 GvNAME(CvGV(cv))) );
	    filled = 1;
	    if (i < DESTROY_amg)
		have_ovl = 1;
	}
	amt.table[i]=(CV*)SvREFCNT_inc_simple(cv);
    }
    if (filled) {
      AMT_AMAGIC_on(&amt);
      if (have_ovl)
	  AMT_OVERLOADED_on(&amt);
      sv_magic((SV*)stash, 0, PERL_MAGIC_overload_table,
						(char*)&amt, sizeof(AMT));
      return have_ovl;
    }
  }
  /* Here we have no table: */
  /* no_table: */
  AMT_AMAGIC_off(&amt);
  sv_magic((SV*)stash, 0, PERL_MAGIC_overload_table,
						(char*)&amt, sizeof(AMTS));
  return FALSE;
}


CV*
Perl_gv_handler(pTHX_ HV *stash, I32 id)
{
    dVAR;
    MAGIC *mg;
    AMT *amtp;
    U32 newgen;
    struct mro_meta* stash_meta;

    if (!stash || !HvNAME_get(stash))
        return NULL;

    stash_meta = HvMROMETA(stash);
    newgen = PL_sub_generation + stash_meta->pkg_gen + stash_meta->cache_gen;

    mg = mg_find((SV*)stash, PERL_MAGIC_overload_table);
    if (!mg) {
      do_update:
	Gv_AMupdate(stash);
	mg = mg_find((SV*)stash, PERL_MAGIC_overload_table);
    }
    assert(mg);
    amtp = (AMT*)mg->mg_ptr;
    if ( amtp->was_ok_am != PL_amagic_generation
	 || amtp->was_ok_sub != newgen )
	goto do_update;
    if (AMT_AMAGIC(amtp)) {
	CV * const ret = amtp->table[id];
	return ret;
    }

    return NULL;
}


SV*
Perl_amagic_call(pTHX_ SV *left, SV *right, int method, int flags)
{
  dVAR;
  MAGIC *mg;
  CV *cv=NULL;
  CV **cvp=NULL, **ocvp=NULL;
  AMT *amtp=NULL, *oamtp=NULL;
  int off = 0, off1, lr = 0, notfound = 0;
  int postpr = 0, force_cpy = 0;
  int assign = AMGf_assign & flags;
  const int assignshift = assign ? 1 : 0;
#ifdef DEBUGGING
  int fl=0;
#endif
  HV* stash=NULL;

  PERL_ARGS_ASSERT_AMAGIC_CALL;

  if (!(AMGf_noleft & flags) && SvAMAGIC(left)
      && (stash = SvSTASH(SvRV(left)))
      && (mg = mg_find((SV*)stash, PERL_MAGIC_overload_table))
      && (ocvp = cvp = (AMT_AMAGIC((AMT*)mg->mg_ptr)
			? (oamtp = amtp = (AMT*)mg->mg_ptr)->table
			: NULL))
      && ((cv = cvp[off=method+assignshift])
	  || (assign && amtp->fallback > AMGfallNEVER && /* fallback to
						          * usual method */
		  (
#ifdef DEBUGGING
		   fl = 1,
#endif
		   cv = cvp[off=method])))) {
    lr = -1;			/* Call method for left argument */
  } else {
    if (cvp && amtp->fallback > AMGfallNEVER && flags & AMGf_unary) {
      int logic;

      /* look for substituted methods */
      /* In all the covered cases we should be called with assign==0. */
	 switch (method) {
	 case inc_amg:
	   force_cpy = 1;
	   if ((cv = cvp[off=add_ass_amg])
	       || ((cv = cvp[off = add_amg]) && (force_cpy = 0, postpr = 1))) {
	     right = &PL_sv_yes; lr = -1; assign = 1;
	   }
	   break;
	 case dec_amg:
	   force_cpy = 1;
	   if ((cv = cvp[off = subtr_ass_amg])
	       || ((cv = cvp[off = subtr_amg]) && (force_cpy = 0, postpr=1))) {
	     right = &PL_sv_yes; lr = -1; assign = 1;
	   }
	   break;
	 case bool__amg:
	   (void)((cv = cvp[off=numer_amg]) || (cv = cvp[off=string_amg]));
	   break;
	 case numer_amg:
	   (void)((cv = cvp[off=string_amg]) || (cv = cvp[off=bool__amg]));
	   break;
	 case string_amg:
	   (void)((cv = cvp[off=numer_amg]) || (cv = cvp[off=bool__amg]));
	   break;
         case not_amg:
           (void)((cv = cvp[off=bool__amg])
                  || (cv = cvp[off=numer_amg])
                  || (cv = cvp[off=string_amg]));
           postpr = 1;
           break;
	 case copy_amg:
	   {
	     /*
		  * SV* ref causes confusion with the interpreter variable of
		  * the same name
		  */
	     SV* const tmpRef=SvRV(left);
	     if (!SvROK(tmpRef) && SvTYPE(tmpRef) <= SVt_PVMG) {
		/*
		 * Just to be extra cautious.  Maybe in some
		 * additional cases sv_setsv is safe, too.
		 */
		SV* const newref = newSVsv(tmpRef);
		SvOBJECT_on(newref);
		/* As a bit of a source compatibility hack, SvAMAGIC() and
		   friends dereference an RV, to behave the same was as when
		   overloading was stored on the reference, not the referant.
		   Hence we can't use SvAMAGIC_on()
		*/
		SvFLAGS(newref) |= SVf_AMAGIC;
		SvSTASH_set(newref, (HV*)SvREFCNT_inc(SvSTASH(tmpRef)));
		return newref;
	     }
	   }
	   break;
	 case abs_amg:
	   if ((cvp[off1=lt_amg] || cvp[off1=ncmp_amg])
	       && ((cv = cvp[off=neg_amg]) || (cv = cvp[off=subtr_amg]))) {
	     SV* const nullsv=sv_2mortal(newSViv(0));
	     if (off1==lt_amg) {
	       SV* const lessp = amagic_call(left,nullsv,
				       lt_amg,AMGf_noright);
	       logic = SvTRUE(lessp);
	     } else {
	       SV* const lessp = amagic_call(left,nullsv,
				       ncmp_amg,AMGf_noright);
	       logic = (SvNV(lessp) < 0);
	     }
	     if (logic) {
	       if (off==subtr_amg) {
		 right = left;
		 left = nullsv;
		 lr = 1;
	       }
	     } else {
	       return left;
	     }
	   }
	   break;
	 case neg_amg:
	   if ((cv = cvp[off=subtr_amg])) {
	     right = left;
	     left = sv_2mortal(newSViv(0));
	     lr = 1;
	   }
	   break;
	 case int_amg:
	 case iter_amg:			/* XXXX Eventually should do to_gv. */
	     /* FAIL safe */
	     return NULL;	/* Delegate operation to standard mechanisms. */
	     break;
	 case to_sv_amg:
	 case to_av_amg:
	 case to_hv_amg:
	 case to_gv_amg:
	 case to_cv_amg:
	     /* FAIL safe */
	     return left;	/* Delegate operation to standard mechanisms. */
	     break;
	 default:
	   goto not_found;
	 }
	 if (!cv) goto not_found;
    } else if (!(AMGf_noright & flags) && SvAMAGIC(right)
	       && (stash = SvSTASH(SvRV(right)))
	       && (mg = mg_find((SV*)stash, PERL_MAGIC_overload_table))
	       && (cvp = (AMT_AMAGIC((AMT*)mg->mg_ptr)
			  ? (amtp = (AMT*)mg->mg_ptr)->table
			  : NULL))
	       && (cv = cvp[off=method])) { /* Method for right
					     * argument found */
      lr=1;
    } else if (((ocvp && oamtp->fallback > AMGfallNEVER
		 && (cvp=ocvp) && (lr = -1))
		|| (cvp && amtp->fallback > AMGfallNEVER && (lr=1)))
	       && !(flags & AMGf_unary)) {
				/* We look for substitution for
				 * comparison operations and
				 * concatenation */
      if (method==concat_amg || method==concat_ass_amg
	  || method==repeat_amg || method==repeat_ass_amg) {
	return NULL;		/* Delegate operation to string conversion */
      }
      off = -1;
      switch (method) {
	 case lt_amg:
	 case le_amg:
	 case gt_amg:
	 case ge_amg:
	 case eq_amg:
	 case ne_amg:
	   postpr = 1; off=ncmp_amg; break;
	 case seq_amg:
	 case sne_amg:
	   postpr = 1; off=scmp_amg; break;
	 }
      if (off != -1) cv = cvp[off];
      if (!cv) {
	goto not_found;
      }
    } else {
    not_found:			/* No method found, either report or croak */
      switch (method) {
	 case lt_amg:
	 case le_amg:
	 case gt_amg:
	 case ge_amg:
	 case eq_amg:
	 case ne_amg:
	 case seq_amg:
	 case sne_amg:
	   postpr = 0; break;
	 case to_sv_amg:
	 case to_av_amg:
	 case to_hv_amg:
	 case to_gv_amg:
	 case to_cv_amg:
	     /* FAIL safe */
	     return left;	/* Delegate operation to standard mechanisms. */
	     break;
      }
      if (ocvp && (cv=ocvp[nomethod_amg])) { /* Call report method */
	notfound = 1; lr = -1;
      } else if (cvp && (cv=cvp[nomethod_amg])) {
	notfound = 1; lr = 1;
      } else if ((amtp && amtp->fallback >= AMGfallYES) && !DEBUG_o_TEST) {
	/* Skip generating the "no method found" message.  */
	return NULL;
      } else {
	SV *msg;
	if (off==-1) off=method;
	msg = sv_2mortal(Perl_newSVpvf(aTHX_
		      "Operation \"%s\": no method found,%sargument %s%s%s%s",
		      AMG_id2name(method + assignshift),
		      (flags & AMGf_unary ? " " : "\n\tleft "),
		      SvAMAGIC(left)?
		        "in overloaded package ":
		        "has no overloaded magic",
		      SvAMAGIC(left)?
		        HvNAME_get(SvSTASH(SvRV(left))):
		        "",
		      SvAMAGIC(right)?
		        ",\n\tright argument in overloaded package ":
		        (flags & AMGf_unary
			 ? ""
			 : ",\n\tright argument has no overloaded magic"),
		      SvAMAGIC(right)?
		        HvNAME_get(SvSTASH(SvRV(right))):
		        ""));
	if (amtp && amtp->fallback >= AMGfallYES) {
	  DEBUG_o( Perl_deb(aTHX_ "%s", SvPVX_const(msg)) );
	} else {
	  Perl_croak(aTHX_ "%"SVf, SVfARG(msg));
	}
	return NULL;
      }
      force_cpy = force_cpy || assign;
    }
  }
#ifdef DEBUGGING
  if (!notfound) {
    DEBUG_o(Perl_deb(aTHX_
		     "Overloaded operator \"%s\"%s%s%s:\n\tmethod%s found%s in package %s%s\n",
		     AMG_id2name(off),
		     method+assignshift==off? "" :
		     " (initially \"",
		     method+assignshift==off? "" :
		     AMG_id2name(method+assignshift),
		     method+assignshift==off? "" : "\")",
		     flags & AMGf_unary? "" :
		     lr==1 ? " for right argument": " for left argument",
		     flags & AMGf_unary? " for argument" : "",
		     stash ? HvNAME_get(stash) : "null",
		     fl? ",\n\tassignment variant used": "") );
  }
#endif
    /* Since we use shallow copy during assignment, we need
     * to dublicate the contents, probably calling user-supplied
     * version of copy operator
     */
    /* We need to copy in following cases:
     * a) Assignment form was called.
     * 		assignshift==1,  assign==T, method + 1 == off
     * b) Increment or decrement, called directly.
     * 		assignshift==0,  assign==0, method + 0 == off
     * c) Increment or decrement, translated to assignment add/subtr.
     * 		assignshift==0,  assign==T,
     *		force_cpy == T
     * d) Increment or decrement, translated to nomethod.
     * 		assignshift==0,  assign==0,
     *		force_cpy == T
     * e) Assignment form translated to nomethod.
     * 		assignshift==1,  assign==T, method + 1 != off
     *		force_cpy == T
     */
    /*	off is method, method+assignshift, or a result of opcode substitution.
     *	In the latter case assignshift==0, so only notfound case is important.
     */
  if (( (method + assignshift == off)
	&& (assign || (method == inc_amg) || (method == dec_amg)))
      || force_cpy)
    RvDEEPCP(left);
  {
    dSP;
    BINOP myop;
    SV* res;
    const bool oldcatch = CATCH_GET;

    CATCH_SET(TRUE);
    Zero(&myop, 1, BINOP);
    myop.op_last = (OP *) &myop;
    myop.op_next = NULL;
    myop.op_flags = OPf_WANT_SCALAR | OPf_STACKED;

    PUSHSTACKi(PERLSI_OVERLOAD);
    ENTER;
    SAVEOP();
    PL_op = (OP *) &myop;
    if (PERLDB_SUB && PL_curstash != PL_debstash)
	PL_op->op_private |= OPpENTERSUB_DB;
    PUTBACK;
    pp_pushmark();

    EXTEND(SP, notfound + 5);
    PUSHs(lr>0? right: left);
    PUSHs(lr>0? left: right);
    PUSHs( lr > 0 ? &PL_sv_yes : ( assign ? &PL_sv_undef : &PL_sv_no ));
    if (notfound) {
	PUSHs( sv_2mortal(newSVpv(AMG_id2name(method + assignshift), 0)));
    }
    PUSHs((SV*)cv);
    PUTBACK;

    if ((PL_op = Perl_pp_entersub(aTHX)))
      CALLRUNOPS(aTHX);
    LEAVE;
    SPAGAIN;

    res=POPs;
    PUTBACK;
    POPSTACK;
    CATCH_SET(oldcatch);

    if (postpr) {
      int ans;
      switch (method) {
      case le_amg:
	ans=SvIV(res)<=0; break;
      case lt_amg:
	ans=SvIV(res)<0; break;
      case ge_amg:
	ans=SvIV(res)>=0; break;
      case gt_amg:
	ans=SvIV(res)>0; break;
      case eq_amg:
      case seq_amg:
	ans=SvIV(res)==0; break;
      case ne_amg:
      case sne_amg:
	ans=SvIV(res)!=0; break;
      case inc_amg:
      case dec_amg:
	SvSetSV(left,res); return left;
      case not_amg:
	ans=!SvTRUE(res); break;
      default:
        ans=0; break;
      }
      return boolSV(ans);
    } else if (method==copy_amg) {
      if (!SvROK(res)) {
	Perl_croak(aTHX_ "Copy method did not return a reference");
      }
      return SvREFCNT_inc(SvRV(res));
    } else {
      return res;
    }
  }
}

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
