/*    cv.h
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1999, 2000, 2001,
 *    2002, 2003, 2004, 2005, 2006, 2007, 2008 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

typedef U32 cv_flags_t;

#define _XPVCV_COMMON								\
    union {									\
	OP *	xcv_start;							\
	ANY	xcv_xsubany;							\
    }		xcv_start_u;					    		\
    union {									\
	ROOTOP *	xcv_root;							\
	void	(*xcv_xsub) (pTHX_ CV*);					\
    }		xcv_root_u;							\
    AV *	xcv_padlist;							\
    I32         xcv_n_minargs;	/* minium number of argument (excl. rhs) */     \
    I32         xcv_n_maxargs;	/* maximum number of argument (-1 for no-limit) (excl. rhs) */     \
    I32         xcv_n_add_refs;	/* number of additional references to the body */     \
    cv_flags_t	xcv_flags

struct xpvcv {
    _XPV_HEAD;
    _XPVMG_HEAD;
    _XPVCV_COMMON;
};

/*
=head1 Handy Values

=for apidoc AmU||Nullcv
Null CV pointer.

(deprecated - use C<(CV *)NULL> instead)

=head1 CV Manipulation Functions

=cut
*/

#ifndef PERL_CORE
#  define Nullcv Null(CV*)
#endif

#define CvSTART(sv)	((XPVCV*)SvANY(sv))->xcv_start_u.xcv_start
#define CvROOT(sv)	((XPVCV*)SvANY(sv))->xcv_root_u.xcv_root
#define CvXSUB(sv)	((XPVCV*)SvANY(sv))->xcv_root_u.xcv_xsub
#define CvXSUBANY(sv)	((XPVCV*)SvANY(sv))->xcv_start_u.xcv_xsubany
#if defined(__GNUC__) && !defined(PERL_GCC_BRACE_GROUPS_FORBIDDEN)
#  define CvDEPTH(sv) (*({const CV *const _cvdepth = (const CV *)sv; \
			  assert(SvTYPE(_cvdepth) == SVt_PVCV);	 \
			  &((XPVCV*)SvANY(_cvdepth))->xiv_u.xivu_i32; \
			}))
#else
#  define CvDEPTH(sv)	((XPVCV*)MUTABLE_PTR(SvANY(sv)))->xiv_u.xivu_i32
#endif
#define CvPADLIST(sv)	((XPVCV*)SvANY(sv))->xcv_padlist
#define CvFLAGS(sv)	((XPVCV*)SvANY(sv))->xcv_flags
#define CvN_MINARGS(sv)	((XPVCV*)SvANY(sv))->xcv_n_minargs
#define CvN_MAXARGS(sv)	((XPVCV*)SvANY(sv))->xcv_n_maxargs
#define CvN_ADD_REFS(sv)	((XPVCV*)SvANY(sv))->xcv_n_add_refs

#define CVf_BLOCK	0x0001	/* CV accept one argument which is assigned to $_ */
#define CVf_CLONE	0x0020	/* anon CV uses external lexicals */
#define CVf_CLONED	0x0040	/* a clone of one of those */
#define CVf_ANON	0x0080	/* CvGV() can't be trusted */
#define CVf_UNIQUE	0x0100	/* sub is only called once (eg PL_main_cv,
				 * require, eval). */
#define CVf_NODEBUG	0x0200	/* no DB::sub indirection for this CV
				   (esp. useful for special XSUBs) */
#define CVf_CONST	0x0400  /* inlinable sub */
#define CVf_ISXSUB	0x0800	/* CV is an XSUB, not pure perl.  */
#define CVf_PROTO	0x1000	/* arguments are passed to prototype variables */
#define CVf_DEFARGS	0x2000	/* arguments are passed to @_ */
#define CVf_ASSIGNARG	0x4000	/* last argument should be the rhs of an assignment (only used in combination with CVf_PROTO */
#define CVf_OPTASSIGNARG	0x8000	/* last argument should be the rhs of an assignment (only used in combination with CVf_PROTO */
#define CVf_TMPREFCNT	0x10000	/* already counted for refcounting checking */
#define CVf_SPECIAL	0x20000	/* BEGIN/END/UNIT block */

#define CvCLONE(cv)		(CvFLAGS(cv) & CVf_CLONE)
#define CvCLONE_on(cv)		(CvFLAGS(cv) |= CVf_CLONE)
#define CvCLONE_off(cv)		(CvFLAGS(cv) &= ~CVf_CLONE)

#define CvCLONED(cv)		(CvFLAGS(cv) & CVf_CLONED)
#define CvCLONED_on(cv)		(CvFLAGS(cv) |= CVf_CLONED)
#define CvCLONED_off(cv)	(CvFLAGS(cv) &= ~CVf_CLONED)

#define CvANON(cv)		(CvFLAGS(cv) & CVf_ANON)
#define CvANON_on(cv)		(CvFLAGS(cv) |= CVf_ANON)
#define CvANON_off(cv)		(CvFLAGS(cv) &= ~CVf_ANON)

#define CvUNIQUE(cv)		(CvFLAGS(cv) & CVf_UNIQUE)
#define CvUNIQUE_on(cv)		(CvFLAGS(cv) |= CVf_UNIQUE)
#define CvUNIQUE_off(cv)	(CvFLAGS(cv) &= ~CVf_UNIQUE)

#define CvNODEBUG(cv)		(CvFLAGS(cv) & CVf_NODEBUG)
#define CvNODEBUG_on(cv)	(CvFLAGS(cv) |= CVf_NODEBUG)
#define CvNODEBUG_off(cv)	(CvFLAGS(cv) &= ~CVf_NODEBUG)

#define CvEVAL(cv)		(CvUNIQUE(cv) && !SvFAKE(cv))
#define CvEVAL_on(cv)		(CvUNIQUE_on(cv),SvFAKE_off(cv))
#define CvEVAL_off(cv)		CvUNIQUE_off(cv)

/* BEGIN|CHECK|INIT|UNITCHECK|END */
#define CvSPECIAL(cv)		(CvFLAGS(cv) & CVf_SPECIAL)
#define CvSPECIAL_on(cv)		(CvFLAGS(cv) |= CVf_SPECIAL)
#define CvSPECIAL_off(cv)		(CvFLAGS(cv) &= ~CVf_SPECIAL)

#define CvCONST(cv)		(CvFLAGS(cv) & CVf_CONST)
#define CvCONST_on(cv)		(CvFLAGS(cv) |= CVf_CONST)
#define CvCONST_off(cv)		(CvFLAGS(cv) &= ~CVf_CONST)

#define CvISXSUB(cv)		(CvFLAGS(cv) & CVf_ISXSUB)
#define CvISXSUB_on(cv)		(CvFLAGS(cv) |= CVf_ISXSUB)
#define CvISXSUB_off(cv)	(CvFLAGS(cv) &= ~CVf_ISXSUB)

/* Flags for newXS_flags  */
#define XS_DYNAMIC_FILENAME	0x01	/* The filename isn't static  */

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
