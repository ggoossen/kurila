/*    op.h
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2002, 2003, 2004, 2005, 2006 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * The fields of BASEOP are:
 *	op_next		Pointer to next ppcode to execute after this one.
 *			(Top level pre-grafted op points to first op,
 *			but this is replaced when op is grafted in, when
 *			this op will point to the real next op, and the new
 *			parent takes over role of remembering starting op.)
 *	op_ppaddr	Pointer to current ppcode's function.
 *	op_type		The type of the operation.
 *	op_opt		Whether or not the op has been optimised by the
 *			peephole optimiser.
 *
 *			See the comments in S_clear_yystack() for more
 *			details on the following three flags:
 *
 *	op_latefree	tell op_free() to clear this op (and free any kids)
 *			but not yet deallocate the struct. This means that
 *			the op may be safely op_free()d multiple times
 *	op_latefreed	an op_latefree op has been op_free()d
 *	op_attached	this op (sub)tree has been attached to a CV
 *
 *	op_spare	three spare bits!
 *	op_flags	Flags common to all operations.  See OPf_* below.
 *	op_private	Flags peculiar to a particular operation (BUT,
 *			by default, set to the number of children until
 *			the operation is privatized by a check routine,
 *			which may or may not check number of children).
 */

#define OPCODE U16
#define OPFLAGS U16

#ifdef PERL_MAD
#  define MADPROP_IN_BASEOP	MADPROP*	op_madprop;
#else
#  define MADPROP_IN_BASEOP
#endif

typedef PERL_BITFIELD16 optype;

#ifdef BASEOP_DEFINITION
#define BASEOP BASEOP_DEFINITION
#else
#define BASEOP				\
    OP*		op_next;		\
    OP*		op_sibling;		\
    OP*		(CPERLscope(*op_ppaddr))(pTHX);		\
    SV*         op_location;            \
    MADPROP_IN_BASEOP			\
    PADOFFSET	op_targ;		\
    PERL_BITFIELD16 op_type:9;		\
    PERL_BITFIELD16 op_opt:1;		\
    PERL_BITFIELD16 op_spare:3;		\
    OPFLAGS		op_flags;		\
    U8		op_private;
#endif

/* If op_type:9 is changed to :10, also change PUSHEVAL in cop.h.
   Also, if the type of op_type is ever changed (e.g. to PERL_BITFIELD32)
   then all the other bit-fields before/after it should change their
   types too to let VC pack them into the same 4 byte integer.*/

#define OP_GIMME(op,dfl) \
	(((op)->op_flags & OPf_WANT) == OPf_WANT_VOID   ? G_VOID   : \
	 ((op)->op_flags & OPf_WANT) == OPf_WANT_SCALAR ? G_SCALAR : \
	 ((op)->op_flags & OPf_WANT) == OPf_WANT_LIST   ? G_ARRAY   : \
	 dfl)

#define OP_GIMME_REVERSE(flags)	((flags) & G_WANT)

/*
=head1 "Gimme" Values

=for apidoc Amn|U32|GIMME_V
The XSUB-writer's equivalent to Perl's C<wantarray>.  Returns C<G_VOID>,
C<G_SCALAR> or C<G_ARRAY> for void, scalar or list context,
respectively.

=for apidoc Amn|U32|GIMME
A backward-compatible version of C<GIMME_V> which can only return
C<G_SCALAR> or C<G_ARRAY>; in a void context, it returns C<G_SCALAR>.
Deprecated.  Use C<GIMME_V> instead.

=cut
*/

#define GIMME_V		OP_GIMME(PL_op, block_gimme())

/* Public flags */

#define OPf_WANT	3	/* Mask for "want" bits: */
#define  OPf_WANT_VOID	 1	/*   Want nothing */
#define  OPf_WANT_SCALAR 2	/*   Want single value */
#define  OPf_WANT_LIST	 3	/*   Want list of any length */
#define OPf_KIDS	4	/* There is a firstborn child. */
#define OPf_PARENS	8	/* This operator was parenthesized. */
				/*  (Or block needs explicit scope entry.) */
