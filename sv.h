/*    sv.h
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000,
 *    2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

#ifdef DEBUGGING
#  include "valgrind/memcheck.h"
#else
#  define VALGRIND_MAKE_MEM_UNDEFINED(p, s)
#  define VALGRIND_MAKE_MEM_DEFINED(p, s)
#  define VALGRIND_MAKE_MEM_NOACCESS(p, s)
#  define VALGRIND_MEMPOOL_ALLOC(pool, p, s)
#  define VALGRIND_MEMPOOL_FREE(pool, p)
#  define VALGRIND_CREATE_MEMPOOL(pool, x, s)
#endif

#ifdef sv_flags
#undef sv_flags		/* Convex has this in <signal.h> for sigvec() */
#endif

/*
=head1 SV Flags

=for apidoc AmU||svtype
An enum of flags for Perl types.  These are found in the file B<sv.h>
in the C<svtype> enum.  Test these flags with the C<SvTYPE> macro.

=for apidoc AmU||SVt_PV
Pointer type flag for scalars.  See C<svtype>.

=for apidoc AmU||SVt_IV
Integer type flag for scalars.  See C<svtype>.

=for apidoc AmU||SVt_NV
Double type flag for scalars.  See C<svtype>.

=for apidoc AmU||SVt_PVMG
Type flag for blessed scalars.  See C<svtype>.

=for apidoc AmU||SVt_PVAV
Type flag for arrays.  See C<svtype>.

=for apidoc AmU||SVt_PVHV
Type flag for hashes.  See C<svtype>.

=for apidoc AmU||SVt_PVCV
Type flag for code refs.  See C<svtype>.

=cut
*/

typedef enum {
	SVt_NULL,	/* 0 */
	SVt_BIND,	/* 1 */
	SVt_IV,		/* 2 */
	SVt_NV,		/* 3 */
	/* RV was here, before it was merged with IV.  */
	SVt_PV,		/* 4 */
	SVt_PVIV,	/* 5 */
	SVt_PVNV,	/* 6 */
	SVt_PVMG,	/* 7 */
	SVt_REGEXP,	/* 8 */
	/* PVBM was here, before BIND replaced it.  */
	SVt_PVGV,	/* 9 */
	SVt_PVAV,	/* 10 */
	SVt_PVHV,	/* 11 */
	SVt_PVCV,	/* 12 */
	SVt_PVIO,	/* 13 */
	SVt_LAST	/* keep last in enum. used to size arrays */
} svtype;


typedef enum {
    Dt_UNDEF,
    Dt_PLAIN,
    Dt_REF,
    Dt_ARRAY,
    Dt_HASH,
    Dt_CODE,
    Dt_IO,
    Dt_GLOB,
    Dt_REGEXP,
    Dt_COMPLEX
} datatype;


/* There is collusion here with sv_clear - sv_clear exits early for SVt_NULL
   and SVt_IV, so never reaches the clause at the end that uses
   sv_type_details->body_size to determine whether to call safefree(). Hence
   body_size can be set no-zero to record the size of PTEs and HEs, without
   fear of bogus frees.  */
#ifdef PERL_IN_SV_C
#define PTE_SVSLOT	SVt_IV
#endif
#if defined(PERL_IN_HV_C) || defined(PERL_IN_XS_APITEST)
#define HE_SVSLOT	SVt_NULL
#endif

#define PERL_ARENA_ROOTS_SIZE	(SVt_LAST)

/* typedefs to eliminate some typing */
typedef struct he HE;
typedef struct hek HEK;

/* Using C's structural equivalence to help emulate C++ inheritance here... */

/* start with 2 sv-head building blocks */
#define _SV_HEAD(ptrtype) \
    ptrtype	sv_any;		/* pointer to body */	\
    U32		sv_refcnt;	/* how many references to us */	\
    U32		sv_flags;	/* what we are */  \
    SV*         sv_location;    /* location where the scalar was declared */ \
    U32		sv_tmprefcnt	/* temporary how many references to us */

#define _SV_HEAD_UNION \
    union {				\
	IV      svu_iv;			\
	UV      svu_uv;			\
	SV*     svu_rv;		/* pointer to another SV */		\
	char*   svu_pv;		/* pointer to malloced string */	\
	SV**    svu_array;		\
	HE**	svu_hash;		\
	GP*	svu_gp;			\
    }	sv_u


struct STRUCT_SV {		/* struct sv { */
    _SV_HEAD(void*);
    _SV_HEAD_UNION;
#ifdef DEBUG_LEAKING_SCALARS
    PERL_BITFIELD32 sv_debug_optype:9;	/* the type of OP that allocated us */
    PERL_BITFIELD32 sv_debug_inpad:1;	/* was allocated in a pad for an OP */
    PERL_BITFIELD32 sv_debug_cloned:1;	/* was cloned for an ithread */
    PERL_BITFIELD32 sv_debug_line:16;	/* the line where we were allocated */
    U32		    sv_debug_serial;	/* serial number of sv allocation   */
    char *	sv_debug_file;		/* the file where we were allocated */
#endif
};

struct gv {
    _SV_HEAD(XPVGV*);		/* pointer to xpvgv body */
    _SV_HEAD_UNION;
};

struct cv {
    _SV_HEAD(XPVCV*);		/* pointer to xpvcv body */
    _SV_HEAD_UNION;
};

struct av {
    _SV_HEAD(XPVAV*);		/* pointer to xpvav body */
    _SV_HEAD_UNION;
};

struct hv {
    _SV_HEAD(XPVHV*);		/* pointer to xpvhv body */
    _SV_HEAD_UNION;
};

struct io {
    _SV_HEAD(XPVIO*);		/* pointer to xpvio body */
    _SV_HEAD_UNION;
};

struct p5rx {
    _SV_HEAD(struct regexp*);	/* pointer to regexp body */
    _SV_HEAD_UNION;
};

#undef _SV_HEAD
#undef _SV_HEAD_UNION		/* ensure no pollution */

/*
=head1 SV Manipulation Functions

=for apidoc Am|U32|SvREFCNT|SV* sv
Returns the value of the object's reference count.

=for apidoc Am|SV*|SvREFCNT_inc|SV* sv
Increments the reference count of the given SV.

All of the following SvREFCNT_inc* macros are optimized versions of
SvREFCNT_inc, and can be replaced with SvREFCNT_inc.

=for apidoc Am|SV*|SvREFCNT_inc_NN|SV* sv
Same as SvREFCNT_inc, but can only be used if you know I<sv>
is not NULL.  Since we don't have to check the NULLness, it's faster
and smaller.

=for apidoc Am|void|SvREFCNT_inc_void|SV* sv
Same as SvREFCNT_inc, but can only be used if you don't need the
return value.  The macro doesn't need to return a meaningful value.

=for apidoc Am|void|SvREFCNT_inc_void_NN|SV* sv
Same as SvREFCNT_inc, but can only be used if you don't need the return
value, and you know that I<sv> is not NULL.  The macro doesn't need
to return a meaningful value, or check for NULLness, so it's smaller
and faster.

=for apidoc Am|void|SvREFCNT_dec|SV* sv
Decrements the reference count of the given SV.

=for apidoc Am|svtype|SvTYPE|SV* sv
Returns the type of the SV.  See C<svtype>.

=for apidoc Am|void|SvUPGRADE|SV* sv|svtype type
Used to upgrade an SV to a more complex form.  Uses C<sv_upgrade> to
perform the upgrade if necessary.  See C<svtype>.

=cut
*/

#define SvANY(sv)	(sv)->sv_any
#define SvFLAGS(sv)	(sv)->sv_flags
#define SvREFCNT(sv)	(sv)->sv_refcnt
#define SvLOCATION(sv)	(sv)->sv_location
#define SvTMPREFCNT(sv)	(sv)->sv_tmprefcnt

#if defined(__GNUC__) && !defined(PERL_GCC_BRACE_GROUPS_FORBIDDEN)
#  define SvREFCNT_inc_NN(sv)		\
    ({					\
	SV * const _sv = MUTABLE_SV(sv);	\
	SvREFCNT(_sv)++;		\
	_sv;				\
    })
#  define SvREFCNT_inc_void(sv)		\
    ({					\
	SV * const _sv = MUTABLE_SV(sv);	\
	if (_sv)			\
	    (void)(SvREFCNT(_sv)++);	\
    })
#else
#  define SvREFCNT_inc_NN(sv) \
	(PL_Sv=MUTABLE_SV(sv),++(SvREFCNT(PL_Sv)),PL_Sv)
#  define SvREFCNT_inc_void(sv) \
	(void)((PL_Sv=MUTABLE_SV(sv)) ? ++(SvREFCNT(PL_Sv)) : 0)
#endif

/* These guys don't need the curly blocks */
#define SvREFCNT_inc_void_NN(sv)	(void)(++SvREFCNT((SV*)(sv)))

#define SVTYPEMASK	0xff
#define SvTYPE(sv)	((svtype)((sv)->sv_flags & SVTYPEMASK))

/* Sadly there are some parts of the core that have pointers to already-freed
   SV heads, and rely on being able to tell that they are now free. So mark
   them all by using a consistent macro.  */
#define SvIS_FREED(sv)	((sv)->sv_flags == SVTYPEMASK)

#define SvUPGRADE(sv, mt) (sv_upgrade(sv, mt), 1)