#define OPf_REF		16	/* Certified reference. */
				/*  (Return container, not containee). */
#define OPf_MOD		32	/* Will modify (lvalue). */
#define OPf_STACKED	64	/* Some arg is arriving on the stack. */
#define OPf_SPECIAL	128	/* Do something weird for this op: */
				/*  On local LVAL, don't init local value. */
				/*  On OP_SORT, subroutine is inlined. */
				/*  On OP_NOT, inversion was implicit. */
				/*  On OP_LEAVE, don't restore curpm. */
				/*  On truncate, we truncate filehandle */
				/*  On control verbs, we saw no label */
				/*  On flipflop, we saw ... instead of .. */
				/*  On UNOPs, saw bare parens, e.g. eof(). */
				/*  On OP_ENTERSUB || OP_NULL, saw a "do". */
				/*  On OP_EXISTS, treat av as av, not avhv.  */
				/*  On OP_(ENTER|LEAVE)EVAL, don't clear $@ */
				/*  On OP_ENTERITER, two items on the stack are the for loop range */
				/*  On pushre, re is /\s+/ imp. by split " " */
				/*  On regcomp, "use re 'eval'" was in scope */
				/*  On OP_READLINE, was <$filehandle> */
				/*  On RV2[ACGHS]V, don't create GV--in
				    defined()*/
				/*  On OP_DBSTATE, indicates breakpoint
				 *    (runtime property) */
				/*  On OP_AELEMFAST, indiciates pad var */
				/*  On OP_REQUIRE, was seen as CORE::require */
				/*  On OP_BREAK, an implicit break */
				/*  On OP_ANONHASH and OP_ANONARRAY, create a
				    reference to the new anon hash or array */
				/*  On OP_AASIGN last element of the assignment is an expanded array/hash */
#define OPf_ASSIGN      0x100   /*  op should do an assignment */
#define OPf_ASSIGN_PART 0x200   /* op should do an assignment using
                                   "pop_assing_part" and without pusing
                                   onto the stack */
#define OPf_OPTIONAL      0x400   /*  assignment is optional, flags
				      should be passed to "pop_assign_part"
				  */
#define OPf_TARGET_MY	0x800	/* Target is PADMY. (for ops with TARGLEX */


/* old names; don't use in new code, but don't break them, either */
#define OPf_LIST	OPf_WANT_LIST
#define OPf_KNOW	OPf_WANT

#define GIMME \
	  (PL_op->op_flags & OPf_WANT					\
	   ? ((PL_op->op_flags & OPf_WANT) == OPf_WANT_LIST		\
	      ? G_ARRAY							\
	      : G_SCALAR)						\
	   : dowantarray())

/* NOTE: OP_NEXTSTATE, OP_DBSTATE, and OP_SETSTATE (i.e. COPs) carry lower
 * bits of PL_hints in op_private */

/* Private for lvalues */
#define OPpLVAL_INTRO	128	/* Lvalue must be localized or lvalue sub */

/* Private for OP_MATCH and OP_SUBST{,CONST} */
#define OPpRUNTIME		64	/* Pattern coming in on the stack */

/* Private for OP_REPEAT */
#define OPpREPEAT_DOLIST	64	/* List replication. */

/* Private for OP_RV2GV, OP_RV2SV, OP_AELEM, OP_HELEM, OP_PADSV */
#define OPpDEREF		(32|64)	/* autovivify: Want ref to something: */
#define OPpDEREF_AV		32	/*   Want ref to AV. */
#define OPpDEREF_HV		64	/*   Want ref to HV. */
#define OPpDEREF_SV		(32|64)	/*   Want ref to SV. */

  /* OP_ENTERSUB only */
#define OPpENTERSUB_BLOCK       2       /* Accepts only one arguments which is assigned to my $_ */
#define OPpENTERSUB_DB		16	/* Debug subroutine. */
#define OPpENTERSUB_HASTARG	32	/* Called from OP tree. */
  /* OP_ENTERSUB and OP_RV2CV only */