#define SVf_IOK		0x00000100  /* has valid public integer value */
#define SVf_NOK		0x00000200  /* has valid public numeric value */
#define SVf_POK		0x00000400  /* has valid public pointer value */
#define SVf_ROK		0x00000800  /* has a valid reference pointer */

#define SVp_IOK		0x00001000  /* has valid non-public integer value */
#define SVp_NOK		0x00002000  /* has valid non-public numeric value */
#define SVp_POK		0x00004000  /* has valid non-public pointer value */
#define SVp_SCREAM	0x00008000  /* has been studied? */
#define SVphv_CLONEABLE	SVp_SCREAM  /* PVHV (stashes) clone its objects */
#define SVpgv_GP	SVp_SCREAM  /* GV has a valid GP */
#define SVprv_PCS_IMPORTED  SVp_SCREAM  /* RV is a proxy for a constant
				       subroutine in another package. Set the
				       CvIMPORTED_CV_ON() if it needs to be
				       expanded to a real GV */

#define SVs_PADSTALE	0x00010000  /* lexical has gone out of scope */
#define SVpad_STATE	0x00010000  /* pad name is a "state" var */
#define SVs_PADTMP	0x00020000  /* in use as tmp */
#define SVs_PADMY	0x00040000  /* in use a "my" variable */
#define SVpad_OUR	0x00040000  /* pad name is "our" instead of "my" */
#define SVs_TEMP	0x00080000  /* string is stealable? */
#define SVs_OBJECT	0x00100000  /* is "blessed" */
#define SVs_NOTUSED		0x00200000  /* has magical get method */
#define SVs_SMG		0x00400000  /* has magical set method */
#define SVs_RMG		0x00800000  /* has random magical methods */

#define SVf_FAKE	0x01000000  /* 0: glob or lexical is just a copy
				       1: SV head arena wasn't malloc()ed
				       2: in conjunction with SVf_READONLY
					  marks a shared hash key scalar
					  (SvLEN == 0) or a copy on write
					  string (SvLEN != 0) [SvIsCOW(sv)]
				       3: For PVCV, whether CvUNIQUE(cv)
					  refers to an eval or once only
					  [CvEVAL(cv), CvSPECIAL(cv)]
				       4: On a pad name SV, that slot in the
					  frame AV is a REFCNT'ed reference
					  to a lexical from "outside". */
#define SVphv_REHASH	SVf_FAKE    /* 5: On a PVHV, hash values are being
					  recalculated */
#define SVf_OOK		0x02000000  /* has valid offset value. For a PVHV this
				       means that a hv_aux struct is present
				       after the main array */
#define SVf_BREAK	0x04000000  /* refcnt is artificially low - used by
				       SVs in final arena cleanup.
				       Set in S_regtry on PL_reg_curpm, so that
				       perl_destruct will skip it. */
#define SVf_READONLY	0x08000000  /* may not be modified */




#define SVf_THINKFIRST	(SVf_READONLY|SVf_ROK|SVf_FAKE)

#define SVf_OK		(SVf_IOK|SVf_NOK|SVf_POK|SVf_ROK| \
			 SVp_IOK|SVp_NOK|SVp_POK|SVpgv_GP)

#define PRIVSHIFT 4	/* (SVp_?OK >> PRIVSHIFT) == SVf_?OK */

/* Some private flags. */

/* PVAV could probably use 0x2000000 without conflict. I assume that PVFM can
   be UTF-8 encoded, and PVCVs could well have UTF-8 prototypes. PVIOs haven't
   been restructured, so sometimes get used as string buffers.  */

/* PVHV */
#define SVphv_RESTRICTED	0x10000000  /* PVHV is restricted */
#define SVphv_SHAREKEYS 0x20000000  /* PVHV keys live on shared string table */
/* PVNV, PVMG, presumably only inside pads */
#define SVpad_NAME	0x40000000  /* This SV is a name in the PAD, so
				       SVpad_OUR and SVpad_STATE apply */
/* PVAV */
#define SVpav_REAL	0x40000000  /* free old entries */
/* PVHV */
#define SVphv_LAZYDEL	0x40000000  /* entry in xhv_eiter must be deleted */
/* This is only set true on a PVGV when it's playing "PVBM", but is tested for
   on any regular scalar (anything <= PVGV) */
#define SVpbm_VALID	0x40000000

/* IV, PVIV, PVNV, PVMG, PVGV  */
/* Presumably IVs aren't stored in pads */
#define SVf_IVisUV	0x80000000  /* use XPVUV instead of XPVIV */
/* PVAV */
#define SVpav_REIFY 	0x80000000  /* can become real */
/* PVHV */
#define SVphv_NOTUSED	0x80000000  /* unused */
/* PVGV when SVpbm_VALID is true */
#define SVpbm_TAIL	0x80000000
/* RV upwards. However, SVf_ROK and SVp_IOK are exclusive  */
#define SVprv_WEAKREF   0x80000000  /* Weak reference */

#define _XPV_ALLOCATED_HEAD						\
    STRLEN	xpv_cur;	/* length of svu_pv as a C string */    \
    STRLEN	xpv_len 	/* allocated size */

#define _XPV_HEAD	\
    union _xnvu xnv_u;	\
    _XPV_ALLOCATED_HEAD

union _xnvu {
    NV	    xnv_nv;		/* numeric value, if any */
    HV *    xgv_stash;
    struct {
	U32 xlow;
	U32 xhigh;
    }	    xpad_cop_seq;	/* used by pad.c for cop_sequence */
    struct {
	U32 xbm_previous;	/* how many characters in string before rare? */
	U8  xbm_flags;
	U8  xbm_rare;		/* rarest character in string */
    }	    xbm_s;		/* fields from PVBM */
};

union _xivu {
    IV	    xivu_iv;		/* integer value */
				/* xpvfm: lines */
    UV	    xivu_uv;
    void *  xivu_p1;
    I32	    xivu_i32;
    HEK *   xivu_namehek;	/* xpvlv, xpvgv: GvNAME */
    HV *    xivu_hv;		/* regexp: paren_names */
};

union _xmgu {
    MAGIC*  xmg_magic;		/* linked list of magicalness */
    GV*     xmg_ourgv;          /* Glob for our (when SvPAD_OUR is true) */
};

struct xpv {
    _XPV_HEAD;
};

typedef struct {
    _XPV_ALLOCATED_HEAD;
} xpv_allocated;

struct xpviv {
    _XPV_HEAD;
    union _xivu xiv_u;
};

typedef struct {
    _XPV_ALLOCATED_HEAD;
    union _xivu xiv_u;
} xpviv_allocated;

#define xiv_iv xiv_u.xivu_iv

struct xpvuv {
    _XPV_HEAD;
    union _xivu xuv_u;
};

#define xuv_uv xuv_u.xivu_uv

struct xpvnv {
    _XPV_HEAD;
    union _xivu xiv_u;
};

#define _XPVMG_HEAD				    \
    union _xivu xiv_u;				    \
    union _xmgu	xmg_u;				    \
    HV*		xmg_stash	/* class package */

/* These structure must match the beginning of struct xpvhv in hv.h. */
struct xpvmg {
    _XPV_HEAD;
    _XPVMG_HEAD;
};

struct xpvlv {
    _XPV_HEAD;
    _XPVMG_HEAD;

    STRLEN	xlv_targoff;
    STRLEN	xlv_targlen;
    SV*		xlv_targ;
    char	xlv_type;	/* k=keys .=pos x=substr v=vec /=join/re
				 * y=alem/helem/iter t=tie T=tied HE */
};

/* This structure works in 3 ways - regular scalar, GV with GP, or fast
   Boyer-Moore.  */
struct xpvgv {
    _XPV_HEAD;
    _XPVMG_HEAD;
};

#define _XPVIO_TAIL							\
    PerlIO *	xio_ifp;	/* ifp and ofp are normally the same */	\
    PerlIO *	xio_ofp;	/* but sockets need separate streams */	\
    /* Cray addresses everything by word boundaries (64 bits) and	\
     * code and data pointers cannot be mixed (which is exactly what	\
     * Perl_filter_add() tries to do with the dirp), hence the		\
     *  following union trick (as suggested by Gurusamy Sarathy).	\
     * For further information see Geir Johansen's problem report	\
     * titled [ID 20000612.002] Perl problem on Cray system		\
     * The any pointer (known as IoANY()) will also be a good place	\
     * to hang any IO disciplines to.					\
     */									\
    union {								\
	DIR *	xiou_dirp;	/* for opendir, readdir, etc */		\
	void *	xiou_any;	/* for alignment */			\
    } xio_dirpu;							\
    IV		xio_lines;	/* $. */				\
    char	xio_type;						\
    U8		xio_flags


struct xpvio {
    _XPV_HEAD;
    _XPVMG_HEAD;
    _XPVIO_TAIL;
};

typedef struct {
    _XPV_ALLOCATED_HEAD;
    _XPVMG_HEAD;
    _XPVIO_TAIL;
} xpvio_allocated;

#define xio_dirp	xio_dirpu.xiou_dirp
#define xio_any		xio_dirpu.xiou_any

#define IOf_ARGV	1	/* this fp iterates over ARGV */
#define IOf_START	2	/* check for null ARGV and substitute '-' */
#define IOf_FLUSH	4	/* this fp wants a flush after write op */
#define IOf_DIDTOP	8	/* just did top of form */
#define IOf_NOLINE	32	/* slurped a pseudo-line from empty file */
#define IOf_FAKE_DIRP	64	/* xio_dirp is fake (source filters kludge) */