#define OPpENTERSUB_AMPER	8	/* Used & form to call. */
#define OPpENTERSUB_INARGS	4	/* Lval used as arg to a sub. */
#define OPpENTERSUB_SAVEARGS    128     /* Save the arguments in the targ */
#define OPpENTERSUB_TARGARGS    64      /* Use the save argument in targ */
#define OPpENTERSUB_SAVE_DISCARD  2   /* Discard the value returned */

  /* OP_GV only */
#define OPpEARLY_CV		32	/* foo() called before sub foo was parsed */
/* Private for OP_HELEM and OP_AELEM */
#define OPpELEM_ADD            8       /* Add key if it doesn't exist */
#define OPpELEM_OPTIONAL       4       /* Ignore if the key does not exist */

  /* OP_RV2?V, OP_GVSV, OP_ENTERITER only */
#define OPpOUR_INTRO		16	/* Variable was in an our() */
  /* OP_PADSV only */
  /* for OP_RV2?V, lower bits carry hints (currently only HINT_STRICT_REFS) */

/* Private for OP_ENTERITER and OP_ITER */
#define OPpITER_REVERSED	4	/* for (reverse ...) */
#define OPpITER_DEF		8	/* for $_ or for my $_ */

/* Private for OP_CONST */
#define	OPpCONST_SHORTCIRCUIT	4	/* eg the constant 5 in (5 || foo) */
#define	OPpCONST_STRICT		8	/* bearword subject to strict 'subs' */
#define OPpCONST_ENTERED	16	/* Has been entered as symbol. */
#define OPpCONST_BARE		64	/* Was a bare word (filehandle?). */

/* Private for OP_FLIP/FLOP */
#define OPpFLIP_LINENUM		64	/* Range arg potentially a line num. */

/* Private for OP_LIST */
#define OPpLIST_GUESSED		64	/* Guessed that pushmark was needed. */

/* Private for OP_DELETE */
#define OPpSLICE		64	/* Operating on a list of keys */

/* Private for OP_EXISTS */
#define OPpEXISTS_SUB		64	/* Checking for &sub, not {} or [].  */

/* Private for OP_SORT */
#define OPpSORT_NUMERIC		1	/* Optimized away { $a <=> $b } */
#define OPpSORT_INTEGER		2	/* Ditto while under "use integer" */
#define OPpSORT_REVERSE		4	/* Reversed sort */
#define OPpSORT_DESCEND		16	/* Descending sort */
#define OPpSORT_QSORT		32	/* Use quicksort (not mergesort) */
#define OPpSORT_STABLE		64	/* Use a stable algorithm */

/* Private for OP_OPEN and OP_BACKTICK */
#define OPpOPEN_IN_RAW		16	/* binmode(F,":raw") on input fh */
#define OPpOPEN_IN_CRLF		32	/* binmode(F,":crlf") on input fh */
#define OPpOPEN_OUT_RAW		64	/* binmode(F,":raw") on output fh */
#define OPpOPEN_OUT_CRLF	128	/* binmode(F,":crlf") on output fh */

/* Private for OP_EXIT, HUSH also for OP_DIE */
#define OPpHUSH_VMSISH		64	/* hush DCL exit msg vmsish mode*/
#define OPpEXIT_VMSISH		128	/* exit(0) vs. exit(1) vmsish mode*/

/* Private for OP_FTXXX */
#define OPpFT_ACCESS		2	/* use filetest 'access' */
#define OPpFT_STACKED		4	/* stacked filetest, as in "-f -x $f" */

/* Private for OP_ENTEREVAL */
#define OPpEVAL_HAS_HH		2	/* Does it have a copy of %^H */

struct op {
    BASEOP
};

struct unop {
    BASEOP
    OP *	op_first;
};

struct binop {
    BASEOP
    OP *	op_first;
    OP *	op_last;
};

struct logop {
    BASEOP
    OP *	op_first;
    OP *	op_other;
};

struct listop {
    BASEOP
    OP *	op_first;
    OP *	op_last;
};

struct pmop {
    BASEOP
    OP *	op_first;
    OP *	op_last;
    REGEXP *    op_pmregexp;            /* compiled expression */
    U32         op_pmflags;
    union {
	OP *	op_pmreplroot;		/* For OP_SUBST */
	GV *	op_pmtargetgv;
    }	op_pmreplrootu;
    union {
	OP *	op_pmreplstart;	/* Only used in OP_SUBST */
    }		op_pmstashstartu;
};

#define PM_GETRE(o)     ((o)->op_pmregexp)
#define PM_SETRE(o,r)   ((o)->op_pmregexp = (r))


#define PMf_UNSED	0x0002		/* was PMf_ONCE */

#define PMf_NOTUSED2	0x0004		/* free for use */
#define PMf_MAYBE_CONST	0x0008		/* replacement contains variables */

#define PMf_NOTUSED3    0x0010          /* was PMf_USED */

#define PMf_CONST	0x0040		/* subst replacement is constant */
#define PMf_KEEP	0x0080		/* keep 1st runtime pattern forever */
#define PMf_GLOBAL	0x0100		/* pattern had a g modifier */
#define PMf_CONTINUE	0x0200		/* don't reset pos() if //g fails */

/* The following flags have exact equivalents in regcomp.h with the prefix RXf_
 * which are stored in the regexp->extflags member. If you change them here,
 * you have to change them there, and vice versa.
 */
#define PMf_NOTUSED	0x0800		/* not used. was: use locale for character types */
#define PMf_MULTILINE	0x1000		/* assume multiple lines */
#define PMf_SINGLELINE	0x2000		/* assume single line */
#define PMf_FOLD	0x4000		/* case insensitivity */
#define PMf_EXTENDED	0x8000		/* chuck embedded whitespace */
#define PMf_UTF8	0x10000		/* unicode characters */
#define PMf_KEEPCOPY	0x20000		/* copy the string when matching */

/* mask of bits that need to be transfered to re->extflags */
#define PMf_COMPILETIME	(PMf_MULTILINE|PMf_SINGLELINE|PMf_FOLD|PMf_EXTENDED|PMf_KEEPCOPY|PMf_UTF8)

struct svop {
    BASEOP
    SV *	op_sv;
};

struct padop {
    BASEOP
    PADOFFSET	op_padix;
};

struct pvop {
    BASEOP
    char *	op_pv;
};

struct loop {
    BASEOP
    OP *	op_first;
    OP *	op_last;
    OP *	op_redoop;
    OP *	op_nextop;
    OP *	op_lastop;
};

struct rootop {
    BASEOP
    OP *	op_first;
    ROOTOP *	op_prev_root;
    ROOTOP *	op_next_root;
};

#define cUNOPx(o)	((UNOP*)o)
#define cBINOPx(o)	((BINOP*)o)
#define cLISTOPx(o)	((LISTOP*)o)
#define cLOGOPx(o)	((LOGOP*)o)
#define cPMOPx(o)	((PMOP*)o)
#define cSVOPx(o)	((SVOP*)o)
#define cPADOPx(o)	((PADOP*)o)
#define cPVOPx(o)	((PVOP*)o)
#define cCOPx(o)	((COP*)o)
#define cLOOPx(o)	((LOOP*)o)

#define cUNOP		cUNOPx(PL_op)
#define cBINOP		cBINOPx(PL_op)
#define cLISTOP		cLISTOPx(PL_op)
#define cLOGOP		cLOGOPx(PL_op)
#define cPMOP		cPMOPx(PL_op)
#define cSVOP		cSVOPx(PL_op)
#define cPADOP		cPADOPx(PL_op)
#define cPVOP		cPVOPx(PL_op)
#define cCOP		cCOPx(PL_op)
#define cLOOP		cLOOPx(PL_op)

#define cUNOPo		cUNOPx(o)
#define cBINOPo		cBINOPx(o)
#define cLISTOPo	cLISTOPx(o)
#define cLOGOPo		cLOGOPx(o)
#define cPMOPo		cPMOPx(o)
#define cSVOPo		cSVOPx(o)
#define cPADOPo		cPADOPx(o)
#define cPVOPo		cPVOPx(o)
#define cCOPo		cCOPx(o)
#define cLOOPo		cLOOPx(o)