/* The following macros define implementation-independent predicates on SVs. */

/*
=for apidoc Am|U32|SvNIOK|SV* sv
Returns a U32 value indicating whether the SV contains a number, integer or
double.

=for apidoc Am|U32|SvNIOKp|SV* sv
Returns a U32 value indicating whether the SV contains a number, integer or
double.  Checks the B<private> setting.  Use C<SvNIOK> instead.

=for apidoc Am|void|SvNIOK_off|SV* sv
Unsets the NV/IV status of an SV.

=for apidoc Am|U32|SvOK|SV* sv
Returns a U32 value indicating whether the value is an SV. It also tells
whether the value is defined or not.

=for apidoc Am|U32|SvIOKp|SV* sv
Returns a U32 value indicating whether the SV contains an integer.  Checks
the B<private> setting.  Use C<SvIOK> instead.

=for apidoc Am|U32|SvNOKp|SV* sv
Returns a U32 value indicating whether the SV contains a double.  Checks the
B<private> setting.  Use C<SvNOK> instead.

=for apidoc Am|U32|SvPOKp|SV* sv
Returns a U32 value indicating whether the SV contains a character string.
Checks the B<private> setting.  Use C<SvPOK> instead.

=for apidoc Am|U32|SvIOK|SV* sv
Returns a U32 value indicating whether the SV contains an integer.

=for apidoc Am|void|SvIOK_on|SV* sv
Tells an SV that it is an integer.

=for apidoc Am|void|SvIOK_off|SV* sv
Unsets the IV status of an SV.

=for apidoc Am|void|SvIOK_only|SV* sv
Tells an SV that it is an integer and disables all other OK bits.

=for apidoc Am|void|SvIOK_only_UV|SV* sv
Tells and SV that it is an unsigned integer and disables all other OK bits.

=for apidoc Am|bool|SvIOK_UV|SV* sv
Returns a boolean indicating whether the SV contains an unsigned integer.

=for apidoc Am|bool|SvUOK|SV* sv
Returns a boolean indicating whether the SV contains an unsigned integer.

=for apidoc Am|bool|SvIOK_notUV|SV* sv
Returns a boolean indicating whether the SV contains a signed integer.

=for apidoc Am|U32|SvNOK|SV* sv
Returns a U32 value indicating whether the SV contains a double.

=for apidoc Am|void|SvNOK_on|SV* sv
Tells an SV that it is a double.

=for apidoc Am|void|SvNOK_off|SV* sv
Unsets the NV status of an SV.

=for apidoc Am|void|SvNOK_only|SV* sv
Tells an SV that it is a double and disables all other OK bits.

=for apidoc Am|U32|SvPOK|SV* sv
Returns a U32 value indicating whether the SV contains a character
string.

=for apidoc Am|void|SvPOK_on|SV* sv
Tells an SV that it is a string.

=for apidoc Am|void|SvPOK_off|SV* sv
Unsets the PV status of an SV.

=for apidoc Am|void|SvPOK_only|SV* sv
Tells an SV that it is a string and disables all other OK bits.
Will also turn off the UTF-8 status.

=for apidoc Am|U32|SvOOK|SV* sv
Returns a U32 indicating whether the pointer to the string buffer is offset.
This hack is used internally to speed up removal of characters from the
beginning of a SvPV.  When SvOOK is true, then the start of the
allocated string buffer is actually C<SvOOK_offset()> bytes before SvPVX.
This offset used to be stored in SvIV, but is now stored within the spare
part of the buffer.

=for apidoc Am|U32|SvROK|SV* sv
Tests if the SV is an RV.

=for apidoc Am|void|SvROK_on|SV* sv
Tells an SV that it is an RV.

=for apidoc Am|void|SvROK_off|SV* sv
Unsets the RV status of an SV.

=for apidoc Am|SV*|SvRV|SV* sv
Dereferences an RV to return the SV.

=for apidoc Am|IV|I_SvIV|SV* sv
Returns the raw value in the SV's IV slot, without checks or conversions.
Only use when you are sure SvIOK is true. See also C<SvIV()>.

=for apidoc Am|UV|SvUVX|SV* sv
Returns the raw value in the SV's UV slot, without checks or conversions.
Only use when you are sure SvIOK is true. See also C<SvUV()>.

=for apidoc Am|NV|SvNVX|SV* sv
Returns the raw value in the SV's NV slot, without checks or conversions.
Only use when you are sure SvNOK is true. See also C<SvNV()>.

=for apidoc Am|char*|SvPVX|SV* sv
Returns a pointer to the physical string in the SV.  The SV must contain a
string.

=for apidoc Am|STRLEN|SvCUR|SV* sv
Returns the length of the string which is in the SV.  See C<SvLEN>.

=for apidoc Am|STRLEN|SvLEN|SV* sv
Returns the size of the string buffer in the SV, not including any part
attributable to C<SvOOK>.  See C<SvCUR>.

=for apidoc Am|char*|SvEND|SV* sv
Returns a pointer to the last character in the string which is in the SV.
See C<SvCUR>.  Access the character as *(SvEND(sv)).

=for apidoc Am|HV*|SvSTASH|SV* sv
Returns the stash of the SV.

=for apidoc Am|void|SvIV_set|SV* sv|IV val
Set the value of the IV pointer in sv to val.

=for apidoc Am|void|SvNV_set|SV* sv|NV val
Set the value of the NV pointer in sv to val.  See C<SvIV_set>.

=for apidoc Am|void|SvPV_set|SV* sv|char* val
Set the value of the PV pointer in sv to val.  See C<SvIV_set>.

=for apidoc Am|void|SvUV_set|SV* sv|UV val
Set the value of the UV pointer in sv to val.  See C<SvIV_set>.

=for apidoc Am|void|SvRV_set|SV* sv|SV* val
Set the value of the RV pointer in sv to val.  See C<SvIV_set>.

=for apidoc Am|void|SvMAGIC_set|SV* sv|MAGIC* val
Set the value of the MAGIC pointer in sv to val.  See C<SvIV_set>.

=for apidoc Am|void|SvSTASH_set|SV* sv|HV* val
Set the value of the STASH pointer in sv to val.  See C<SvIV_set>.

=for apidoc Am|void|SvCUR_set|SV* sv|STRLEN len
Set the current length of the string which is in the SV.  See C<SvCUR>
and C<SvIV_set>.

=for apidoc Am|void|SvLEN_set|SV* sv|STRLEN len
Set the actual length of the string which is in the SV.  See C<SvIV_set>.

=cut
*/

#define SvNIOK(sv)		(SvFLAGS(sv) & (SVf_IOK|SVf_NOK))
#define SvNIOKp(sv)		(SvFLAGS(sv) & (SVp_IOK|SVp_NOK))
#define SvNIOK_off(sv)		(SvFLAGS(sv) &= ~(SVf_IOK|SVf_NOK| \
						  SVp_IOK|SVp_NOK|SVf_IVisUV))

#if defined(__GNUC__) && !defined(PERL_GCC_BRACE_GROUPS_FORBIDDEN)
#define assert_not_ROK(sv)	({assert(!SvROK(sv) || !SvRV(sv));}),
#define assert_not_glob(sv)	({assert(!isGV_with_GP(sv));}),
#else
#define assert_not_ROK(sv)	
#define assert_not_glob(sv)	
#endif

#define SvAVOK(sv)              (SvTYPE(sv) == SVt_PVAV)
#define SvHVOK(sv)              (SvTYPE(sv) == SVt_PVHV)
#define SvCVOK(sv)              (SvTYPE(sv) == SVt_PVCV)
#define SvIOOK(sv)              (SvTYPE(sv) == SVt_PVIO)
#define SvRVOK(sv)              (SvROK(sv))

#define SvPVOK(sv)		( (SvFLAGS(sv) & SVf_OK) && ( ! SvRVOK(sv) ) )
#define SvOK(sv)		(SvAVOK(sv) || SvHVOK(sv) || SvPVOK(sv) \
				 || SvIOOK(sv) || SvCVOK(sv) || SvRVOK(sv) )
#define SvOK_off(sv)		( SvAVOK(sv) || SvHVOK(sv) ? sv_setsv(sv, NULL) : SvPVOK_off(sv) )
#define SvPVOK_off(sv)		(assert_not_ROK(sv) assert_not_glob(sv)	\
				 SvFLAGS(sv) &=	~(SVf_OK|		\
						  SVf_IVisUV),	\
							SvOOK_off(sv))
#define SvOK_off_exc_UV(sv)	(assert_not_ROK(sv)			\
				 SvFLAGS(sv) &=	~(SVf_OK),		\
							SvOOK_off(sv))

#define SvOKp(sv)		(SvFLAGS(sv) & (SVp_IOK|SVp_NOK|SVp_POK))
#define SvIOKp(sv)		(SvFLAGS(sv) & SVp_IOK)
#define SvNOKp(sv)		(SvFLAGS(sv) & SVp_NOK)
#define SvNOKp_on(sv)		(assert_not_glob(sv) SvFLAGS(sv) |= SVp_NOK)
#define SvPOKp(sv)		(SvFLAGS(sv) & SVp_POK)
#define SvPOKp_on(sv)		(assert_not_ROK(sv) assert_not_glob(sv)	\
				 SvFLAGS(sv) |= SVp_POK)

#define SvIOK(sv)		(SvFLAGS(sv) & SVf_IOK)
#define SvIOK_on(sv)		(assert_not_glob(sv) SvRELEASE_IVX_(sv)	\
				    SvFLAGS(sv) |= (SVf_IOK|SVp_IOK))
#define SvIOK_off(sv)		(SvFLAGS(sv) &= ~(SVf_IOK|SVp_IOK|SVf_IVisUV))
#define SvIOK_only(sv)		(SvOK_off(sv), \
				    SvFLAGS(sv) |= (SVf_IOK|SVp_IOK))
#define SvIOK_only_UV(sv)	(assert_not_glob(sv) SvOK_off_exc_UV(sv), \
				    SvFLAGS(sv) |= (SVf_IOK|SVp_IOK))

#define SvIOK_UV(sv)		((SvFLAGS(sv) & (SVf_IOK|SVf_IVisUV))	\
				 == (SVf_IOK|SVf_IVisUV))
#define SvUOK(sv)		SvIOK_UV(sv)
#define SvIOK_notUV(sv)		((SvFLAGS(sv) & (SVf_IOK|SVf_IVisUV))	\
				 == SVf_IOK)

#define SvIsUV(sv)		(SvFLAGS(sv) & SVf_IVisUV)
#define SvIsUV_on(sv)		(SvFLAGS(sv) |= SVf_IVisUV)
#define SvIsUV_off(sv)		(SvFLAGS(sv) &= ~SVf_IVisUV)

#define SvNOK(sv)		(SvFLAGS(sv) & SVf_NOK)
#define SvNOK_on(sv)		(assert_not_glob(sv) \
				 SvFLAGS(sv) |= (SVf_NOK|SVp_NOK))
#define SvNOK_off(sv)		(SvFLAGS(sv) &= ~(SVf_NOK|SVp_NOK))
#define SvNOK_only(sv)		(SvOK_off(sv), \
				    SvFLAGS(sv) |= (SVf_NOK|SVp_NOK))

/* Ensure the return value of this macro does not clash with the GV_ADD* flags
in gv.h: */
#define SvPOK(sv)		(SvFLAGS(sv) & SVf_POK)
#define SvPOK_on(sv)		(assert_not_ROK(sv) assert_not_glob(sv)	\
				 SvFLAGS(sv) |= (SVf_POK|SVp_POK))
#define SvPOK_off(sv)		(SvFLAGS(sv) &= ~(SVf_POK|SVp_POK))
#define SvPOK_only(sv)		(assert_not_ROK(sv) assert_not_glob(sv)	\
				 SvFLAGS(sv) &= ~(SVf_OK|		\
						  SVf_IVisUV),	\
				    SvFLAGS(sv) |= (SVf_POK|SVp_POK))

#define SvOOK(sv)		(SvFLAGS(sv) & SVf_OOK)
#define SvOOK_on(sv)		((void)SvIOK_off(sv), SvFLAGS(sv) |= SVf_OOK)
#define SvOOK_off(sv)		((void)(SvOOK(sv) && sv_backoff(sv)))

#define SvFAKE(sv)		(SvFLAGS(sv) & SVf_FAKE)
#define SvFAKE_on(sv)		(SvFLAGS(sv) |= SVf_FAKE)
#define SvFAKE_off(sv)		(SvFLAGS(sv) &= ~SVf_FAKE)

#define SvROK(sv)		(SvFLAGS(sv) & SVf_ROK)
#define SvROK_on(sv)		(SvFLAGS(sv) |= SVf_ROK)
#define SvROK_off(sv)		(SvFLAGS(sv) &= ~(SVf_ROK))

#define SvMAGICAL(sv)		(SvFLAGS(sv) & (SVs_SMG|SVs_RMG))
#define SvMAGICAL_on(sv)	(SvFLAGS(sv) |= (SVs_SMG|SVs_RMG))
#define SvMAGICAL_off(sv)	(SvFLAGS(sv) &= ~(SVs_SMG|SVs_RMG))

#define SvSMAGICAL(sv)		(SvFLAGS(sv) & SVs_SMG)
#define SvSMAGICAL_on(sv)	(SvFLAGS(sv) |= SVs_SMG)
#define SvSMAGICAL_off(sv)	(SvFLAGS(sv) &= ~SVs_SMG)

#define SvRMAGICAL(sv)		(SvFLAGS(sv) & SVs_RMG)
#define SvRMAGICAL_on(sv)	(SvFLAGS(sv) |= SVs_RMG)
#define SvRMAGICAL_off(sv)	(SvFLAGS(sv) &= ~SVs_RMG)

#define SvWEAKREF(sv)		((SvFLAGS(sv) & (SVf_ROK|SVprv_WEAKREF)) \
				  == (SVf_ROK|SVprv_WEAKREF))
#define SvWEAKREF_on(sv)	(SvFLAGS(sv) |=  (SVf_ROK|SVprv_WEAKREF))
#define SvWEAKREF_off(sv)	(SvFLAGS(sv) &= ~(SVf_ROK|SVprv_WEAKREF))

#define SvPCS_IMPORTED(sv)	((SvFLAGS(sv) & (SVf_ROK|SVprv_PCS_IMPORTED)) \
				 == (SVf_ROK|SVprv_PCS_IMPORTED))
#define SvPCS_IMPORTED_on(sv)	(SvFLAGS(sv) |=  (SVf_ROK|SVprv_PCS_IMPORTED))
#define SvPCS_IMPORTED_off(sv)	(SvFLAGS(sv) &= ~(SVf_ROK|SVprv_PCS_IMPORTED))

#define SvTHINKFIRST(sv)	(SvFLAGS(sv) & SVf_THINKFIRST)

#define SvPADSTALE(sv)		(SvFLAGS(sv) & SVs_PADSTALE)
#define SvPADSTALE_on(sv)	(SvFLAGS(sv) |= SVs_PADSTALE)
#define SvPADSTALE_off(sv)	(SvFLAGS(sv) &= ~SVs_PADSTALE)

#define SvPADTMP(sv)		(SvFLAGS(sv) & SVs_PADTMP)
#define SvPADTMP_on(sv)		(SvFLAGS(sv) |= SVs_PADTMP)
#define SvPADTMP_off(sv)	(SvFLAGS(sv) &= ~SVs_PADTMP)

#define SvPADMY(sv)		(SvFLAGS(sv) & SVs_PADMY)
#define SvPADMY_on(sv)		(SvFLAGS(sv) |= SVs_PADMY)

#define SvTEMP(sv)		(SvFLAGS(sv) & SVs_TEMP)
#define SvTEMP_on(sv)		(SvFLAGS(sv) |= SVs_TEMP)
#define SvTEMP_off(sv)		(SvFLAGS(sv) &= ~SVs_TEMP)

#define SvOBJECT(sv)		(SvFLAGS(sv) & SVs_OBJECT)
#define SvOBJECT_on(sv)		(SvFLAGS(sv) |= SVs_OBJECT)
#define SvOBJECT_off(sv)	(SvFLAGS(sv) &= ~SVs_OBJECT)

#define SvREADONLY(sv)		(SvFLAGS(sv) & SVf_READONLY)
#define SvREADONLY_on(sv)	(SvFLAGS(sv) |= SVf_READONLY)
#define SvREADONLY_off(sv)	(SvFLAGS(sv) &= ~SVf_READONLY)

#define SvSCREAM(sv) ((SvFLAGS(sv) & (SVp_SCREAM|SVp_POK)) == (SVp_SCREAM|SVp_POK))
#define SvSCREAM_on(sv)		(SvFLAGS(sv) |= SVp_SCREAM)
#define SvSCREAM_off(sv)	(SvFLAGS(sv) &= ~SVp_SCREAM)

#define SvCOMPILED(sv)		(SvFLAGS(sv) & SVpfm_COMPILED)
#define SvCOMPILED_on(sv)	(SvFLAGS(sv) |= SVpfm_COMPILED)
#define SvCOMPILED_off(sv)	(SvFLAGS(sv) &= ~SVpfm_COMPILED)

#if defined (DEBUGGING) && defined(__GNUC__) && !defined(PERL_GCC_BRACE_GROUPS_FORBIDDEN)
#  define SvVALID(sv)		({ const SV *const _svvalid = (const SV*)(sv); \
				   if (SvFLAGS(_svvalid) & SVpbm_VALID)	\
				       assert(!isGV_with_GP(_svvalid));	\
				   (SvFLAGS(_svvalid) & SVpbm_VALID);	\
				})
#  define SvVALID_on(sv)	({ SV *const _svvalid = MUTABLE_SV(sv);	\
				   assert(!isGV_with_GP(_svvalid));	\
				   (SvFLAGS(_svvalid) |= SVpbm_VALID);	\
				})
#  define SvVALID_off(sv)	({ SV *const _svvalid = MUTABLE_SV(sv);	\
				   assert(!isGV_with_GP(_svvalid));	\
				   (SvFLAGS(_svvalid) &= ~SVpbm_VALID);	\
				})

#  define SvTAIL(sv)	({ const SV *const _svtail = (const SV *)(sv);	\
			    assert(SvTYPE(_svtail) != SVt_PVAV);		\
			    assert(SvTYPE(_svtail) != SVt_PVHV);		\
			    (SvFLAGS(sv) & (SVpbm_TAIL|SVpbm_VALID))	\
				== (SVpbm_TAIL|SVpbm_VALID);		\
			})