#define kUNOP		cUNOPx(kid)
#define kBINOP		cBINOPx(kid)
#define kLISTOP		cLISTOPx(kid)
#define kLOGOP		cLOGOPx(kid)
#define kPMOP		cPMOPx(kid)
#define kSVOP		cSVOPx(kid)
#define kPADOP		cPADOPx(kid)
#define kPVOP		cPVOPx(kid)
#define kCOP		cCOPx(kid)
#define kLOOP		cLOOPx(kid)


#  define	cGVOPx_gv(o)	((GV*)cSVOPx(o)->op_sv)
#  define	IS_PADGV(v)	FALSE
#  define	IS_PADCONST(v)	FALSE
#  define	cSVOPx_sv(v)	(cSVOPx(v)->op_sv)
#  define	cSVOPx_svp(v)	(&cSVOPx(v)->op_sv)

#define	cGVOP_gv		cGVOPx_gv(PL_op)
#define	cGVOPo_gv		cGVOPx_gv(o)
#define	kGVOP_gv		cGVOPx_gv(kid)
#define cSVOP_sv		cSVOPx_sv(PL_op)
#define cSVOPo_sv		cSVOPx_sv(o)
#define kSVOP_sv		cSVOPx_sv(kid)

#define ROOTOPcpNULL(rootop) STMT_START {	\
	if ((rootop)) {				\
	    rootop_refcnt_dec((rootop));	\
	    (rootop) = NULL;			\
	}					\
    } STMT_END

#ifndef PERL_CORE
#  define Nullop ((OP*)NULL)
#endif

/* Lowest byte-and-a-bit of PL_opargs */
#define OA_MARK 1
#define OA_FOLDCONST 2
#define OA_RETSCALAR 4
#define OA_TARGET 8
#define OA_RETINTEGER 16
#define OA_OTHERINT 32
#define OA_DANGEROUS 64
#define OA_DEFGV 128
#define OA_TARGLEX 256

/* The next 4 bits encode op class information */
#define OCSHIFT 9

#define OA_CLASS_MASK (15 << OCSHIFT)

#define OA_BASEOP (0 << OCSHIFT)
#define OA_UNOP (1 << OCSHIFT)
#define OA_BINOP (2 << OCSHIFT)
#define OA_LOGOP (3 << OCSHIFT)
#define OA_LISTOP (4 << OCSHIFT)
#define OA_PMOP (5 << OCSHIFT)
#define OA_SVOP (6 << OCSHIFT)
#define OA_PADOP (7 << OCSHIFT)
#define OA_LOOP (9 << OCSHIFT)
#define OA_COP (10 << OCSHIFT)
#define OA_BASEOP_OR_UNOP (11 << OCSHIFT)
#define OA_FILESTATOP (12 << OCSHIFT)
#define OA_LOOPEXOP (13 << OCSHIFT)
#define OA_ROOTOP (14 << OCSHIFT)

#define OASHIFT 13

/* Remaining nybbles of PL_opargs */
#define OA_SCALAR 1
#define OA_LIST 2
#define OA_AVREF 3
#define OA_HVREF 4
#define OA_CVREF 5
#define OA_FILEREF 6
#define OA_SCALARREF 7
#define OA_OPTIONAL 8

/* Op_REFCNT is a reference count at the head of each op tree: needed
 * since the tree is shared between threads, and between cloned closure
 * copies in the same thread. OP_REFCNT_LOCK/UNLOCK is used when modifying
 * this count.
 * The same mutex is used to protect the refcounts of the reg_trie_data
 * and reg_ac_data structures, which are shared between duplicated
 * regexes.
 */

#  define OP_REFCNT_INIT		NOOP
#  define OP_REFCNT_LOCK		NOOP
#  define OP_REFCNT_UNLOCK		NOOP
#  define OP_REFCNT_TERM		NOOP

#define OpREFCNT(o)		((o)->op_targ)
#define OpREFCNT_set(o,n)		((o)->op_targ = (n))
#ifdef PERL_DEBUG_READONLY_OPS
#  define OpREFCNT_inc(o)		Perl_op_refcnt_inc(aTHX_ o)
#  define OpREFCNT_dec(o)		Perl_op_refcnt_dec(aTHX_ o)
#else
#  define OpREFCNT_inc(o)		((o) ? (++(o)->op_targ, (o)) : NULL)
#  define OpREFCNT_dec(o)		(--(o)->op_targ)
#endif