#else
#  define SvVALID(sv)		(SvFLAGS(sv) & SVpbm_VALID)
#  define SvVALID_on(sv)	(SvFLAGS(sv) |= SVpbm_VALID)
#  define SvVALID_off(sv)	(SvFLAGS(sv) &= ~SVpbm_VALID)
#  define SvTAIL(sv)	    ((SvFLAGS(sv) & (SVpbm_TAIL|SVpbm_VALID))	\
			     == (SVpbm_TAIL|SVpbm_VALID))

#endif
#define SvTAIL_on(sv)		(SvFLAGS(sv) |= SVpbm_TAIL)
#define SvTAIL_off(sv)		(SvFLAGS(sv) &= ~SVpbm_TAIL)


#define SvPAD_TYPED(sv) \
	((SvFLAGS(sv) & (SVpad_NAME|SVpad_TYPED)) == (SVpad_NAME|SVpad_TYPED))

#define SvPAD_OUR(sv)	\
	((SvFLAGS(sv) & (SVpad_NAME|SVpad_OUR)) == (SVpad_NAME|SVpad_OUR))

#if defined (DEBUGGING) && defined(__GNUC__) && !defined(PERL_GCC_BRACE_GROUPS_FORBIDDEN)
#define SvPAD_OUR_on(sv)	({					\
	    SV *const _svpad = MUTABLE_SV(sv);				\
	    assert(SvTYPE(_svpad) == SVt_PVMG);				\
	    (SvFLAGS(_svpad) |= SVpad_NAME|SVpad_OUR);			\
	})
#else
#  define SvPAD_OUR_on(sv)	(SvFLAGS(sv) |= SVpad_NAME|SVpad_OUR)
#endif

#define SvOURGV(sv) \
    ({ assert(SvPAD_OUR(sv));		       \
	((XPVMG*) SvANY(sv))->xmg_u.xmg_ourgv; \
     })

#define SvOURGV_set(sv, st)                                 \
        STMT_START {                                           \
           assert(SvTYPE(sv) == SVt_PVMG);                     \
           ((XPVMG*) SvANY(sv))->xmg_u.xmg_ourgv = st;      \
       } STMT_END


#define I_SvIV(sv) (((XPVIV*) SvANY(sv))->xiv_iv)
#define I_SvPVX(sv) ((sv)->sv_u.svu_pv)

#ifdef PERL_DEBUG_COW
/* Need -0.0 for SvNVX to preserve IEEE FP "negative zero" because
   +0.0 + -0.0 => +0.0 but -0.0 + -0.0 => -0.0 */
#  define SvUVX(sv) (0 + ((XPVUV*) SvANY(sv))->xuv_uv)
#  define SvNVX(sv) (-0.0 + ((XPVNV*) SvANY(sv))->xnv_u.xnv_nv)
#  define SvRV(sv) (0 + (sv)->sv_u.svu_rv)
#  define SvRV_const(sv) (0 + (sv)->sv_u.svu_rv)
/* Don't test the core XS code yet.  */
#  define SvLEN(sv) (0 + ((XPV*) SvANY(sv))->xpv_len)
#  define SvEND(sv) ((sv)->sv_u.svu_pv + ((XPV*)SvANY(sv))->xpv_cur)

#  ifdef DEBUGGING
#    define SvMAGIC(sv)	(0 + *(assert(SvTYPE(sv) >= SVt_PVMG), &((XPVMG*)  SvANY(sv))->xmg_u.xmg_magic))
#    define SvSTASH(sv)	(0 + *(assert(SvTYPE(sv) >= SVt_PVMG), &((XPVMG*)  SvANY(sv))->xmg_stash))
#  else
#    define SvMAGIC(sv)	(0 + ((XPVMG*)  SvANY(sv))->xmg_u.xmg_magic)
#    define SvSTASH(sv)	(0 + ((XPVMG*)  SvANY(sv))->xmg_stash)
#  endif
#else
#  define SvLEN(sv) ((XPV*) SvANY(sv))->xpv_len
#  define SvEND(sv) ((sv)->sv_u.svu_pv + ((XPV*)SvANY(sv))->xpv_cur)

#  if defined (DEBUGGING) && defined(__GNUC__) && !defined(PERL_GCC_BRACE_GROUPS_FORBIDDEN)
/* These get expanded inside other macros that already use a variable _sv  */
#    define SvUVX(sv)							\
	(*({ const SV *const _svuvx = (const SV *)(sv);			\
	    assert(SvTYPE(_svuvx) == SVt_IV || SvTYPE(_svuvx) >= SVt_PVIV); \
	    assert(SvTYPE(_svuvx) != SVt_PVAV);				\
	    assert(SvTYPE(_svuvx) != SVt_PVHV);				\
	    assert(SvTYPE(_svuvx) != SVt_PVCV);				\
	    assert(SvTYPE(_svuvx) != SVt_PVIO);				\
	    assert(!isGV_with_GP(_svuvx));				\
	    &(((XPVUV*) MUTABLE_PTR(SvANY(_svuvx)))->xuv_uv);		\
	 }))
#    define SvNVX(sv)							\
	(*({ const SV *const _svnvx = (const SV *)(sv);			\
	    assert(SvTYPE(_svnvx) == SVt_NV || SvTYPE(_svnvx) >= SVt_PVNV); \
	    assert(SvTYPE(_svnvx) != SVt_PVAV);				\
	    assert(SvTYPE(_svnvx) != SVt_PVHV);				\
	    assert(SvTYPE(_svnvx) != SVt_PVCV);				\
	    assert(SvTYPE(_svnvx) != SVt_PVIO);				\
	    assert(!isGV_with_GP(_svnvx));				\
	    &(((XPVNV*) MUTABLE_PTR(SvANY(_svnvx)))->xnv_u.xnv_nv);	\
	 }))
#    define SvRV(sv)							\
	(*({ SV *const _svrv = MUTABLE_SV(sv);				\
	    assert(SvTYPE(_svrv) >= SVt_PV || SvTYPE(_svrv) == SVt_IV);	\
	    assert(SvTYPE(_svrv) != SVt_PVAV);				\
	    assert(SvTYPE(_svrv) != SVt_PVHV);				\
	    assert(SvTYPE(_svrv) != SVt_PVCV);				\
	    assert(!isGV_with_GP(_svrv));				\
	    &((_svrv)->sv_u.svu_rv);					\
	 }))
#    define SvRV_const(sv)						\
	({ const SV *const _svrv = (const SV *)(sv);			\
	    assert(SvTYPE(_svrv) >= SVt_PV || SvTYPE(_svrv) == SVt_IV);	\
	    assert(SvTYPE(_svrv) != SVt_PVAV);				\
	    assert(SvTYPE(_svrv) != SVt_PVHV);				\
	    assert(SvTYPE(_svrv) != SVt_PVCV);				\
	    assert(SvTYPE(_svrv) != SVt_PVFM);				\
	    assert(!isGV_with_GP(_svrv));				\
	    (_svrv)->sv_u.svu_rv;					\
	 })
#    define SvMAGIC(sv)							\
	(*({ const SV *const _svmagic = (const SV *)(sv);		\
	    assert(SvTYPE(_svmagic) >= SVt_PVMG);			\
	    if(SvTYPE(_svmagic) == SVt_PVMG)				\
		assert(!SvPAD_OUR(_svmagic));				\
	    &(((XPVMG*) MUTABLE_PTR(SvANY(_svmagic)))->xmg_u.xmg_magic); \
	  }))
#    define SvSTASH(sv)							\
	(*({ const SV *const _svstash = (const SV *)(sv);		\
	    assert(SvTYPE(_svstash) >= SVt_PVMG);			\
	    &(((XPVMG*) MUTABLE_PTR(SvANY(_svstash)))->xmg_stash);	\
	  }))
#  else
#    define SvUVX(sv) ((XPVUV*) SvANY(sv))->xuv_uv
#    define SvNVX(sv) ((XPVNV*) SvANY(sv))->xnv_u.xnv_nv
#    define SvRV(sv) ((sv)->sv_u.svu_rv)
#    define SvRV_const(sv) (0 + (sv)->sv_u.svu_rv)
#    define SvMAGIC(sv)	((XPVMG*)  SvANY(sv))->xmg_u.xmg_magic
#    define SvSTASH(sv)	((XPVMG*)  SvANY(sv))->xmg_stash
#  endif
#endif


#define SvIV_set(sv, val) \
	STMT_START { assert(SvTYPE(sv) == SVt_IV || SvTYPE(sv) >= SVt_PVIV); \
		assert(SvTYPE(sv) != SVt_PVAV);		\
		assert(SvTYPE(sv) != SVt_PVHV);		\
		assert(SvTYPE(sv) != SVt_PVCV);		\
		assert(!isGV_with_GP(sv));		\
		(((XPVIV*)  SvANY(sv))->xiv_iv = (val)); } STMT_END
#define SvNV_set(sv, val) \
	STMT_START { assert(SvTYPE(sv) == SVt_NV || SvTYPE(sv) >= SVt_PVNV); \
	    assert(SvTYPE(sv) != SVt_PVAV); assert(SvTYPE(sv) != SVt_PVHV); \
	    assert(SvTYPE(sv) != SVt_PVCV); \
		assert(SvTYPE(sv) != SVt_PVIO);		\
		assert(!isGV_with_GP(sv));		\
		(((XPVNV*)SvANY(sv))->xnv_u.xnv_nv = (val)); } STMT_END
#define SvPV_set(sv, val) \
	STMT_START { assert(SvTYPE(sv) >= SVt_PV); \
		assert(SvTYPE(sv) != SVt_PVAV);		\
		assert(SvTYPE(sv) != SVt_PVHV);		\
		assert(!isGV_with_GP(sv));		\
		((sv)->sv_u.svu_pv = (val)); } STMT_END
#define SvUV_set(sv, val) \
	STMT_START { assert(SvTYPE(sv) == SVt_IV || SvTYPE(sv) >= SVt_PVIV); \
		assert(SvTYPE(sv) != SVt_PVAV);		\
		assert(SvTYPE(sv) != SVt_PVHV);		\
		assert(SvTYPE(sv) != SVt_PVCV);		\
		assert(!isGV_with_GP(sv));		\
		(((XPVUV*)SvANY(sv))->xuv_uv = (val)); } STMT_END
#define SvRV_set(sv, val) \
        STMT_START { assert(SvTYPE(sv) >=  SVt_PV || SvTYPE(sv) ==  SVt_IV); \
		assert(SvTYPE(sv) != SVt_PVAV);		\
		assert(SvTYPE(sv) != SVt_PVHV);		\
		assert(SvTYPE(sv) != SVt_PVCV);		\
		assert(!isGV_with_GP(sv));		\
                ((sv)->sv_u.svu_rv = (val)); } STMT_END
#define SvMAGIC_set(sv, val) \
        STMT_START { assert(SvTYPE(sv) >= SVt_PVMG); \
                (((XPVMG*)SvANY(sv))->xmg_u.xmg_magic = (val)); } STMT_END
#define SvSTASH_set(sv, val) \
        STMT_START { assert(SvTYPE(sv) >= SVt_PVMG); \
                (((XPVMG*)  SvANY(sv))->xmg_stash = (val)); } STMT_END
#define SvLEN_set(sv, val) \
	STMT_START { assert(SvTYPE(sv) >= SVt_PV); \
		assert(SvTYPE(sv) != SVt_PVAV);	\
		assert(SvTYPE(sv) != SVt_PVHV);	\
		assert(!isGV_with_GP(sv));	\
		(((XPV*)  SvANY(sv))->xpv_len = (val)); } STMT_END
#define SvEND_set(sv, val) \
	STMT_START { assert(SvTYPE(sv) >= SVt_PV); \
	    (SvCUR_set(sv, (val) - SvPVX_const(sv))); } STMT_END

#define SvPV_renew(sv,n) \
	STMT_START { SvLEN_set(sv, n); \
		SvPV_set((sv), (MEM_WRAP_CHECK_(n,char)			\
				(char*)saferealloc((Malloc_t)SvPVX_mutable(sv), \
						   (MEM_SIZE)((n)))));  \
		 } STMT_END

#define SvPV_shrink_to_cur(sv) STMT_START { \
		   const STRLEN _lEnGtH = SvCUR(sv) + 1; \
		   SvPV_renew(sv, _lEnGtH); \
		 } STMT_END

#define SvPV_free(sv)							\
    STMT_START {							\
		     assert(SvTYPE(sv) >= SVt_PV);			\
		     if (SvLEN(sv)) {					\
			 assert(!SvROK(sv));				\
			 if(SvOOK(sv)) {				\
			     STRLEN zok; 				\
			     SvOOK_offset(sv, zok);			\
			     SvPV_set(sv, SvPVX_mutable(sv) - zok);	\
			     SvFLAGS(sv) &= ~SVf_OOK;			\
			 }						\
			 Safefree(SvPVX_mutable(sv));				\
		     }							\
		 } STMT_END

#ifdef PERL_CORE
/* Code that crops up in three places to take a scalar and ready it to hold
   a reference */
#  define prepare_SV_for_RV(sv)						\
    STMT_START {							\
		    if (SvTYPE(sv) == SVt_PVAV || SvTYPE(sv) == SVt_PVHV)	\
			Perl_croak(aTHX_ "Can't update array or hash to ref"); \
		    if (SvTYPE(sv) < SVt_PV && SvTYPE(sv) != SVt_IV)	\
			sv_upgrade(sv, SVt_IV);				\
		    else if (SvTYPE(sv) >= SVt_PV) {			\
			SvPV_free(sv);					\
			SvLEN_set(sv, 0);				\
                        SvCUR_set(sv, 0);				\
		    }							\
		 } STMT_END
#endif

#define PERL_FBM_TABLE_OFFSET 1	/* Number of bytes between EOS and table */

/* SvPOKp not SvPOK in the assertion because the string can be tainted! eg
   perl -T -e '/$^X/'
*/
#if defined (DEBUGGING) && defined(__GNUC__) && !defined(PERL_GCC_BRACE_GROUPS_FORBIDDEN)
#  define BmFLAGS(sv)							\
	(*({ SV *const _bmflags = (SV *) (sv);				\
		assert(SvTYPE(_bmflags) == SVt_PVMG);			\
		assert(SvVALID(_bmflags));				\
	    &(((XPVGV*) SvANY(_bmflags))->xnv_u.xbm_s.xbm_flags);	\
	 }))
#  define BmRARE(sv)							\
	(*({ SV *const _bmrare = (SV *) (sv);				\
		assert(SvTYPE(_bmrare) == SVt_PVMG);			\
		assert(SvVALID(_bmrare));				\
	    &(((XPVGV*) SvANY(_bmrare))->xnv_u.xbm_s.xbm_rare);		\
	 }))
#  define BmUSEFUL(sv)							\
	(*({ SV *const _bmuseful = (SV *) (sv);				\
	    assert(SvTYPE(_bmuseful) == SVt_PVMG);			\
	    assert(SvVALID(_bmuseful));					\
	    assert(!SvIOK(_bmuseful));					\
	    &(((XPVGV*) SvANY(_bmuseful))->xiv_u.xivu_i32);		\
	 }))
#  define BmPREVIOUS(sv)						\
    (*({ SV *const _bmprevious = (SV *) (sv);				\
		assert(SvTYPE(_bmprevious) == SVt_PVMG);		\
		assert(SvVALID(_bmprevious));				\
	    &(((XPVGV*) SvANY(_bmprevious))->xnv_u.xbm_s.xbm_previous);	\
	 }))
#else
#  define BmFLAGS(sv)		((XPVMG*) SvANY(sv))->xnv_u.xbm_s.xbm_flags
#  define BmRARE(sv)		((XPVMG*) SvANY(sv))->xnv_u.xbm_s.xbm_rare
#  define BmUSEFUL(sv)		((XPVMG*) SvANY(sv))->xiv_u.xivu_i32
#  define BmPREVIOUS(sv)	((XPVMG*) SvANY(sv))->xnv_u.xbm_s.xbm_previous

#endif

#define IoIFP(sv)	((XPVIO*)  SvANY(sv))->xio_ifp
#define IoOFP(sv)	((XPVIO*)  SvANY(sv))->xio_ofp
#define IoDIRP(sv)	((XPVIO*)  SvANY(sv))->xio_dirp
#define IoANY(sv)	((XPVIO*)  SvANY(sv))->xio_any
#define IoLINES(sv)	((XPVIO*)  SvANY(sv))->xio_lines
#define IoTYPE(sv)	((XPVIO*)  SvANY(sv))->xio_type
#define IoFLAGS(sv)	((XPVIO*)  SvANY(sv))->xio_flags

/* IoTYPE(sv) is a single character telling the type of I/O connection. */
#define IoTYPE_RDONLY		'<'
#define IoTYPE_WRONLY		'>'
#define IoTYPE_RDWR		'+'
#define IoTYPE_APPEND 		'a'
#define IoTYPE_PIPE		'|'
#define IoTYPE_STD		'-'	/* stdin or stdout */
#define IoTYPE_SOCKET		's'
#define IoTYPE_CLOSED		' '
#define IoTYPE_IMPLICIT		'I'	/* stdin or stdout or stderr */
#define IoTYPE_NUMERIC		'#'	/* fdopen */

/* all these 'functions' are now just macros */

#define sv_pv(sv) SvPV_nolen(sv)

#define sv_pvn_force_nomg(sv, lp) sv_pvn_force_flags(sv, lp, 0)
#define sv_catpvn_nomg(dsv, sstr, slen) sv_catpvn_flags(dsv, sstr, slen, 0)
#define sv_setsv(dsv, ssv) \
	sv_setsv_flags(dsv, ssv, SV_DO_COW_SVSETSV)
#define sv_setsv_nomg(dsv, ssv) sv_setsv_flags(dsv, ssv, SV_DO_COW_SVSETSV)
#define sv_catsv(dsv, ssv) sv_catsv_flags(dsv, ssv, 0)
#define sv_catsv_nomg(dsv, ssv) sv_catsv_flags(dsv, ssv, 0)
#define sv_catsv_mg(dsv, ssv) sv_catsv_flags(dsv, ssv, SV_SMAGIC)
#define sv_catpvn(dsv, sstr, slen) sv_catpvn_flags(dsv, sstr, slen, 0)
#define sv_catpvn_mg(sv, sstr, slen) \
	sv_catpvn_flags(sv, sstr, slen, SV_SMAGIC);