/* flags used by Perl_load_module() */
#define PERL_LOADMOD_DENY		0x1
#define PERL_LOADMOD_NOIMPORT		0x2
#define PERL_LOADMOD_IMPORT_OPS		0x4

#if defined(PERL_IN_PERLY_C) || defined(PERL_IN_OP_C)
#define ref(o, type) doref(o, type, TRUE)
#endif

/* no longer used anywhere in core */
#ifndef PERL_CORE
#define cv_ckproto(cv, gv, p) \
   cv_ckproto_len((cv), (gv), (p), (p) ? strlen(p) : 0)
#endif

#ifdef USE_REENTRANT_API
#include "reentr.h"
#endif

#if defined(PL_OP_SLAB_ALLOC)
#define NewOp(m,var,c,type)	\
	(var = (type *) Perl_Slab_Alloc(aTHX_ c*sizeof(type)))
#define FreeOp(p) Perl_Slab_Free(aTHX_ p)
#else
#define NewOp(m, var, c, type)	\
	(var = (MEM_WRAP_CHECK_(c,type) \
	 (type*)PerlMemShared_calloc(c, sizeof(type))))
#define FreeOp(p) PerlMemShared_free(p)
#endif

#ifdef PERL_MAD
#  define MAD_OP 1
#  define MAD_SV 2

struct madprop {
    MADPROP* mad_next;
    const void *mad_val;
    U32 mad_vlen;
/*    short mad_count; */
    char mad_key;
    char mad_type;
};

struct madtoken {
    I32 tk_type;
    MADPROP* tk_mad;
};
#endif

/*
 * Values that can be held by mad_key :
 * ^       unfilled head spot
 * ,       literal ,
 * ;       literal ; (blank if implicit ; at end of block)
 * :       literal : from ?: or attr list
 * +       unary +
 * ?       literal ? from ?:
 * (       literal (
 * )       literal )
 * [       literal [
 * ]       literal ]
 * {       literal {
 * }       literal }
 * @       literal @ sigil
 * $       literal $ sigil
 * *       literal * sigil
 * !       use is source filtered
 * &       & or sub
 * #       whitespace/comment following ; or }
 * #       $# sigil
 * 1       1st ; from for(;;)
 * 1       retired protasis
 * 2       2nd ; from for(;;)
 * 2       retired apodosis
 * 3       C-style for list
 * a       sub or var attributes
 * a       non-method arrow operator
 * A       method arrow operator
 * A       use import args
 * b       format block
 * B       retired stub block
 * c       the type the opcode is prototyped to
 * C       constant conditional op
 * d       declarator
 * D       do block
 * e       unreached "else" (see C)
 * e       expression producing E
 * f       folded constant op
 * F       peg op for format
 * g       op was forced to be a word
 * G       __END__ section
 * i       if/unless modifier
 * I       if/elsif/unless statement
 * j       first ']' of an array or hash slice
 * k       local declarator
 * K       retired kid op
 * l       last index of array ($#foo)
 * L       label
 * m       modifier on regex
 * n       sub or format name
 * o       current operator/declarator name
 * o       else/continue
 * O       generic optimized op
 * p       peg to hold extra whitespace at statement level
 * P       peg op for package declaration
 * q       opening quote
 * =       quoted material
 * Q       closing quote
 * Q       optimized qw//
 * r       expression producing R
 * R       tr/E/R/ s/E/R/
 * s       sub signature
 * S       use import stub (no import)
 * S       retired sort block
 * t       unreached "then" (see C)
 * U       use import op
 * v       private sv of for loop
 * V       use version
 * w       while/until modifier
 * W       while/for statement
 * x       optimized qw
 * X       random thing
 * _       whitespace/comments preceding anything else
 * ~       =~ operator
 * >       op_null type (not a token)
 * <       op_null type first (not a token)
 */

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