#define sv_2pv(sv, lp) sv_2pv_flags(sv, lp, 0)
#define sv_2pv_nolen(sv) sv_2pv(sv, 0)
#define sv_2pv_nomg(sv, lp) sv_2pv_flags(sv, lp, 0)
#define sv_pvn_force(sv, lp) sv_pvn_force_flags(sv, lp, 0)
/*
=for apidoc Am|char*|SvPV_force|SV* sv|STRLEN len
Like C<SvPV> but will force the SV into containing just a string
(C<SvPOK_only>).  You want force if you are going to update the C<SvPVX>
directly.

=for apidoc Am|char*|SvPV_force_nomg|SV* sv|STRLEN len
Like C<SvPV> but will force the SV into containing just a string
(C<SvPOK_only>).  You want force if you are going to update the C<SvPVX>
directly. Doesn't process magic.

=for apidoc Am|char*|SvPV|SV* sv|STRLEN len
Returns a pointer to the string in the SV, or a stringified form of
the SV if the SV does not contain a string.  The SV may cache the
stringified version becoming C<SvPOK>.  Handles 'get' magic. See also
C<SvPVx> for a version which guarantees to evaluate sv only once.

=for apidoc Am|char*|SvPVx|SV* sv|STRLEN len
A version of C<SvPV> which guarantees to evaluate C<sv> only once.
Only use this if C<sv> is an expression with side effects, otherwise use the
more efficient C<SvPVX>.

=for apidoc Am|char*|SvPV_nolen|SV* sv
Returns a pointer to the string in the SV, or a stringified form of
the SV if the SV does not contain a string.  The SV may cache the
stringified form becoming C<SvPOK>.  Handles 'get' magic.

=for apidoc Am|IV|SvIV|SV* sv
Coerces the given SV to an integer and returns it.

=for apidoc Am|IV|SvIV_nomg|SV* sv
Like C<SvIV> but doesn't process magic.

=for apidoc Am|NV|SvNV|SV* sv
Coerce the given SV to a double and return it.

=for apidoc Am|UV|SvUV|SV* sv
Coerces the given SV to an unsigned integer and returns it.

=for apidoc Am|UV|SvUV_nomg|SV* sv
Like C<SvUV> but doesn't process magic.

=for apidoc Am|bool|SvTRUE|SV* sv
Returns a boolean indicating whether Perl would evaluate the SV as true or
false, defined or undefined.  Does not handle 'get' magic.

=for apidoc Am|bool|SvIsCOW|SV* sv
Returns a boolean indicating whether the SV is Copy-On-Write. (either shared
hash key scalars, or full Copy On Write scalars if 5.9.0 is configured for
COW)

=for apidoc Am|bool|SvIsCOW_shared_hash|SV* sv
Returns a boolean indicating whether the SV is Copy-On-Write shared hash key
scalar.

=for apidoc Am|void|sv_catpvn_nomg|SV* sv|const char* ptr|STRLEN len
Like C<sv_catpvn> but doesn't process magic.

=for apidoc Am|void|sv_setsv_nomg|SV* dsv|SV* ssv
Like C<sv_setsv> but doesn't process magic.

=for apidoc Am|void|sv_catsv_nomg|SV* dsv|SV* ssv
Like C<sv_catsv> but doesn't process magic.

=cut
*/

/* ----*/

#define SvPV(sv, lp) SvPV_flags(sv, lp, 0)
#define SvPV_const(sv, lp) SvPV_flags_const(sv, lp, 0)
#define SvPV_mutable(sv, lp) SvPV_flags_mutable(sv, lp, 0)

#define SvPV_flags(sv, lp, flags) \
    ((SvFLAGS(sv) & (SVf_POK)) == SVf_POK \
     ? ((lp = SvCUR(sv)), SvPVX_mutable(sv)) : sv_2pv_flags(sv, &lp, flags))
#define SvPV_flags_const(sv, lp, flags) \
    ((SvFLAGS(sv) & (SVf_POK)) == SVf_POK \
     ? ((lp = SvCUR(sv)), SvPVX_const(sv)) : \
     (const char*) sv_2pv_flags(sv, &lp, flags|SV_CONST_RETURN))
#define SvPV_flags_const_nolen(sv, flags) \
    ((SvFLAGS(sv) & (SVf_POK)) == SVf_POK \
     ? SvPVX_const(sv) : \
     (const char*) sv_2pv_flags(sv, 0, flags|SV_CONST_RETURN))
#define SvPV_flags_mutable(sv, lp, flags) \
    ((SvFLAGS(sv) & (SVf_POK)) == SVf_POK \
     ? ((lp = SvCUR(sv)), SvPVX_mutable(sv)) : \
     sv_2pv_flags(sv, &lp, flags|SV_MUTABLE_RETURN))

#define SvPV_force(sv, lp) SvPV_force_flags(sv, lp, 0)
#define SvPV_force_nolen(sv) SvPV_force_flags_nolen(sv, 0)
#define SvPV_force_mutable(sv, lp) SvPV_force_flags_mutable(sv, lp, 0)

#define SvPV_force_nomg(sv, lp) SvPV_force_flags(sv, lp, 0)
#define SvPV_force_nomg_nolen(sv) SvPV_force_flags_nolen(sv, 0)

#define SvPV_force_flags(sv, lp, flags) \
    ((SvFLAGS(sv) & (SVf_POK|SVf_THINKFIRST)) == SVf_POK \
    ? ((lp = SvCUR(sv)), SvPVX_mutable(sv)) : sv_pvn_force_flags(sv, &lp, flags))
#define SvPV_force_flags_nolen(sv, flags) \
    ((SvFLAGS(sv) & (SVf_POK|SVf_THINKFIRST)) == SVf_POK \
    ? SvPVX_mutable(sv) : sv_pvn_force_flags(sv, 0, flags))
#define SvPV_force_flags_mutable(sv, lp, flags) \
    ((SvFLAGS(sv) & (SVf_POK|SVf_THINKFIRST)) == SVf_POK \
    ? ((lp = SvCUR(sv)), SvPVX_mutable(sv)) \
     : sv_pvn_force_flags(sv, &lp, flags|SV_MUTABLE_RETURN))

#define SvPV_nolen(sv) \
    ((SvFLAGS(sv) & (SVf_POK)) == SVf_POK \
     ? SvPVX_mutable(sv) : sv_2pv_flags(sv, 0, 0))

#define SvPV_nolen_const(sv) \
    ((SvFLAGS(sv) & (SVf_POK)) == SVf_POK \
     ? SvPVX_const(sv) : sv_2pv_flags(sv, 0, SV_CONST_RETURN))

/* ----*/

/* define FOOx(): idempotent versions of FOO(). If possible, use a local
 * var to evaluate the arg once; failing that, use a global if possible;
 * failing that, call a function to do the work
 */

#define SvPVx_force(sv, lp) sv_pvn_force(sv, &lp)

#define SvIsCOW(sv)		((SvFLAGS(sv) & (SVf_FAKE | SVf_READONLY)) == \
				    (SVf_FAKE | SVf_READONLY))
#define SvIsCOW_shared_hash(sv)	(SvIsCOW(sv) && SvLEN(sv) == 0)

#define SvSHARED_HEK_FROM_PV(pvx) \
	((struct hek*)(pvx - STRUCT_OFFSET(struct hek, hek_key)))
#define SvSHARED_HASH(sv) (0 + SvSHARED_HEK_FROM_PV(SvPVX_const(sv))->hek_hash)

/* flag values for sv_*_flags functions */
#define SV_IMMEDIATE_UNREF	1
#define SV_COW_DROP_PV		4
#define SV_NOSTEAL		16
#define SV_CONST_RETURN		32
#define SV_MUTABLE_RETURN	64
#define SV_SMAGIC		128
#define SV_HAS_TRAILING_NUL	256
#define SV_COW_SHARED_HASH_KEYS	512
/* This one is only enabled for PERL_OLD_COPY_ON_WRITE */
#define SV_COW_OTHER_PVS	1024
/* Make sv_2pv_flags return NULL if something is undefined.  */
#define SV_UNDEF_RETURNS_NULL	2048

/* The core is safe for this COW optimisation. XS code on CPAN may not be.
   So only default to doing the COW setup if we're in the core.
 */
#ifdef PERL_CORE
#  ifndef SV_DO_COW_SVSETSV
#    define SV_DO_COW_SVSETSV	SV_COW_SHARED_HASH_KEYS|SV_COW_OTHER_PVS
#  endif
#endif

#ifndef SV_DO_COW_SVSETSV
#  define SV_DO_COW_SVSETSV	0
#endif


#define sv_unref(sv)    	sv_unref_flags(sv, 0)
#define sv_force_normal(sv)	sv_force_normal_flags(sv, 0)
#define sv_usepvn(sv, p, l)	sv_usepvn_flags(sv, p, l, 0)
#define sv_usepvn_mg(sv, p, l)	sv_usepvn_flags(sv, p, l, SV_SMAGIC)

/* We are about to replace the SV's current value. So if it's copy on write
   we need to normalise it. Use the SV_COW_DROP_PV flag hint to say that
   the value is about to get thrown away, so drop the PV rather than go to
   the effort of making a read-write copy only for it to get immediately
   discarded.  */

#define SV_CHECK_THINKFIRST_COW_DROP(sv) if (SvTHINKFIRST(sv)) \
				    sv_force_normal_flags(sv, SV_COW_DROP_PV)

#ifdef PERL_OLD_COPY_ON_WRITE
#define SvRELEASE_IVX(sv)   \
    ((SvIsCOW(sv) ? sv_force_normal_flags(sv, 0) : (void) 0), 0)
#  define SvIsCOW_normal(sv)	(SvIsCOW(sv) && SvLEN(sv))
#  define SvRELEASE_IVX_(sv)	SvRELEASE_IVX(sv),
#else
#  define SvRELEASE_IVX(sv)   0
/* This little game brought to you by the need to shut this warning up:
mg.c: In function `Perl_magic_get':
mg.c:1024: warning: left-hand operand of comma expression has no effect
*/
#  define SvRELEASE_IVX_(sv)  /**/
#endif /* PERL_OLD_COPY_ON_WRITE */

#define CAN_COW_MASK	(SVs_OBJECT|SVs_SMG|SVs_RMG|SVf_IOK|SVf_NOK| \
			 SVf_POK|SVf_ROK|SVp_IOK|SVp_NOK|SVp_POK|SVf_FAKE| \
			 SVf_OOK|SVf_BREAK|SVf_READONLY)
#define CAN_COW_FLAGS	(SVp_POK|SVf_POK)

#define SV_CHECK_THINKFIRST(sv) if (SvTHINKFIRST(sv)) \
				    sv_force_normal_flags(sv, 0)


/* all these 'functions' are now just macros */

#define sv_pv(sv) SvPV_nolen(sv)

#define sv_pvn_force_nomg(sv, lp) sv_pvn_force_flags(sv, lp, 0)
#define sv_catpvn_nomg(dsv, sstr, slen) sv_catpvn_flags(dsv, sstr, slen, 0)
#define sv_setsv_nomg(dsv, ssv) sv_setsv_flags(dsv, ssv, SV_DO_COW_SVSETSV)
#define sv_catsv_nomg(dsv, ssv) sv_catsv_flags(dsv, ssv, 0)
#define sv_2pv_nolen(sv) sv_2pv(sv, 0)
#define sv_2pv_nomg(sv, lp) sv_2pv_flags(sv, lp, 0)
#define sv_insert(bigstr, offset, len, little, littlelen)		\
	Perl_sv_insert_flags(aTHX_ (bigstr),(offset), (len), (little),	\
			     (littlelen), 0)

/*
=for apidoc Am|SV*|newRV_inc|SV* sv

Creates an RV wrapper for an SV.  The reference count for the original SV is
incremented.

=cut
*/

#define newRV_inc(sv)	newRV(sv)

/* the following macros update any magic values this sv is associated with */

/*
=head1 Magical Functions

=for apidoc Am|void|SvSETMAGIC|SV* sv
Invokes C<mg_set> on an SV if it has 'set' magic.  This macro evaluates its
argument more than once.

=for apidoc Am|void|SvSetSV|SV* dsb|SV* ssv
Calls C<sv_setsv> if dsv is not the same as ssv.  May evaluate arguments
more than once.

=for apidoc Am|void|SvSetSV_nosteal|SV* dsv|SV* ssv
Calls a non-destructive version of C<sv_setsv> if dsv is not the same as
ssv. May evaluate arguments more than once.

=for apidoc Am|void|SvSetMagicSV|SV* dsb|SV* ssv
Like C<SvSetSV>, but does any set magic required afterwards.

=for apidoc Am|void|SvSetMagicSV_nosteal|SV* dsv|SV* ssv
Like C<SvSetSV_nosteal>, but does any set magic required afterwards.

=for apidoc Am|void|SvSHARE|SV* sv
Arranges for sv to be shared between threads if a suitable module
has been loaded.

=for apidoc Am|void|SvLOCK|SV* sv
Arranges for a mutual exclusion lock to be obtained on sv if a suitable module
has been loaded.

=for apidoc Am|void|SvUNLOCK|SV* sv
Releases a mutual exclusion lock on sv if a suitable module
has been loaded.

=head1 SV Manipulation Functions

=for apidoc Am|char *|SvGROW|SV* sv|STRLEN len
Expands the character buffer in the SV so that it has room for the
indicated number of bytes (remember to reserve space for an extra trailing
NUL character).  Calls C<sv_grow> to perform the expansion if necessary.
Returns a pointer to the character buffer.

=cut
*/

#define SvSHARE(sv) CALL_FPTR(PL_sharehook)(aTHX_ sv)
#define SvLOCK(sv) CALL_FPTR(PL_lockhook)(aTHX_ sv)
#define SvUNLOCK(sv) CALL_FPTR(PL_unlockhook)(aTHX_ sv)

#define SvSETMAGIC(x) STMT_START { if (SvSMAGICAL(x)) mg_set(x); } STMT_END

#define SvSetSV_and(dst,src,finally) \
	STMT_START {					\
	    if ((dst) != (src)) {			\
		sv_setsv(dst, src);			\
		finally;				\
	    }						\
	} STMT_END
#define SvSetSV_nosteal_and(dst,src,finally) \
	STMT_START {					\
	    if ((dst) != (src)) {			\
		sv_setsv_flags(dst, src, SV_NOSTEAL | SV_DO_COW_SVSETSV);	\
		finally;				\
	    }						\
	} STMT_END

#define SvSetSV(dst,src) \
		SvSetSV_and(dst,src,/*nothing*/;)
#define SvSetSV_nosteal(dst,src) \
		SvSetSV_nosteal_and(dst,src,/*nothing*/;)

#define SvSetMagicSV(dst,src) \
		SvSetSV_and(dst,src,SvSETMAGIC(dst))
#define SvSetMagicSV_nosteal(dst,src) \
		SvSetSV_nosteal_and(dst,src,SvSETMAGIC(dst))


#if !defined(SKIP_DEBUGGING)
#define SvPEEK(sv) sv_peek(sv)
#else
#define SvPEEK(sv) ""
#endif

#define SvIMMORTAL(sv) ((sv)==&PL_sv_undef || (sv)==&PL_sv_yes || (sv)==&PL_sv_no || (sv)==&PL_sv_placeholder)

#define boolSV(b) ((b) ? &PL_sv_yes : &PL_sv_no)

#define isGV(sv) (SvTYPE(sv) == SVt_PVGV)
/* If I give every macro argument a different name, then there won't be bugs
   where nested macros get confused. Been there, done that.  */
#define isGV_with_GP(pwadak) \
	(((SvFLAGS(pwadak) & (SVp_POK|SVpgv_GP)) == SVpgv_GP)	\
	    && (SvTYPE(pwadak) == SVt_PVGV))
#define isGV_with_GP_on(sv)	STMT_START {			       \
	assert (SvTYPE(sv) == SVt_PVGV); \
	assert (!SvPOKp(sv));					       \
	assert (!SvIOKp(sv));					       \
	(SvFLAGS(sv) |= SVpgv_GP);				       \
    } STMT_END
#define isGV_with_GP_off(sv)	STMT_START {			       \
	assert (SvTYPE(sv) == SVt_PVGV); \
	assert (!SvPOKp(sv));					       \
	assert (!SvIOKp(sv));					       \
	(SvFLAGS(sv) &= ~SVpgv_GP);				       \
    } STMT_END


#define SvGROW(sv,len) (SvLEN(sv) < (len) ? sv_grow(sv,len) : SvPVX_mutable(sv))
#define SvGROW_mutable(sv,len) \
    (SvLEN(sv) < (len) ? sv_grow(sv,len) : SvPVX_mutable(sv))
#define Sv_Grow sv_grow

#define CLONEf_COPY_STACKS 1
#define CLONEf_KEEP_PTR_TABLE 2
#define CLONEf_CLONE_HOST 4
#define CLONEf_JOIN_IN 8

struct clone_params {
  AV* stashes;
  UV  flags;
  PerlInterpreter *proto_perl;
};

/*
=for apidoc Am|void|SvOOK_offset|NN SV*sv|STRLEN len

Reads into I<len> the offset from SvPVX back to the true start of the
allocated buffer, which will be non-zero if C<sv_chop> has been used to
efficiently remove characters from start of the buffer. Implemented as a
macro, which takes the address of I<len>, which must be of type C<STRLEN>.
Evaluates I<sv> more than once. Sets I<len> to 0 if C<SvOOK(sv)> is false.

=cut
*/

#ifdef DEBUGGING
/* Does the bot know something I don't?
10:28 <@Nicholas> metabatman
10:28 <+meta> Nicholas: crash
*/
#  define SvOOK_offset(sv, offset) STMT_START {				\
	assert(sizeof(offset) == sizeof(STRLEN));			\
	if (SvOOK(sv)) {						\
	    const U8 *crash = (U8*)SvPVX_const(sv);			\
	    offset = *--crash;						\
 	    if (!offset) {						\
		crash -= sizeof(STRLEN);				\
		Copy(crash, (U8 *)&offset, sizeof(STRLEN), U8);		\
	    }								\
	    {								\
		/* Validate the preceding buffer's sentinels to		\
		   verify that no-one is using it.  */			\
		const U8 *const bonk = (U8 *) SvPVX_const(sv) - offset;	\
		while (crash > bonk) {					\
		    --crash;						\
		    assert (*crash == (U8)PTR2UV(crash));		\
		}							\
	    }								\
	} else {							\
	    offset = 0;							\
	}								\
    } STMT_END
#else
    /* This is the same code, but avoids using any temporary variables:  */
#  define SvOOK_offset(sv, offset) STMT_START {				\
	assert(sizeof(offset) == sizeof(STRLEN));			\
	if (SvOOK(sv)) {						\
	    offset = ((U8*)SvPVX_const(sv))[-1];			\
	    if (!offset) {						\
		Copy(SvPVX_const(sv) - 1 - sizeof(STRLEN),		\
		     (U8 *)&offset, sizeof(STRLEN), U8);		\
	    }								\
	} else {							\
	    offset = 0;							\
	}								\
    } STMT_END
#endif
/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
