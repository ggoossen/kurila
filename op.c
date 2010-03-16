/*    op.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000,
 *    2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * 'You see: Mr. Drogo, he married poor Miss Primula Brandybuck.  She was
 *  our Mr. Bilbo's first cousin on the mother's side (her mother being the
 *  youngest of the Old Took's daughters); and Mr. Drogo was his second
 *  cousin.  So Mr. Frodo is his first *and* second cousin, once removed
 *  either way, as the saying is, if you follow me.'       --the Gaffer
 *
 *     [p.23 of _The Lord of the Rings_, I/i: "A Long-Expected Party"]
 */

/* This file contains the functions that create, manipulate and optimize
 * the OP structures that hold a compiled perl program.
 *
 * A Perl program is compiled into a tree of OPs. Each op contains
 * structural pointers (eg to its siblings and the next op in the
 * execution sequence), a pointer to the function that would execute the
 * op, plus any data specific to that op. For example, an OP_CONST op
 * points to the pp_const() function and to an SV containing the constant
 * value. When pp_const() is executed, its job is to push that SV onto the
 * stack.
 *
 * OPs are mainly created by the newFOO() functions, which are mainly
 * called from the parser (in perly.y) as the code is parsed. For example
 * the Perl code $a + $b * $c would cause the equivalent of the following
 * to be called (oversimplifying a bit):
 *
 *  newBINOP(OP_ADD, flags,
 *	newSVREF($a),
 *	newBINOP(OP_MULTIPLY, flags, newSVREF($b), newSVREF($c))
 *  )
 *
 * Note that during the build of miniperl, a temporary copy of this file
 * is made, called opmini.c.
 */

/*
Perl's compiler is essentially a 3-pass compiler with interleaved phases:

    A bottom-up pass
    A top-down pass
    An execution-order pass

The bottom-up pass is represented by all the "newOP" routines and
the ck_ routines.  The bottom-upness is actually driven by yacc.
So at the point that a ck_ routine fires, we have no idea what the
context is, either upward in the syntax tree, or either forward or
backward in the execution order.  (The bottom-up parser builds that
part of the execution order it knows about, but if you follow the "next"
links around, you'll find it's actually a closed loop through the
top level node.

Whenever the bottom-up parser gets to a node that supplies context to
its components, it invokes that portion of the top-down pass that applies
to that part of the subtree (and marks the top node as processed, so
if a node further up supplies context, it doesn't have to take the
plunge again).  As a particular subcase of this, as the new node is
built, it takes all the closed execution loops of its subcomponents
and links them into a new closed loop for the higher level node.  But
it's still not the real execution order.

The actual execution order is not known till we get a grammar reduction
to a top-level unit like a subroutine or file that will be called by
"name" rather than via a "next" pointer.  At that point, we can call
into peep() to do that code's portion of the 3rd pass.  It has to be
recursive, but it's recursive on basic blocks, not on tree nodes.
*/

#include "EXTERN.h"
#define PERL_IN_OP_C
#include "perl.h"
#include "keywords.h"

#define CALL_PEEP(o) CALL_FPTR(PL_peepp)(aTHX_ o)
#define CALL_OPFREEHOOK(o) if (PL_opfreehook) CALL_FPTR(PL_opfreehook)(aTHX_ o)

#if defined(PL_OP_SLAB_ALLOC)

#ifdef PERL_DEBUG_READONLY_OPS
#  define PERL_SLAB_SIZE 4096
#  include <sys/mman.h>
#endif

#ifndef PERL_SLAB_SIZE
#define PERL_SLAB_SIZE 2048
#endif

void *
Perl_Slab_Alloc(pTHX_ size_t sz)
{
    dVAR;
    /*
     * To make incrementing use count easy PL_OpSlab is an I32 *
     * To make inserting the link to slab PL_OpPtr is I32 **
     * So compute size in units of sizeof(I32 *) as that is how Pl_OpPtr increments
     * Add an overhead for pointer to slab and round up as a number of pointers
     */
    sz = (sz + 2*sizeof(I32 *) -1)/sizeof(I32 *);
    if ((PL_OpSpace -= sz) < 0) {
#ifdef PERL_DEBUG_READONLY_OPS
	/* We need to allocate chunk by chunk so that we can control the VM
	   mapping */
	PL_OpPtr = (I32**) mmap(0, PERL_SLAB_SIZE*sizeof(I32*), PROT_READ|PROT_WRITE,
			MAP_ANON|MAP_PRIVATE, -1, 0);

	DEBUG_m(PerlIO_printf(Perl_debug_log, "mapped %lu at %p\n",
			      (unsigned long) PERL_SLAB_SIZE*sizeof(I32*),
			      PL_OpPtr));
	if(PL_OpPtr == MAP_FAILED) {
	    perror("mmap failed");
	    abort();
	}
#else

        PL_OpPtr = (I32 **) PerlMemShared_calloc(PERL_SLAB_SIZE,sizeof(I32*)); 
#endif
    	if (!PL_OpPtr) {
	    return NULL;
	}
	/* We reserve the 0'th I32 sized chunk as a use count */
	PL_OpSlab = (I32 *) PL_OpPtr;
	/* Reduce size by the use count word, and by the size we need.
	 * Latter is to mimic the '-=' in the if() above
	 */
	PL_OpSpace = PERL_SLAB_SIZE - (sizeof(I32)+sizeof(I32 **)-1)/sizeof(I32 **) - sz;
	/* Allocation pointer starts at the top.
	   Theory: because we build leaves before trunk allocating at end
	   means that at run time access is cache friendly upward
	 */
	PL_OpPtr += PERL_SLAB_SIZE;

#ifdef PERL_DEBUG_READONLY_OPS
	/* We remember this slab.  */
	/* This implementation isn't efficient, but it is simple. */
	PL_slabs = (I32**) realloc(PL_slabs, sizeof(I32**) * (PL_slab_count + 1));
	PL_slabs[PL_slab_count++] = PL_OpSlab;
	DEBUG_m(PerlIO_printf(Perl_debug_log, "Allocate %p\n", PL_OpSlab));
#endif
    }
    assert( PL_OpSpace >= 0 );
    /* Move the allocation pointer down */
    PL_OpPtr   -= sz;
    assert( PL_OpPtr > (I32 **) PL_OpSlab );
    *PL_OpPtr   = PL_OpSlab;	/* Note which slab it belongs to */
    (*PL_OpSlab)++;		/* Increment use count of slab */
    assert( PL_OpPtr+sz <= ((I32 **) PL_OpSlab + PERL_SLAB_SIZE) );
    assert( *PL_OpSlab > 0 );
    return (void *)(PL_OpPtr + 1);
}

#ifdef PERL_DEBUG_READONLY_OPS
void
Perl_pending_Slabs_to_ro(pTHX) {
    /* Turn all the allocated op slabs read only.  */
    U32 count = PL_slab_count;
    I32 **const slabs = PL_slabs;

    /* Reset the array of pending OP slabs, as we're about to turn this lot
       read only. Also, do it ahead of the loop in case the warn triggers,
       and a warn handler has an eval */

    PL_slabs = NULL;
    PL_slab_count = 0;

    /* Force a new slab for any further allocation.  */
    PL_OpSpace = 0;

    while (count--) {
	void *const start = slabs[count];
	const size_t size = PERL_SLAB_SIZE* sizeof(I32*);
	if(mprotect(start, size, PROT_READ)) {
	    Perl_warn(aTHX_ "mprotect for %p %lu failed with %d",
		      start, (unsigned long) size, errno);
	}
    }

    free(slabs);
}

STATIC void
S_Slab_to_rw(pTHX_ void *op)
{
    I32 * const * const ptr = (I32 **) op;
    I32 * const slab = ptr[-1];

    PERL_ARGS_ASSERT_SLAB_TO_RW;

    assert( ptr-1 > (I32 **) slab );
    assert( ptr < ( (I32 **) slab + PERL_SLAB_SIZE) );
    assert( *slab > 0 );
    if(mprotect(slab, PERL_SLAB_SIZE*sizeof(I32*), PROT_READ|PROT_WRITE)) {
	Perl_warn(aTHX_ "mprotect RW for %p %lu failed with %d",
		  slab, (unsigned long) PERL_SLAB_SIZE*sizeof(I32*), errno);
    }
}

OP *
Perl_op_refcnt_inc(pTHX_ OP *o)
{
    if(o) {
	Slab_to_rw(o);
	++o->op_targ;
    }
    return o;

}

PADOFFSET
Perl_op_refcnt_dec(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_OP_REFCNT_DEC;
    Slab_to_rw(o);
    return --o->op_targ;
}
#else
#  define Slab_to_rw(op)
#endif

void
Perl_Slab_Free(pTHX_ void *op)
{
    I32 * const * const ptr = (I32 **) op;
    I32 * const slab = ptr[-1];
    PERL_ARGS_ASSERT_SLAB_FREE;
    assert( ptr-1 > (I32 **) slab );
    assert( ptr < ( (I32 **) slab + PERL_SLAB_SIZE) );
    assert( *slab > 0 );
    Slab_to_rw(op);
    if (--(*slab) == 0) {
#  ifdef NETWARE
#    define PerlMemShared PerlMem
#  endif
	
#ifdef PERL_DEBUG_READONLY_OPS
	U32 count = PL_slab_count;
	/* Need to remove this slab from our list of slabs */
	if (count) {
	    while (count--) {
		if (PL_slabs[count] == slab) {
		    dVAR;
		    /* Found it. Move the entry at the end to overwrite it.  */
		    DEBUG_m(PerlIO_printf(Perl_debug_log,
					  "Deallocate %p by moving %p from %lu to %lu\n",
					  PL_OpSlab,
					  PL_slabs[PL_slab_count - 1],
					  PL_slab_count, count));
		    PL_slabs[count] = PL_slabs[--PL_slab_count];
		    /* Could realloc smaller at this point, but probably not
		       worth it.  */
		    if(munmap(slab, PERL_SLAB_SIZE*sizeof(I32*))) {
			perror("munmap failed");
			abort();
		    }
		    break;
		}
	    }
	}
#else
    PerlMemShared_free(slab);
#endif
	if (slab == PL_OpSlab) {
	    PL_OpSpace = 0;
	}
    }
}
#endif
/*
 * In the following definition, the ", (OP*)0" is just to make the compiler
 * think the expression is of the right type: croak actually does a Siglongjmp.
 */
#define CHECKOP(type,o) \
    ((PL_op_mask && PL_op_mask[type])				\
     ? ( op_free((OP*)o),					\
	 Perl_croak(aTHX_ "'%s' trapped by operation mask", PL_op_desc[type]),	\
	 (OP*)0 )						\
     : CALL_FPTR(PL_check[type])(aTHX_ (OP*)o))

#define RETURN_UNLIMITED_NUMBER (PERL_INT_MAX / 2)

ROOTOP*
Perl_newROOTOP(pTHX_ OP *main, SV* location)
{
    ROOTOP* o;
    Optype type = OP_ROOT;

    PERL_ARGS_ASSERT_NEWROOTOP;

    NewOp(1101, o, 1, ROOTOP);
    o->op_type = type;
    o->op_ppaddr = PL_ppaddr[type];
    o->op_first = main;
    o->op_flags = OPf_KIDS;
    o->op_location = SvREFCNT_inc(location);
    OpREFCNT_set(o, 1);

    o->op_prev_root = NULL;
    o->op_next_root = PL_rootop_ll;
    if (PL_rootop_ll)
	PL_rootop_ll->op_prev_root = o;
    PL_rootop_ll = o;

    return o;
}

STATIC OP *
S_no_fh_allowed(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_NO_FH_ALLOWED;

    yyerror(Perl_form(aTHX_ "Missing comma after first argument to %s function",
		 OP_DESC(o)));
    return o;
}

STATIC OP *
S_too_few_arguments(pTHX_ OP *o, const char *name)
{
    PERL_ARGS_ASSERT_TOO_FEW_ARGUMENTS;

    yyerror(Perl_form(aTHX_ "Not enough arguments for %s", name));
    return o;
}

STATIC OP *
S_too_many_arguments(pTHX_ OP *o, const char *name)
{
    PERL_ARGS_ASSERT_TOO_MANY_ARGUMENTS;

    yyerror(Perl_form(aTHX_ "Too many arguments for %s", name));
    return o;
}

STATIC void
S_bad_type(pTHX_ I32 n, const char *t, const char *name, const OP *kid)
{
    PERL_ARGS_ASSERT_BAD_TYPE;

    yyerror(Perl_form(aTHX_ "Type of arg %d to %s must be %s (not %s)",
		 (int)n, name, t, OP_DESC(kid)));
}

STATIC void
S_no_bareword_allowed(pTHX_ const OP *o)
{
    PERL_ARGS_ASSERT_NO_BAREWORD_ALLOWED;

    Perl_croak_at(aTHX_
	o->op_location,
	"Bareword \"%"SVf"\" not allowed while \"strict subs\" in use",
	SVfARG(cSVOPo_sv));
}

/* "register" allocation */

PADOFFSET
Perl_allocmy(pTHX_ const char *const name)
{
    dVAR;
    PADOFFSET off;
    const bool is_our = (PL_parser->in_my == KEY_our);
    GV* ourgv = NULL;

    PERL_ARGS_ASSERT_ALLOCMY;

    /* check for duplicate declaration */
    pad_check_dup(name, is_our, (PL_curstash ? PL_curstash : PL_defstash));

    /* allocate a spare slot and store the name in that slot */

    if (is_our) {
	                                 /* $_ is always in main::, even with our */
	HV *  const stash = PL_curstash && !strEQ(name,"$_") ? PL_curstash : PL_defstash;
	HEK * const stashname = HvNAME_HEK(stash);
	SV *  const sym = sv_2mortal(newSVhek(stashname));
	sv_catpvs(sym, "::");
	sv_catpv(sym, name+1);
	ourgv = gv_fetchsv(sym,
			   (PL_in_eval
			    ? (GV_ADDMULTI | GV_ADDINEVAL)
			    : GV_ADDMULTI
			    ),
			   SVt_PVGV
			   );
    }

    off = pad_add_name(
	name,
	ourgv,
	0 /*  not fake */
    );

    return off;
}

/* free the body of an op without examining its contents.
 * Always use this rather than FreeOp directly */

static void
S_op_destroy(pTHX_ OP *o)
{
    SVcpNULL(o->op_location);
    FreeOp(o);
}

/* Destructor */

void
Perl_op_free(pTHX_ OP *o)
{
    dVAR;
    OPCODE type;

    if (!o)
	return;

    type = o->op_type;
    if (type == OP_ROOT) {
	PADOFFSET refcnt;
	ROOTOP* rooto = (ROOTOP*)o;
	refcnt = OpREFCNT(o);
	if (refcnt) {
	    Perl_croak(aTHX_ "panic: Attempt to free referenced rootop");
	}

	if (rooto->op_next_root) 
	    rooto->op_next_root->op_prev_root = rooto->op_prev_root;
	if (rooto->op_prev_root)
	    rooto->op_prev_root->op_next_root = rooto->op_next_root;
	if (rooto == PL_rootop_ll)
	    PL_rootop_ll = rooto->op_next_root;
    }

    /* Call the op_free hook if it has been set. Do it now so that it's called
     * at the right time for refcounted ops, but still before all of the kids
     * are freed. */
    CALL_OPFREEHOOK(o);

    if (o->op_flags & OPf_KIDS) {
        register OP *kid, *nextkid;
	for (kid = cUNOPo->op_first; kid; kid = nextkid) {
	    nextkid = kid->op_sibling; /* Get before next freeing kid */
	    op_free(kid);
	}
    }

#ifdef PERL_DEBUG_READONLY_OPS
    Slab_to_rw(o);
#endif

    /* COP* is not cleared by op_clear() so that we may track line
     * numbers etc even after null() */
    if (type == OP_NEXTSTATE || type == OP_DBSTATE
	    || (type == OP_NULL /* the COP might have been null'ed */
		&& ((OPCODE)o->op_targ == OP_NEXTSTATE
		    || (OPCODE)o->op_targ == OP_DBSTATE))) {
	cop_free((COP*)o);
    }

    if (type == OP_NULL)
	type = (OPCODE)o->op_targ;

    op_clear(o);
    FreeOp(o);
}

void
Perl_op_tmprefcnt(pTHX_ OP *o)
{
    dVAR;
    OPCODE type;

    if (!o)
	return;

    type = o->op_type;

    if (o->op_flags & OPf_KIDS) {
        register OP *kid;
	for (kid = cUNOPo->op_first; kid; kid = kid->op_sibling) {
	    op_tmprefcnt(kid);
	}
    }
    if (type == OP_NULL)
	type = (OPCODE)o->op_targ;

    if (type == OP_NEXTSTATE || type == OP_DBSTATE) {
	HvTMPREFCNT_inc(((COP*)o)->cop_hints_hash);
    }

    SvTMPREFCNT_inc(o->op_location);

    switch (o->op_type) {
    case OP_NULL:	/* Was holding old type, if any. */
    case OP_ENTEREVAL:	/* Was holding hints. */
	break;
    default:
	if (!(o->op_flags & OPf_REF)
	    || (PL_check[o->op_type] != MEMBER_TO_FPTR(Perl_ck_ftst)))
	    break;
	/* FALL THROUGH */
    case OP_GVSV:
    case OP_GV:
    case OP_AELEMFAST:
	if (! (o->op_type == OP_AELEMFAST && o->op_flags & OPf_SPECIAL)) {
	    /* not an OP_PADSV replacement */
	    SvTMPREFCNT_inc(cSVOPo->op_sv);
	}
	break;
    case OP_METHOD_NAMED:
    case OP_CONST:
    case OP_VAR:
    case OP_HINTSEVAL:
    case OP_MAGICSV:
	SvTMPREFCNT_inc(cSVOPo->op_sv);
	break;
    case OP_NEXT:
    case OP_LAST:
    case OP_REDO:
	break;
    case OP_SUBST:
	op_tmprefcnt(cPMOPo->op_pmreplrootu.op_pmreplroot);
	goto tmpref_pmop;
    case OP_PUSHRE:
	SvTMPREFCNT_inc((SV*)cPMOPo->op_pmreplrootu.op_pmtargetgv);
	/* FALL THROUGH */
    case OP_MATCH:
    case OP_QR:
tmpref_pmop:
	ReTMPREFCNT_inc(PM_GETRE(cPMOPo));
	break;
    }
}

void
Perl_op_clear(pTHX_ OP *o)
{

    dVAR;

    PERL_ARGS_ASSERT_OP_CLEAR;

#ifdef PERL_MAD
    /* if (o->op_madprop && o->op_madprop->mad_next)
       abort(); */
    /* FIXME for MAD - if I uncomment these two lines t/op/pack.t fails with
       "modification of a read only value" for a reason I can't fathom why.
       It's the "" stringification of $_, where $_ was set to '' in a foreach
       loop, but it defies simplification into a small test case.
       However, commenting them out has caused ext/List/Util/t/weak.t to fail
       the last test.  */
    /*
      mad_free(o->op_madprop);
      o->op_madprop = 0;
    */
#endif    

 retry:
    switch (o->op_type) {
    case OP_NULL:	/* Was holding old type, if any. */
	if (PL_madskills && o->op_targ != OP_NULL) {
	    o->op_type = (Optype)o->op_targ;
	    o->op_targ = 0;
	    goto retry;
	}
    case OP_ENTEREVAL:	/* Was holding hints. */
	o->op_targ = 0;
	break;
    default:
	if (!(o->op_flags & OPf_REF)
	    || (PL_check[o->op_type] != MEMBER_TO_FPTR(Perl_ck_ftst)))
	    break;
	/* FALL THROUGH */
    case OP_GVSV:
    case OP_GV:
    case OP_AELEMFAST:
	if (! (o->op_type == OP_AELEMFAST && o->op_flags & OPf_SPECIAL)) {
	    /* not an OP_PADSV replacement */
	    SVcpNULL(cSVOPo->op_sv);
	}
	break;
    case OP_METHOD_NAMED:
    case OP_CONST:
    case OP_VAR:
    case OP_HINTSEVAL:
    case OP_MAGICSV:
	SVcpNULL(cSVOPo->op_sv);
	break;
    case OP_NEXT:
    case OP_LAST:
    case OP_REDO:
	if (o->op_flags & (OPf_SPECIAL|OPf_STACKED|OPf_KIDS))
	    break;
	PerlMemShared_free(cPVOPo->op_pv);
	cPVOPo->op_pv = NULL;
	break;
    case OP_SUBST:
	op_free(cPMOPo->op_pmreplrootu.op_pmreplroot);
	goto clear_pmop;
    case OP_PUSHRE:
	SvREFCNT_dec((SV*)cPMOPo->op_pmreplrootu.op_pmtargetgv);
	/* FALL THROUGH */
    case OP_MATCH:
    case OP_QR:
clear_pmop:
	cPMOPo->op_pmreplrootu.op_pmreplroot = NULL;
        /* we use the same protection as the "SAFE" version of the PM_ macros
         * here since sv_clean_all might release some PMOPs
         * after PL_regex_padav has been cleared
         * and the clearing of PL_regex_padav needs to
         * happen before sv_clean_all
         */
	ReREFCNT_dec(PM_GETRE(cPMOPo));
	PM_SETRE(cPMOPo, NULL);

	break;
    }

    if (o->op_targ > 0) {
	pad_free(o->op_targ);
	o->op_targ = 0;
    }

    SVcpNULL(o->op_location);
}

STATIC void
S_cop_free(pTHX_ COP* cop)
{
    PERL_ARGS_ASSERT_COP_FREE;

    CopLABEL_free(cop);
    CopSTASH_free(cop);
    if (! specialWARN(cop->cop_warnings))
	PerlMemShared_free(cop->cop_warnings);
    SvREFCNT_dec((SV*)cop->cop_hints_hash);
}

void
Perl_op_null(pTHX_ OP *o)
{
    dVAR;

    SV* location;
    PERL_ARGS_ASSERT_OP_NULL;

    if (o->op_type == OP_NULL)
	return;

    location = SvREFCNT_inc(o->op_location);
    if (!PL_madskills)
	op_clear(o);
    o->op_targ = o->op_type;
    o->op_type = OP_NULL;
    o->op_ppaddr = PL_ppaddr[OP_NULL];
    o->op_location = location;
}

void
Perl_op_refcnt_lock(pTHX)
{
    dVAR;
    PERL_UNUSED_CONTEXT;
    OP_REFCNT_LOCK;
}

void
Perl_op_refcnt_unlock(pTHX)
{
    dVAR;
    PERL_UNUSED_CONTEXT;
    OP_REFCNT_UNLOCK;
}

/* Contextualizers */

#define LINKLIST(o) ((o)->op_next ? (o)->op_next : linklist((OP*)o))

static OP *
S_linklist(pTHX_ OP *o)
{
    OP *first;

    PERL_ARGS_ASSERT_LINKLIST;

    if (o->op_next)
	return o->op_next;

    /* establish postfix order */
    first = cUNOPo->op_first;
    if (first) {
        register OP *kid;
	o->op_next = LINKLIST(first);
	kid = first;
	for (;;) {
	    if (kid->op_sibling) {
		kid->op_next = LINKLIST(kid->op_sibling);
		kid = kid->op_sibling;
	    } else {
		kid->op_next = o;
		break;
	    }
	}
    }
    else
	o->op_next = o;

    return o->op_next;
}

static bool
S_is_handle_constructor(const OP *o, I32 numargs)
{
    PERL_ARGS_ASSERT_IS_HANDLE_CONSTRUCTOR;

    switch (o->op_type) {
    case OP_PIPE_OP:
    case OP_SOCKPAIR:
	if (numargs == 2)
	    return TRUE;
	/* FALL THROUGH */
    case OP_SYSOPEN:
    case OP_OPEN:
    case OP_SOCKET:
    case OP_OPEN_DIR:
    case OP_ACCEPT:
	if (numargs == 1)
	    return TRUE;
	/* FALLTHROUGH */
    default:
	return FALSE;
    }
}

STATIC OP *
S_my_kid(pTHX_ OP *o, OP **imopsp)
{
    dVAR;
    I32 type;

    PERL_ARGS_ASSERT_MY_KID;

    if (!o || (PL_parser && PL_parser->error_count))
	return o;

    type = o->op_type;
    if (PL_madskills && type == OP_NULL && o->op_flags & OPf_KIDS) {
	(void)my_kid(cUNOPo->op_first, imopsp);
	return o;
    }

    if (type == OP_LIST) {
        OP *kid;
	for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling)
	    my_kid(kid, imopsp);
    } else if (type == OP_UNDEF
	|| type == OP_DOTDOTDOT
	|| type == OP_PLACEHOLDER
#ifdef PERL_MAD
	       || type == OP_STUB
#endif
	       ) {
	return o;
    }
    else if (type == OP_EXPAND 
	|| type == OP_HASHEXPAND
	|| type == OP_ARRAYEXPAND) {
	my_kid(cUNOPo->op_first, imopsp);
    }
    else if (type == OP_ANONARRAY) {
        OP *kid;
	for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling)
	    my_kid(kid, imopsp);
    }
    else if (type == OP_ANONHASH) {
        OP *kid;
	for (kid = cLISTOPo->op_first->op_sibling; kid; kid = kid->op_sibling) {
	    if (kid->op_type == OP_CONST
#ifdef PERL_MAD
		|| (kid->op_type == OP_NULL 
		    && cLISTOPx(kid)->op_first->op_type == OP_CONST)
#endif
		) {
		kid = kid->op_sibling;
		if ( ! kid )
		    break;
	    }
	    my_kid(kid, imopsp);
	}
    }
    else if (type == OP_RV2SV ||	/* "our" declaration */
	       type == OP_RV2AV ||
	       type == OP_RV2HV) { /* XXX does this let anything illegal in? */
	if (cUNOPo->op_first->op_type != OP_GV) { /* MJD 20011224 */
	    yyerror_at(
		o->op_location,
		Perl_form(aTHX_ "Can't declare %s in \"%s\"",
			OP_DESC(o),
			PL_parser->in_my == KEY_our
			    ? "our" : "my"));
	}
	o->op_private |= OPpOUR_INTRO;
	return o;
    }
    else if (type != OP_PADSV &&
	     type != OP_PUSHMARK)
    {
	yyerror_at(
	    o->op_location,
	    Perl_form(aTHX_ "Can't declare %s in \"%s\"",
		OP_DESC(o),
		PL_parser->in_my == KEY_our ? "our" : "my")
	    );
	return o;
    }
    o->op_flags |= OPf_MOD;
    o->op_private |= OPpLVAL_INTRO;
    return o;
}

OP *
Perl_my(pTHX_ OP *o)
{
    dVAR;
    OP *rops;
    int maybe_scalar = 0;

    PERL_ARGS_ASSERT_MY;

    maybe_scalar = 1;
    rops = NULL;
    o = my_kid(o, &rops);
    if (rops) {
	if (maybe_scalar && o->op_type == OP_PADSV) {
	    o = append_list(OP_LISTLAST, (LISTOP*)rops, (LISTOP*)o);
	}
	else
	    o = append_list(OP_LIST, (LISTOP*)o, (LISTOP*)rops);
    }
    PL_parser->in_my = FALSE;
    return o;
}

OP *
Perl_sawparens(pTHX_ OP *o)
{
    PERL_UNUSED_CONTEXT;
    if (o)
	o->op_flags |= OPf_PARENS;
    return o;
}

/*
=for apidoc op_mod_assign

C<operator> is an opcode which modifies the
top item of the stack. C<operand> is an opcode which will be split into
a get and a set part using op_assign.
The tree returns uses a temporary variable and the get and set to mimic applying
the operator directly to the C<operand>.

=cut
*/
OP *
Perl_op_mod_assign(pTHX_ OP *otor, OP **oandp, I32 optype)
{
    OP* finish_assign;
    OP* operator_sibling;
    OP* o;
    PERL_ARGS_ASSERT_OP_MOD_ASSIGN;

    if (optype == OP_ENTERSUB) {
	*oandp = mod(*oandp, optype);
	return otor;
    }

    if (!*oandp)
	return otor;

    finish_assign = op_assign(oandp, optype);

    if (!finish_assign) {
	return otor;
    }

    operator_sibling = otor->op_sibling;
    o = append_elem(OP_LISTFIRST, scalar(otor), finish_assign);
    o->op_sibling = operator_sibling;
    return o;
}

OP *
Perl_bind_match(pTHX_ I32 type, OP *left, OP *right)
{
    OP *o;
    bool ismatchop = 0;
    const OPCODE ltype = left->op_type;
    const OPCODE rtype = right->op_type;

    PERL_ARGS_ASSERT_BIND_MATCH;

    if ( (ltype == OP_RV2AV || ltype == OP_RV2HV) && ckWARN(WARN_MISC))
    {
      const char * const desc
	  = PL_op_desc[(rtype == OP_SUBST)
		       ? (int)rtype : OP_MATCH];
      const char * const sample = ((ltype == OP_RV2AV)
	     ? "@array" : "%hash");
      Perl_warner(aTHX_ packWARN(WARN_MISC),
             "Applying %s to %s will act on scalar(%s)",
             desc, sample, sample);
    }

    if (rtype == OP_CONST &&
	cSVOPx(right)->op_private & OPpCONST_BARE &&
	cSVOPx(right)->op_private & OPpCONST_STRICT)
    {
	no_bareword_allowed(right);
    }

    ismatchop = rtype == OP_MATCH ||
         	rtype == OP_SUBST;
    if (ismatchop && right->op_flags & OPf_TARGET_MY) {
	right->op_targ = 0;
	right->op_flags &= ~OPf_TARGET_MY;
    }
    if (!(right->op_flags & OPf_STACKED) && ismatchop) {
	OP *newleft;

	right->op_flags |= OPf_STACKED;
	if (rtype != OP_MATCH)
	    newleft = mod(left, rtype);
	else
	    newleft = left;
	o = prepend_elem(rtype, scalar(newleft), right);
	if (rtype == OP_SUBST) {
	    o = op_mod_assign(o, &(cBINOPo->op_first), OP_SUBST);
	}
	if (type == OP_NOT)
	    return newUNOP(OP_NOT, 0, scalar(o), o->op_location);
	return o;
    }
    else
	return bind_match(type, left,
			  pmruntime(newPMOP(OP_MATCH, 0, right->op_location), right, 0));
}

OP *
Perl_invert(pTHX_ OP *o)
{
    if (!o)
	return NULL;
    return newUNOP(OP_NOT, OPf_SPECIAL, scalar(o), o->op_location);
}

OP *
Perl_scope(pTHX_ OP *o)
{
    dVAR;
    if (o) {
	if (o->op_flags & OPf_PARENS || PERLDB_NOOPT) {
	    o = prepend_elem(OP_LINESEQ, newOP(OP_ENTER, 0, o->op_location), o);
	    o->op_type = OP_LEAVE;
	    o->op_ppaddr = PL_ppaddr[OP_LEAVE];
	}
	else if (o->op_type == OP_LINESEQ) {
	    OP *kid;
	    o->op_type = OP_SCOPE;
	    o->op_ppaddr = PL_ppaddr[OP_SCOPE];
	    kid = ((LISTOP*)o)->op_first;
	    if (kid->op_type == OP_NEXTSTATE || kid->op_type == OP_DBSTATE) {
		op_null(kid);

		/* The following deals with things like 'do {1 for 1}' */
		kid = kid->op_sibling;
		if (kid &&
		    (kid->op_type == OP_NEXTSTATE || kid->op_type == OP_DBSTATE))
		    op_null(kid);
	    }
	}
	else
	    o = newLISTOP(OP_SCOPE, 0, o, NULL, o->op_location);
    }
    return o;
}
	
int
Perl_block_start(pTHX_ int full)
{
    dVAR;
    const int retval = PL_savestack_ix;
    pad_block_start(full);
    SAVEHINTS();
    PL_hints &= ~HINT_BLOCK_SCOPE;
    SAVECOMPILEWARNINGS();
    PL_compiling.cop_warnings = DUP_WARNINGS(PL_compiling.cop_warnings);
    return retval;
}

OP*
Perl_block_end(pTHX_ I32 floor, OP *seq)
{
    dVAR;
    const int needblockscope = PL_hints & HINT_BLOCK_SCOPE;
    OP* const retval = scalarseq(seq);
    LEAVE_SCOPE(floor);
    CopHINTS_set(&PL_compiling, PL_hints);
    if (needblockscope)
	PL_hints |= HINT_BLOCK_SCOPE; /* propagate out */
    pad_leavemy();
    return retval;
}

STATIC OP *
S_newDEFSVOP(pTHX_ SV* location)
{
    dVAR;
    const PADOFFSET offset = pad_findmy("$_");
    if (offset == NOT_IN_PAD || PAD_COMPNAME_FLAGS_isOUR(offset)) {
	return newSVREF(newGVOP(OP_GV, 0, PL_defgv, location), location);
    }
    else {
	OP * const o = newOP(OP_PADSV, 0, location);
	o->op_targ = offset;
	return o;
    }
}

void
Perl_newPROG(pTHX_ OP *o)
{
    dVAR;

    PERL_ARGS_ASSERT_NEWPROG;

    if (PL_in_eval) {
	OP* opleave;
	if (PL_eval_root)
	    return;
	opleave = newUNOP(OP_LEAVEEVAL,
			       ((PL_in_eval & EVAL_KEEPERR)
				? OPf_SPECIAL : 0), o, o->op_location);
	PL_eval_start = linklist(opleave);
	opleave->op_next = NULL;
	PL_eval_root = newROOTOP(opleave, opleave->op_location);
	PL_eval_root->op_next = PL_eval_start;
	CALL_PEEP(PL_eval_start);
    }
    else {
	OP* scopeop;
	if (o->op_type == OP_STUB) {
	    AVcpNULL(PL_comppad_name);
	    CVcpNULL(PL_compcv);
	    S_op_destroy(aTHX_ o);
	    return;
	}
	scopeop = scope(sawparens(scalarvoid(o)));
	PL_curcop = &PL_compiling;
	PL_main_start = LINKLIST(scopeop);
	scopeop->op_next = NULL;
	PL_main_root = newROOTOP(scopeop, scopeop->op_location);
	CALL_PEEP(PL_main_start);
	CVcpNULL(PL_compcv);

	/* Register with debugger */
	if (PERLDB_INTER) {
	    CV * const cv = get_cvs("DB::postponed", 0);
	    if (cv) {
		dSP;
		PUSHMARK(SP);
		XPUSHs(PL_parser->lex_filename);
		PUTBACK;
		call_sv(MUTABLE_SV(cv), G_DISCARD);
	    }
	}
    }
}

OP *
Perl_localize(pTHX_ OP *o, I32 lex)
{
    dVAR;

    PERL_ARGS_ASSERT_LOCALIZE;

    if (o->op_flags & OPf_PARENS)
	NOOP;

    if (lex)
	o = my(o);
    else
	o = mod(o, OP_NULL);		/* a bit kludgey */
    PL_parser->in_my = FALSE;
    return o;
}

OP *
Perl_fold_constants(pTHX_ register OP *o)
{
    dVAR;
    register OP * VOL curop;
    OP *newop;
    VOL I32 type = o->op_type;
    SV * VOL sv = NULL;
    int ret = 0;
    I32 oldscope;
    OP *old_next;
    SV * const oldwarnhook = PL_warnhook;
    SV * const olddiehook  = PL_diehook;
    U32 olddebug = PL_debug;
    COP not_compiling;
    dJMPENV;

    PERL_ARGS_ASSERT_FOLD_CONSTANTS;

    if (PL_opargs[type] & OA_RETSCALAR)
	scalar(o);
    if (PL_opargs[type] & OA_TARGET && !o->op_targ)
	o->op_targ = pad_alloc(type, SVs_PADTMP);

    /* integerize op */
    if ((PL_opargs[type] & OA_OTHERINT) && (PL_hints & HINT_INTEGER))
    {
	o->op_ppaddr = PL_ppaddr[type = ++(o->op_type)];
    }

    if (PL_madskills)
	goto nope;

    if (!(PL_opargs[type] & OA_FOLDCONST))
	goto nope;

    if (PL_parser && PL_parser->error_count)
	goto nope;		/* Don't try to run w/ errors */

    for (curop = LINKLIST(o); curop != o; curop = LINKLIST(curop)) {
	const OPCODE type = curop->op_type;
	if ((type != OP_CONST || (curop->op_private & OPpCONST_BARE)) &&
	    type != OP_LIST &&
	    type != OP_SCALAR &&
	    type != OP_NULL &&
	    type != OP_PUSHMARK)
	{
	    goto nope;
	}
    }

    curop = LINKLIST(o);
    old_next = o->op_next;
    o->op_next = 0;
    PL_op = curop;

    oldscope = PL_scopestack_ix;
    create_eval_scope(G_FAKINGEVAL);

    /* Verify that we don't need to save it:  */
    assert(PL_curcop == &PL_compiling);
    StructCopy(&PL_compiling, &not_compiling, COP);
    PL_curcop = &not_compiling;
    /* The above ensures that we run with all the correct hints of the
       currently compiling COP, but that IN_PERL_RUNTIME is not true. */
    assert(IN_PERL_RUNTIME);
    PL_warnhook = PERL_WARNHOOK_FATAL;
    PL_diehook  = PERL_DIEHOOK_IGNORE;
    PL_debug &= ~DEBUG_R_FLAG;
    JMPENV_PUSH(ret);

    switch (ret) {
    case 0:
	CALLRUNOPS(aTHX);
	sv = *(PL_stack_sp--);
	if (o->op_targ && sv == PAD_SV(o->op_targ))	/* grab pad temp? */
	    pad_swipe(o->op_targ,  FALSE);
	else if (SvTEMP(sv)) {			/* grab mortal temp? */
	    SvREFCNT_inc_void(sv);
	    SvTEMP_off(sv);
	}
	break;
    case 3:
	/* Something tried to die.  Abandon constant folding.  */
	/* Pretend the error never happened.  */
	CLEAR_ERRSV();
	o->op_next = old_next;
	break;
    default:
	JMPENV_POP;
	/* Don't expect 1 (setjmp failed) or 2 (something called my_exit)  */
	PL_warnhook = oldwarnhook;
	PL_diehook  = olddiehook;
	/* XXX note that this croak may fail as we've already blown away
	 * the stack - eg any nested evals */
	Perl_croak(aTHX_ "panic: fold_constants JMPENV_PUSH returned %d", ret);
    }
    JMPENV_POP;
    PL_warnhook = oldwarnhook;
    PL_diehook  = olddiehook;
    PL_debug = olddebug;
    PL_curcop = &PL_compiling;

    if (PL_scopestack_ix > oldscope)
	delete_eval_scope();

    if (ret)
	goto nope;

    assert(sv);
    if (type == OP_RV2GV)
	newop = newGVOP(OP_GV, 0, (GV*)sv, o->op_location);
    else
	newop = newSVOP(OP_CONST, 0, (SV*)sv, o->op_location);
#ifndef PERL_MAD
    op_free(o);
#endif
    op_getmad(o,newop,'f');
    return newop;

 nope:
    return o;
}

OP *
Perl_gen_constant_list(pTHX_ register OP *o)
{
    dVAR;
    register OP *curop;
    const I32 oldtmps_floor = PL_tmps_floor;

    list(o);
    if (PL_parser && PL_parser->error_count)
	return o;		/* Don't attempt to run with errors */

    PL_op = curop = LINKLIST(o);
    o->op_next = 0;
    CALL_PEEP(curop);
    pp_pushmark();
    CALLRUNOPS(aTHX);
    PL_op = curop;
    assert (!(curop->op_flags & OPf_SPECIAL));
    assert(curop->op_type == OP_RANGE);
    PL_op->op_flags &= ~OPf_REF;
    pp_anonarray();
    PL_tmps_floor = oldtmps_floor;

    o->op_type = OP_EXPAND;
    o->op_ppaddr = PL_ppaddr[OP_EXPAND];
    o->op_flags |= OPf_PARENS;	/* and flatten \(1..2,3) */
    o->op_opt = 0;		/* needs to be revisited in peep() */
    curop = ((UNOP*)o)->op_first;
    ((UNOP*)o)->op_first = newSVOP(OP_CONST, 0, SvREFCNT_inc_NN(*PL_stack_sp--), o->op_location);
#ifdef PERL_MAD
    op_getmad(curop,o,'O');
#else
    op_free(curop);
#endif
    linklist(o);
    return list(o);
}

OP *
Perl_convert(pTHX_ I32 type, OPFLAGS flags, OP *o, SV *location)
{
    dVAR;
    if (!o || o->op_type != OP_LIST)
	o = newLISTOP(OP_LIST, 0, o, NULL, location);
    else {
	o->op_flags &= ~OPf_WANT;
	SVcpREPLACE(o->op_location, location);
    }

    if (!(PL_opargs[type] & OA_MARK))
	op_null(cLISTOPo->op_first);

    o->op_type = (OPCODE)type;
    o->op_ppaddr = PL_ppaddr[type];
    o->op_flags |= flags;

    o = CHECKOP(type, o);
    if (o->op_type != (unsigned)type)
	return o;

    return fold_constants(o);
}

/*
=for apidoc op_assign

op_assign modified the OP C<*o> to be assignable, and returns the OP
which finishes the assignment.

=cut
*/
OP *
Perl_op_assign(pTHX_ OP** po, I32 optype)
{
    OP* o = *po;
    PERL_ARGS_ASSERT_OP_ASSIGN;

    switch (o->op_type) {
    case OP_NULL:
    case OP_HELEM:
    case OP_AELEM:
    {
	o->op_flags |= OPf_MOD;
	return op_assign(&(cBINOPx(o)->op_first), optype);
    }
    case OP_MAGICSV:
    {
	I32 min_modcount = 0;
	I32 max_modcount = 0;
	OP* copyo;
	OP* padop;
	OP* padop2;
	OP* copy_to_tmp;
	OP* copy_from_tmp;
	OP* o_sibling;

	const PADOFFSET tmpsv = pad_alloc(OP_SASSIGN, SVs_PADTMP);

	padop = newOP(OP_PADSV, OPf_MOD | OPf_ASSIGN, o->op_location);
	padop->op_private |= OPpLVAL_INTRO;
	padop->op_targ = tmpsv;

	o_sibling = o->op_sibling;
	o->op_sibling = NULL;
	copy_to_tmp =
	    newBINOP(
		OP_SASSIGN,
		    0,
		    scalar(o), 
		    scalar(padop),
		    o->op_location
		);
	copy_to_tmp->op_sibling = o_sibling;
	*po = copy_to_tmp;

	copyo = newSVOP(OP_MAGICSV, 0,
	    SvREFCNT_inc_NN(cSVOPx_sv(o)), sv_mortalcopy(o->op_location));
	copyo = assign(copyo, FALSE, &min_modcount, &max_modcount);

	padop2 = newOP(OP_PADSV, 0, o->op_location);
	padop2->op_targ = tmpsv;

	copy_from_tmp =
	    newBINOP(
		OP_SASSIGN,
		    0,
		    padop2,
		    copyo,
		    o->op_location
		);
    
	return copy_from_tmp;
    }
    case OP_ENTERSUB:
    case OP_ENTERSUB_SAVE:
    {
	I32 min_modcount = 0;
	I32 max_modcount = 0;
	OP* copyo;
	OP* padop;
	OP* padop2;
	OP* copy_to_tmp;
	OP* copy_from_tmp;
	OP* o_sibling;
	const bool existingpo = o->op_type == OP_ENTERSUB_SAVE;

	const PADOFFSET tmppo = pad_alloc(OP_SASSIGN, SVs_PADTMP);
	const PADOFFSET argspo = existingpo ? o->op_targ : pad_alloc(OP_SASSIGN, SVs_PADTMP);

	padop = newOP(OP_PADSV, OPf_MOD | OPf_ASSIGN, o->op_location);
	padop->op_private |= OPpLVAL_INTRO;
	padop->op_targ = tmppo;

	o->op_private |= OPpENTERSUB_SAVEARGS;
	o->op_targ = argspo;

	o_sibling = o->op_sibling;
	o->op_sibling = NULL;
	copy_to_tmp =
	    newBINOP(
		OP_SASSIGN,
		    0,
		    scalar(o), 
		    scalar(padop),
		    o->op_location
		);
	copy_to_tmp->op_sibling = o_sibling;
	*po = copy_to_tmp;

	copyo = newOP(OP_ENTERSUB_TARGARGS, 0, o->op_location);
	copyo->op_targ = argspo;
	copyo->op_flags = OPf_STACKED;
	copyo = assign(copyo, FALSE, &min_modcount, &max_modcount);

	padop2 = newOP(OP_PADSV, 0, o->op_location);
	padop2->op_targ = tmppo;

	copy_from_tmp =
	    newBINOP(
		OP_SASSIGN,
		    0,
		    padop2,
		    copyo,
		    o->op_location
		);
    
	return copy_from_tmp;
    }
    case OP_LISTFIRST:
    {
	/* LISTFIRST is only generated as part of C<op_assign> finish_assign op. */
	OP* copyo;
	OP* padop2;
	I32 min_modcount = 0;
	I32 max_modcount = 0;
	BINOP* oldassign = cBINOPx(cLISTOPo->op_last);
	assert(oldassign->op_type == OP_SASSIGN);

	copyo = newSVOP(oldassign->op_last->op_type, 0, cSVOPx_sv(oldassign->op_last), 
	    sv_mortalcopy(oldassign->op_location));
	copyo = assign(copyo, FALSE, &min_modcount, &max_modcount);

	padop2 = newOP(OP_PADSV, 0, oldassign->op_location);
	padop2->op_targ = oldassign->op_first->op_targ;

	return newBINOP(
	    OP_SASSIGN,
		0, 
		padop2,
		copyo,
		o->op_location
	    );
    }
    default:
	*po = mod(o, optype);
    }
    return NULL;
}

OP *
Perl_assign(pTHX_ OP *o, bool partial, I32 *min_modcount, I32 *max_modcount)
{
    OP* kid;

    PERL_ARGS_ASSERT_ASSIGN;

    switch (o->op_type) {
    case OP_STUB:
	break;

    case OP_LISTFIRST:
	assert(cBINOPo->op_first->op_sibling);
	cBINOPo->op_first->op_sibling
	    = assign(cBINOPo->op_first->op_sibling, partial, min_modcount, max_modcount);
	break;

    case OP_RV2SV:
    case OP_RV2AV:
    case OP_RV2HV:
    case OP_RV2GV:
    case OP_RV2CV:
    case OP_PADSV:
    case OP_MAGICSV:
    case OP_PLACEHOLDER:
	o->op_flags |= OPf_ASSIGN;
	if (partial)
	    o->op_flags |= OPf_ASSIGN_PART;
	(*max_modcount)++;
	if ( ! (o->op_flags & OPf_OPTIONAL) )
	    (*min_modcount)++;
	o = mod(o, OP_SASSIGN);
	break;

    case OP_HELEM:
    case OP_AELEM:
    case OP_HSLICE:
    case OP_ASLICE:
    case OP_ENTERSUB:
	o->op_flags |= OPf_ASSIGN;
	if (partial) {
	    o->op_flags |= OPf_ASSIGN_PART;
	    o->op_flags = (o->op_flags & ~OPf_WANT) | OPf_WANT_VOID;
	}
	(*max_modcount)++;
	if ( ! (o->op_flags & OPf_OPTIONAL) )
	    (*min_modcount)++;
	o = mod(o, o->op_type);
	break;

    case OP_ENTERSUB_SAVE: {
	OP* saveo = o;
	saveo->op_private |= OPpENTERSUB_SAVE_DISCARD;
	o = newUNOP(OP_ENTERSUB_TARGARGS, 0, saveo, saveo->op_location);
	o->op_targ = saveo->op_targ;
	o->op_flags |= OPf_ASSIGN | OPf_STACKED;
	if (partial) {
	    o->op_flags |= OPf_ASSIGN_PART;
	    o->op_flags = (o->op_flags & ~OPf_WANT) | OPf_WANT_VOID;
	}
	(*max_modcount)++;
	if ( ! (o->op_flags & OPf_OPTIONAL) )
	    (*min_modcount)++;
	break;
    }

    case OP_ENTERSUB_TARGARGS:
	o->op_flags |= OPf_ASSIGN;
	if (partial) {
	    o->op_flags |= OPf_ASSIGN_PART;
	    o->op_flags = (o->op_flags & ~OPf_WANT) | OPf_WANT_VOID;
	}
	(*max_modcount)++;
	if ( ! (o->op_flags & OPf_OPTIONAL) )
	    (*min_modcount)++;
	break;

    case OP_DOTDOTDOT:
	if ( ! partial )
	    goto no_assign;
	o->op_flags |= OPf_ASSIGN | OPf_ASSIGN_PART;
	if (*max_modcount < *min_modcount)
	    Perl_croak_at(aTHX_ o->op_location, 
		"Multiple variable number of arguments patterns are not allowed");
	(*max_modcount) = -1;
	break;

    case OP_NULL:
	assign(cUNOPo->op_first, partial, min_modcount, max_modcount);
	break;

    case OP_COND_EXPR:
    {
	I32 min_modcount2 = *min_modcount;
	I32 max_modcount2 = *max_modcount;
	assign(cUNOPo->op_first->op_sibling,
	    partial, min_modcount, max_modcount);
	assign(cUNOPo->op_first->op_sibling->op_sibling,
	    partial, &min_modcount2, &max_modcount2);
	if (min_modcount2 != *min_modcount || max_modcount2 != *max_modcount)
	    Perl_croak_at(aTHX_ o->op_location,
		"Conditional expression with different number of arguments not supported");
	break;
    }

    case OP_ARRAYEXPAND:
    case OP_HASHEXPAND:
	if ( ! partial )
	    goto no_assign;
	if (*max_modcount < *min_modcount)
	    Perl_croak_at(aTHX_ o->op_location, 
		"Multiple variable number of arguments patterns are not allowed");
	(*max_modcount) = -1;
	o->op_flags |= OPf_ASSIGN | OPf_ASSIGN_PART;
	{
	    I32 sub_min_modcount = 0;
	    I32 sub_max_modcount = 0;
	    OP* enter = newOP(
		o->op_type == OP_ARRAYEXPAND 
		    ? OP_ENTER_ARRAYEXPAND_ASSIGN 
		    : OP_ENTER_HASHEXPAND_ASSIGN,
		0, o->op_location);
	    enter->op_sibling = cBINOPo->op_first;
	    cBINOPo->op_first = enter;
	    assign(enter->op_sibling, TRUE, &sub_min_modcount, &sub_max_modcount);
	    if (sub_min_modcount != 1 || sub_max_modcount != 1)
		Perl_croak_at(aTHX_ o->op_location,
		    "%s must have a single valued argument", OP_DESC(o));
	}
	break;

    case OP_ANONARRAY:
	o->op_flags |= OPf_ASSIGN;
	if (partial)
	    o->op_flags |= OPf_ASSIGN_PART;
	(*max_modcount)++;
	if ( ! (o->op_flags & OPf_OPTIONAL) )
	    (*min_modcount)++;

	{
	    I32 sub_min_modcount = 0;
	    I32 sub_max_modcount = 0;
	    OP* pushmark = cBINOPo->op_first;
	    OP* enter = newOP(OP_ENTER_ANONARRAY_ASSIGN,
		partial ? (OPf_ASSIGN_PART | OPf_ASSIGN_PART) : OPf_ASSIGN,
		o->op_location);
	    enter->op_sibling = pushmark->op_sibling;
	    cBINOPo->op_first = enter;
	    op_free(pushmark);
	    for (kid = enter->op_sibling; kid; kid = kid->op_sibling)
		assign(kid, TRUE, &sub_min_modcount, &sub_max_modcount);
	}
	break;

    case OP_ANONHASH:
	o->op_flags |= OPf_ASSIGN;
	if (partial)
	    o->op_flags |= OPf_ASSIGN_PART;
	(*max_modcount)++;
	if ( ! (o->op_flags & OPf_OPTIONAL) )
	    (*min_modcount)++;

	{
	    /* split the ops into: OP_PUSHMARK, <key OP>*, OP_ENTER_ANONHASH_ASSIGN <subj OP>* */
	    I32 sub_min_modcount = 0;
	    I32 sub_max_modcount = 0;
	    OP* key_kid = cBINOPo->op_first;
	    OP* enter = newOP(OP_ENTER_ANONHASH_ASSIGN,
		partial ? (OPf_ASSIGN_PART | OPf_ASSIGN_PART) : OPf_ASSIGN,
		o->op_location);
	    OP* value_kid = enter;
	    OP* prev_kid = value_kid;
	    enter->op_sibling = key_kid->op_sibling;
	    key_kid->op_sibling = enter;
	    o->op_next = key_kid;
	    for (kid = prev_kid->op_sibling; kid; kid = prev_kid->op_sibling) {
		OP* op_optional;
		OP* real_kid = kid;
#ifdef PERL_MAD
		if (real_kid->op_type == OP_NULL)
		    real_kid = cUNOPx(real_kid)->op_first;
#endif
		if (real_kid->op_type != OP_CONST) {
		    if ( real_kid->op_type != OP_ARRAYEXPAND
			&& real_kid->op_type != OP_HASHEXPAND
			&& real_kid->op_type != OP_DOTDOTDOT )
			Perl_croak_at(aTHX_ real_kid->op_location, "hash key must be constant not a %s in a %s assignment", OP_DESC(real_kid), OP_DESC(o));
		    if (real_kid->op_sibling)
			Perl_croak_at(aTHX_ real_kid->op_location, "%s must be the last item in %s assignment", OP_DESC(real_kid), OP_DESC(o));
		    assign(kid, TRUE, &sub_min_modcount, &sub_max_modcount);
		    value_kid->op_next = LINKLIST(kid);
		    value_kid = kid;
		    break;
		}
		assign(kid->op_sibling, TRUE, &sub_min_modcount, &sub_max_modcount);

		/* Add optional op */
		op_optional = newSVOP(OP_CONST, 0,
		    (kid->op_flags & OPf_OPTIONAL) ? &PL_sv_yes : &PL_sv_no,
		    o->op_location);
		assert(prev_kid->op_sibling == kid);
		prev_kid->op_sibling = op_optional;
		op_optional->op_sibling = kid;
		op_optional->op_next = LINKLIST(kid);

		/* remove kid->op_sibling from the list and add it the the list of subj_kid */
		value_kid->op_next = LINKLIST(kid->op_sibling);
		value_kid = kid->op_sibling;
		key_kid->op_next = op_optional;
		key_kid = kid;

		prev_kid = kid->op_sibling;
	    }
	    key_kid->op_next = enter;
	    value_kid->op_next = o;
	}
	break;

    default:
    no_assign:
	yyerror_at(o->op_location, Perl_form(aTHX_ "Can't assign to %s", OP_DESC(o)));
    }
    return o;
}

/* List constructors */

OP *
Perl_append_elem(pTHX_ I32 type, OP *first, OP *last)
{
    if (!first)
	return last;

    if (!last)
	return first;

    if (first->op_type != (unsigned)type
	|| (type == OP_LIST && (first->op_flags & OPf_PARENS)))
    {
	return newLISTOP(type, 0, first, last, first->op_location);
    }

    if (first->op_flags & OPf_KIDS)
	((LISTOP*)first)->op_last->op_sibling = last;
    else {
	first->op_flags |= OPf_KIDS;
	((LISTOP*)first)->op_first = last;
    }
    ((LISTOP*)first)->op_last = last;
    return first;
}

OP *
Perl_append_list(pTHX_ I32 type, LISTOP *first, LISTOP *last)
{
    if (!first)
	return (OP*)last;

    if (!last)
	return (OP*)first;

    if (first->op_type != (unsigned)type)
	return prepend_elem(type, (OP*)first, (OP*)last);

    if (last->op_type != (unsigned)type)
	return append_elem(type, (OP*)first, (OP*)last);

    first->op_last->op_sibling = last->op_first;
    first->op_last = last->op_last;
    first->op_flags |= (last->op_flags & OPf_KIDS);

#ifdef PERL_MAD
    if (last->op_first && first->op_madprop) {
	MADPROP *mp = last->op_first->op_madprop;
	if (mp) {
	    while (mp->mad_next)
		mp = mp->mad_next;
	    mp->mad_next = first->op_madprop;
	}
	else {
	    last->op_first->op_madprop = first->op_madprop;
	}
    }
    first->op_madprop = last->op_madprop;
    last->op_madprop = 0;
#endif

    S_op_destroy(aTHX_ (OP*)last);

    return (OP*)first;
}

OP *
Perl_prepend_elem(pTHX_ I32 type, OP *first, OP *last)
{
    if (!first)
	return last;

    if (!last)
	return first;

    if (last->op_type == (unsigned)type) {
	if (type == OP_LIST) {	/* already a PUSHMARK there */
	    first->op_sibling = ((LISTOP*)last)->op_first->op_sibling;
	    ((LISTOP*)last)->op_first->op_sibling = first;
            if (!(first->op_flags & OPf_PARENS))
                last->op_flags &= ~OPf_PARENS;
	}
	else {
	    if (!(last->op_flags & OPf_KIDS)) {
		((LISTOP*)last)->op_last = first;
		last->op_flags |= OPf_KIDS;
	    }
	    first->op_sibling = ((LISTOP*)last)->op_first;
	    ((LISTOP*)last)->op_first = first;
	}
	last->op_flags |= OPf_KIDS;
	return last;
    }

    return newLISTOP(type, 0, first, last, first->op_location);
}

/* Constructors */

#ifdef PERL_MAD
 
MADTOKEN *
Perl_newMADTOKEN(pTHX_ I32 optype, MADPROP* madprop)
{
    MADTOKEN *tk;
    Newxz(tk, 1, MADTOKEN);
    tk->tk_mad = madprop;
    return tk;
}

void
Perl_token_free(pTHX_ MADTOKEN* tk)
{
    PERL_ARGS_ASSERT_TOKEN_FREE;

    mad_free(tk->tk_mad);
    Safefree(tk);
}

void
Perl_token_getmad(pTHX_ MADTOKEN* tk, OP* o, char slot, SV* location)
{
    MADPROP* mp;
    MADPROP* tm;
    IV linenr;
    IV charoffset;

    PERL_ARGS_ASSERT_TOKEN_GETMAD;

    linenr = location ? SvIV(*(av_fetch(svTav(location), 1, FALSE))) : 0;
    charoffset = location ? SvIV(*(av_fetch(svTav(location), 2, FALSE))) : 0;

    tm = tk->tk_mad;
    if (!tm)
	return;

    tm->mad_linenr = linenr;
    tm->mad_charoffset = charoffset;

    /* faked up qw list? */
    if (slot == '(' &&
	tm->mad_type == MAD_SV &&
	SvPVX_const((SV*)tm->mad_val)[0] == 'q')
	    slot = 'x';

    if (o) {
	mp = o->op_madprop;
	if (mp) {
	    for (;;) {
		/* pretend constant fold didn't happen? */
		if (mp->mad_key == 'f' &&
		    (o->op_type == OP_CONST ||
		     o->op_type == OP_GV) )
		{
		    token_getmad(tk, (OP*)mp->mad_val,slot, location);
		    return;
		}
		if (!mp->mad_next)
		    break;
		mp = mp->mad_next;
	    }
	    mp->mad_next = tm;
	    mp = mp->mad_next;
	}
	else {
	    o->op_madprop = tm;
	    mp = o->op_madprop;
	}
	if (mp->mad_key == 'X')
	    mp->mad_key = slot;	/* just change the first one */

	tk->tk_mad = 0;
    }
    else
	mad_free(tm);
    Safefree(tk);
}

void
Perl_op_getmad_weak(pTHX_ OP* from, OP* o, char slot)
{
    MADPROP* mp;
    if (!from)
	return;
    if (o) {
	mp = o->op_madprop;
	if (mp) {
	    for (;;) {
		/* pretend constant fold didn't happen? */
		if (mp->mad_key == 'f' &&
		    (o->op_type == OP_CONST ||
		     o->op_type == OP_GV) )
		{
		    op_getmad(from,(OP*)mp->mad_val,slot);
		    return;
		}
		if (!mp->mad_next)
		    break;
		mp = mp->mad_next;
	    }
	    mp->mad_next = newMADPROP(slot,MAD_OP,from,0,0,0);
	}
	else {
	    o->op_madprop = newMADPROP(slot,MAD_OP,from,0,0,0);
	}
    }
}

void
Perl_op_getmad(pTHX_ OP* from, OP* o, char slot)
{
    MADPROP* mp;
    if (!from)
	return;
    if (o) {
	mp = o->op_madprop;
	if (mp) {
	    for (;;) {
		/* pretend constant fold didn't happen? */
		if (mp->mad_key == 'f' &&
		    (o->op_type == OP_CONST ||
		     o->op_type == OP_GV) )
		{
		    op_getmad(from,(OP*)mp->mad_val,slot);
		    return;
		}
		if (!mp->mad_next)
		    break;
		mp = mp->mad_next;
	    }
	    mp->mad_next = newMADPROP(slot,MAD_OP,from,1,0,0);
	}
	else {
	    o->op_madprop = newMADPROP(slot,MAD_OP,from,1,0,0);
	}
    }
    else {
	PerlIO_printf(PerlIO_stderr(),
		      "DESTROYING op = %0"UVxf"\n", PTR2UV(from));
	op_free(from);
    }
}

void
Perl_prepend_madprops(pTHX_ MADPROP* mp, OP* o, char slot)
{
    MADPROP* tm;
    if (!mp || !o)
	return;
    if (slot)
	mp->mad_key = slot;
    tm = o->op_madprop;
    o->op_madprop = mp;
    for (;;) {
	if (!mp->mad_next)
	    break;
	mp = mp->mad_next;
    }
    mp->mad_next = tm;
}

void
Perl_append_madprops(pTHX_ MADPROP* tm, OP* o, char slot)
{
    if (!o)
	return;
    addmad(tm, &(o->op_madprop), slot);
}

void
Perl_append_madprops_pv(pTHX_ const char* v, OP* o, char slot)
{
    PERL_ARGS_ASSERT_APPEND_MADPROPS_PV;
    append_madprops(newMADsv(slot, newSVpv(v, 0), 0, 0), o, slot);
}

void
Perl_addmad(pTHX_ MADPROP* tm, MADPROP** root, char slot)
{
    MADPROP* mp;
    if (!tm || !root)
	return;
    if (slot)
	tm->mad_key = slot;
    mp = *root;
    if (!mp) {
	*root = tm;
	return;
    }
    for (;;) {
	if (!mp->mad_next)
	    break;
	mp = mp->mad_next;
    }
    mp->mad_next = tm;
}

MADPROP *
Perl_newMADsv(pTHX_ char key, SV* sv, IV linenr, IV charoffset)
{
    PERL_ARGS_ASSERT_NEWMADSV;

    return newMADPROP(key, MAD_SV, sv, 0, linenr, charoffset);
}

MADPROP *
Perl_newMADPROP(pTHX_ char key, char type, void* val, I32 vlen, IV linenr, IV charoffset)
{
    MADPROP *mp;
    Newxz(mp, 1, MADPROP);
    mp->mad_next = 0;
    mp->mad_key = key;
    mp->mad_vlen = vlen;
    mp->mad_type = type;
    mp->mad_val = val;
    mp->mad_linenr = linenr;
    mp->mad_charoffset = charoffset;
/*    PerlIO_printf(PerlIO_stderr(), "NEW  mp = %0x\n", mp);  */
    return mp;
}

void
Perl_mad_free(pTHX_ MADPROP* mp)
{
/*    PerlIO_printf(PerlIO_stderr(), "FREE mp = %0x\n", mp); */
    if (!mp)
	return;
    if (mp->mad_next)
	mad_free(mp->mad_next);
/*    if (PL_parser && PL_parser->lex_state != LEX_NOTPARSING && mp->mad_vlen)
	PerlIO_printf(PerlIO_stderr(), "DESTROYING '%c'=<%s>\n", mp->mad_key & 255, mp->mad_val); */
    switch (mp->mad_type) {
    case MAD_OP:
	if (mp->mad_vlen)	/* vlen holds "strong/weak" boolean */
	    op_free((OP*)mp->mad_val);
	break;
    case MAD_SV:
	sv_free(MUTABLE_SV(mp->mad_val));
	break;
    default:
	PerlIO_printf(PerlIO_stderr(), "Unrecognized mad\n");
	break;
    }
    Safefree(mp);
}

#endif

OP *
Perl_newNULLLIST(pTHX_ SV *location)
{
    return newOP(OP_STUB, 0, location);
}

OP *
Perl_force_list(pTHX_ OP *o)
{
    if (!o || o->op_type != OP_LIST)
	o = newLISTOP(OP_LIST, 0, o, NULL, NULL);
    op_null(o);
    return o;
}

OP *
Perl_newLISTOP(pTHX_ I32 type, OPFLAGS flags, OP *first, OP *last, SV *location)
{
    dVAR;
    LISTOP *listop;

    NewOp(1101, listop, 1, LISTOP);

    listop->op_type = (OPCODE)type;
    listop->op_ppaddr = PL_ppaddr[type];
    if (first || last)
	flags |= OPf_KIDS;
    listop->op_flags = (U8)flags;
    listop->op_location = SvREFCNT_inc(location);

    if (!last && first)
	last = first;
    else if (!first && last)
	first = last;
    else if (first)
	first->op_sibling = last;
    listop->op_first = first;
    listop->op_last = last;
    if (type == OP_LIST || type == OP_LISTLAST || type == OP_LISTFIRST) {
	OP* const pushop = newOP(OP_PUSHMARK, 0, location);
	pushop->op_sibling = first;
	listop->op_first = pushop;
	listop->op_flags |= OPf_KIDS;
	if (!last)
	    listop->op_last = pushop;
    }

    return CHECKOP(type, listop);
}

OP *
Perl_newOP(pTHX_ I32 type, OPFLAGS flags, SV* location)
{
    dVAR;
    OP *o;
    NewOp(1101, o, 1, OP);
    o->op_type = (OPCODE)type;
    o->op_ppaddr = PL_ppaddr[type];
    o->op_flags = flags;

    o->op_location = SvREFCNT_inc(location);

    o->op_next = o;
    o->op_private = (U8)(0 | (flags >> 8));
    if (PL_opargs[type] & OA_RETSCALAR)
	scalar(o);
    if (PL_opargs[type] & OA_TARGET)
	o->op_targ = pad_alloc(type, SVs_PADTMP);
    return CHECKOP(type, o);
}

OP *
Perl_newUNOP(pTHX_ I32 type, OPFLAGS flags, OP *first, SV* location)
{
    dVAR;
    UNOP *unop;

    if (!first)
	first = newOP(OP_STUB, 0, location);
    if (PL_opargs[type] & OA_MARK)
	first = force_list(first);

    NewOp(1101, unop, 1, UNOP);
    unop->op_type = (OPCODE)type;
    unop->op_ppaddr = PL_ppaddr[type];
    unop->op_first = first;
    unop->op_flags = (flags | OPf_KIDS);
    unop->op_private = 1;
    unop->op_location = SvREFCNT_inc(location);
    unop = (UNOP*) CHECKOP(type, unop);
    if (unop->op_next)
	return (OP*)unop;

    return fold_constants((OP *) unop);
}

OP *
Perl_newBINOP(pTHX_ I32 type, OPFLAGS flags, OP *first, OP *last, SV* location)
{
    dVAR;
    BINOP *binop;
    NewOp(1101, binop, 1, BINOP);

    if (!first) {
	first = newOP(OP_NULL, 0, location);
    }

    binop->op_location = SvREFCNT_inc(location);

    binop->op_type = (OPCODE)type;
    binop->op_ppaddr = PL_ppaddr[type];
    binop->op_first = first;
    binop->op_flags = (U8)(flags | OPf_KIDS);
    if (!last) {
	last = first;
	binop->op_private = (U8)(1 | (flags >> 8));
    }
    else {
	binop->op_private = (U8)(2 | (flags >> 8));
	first->op_sibling = last;
    }

    binop = (BINOP*)CHECKOP(type, binop);
    if (binop->op_next || binop->op_type != (OPCODE)type)
	return (OP*)binop;

    binop->op_last = binop->op_first->op_sibling;

    return fold_constants((OP *)binop);
}

OP *
Perl_newPMOP(pTHX_ I32 type, OPFLAGS flags, SV *location)
{
    dVAR;
    PMOP *pmop;

    NewOp(1101, pmop, 1, PMOP);
    pmop->op_type = (OPCODE)type;
    pmop->op_ppaddr = PL_ppaddr[type];
    pmop->op_flags = (U8)flags;
    pmop->op_private = (U8)(0 | (flags >> 8));
    pmop->op_location = SvREFCNT_inc(location);

    return CHECKOP(type, pmop);
}

/* Given some sort of match op o, and an expression expr containing a
 * pattern, either compile expr into a regex and attach it to o (if it's
 * constant), or convert expr into a runtime regcomp op sequence (if it's
 * not)
 *
 * isreg indicates that the pattern is part of a regex construct, eg
 * $x =~ /pattern/ or split /pattern/, as opposed to $x =~ $pattern or
 * split "pattern", which aren't. In the former case, expr will be a list
 * if the pattern contains more than one term (eg /a$b/) or if it contains
 * a replacement, ie s/// or tr///.
 */

OP *
Perl_pmruntime(pTHX_ OP *o, OP *expr, bool isreg)
{
    dVAR;
    PMOP *pm;
    LOGOP *rcop;
    I32 repl_has_vars = 0;
    OP* repl = NULL;
    bool reglist;

    PERL_ARGS_ASSERT_PMRUNTIME;

    if (o->op_type == OP_SUBST) {
	/* last element in list is the replacement; pop it */
	OP* kid;
	repl = cLISTOPx(expr)->op_last;
	kid = cLISTOPx(expr)->op_first;
	while (kid->op_sibling != repl)
	    kid = kid->op_sibling;
	kid->op_sibling = NULL;
	cLISTOPx(expr)->op_last = kid;
    }

    if (isreg && expr->op_type == OP_LIST &&
	cLISTOPx(expr)->op_first->op_sibling == cLISTOPx(expr)->op_last)
    {
	/* convert single element list to element */
	OP* const oe = expr;
	expr = cLISTOPx(oe)->op_first->op_sibling;
	cLISTOPx(oe)->op_first->op_sibling = NULL;
	cLISTOPx(oe)->op_last = NULL;
	op_free(oe);
    }

    reglist = isreg && expr->op_type == OP_LIST;
    if (reglist)
	op_null(expr);

    PL_hints |= HINT_BLOCK_SCOPE;
    pm = (PMOP*)o;

    if (PL_parser && PL_parser->error_count)
        return pm;

    if (expr->op_type == OP_CONST) {
	STRLEN plen;
	SV * const pat = ((SVOP*)expr)->op_sv;
	const char *p = SvPV_const(pat, plen);
	U32 pm_flags = pm->op_pmflags & PMf_COMPILETIME;
	if ((o->op_flags & OPf_SPECIAL) && (plen == 1 && *p == ' ')) {
	    U32 was_readonly = SvREADONLY(pat);

	    if (was_readonly) {
		if (SvFAKE(pat)) {
		    sv_force_normal_flags(pat, 0);
		    assert(!SvREADONLY(pat));
		    was_readonly = 0;
		} else {
		    SvREADONLY_off(pat);
		}
	    }   

	    sv_setpvn(pat, "\\s+", 3);

	    SvFLAGS(pat) |= was_readonly;

	    p = SvPV_const(pat, plen);
	    pm_flags |= RXf_SKIPWHITE;
	}
	if (IN_CODEPOINTS)
	    pm_flags |= RXf_PMf_UTF8;
	PM_SETRE(pm, CALLREGCOMP(pat, pm_flags));

#ifdef PERL_MAD
	op_getmad(expr,(OP*)pm,'e');
#else
	op_free(expr);
#endif
    }
    else {
	if (pm->op_pmflags & PMf_KEEP || !(PL_hints & HINT_RE_EVAL))
	    expr = newUNOP((!(PL_hints & HINT_RE_EVAL)
			    ? OP_REGCRESET
			    : OP_REGCMAYBE),0,expr, expr->op_location);

	NewOp(1101, rcop, 1, LOGOP);
	rcop->op_type = OP_REGCOMP;
	rcop->op_ppaddr = PL_ppaddr[OP_REGCOMP];
	rcop->op_first = scalar(expr);
	rcop->op_flags |= OPf_KIDS
			    | ((PL_hints & HINT_RE_EVAL) ? OPf_SPECIAL : 0)
			    | (reglist ? OPf_STACKED : 0);
	rcop->op_private = 1;
	rcop->op_other = o;
	rcop->op_location = SvREFCNT_inc(expr->op_location);
	if (reglist)
	    rcop->op_targ = pad_alloc(rcop->op_type, SVs_PADTMP);

	/* /$x/ may cause an eval, since $x might be qr/(?{..})/  */
	PL_cv_has_eval = 1;

	/* establish postfix order */
	if (pm->op_pmflags & PMf_KEEP || !(PL_hints & HINT_RE_EVAL)) {
	    LINKLIST(expr);
	    rcop->op_next = expr;
	    ((UNOP*)expr)->op_first->op_next = (OP*)rcop;
	}
	else {
	    rcop->op_next = LINKLIST(expr);
	    expr->op_next = (OP*)rcop;
	}

	prepend_elem(o->op_type, scalar((OP*)rcop), o);
    }

    if (repl) {
	OP *curop = NULL;
	if (repl->op_type == OP_CONST)
	    curop = repl;
	if (curop == repl
	    && !(repl_has_vars
		 && (!PM_GETRE(pm)
		     || RX_EXTFLAGS(PM_GETRE(pm)) & RXf_EVAL_SEEN)))
	{
	    pm->op_pmflags |= PMf_CONST;	/* const for long enough */
	    prepend_elem(o->op_type, scalar(repl), o);
	}
	else {
	    if (curop == repl && !PM_GETRE(pm)) { /* Has variables. */
		pm->op_pmflags |= PMf_MAYBE_CONST;
	    }
	    NewOp(1101, rcop, 1, LOGOP);
	    rcop->op_type = OP_SUBSTCONT;
	    rcop->op_ppaddr = PL_ppaddr[OP_SUBSTCONT];
	    rcop->op_first = scalar(repl);
	    rcop->op_flags |= OPf_KIDS;
	    rcop->op_private = 1;
	    rcop->op_other = o;
	    rcop->op_location = SvREFCNT_inc(o->op_location);

	    /* establish postfix order */
	    rcop->op_next = LINKLIST(repl);
	    repl->op_next = (OP*)rcop;

	    pm->op_pmreplrootu.op_pmreplroot = scalar((OP*)rcop);
	    pm->op_pmstashstartu.op_pmreplstart = LINKLIST(rcop);
	    rcop->op_next = 0;
	}
    }

    return (OP*)pm;
}

OP *
Perl_newSVOP(pTHX_ I32 type, OPFLAGS flags, SV *sv, SV *location)
{
    dVAR;
    SVOP *svop;

    PERL_ARGS_ASSERT_NEWSVOP;

    NewOp(1101, svop, 1, SVOP);
    svop->op_type = (OPCODE)type;
    svop->op_ppaddr = PL_ppaddr[type];
    svop->op_sv = sv;
    svop->op_next = (OP*)svop;
    svop->op_flags = (U8)flags;
    svop->op_location = SvREFCNT_inc(location);
    if (PL_opargs[type] & OA_RETSCALAR)
	scalar((OP*)svop);
    if (PL_opargs[type] & OA_TARGET)
	svop->op_targ = pad_alloc(type, SVs_PADTMP);
    return CHECKOP(type, svop);
}

OP *
Perl_newGVOP(pTHX_ I32 type, OPFLAGS flags, GV *gv, SV *location)
{
    dVAR;

    PERL_ARGS_ASSERT_NEWGVOP;

    return newSVOP(type, flags, SvREFCNT_inc_NN(gv), location);
}

OP *
Perl_newPVOP(pTHX_ I32 type, OPFLAGS flags, char *pv, SV *location)
{
    dVAR;
    PVOP *pvop;
    NewOp(1101, pvop, 1, PVOP);
    pvop->op_type = (OPCODE)type;
    pvop->op_ppaddr = PL_ppaddr[type];
    pvop->op_pv = pv;
    pvop->op_next = (OP*)pvop;
    pvop->op_flags = (U8)flags;
    pvop->op_location = SvREFCNT_inc(location);
    if (PL_opargs[type] & OA_RETSCALAR)
	scalar((OP*)pvop);
    if (PL_opargs[type] & OA_TARGET)
	pvop->op_targ = pad_alloc(type, SVs_PADTMP);
    return CHECKOP(type, pvop);
}

#ifdef PERL_MAD
OP*
#else
void
#endif
Perl_package(pTHX_ OP *o)
{
    dVAR;
    SV *const sv = cSVOPo->op_sv;
#ifdef PERL_MAD
    OP *pegop;
#endif

    PERL_ARGS_ASSERT_PACKAGE;

    SAVESPTR(PL_curstash);
    SAVESPTR(PL_curstname);

    HVcpREPLACE(PL_curstash, gv_stashsv(sv, GV_ADD));

    SVcpSTEAL(PL_curstname, newSVsv(sv));

    PL_hints |= HINT_BLOCK_SCOPE;
    PL_parser->expect = XSTATE;

#ifndef PERL_MAD
    op_free(o);
#else
    if (!PL_madskills) {
	op_free(o);
	return NULL;
    }

    pegop = newOP(OP_NULL,0, o->op_location);
    op_getmad(o,pegop,'P');
    return pegop;
#endif
}

#ifdef PERL_MAD
OP*
#else
CV*
#endif
Perl_utilize(pTHX_ int aver, I32 floor, OP *version, OP *idop, OP *arg)
{
    dVAR;
    OP *pack;
    OP *imop;
    OP *veop;
    CV *cv;
#ifdef PERL_MAD
    OP *pegop = newSVOP(OP_NULL, 0, newSV(0), idop->op_location);
#endif

    PERL_ARGS_ASSERT_UTILIZE;

    if (idop->op_type != OP_CONST)
	Perl_croak(aTHX_ "Module name must be constant");

#ifdef PERL_MAD
    if (PL_madskills) {
	op_getmad(idop,pegop,'U');
	append_madprops_pv("use", pegop, '>');
    }
#endif

    veop = NULL;

    if (version) {
	OP *pack;
	SV *meth;

	if (PL_madskills)
	    op_getmad(version,pegop,'V');

        if (version->op_type != OP_CONST)
	    Perl_croak(aTHX_ "Version number must be a constant number");

	/* Make copy of idop so we don't free it twice */
	pack = newSVOP(OP_CONST, 0, newSVsv(((SVOP*)idop)->op_sv), idop->op_location);

	/* Fake up a method call to VERSION */
	meth = newSVpvs_share("VERSION");
	veop = convert(OP_ENTERSUB, OPf_STACKED|OPf_SPECIAL,
		       append_elem(OP_LIST,
				   prepend_elem(OP_LIST, pack, list(version)),
			   newSVOP(OP_METHOD_NAMED, 0, meth, version->op_location)), version->op_location);
    }

    /* Fake up an import/unimport */
    if (arg && arg->op_type == OP_STUB) {
	if (PL_madskills)
	    op_getmad(arg,pegop,'S');
	imop = arg;		/* no import on explicit () */
    }
    else {
	SV *meth;

	if (PL_madskills)
	    op_getmad(arg,pegop,'A');

	/* Make copy of idop so we don't free it twice */
	pack = newSVOP(OP_CONST, 0, newSVsv(((SVOP*)idop)->op_sv), idop->op_location);

	/* Fake up a method call to import/unimport */
	meth = aver
	    ? newSVpvs_share("import") : newSVpvs_share("unimport");
	imop = convert(OP_ENTERSUB, OPf_STACKED|OPf_SPECIAL|OPf_WANT_VOID,
	    append_elem(OP_LIST,
		prepend_elem(OP_LIST, pack, list(arg)),
		newSVOP(OP_METHOD_NAMED, 0, meth, idop->op_location)), idop->op_location);
    }

    {
	/* Fake up the BEGIN {}, which does its thing immediately. */
	cv = cv_2mortal(newSUB(floor,
	    NULL,
	    append_elem(OP_LINESEQ,
		append_elem(OP_LINESEQ,
		    newSTATEOP(0, NULL, newUNOP(OP_REQUIRE, 0, idop, idop->op_location), idop->op_location),
		    newSTATEOP(0, NULL, veop, (veop ? veop : idop)->op_location)),
		newSTATEOP(0, NULL, imop, (imop ? imop : idop)->op_location) )));
	
	SVcpSTEAL( SvLOCATION(cvTsv(cv)), 
	    idop->op_location ? newSVsv(idop->op_location) : avTsv(newAV()) );
	if (SvAVOK(SvLOCATION((SV*)cv))) {
	    av_store(svTav(SvLOCATION((SV*)cv)), LOC_NAME_INDEX, newSVpv("use", 0));
	}

    }

    /* The "did you use incorrect case?" warning used to be here.
     * The problem is that on case-insensitive filesystems one
     * might get false positives for "use" (and "require"):
     * "use Strict" or "require CARP" will work.  This causes
     * portability problems for the script: in case-strict
     * filesystems the script will stop working.
     *
     * The "incorrect case" warning checked whether "use Foo"
     * imported "Foo" to your namespace, but that is wrong, too:
     * there is no requirement nor promise in the language that
     * a Foo.pm should or would contain anything in package "Foo".
     *
     * There is very little Configure-wise that can be done, either:
     * the case-sensitivity of the build filesystem of Perl does not
     * help in guessing the case-sensitivity of the runtime environment.
     */

    PL_hints |= HINT_BLOCK_SCOPE;
    PL_parser->expect = XSTATE;
    PL_cop_seqmax++; /* Purely for B::*'s benefit */

#ifdef PERL_MAD
    SVcpREPLACE(cSVOPx(pegop)->op_sv, cvTsv(cv));
    return pegop;
#else
    return cv;
#endif
}

/*
=head1 Embedding Functions

=for apidoc load_module

Loads the module whose name is pointed to by the string part of name.
Note that the actual module name, not its filename, should be given.
Eg, "Foo::Bar" instead of "Foo/Bar.pm".  flags can be any of
PERL_LOADMOD_DENY, PERL_LOADMOD_NOIMPORT, or PERL_LOADMOD_IMPORT_OPS
(or 0 for no flags). ver, if specified, provides version semantics
similar to C<use Foo::Bar VERSION>.  The optional trailing SV*
arguments can be used to specify arguments to the module's import()
method, similar to C<use Foo::Bar VERSION LIST>.  They must be
terminated with a final NULL pointer.  Note that this list can only
be omitted when the PERL_LOADMOD_NOIMPORT flag has been used.
Otherwise at least a single NULL pointer to designate the default
import list is required.

=cut */

void
Perl_load_module(pTHX_ U32 flags, SV *name, SV *ver, ...)
{
    va_list args;

    PERL_ARGS_ASSERT_LOAD_MODULE;

    va_start(args, ver);
    vload_module(flags, name, ver, &args);
    va_end(args);
}

void
Perl_vload_module(pTHX_ U32 flags, SV *name, SV *ver, va_list *args)
{
    dVAR;
    OP *veop, *imop;
    OP * const modname = newSVOP(OP_CONST, 0, name, NULL);
    CV * cv;

    PERL_ARGS_ASSERT_VLOAD_MODULE;

    modname->op_private |= OPpCONST_BARE;
    if (ver) {
	veop = newSVOP(OP_CONST, 0, ver, NULL);
    }
    else
	veop = NULL;
    if (flags & PERL_LOADMOD_NOIMPORT) {
	imop = sawparens(newNULLLIST(NULL));
    }
    else if (flags & PERL_LOADMOD_IMPORT_OPS) {
	imop = va_arg(*args, OP*);
    }
    else {
	SV *sv;
	imop = NULL;
	sv = va_arg(*args, SV*);
	while (sv) {
	    imop = append_elem(OP_LIST, imop, newSVOP(OP_CONST, 0, sv, NULL));
	    sv = va_arg(*args, SV*);
	}
    }

    /* utilize() fakes up a BEGIN { require ..; import ... }, so make sure
     * that it has a PL_parser to play with while doing that, and also
     * that it doesn't mess with any existing parser, by creating a tmp
     * new parser with lex_start(). This won't actually be used for much,
     * since pp_require() will create another parser for the real work. */

    ENTER_named("vload_module");
    SAVEVPTR(PL_curcop);
    lex_start(NULL, NULL, FALSE);
    SVcpREPLACE(PL_parser->lex_filename, newSVpv("fake begin block", 0));
#ifdef PERL_MAD
    {
	OP* op = utilize(!(flags & PERL_LOADMOD_DENY), start_subparse(0),
	    veop, modname, imop);
	cv = svTcv(cSVOPx(op)->op_sv);
    }
#else
    cv = utilize(!(flags & PERL_LOADMOD_DENY), start_subparse(0),
	veop, modname, imop);
#endif
    process_special_block(KEY_BEGIN, cv);
    LEAVE_named("vload_module");
}

OP *
Perl_newSLICEOP(pTHX_ OPFLAGS flags, OP *subscript, OP *listval)
{
    return newBINOP(OP_LSLICE, flags, subscript,
		    list(force_list(listval)), subscript->op_location );
}

OP *
Perl_newASSIGNOP(pTHX_ OPFLAGS flags, OP *left, I32 optype, OP *right, SV *location)
{
    dVAR;
    OP *o;

    if (optype) {
	bool is_logassign = (optype == OP_ANDASSIGN || optype == OP_ORASSIGN || optype == OP_DORASSIGN);

	if (is_logassign) {
	    OP* new_left = left;
	    OP* finish_assign = op_assign(&new_left, optype);

	    if (finish_assign) {
		o = newBINOP(OP_SASSIGN, 0, scalar(right),
		    newOP(OP_LOGASSIGN_ASSIGN, 0, location), location);
		o = append_elem(OP_LISTLAST, o, finish_assign);
		return newLOGOP(optype, 0, scalar(new_left), o, location);
	    }
	    else {
		o = newBINOP(OP_SASSIGN, 0, scalar(right),
		    newOP(OP_LOGASSIGN_ASSIGN, 0, location), location);
		return newLOGOP(optype, 0, mod(scalar(left), optype), o, location);
	    }
	}
	else {
	    OP* new_left = scalar(left);
	    OP* finish_assign = op_assign(&new_left, optype);
	    o = newBINOP(optype, OPf_STACKED,
		mod(new_left, optype), scalar(right), location);
	    if (finish_assign) {
		o = append_elem(OP_LISTLAST, o, finish_assign);
	    }
	    return o;
	}
    }

    if (!right)
	right = newOP(OP_UNDEF, 0, location);
    if (right->op_type == OP_READLINE) {
	right->op_flags |= OPf_STACKED;
	return newBINOP(OP_NULL, flags, 
	    mod(scalar(left), OP_SASSIGN), scalar(right),
	    location);
    }
    else {
	I32 min_modcount = 0;
	I32 max_modcount = 0;
	o = newBINOP(OP_SASSIGN,
	    flags,
	    scalar(right), 
	    assign(scalar(left), FALSE, &min_modcount, &max_modcount),
	    location );
    }
    return o;
}

OP *
Perl_newSTATEOP(pTHX_ OPFLAGS flags, char *label, OP *o, SV *location)
{
    dVAR;
    const U32 seq = intro_my();
    register COP *cop;

    NewOp(1101, cop, 1, COP);
    if (PERLDB_LINE && PL_curstash != PL_debstash) {
	cop->op_type = OP_DBSTATE;
	cop->op_ppaddr = PL_ppaddr[ OP_DBSTATE ];
    }
    else {
	cop->op_type = OP_NEXTSTATE;
	cop->op_ppaddr = PL_ppaddr[ OP_NEXTSTATE ];
    }
    cop->op_flags = (U8)flags;
    cop->op_location = SvREFCNT_inc(location);
    CopHINTS_set(cop, PL_hints);
#ifdef NATIVE_HINTS
    cop->op_private |= NATIVE_HINTS;
#endif
    CopHINTS_set(&PL_compiling, CopHINTS_get(cop));
    cop->op_next = (OP*)cop;

    if (label) {
	CopLABEL_set(cop, label);
	PL_hints |= HINT_BLOCK_SCOPE;
    }
    cop->cop_seq = seq;
    cop->cop_warnings = DUP_WARNINGS(PL_curcop->cop_warnings);
    cop->cop_hints_hash = PL_curcop->cop_hints_hash;
    HvREFCNT_inc(cop->cop_hints_hash);

    CopSTASH_set(cop, PL_curstash);

    if (flags & OPf_SPECIAL)
	op_null((OP*)cop);
    return prepend_elem(OP_LINESEQ, (OP*)cop, o);
}


OP *
Perl_newLOGOP(pTHX_ I32 type, OPFLAGS flags, OP *first, OP *other, SV *location)
{
    dVAR;

    PERL_ARGS_ASSERT_NEWLOGOP;

    return new_logop(type, flags, &first, &other, location);
}

STATIC OP *
S_new_logop(pTHX_ I32 type, OPFLAGS flags, OP** firstp, OP** otherp, SV *location)
{
    dVAR;
    LOGOP *logop;
    OP *o;
    OP *first = *firstp;
    OP * const other = *otherp;

    PERL_ARGS_ASSERT_NEW_LOGOP;

    if (type == OP_XOR)		/* Not short circuit, but here by precedence. */
	return newBINOP(type, flags, scalar(first), scalar(other), location);

    scalarboolean(first);
    /* optimize "!a && b" to "a || b", and "!a || b" to "a && b" */
    if (first->op_type == OP_NOT
	&& (first->op_flags & OPf_SPECIAL)
	&& (first->op_flags & OPf_KIDS)
	&& !PL_madskills) {
	if (type == OP_AND || type == OP_OR) {
	    if (type == OP_AND)
		type = OP_OR;
	    else
		type = OP_AND;
	    o = first;
	    first = *firstp = cUNOPo->op_first;
	    if (o->op_next)
		first->op_next = o->op_next;
	    cUNOPo->op_first = NULL;
	    op_free(o);
	}
    }
    if (first->op_type == OP_CONST) {
	if (first->op_private & OPpCONST_STRICT)
	    no_bareword_allowed(first);
	else if ((first->op_private & OPpCONST_BARE) && ckWARN(WARN_BAREWORD))
		Perl_warner(aTHX_ packWARN(WARN_BAREWORD), "Bareword found in conditional");
	if ((type == OP_AND &&  SvTRUE(((SVOP*)first)->op_sv)) ||
	    (type == OP_OR  && !SvTRUE(((SVOP*)first)->op_sv)) ||
	    (type == OP_DOR && !SvOK(((SVOP*)first)->op_sv))) {
	    *firstp = NULL;
	    if (other->op_type == OP_CONST)
		other->op_private |= OPpCONST_SHORTCIRCUIT;
	    if (PL_madskills) {
		OP *newop = newUNOP(OP_NULL, 0, other, location);
		op_getmad(first, newop, '1');
		newop->op_targ = type;	/* set "was" field */
		return newop;
	    }
	    op_free(first);
	    return other;
	}
	else {
	    /* check for C<my $x if 0>, or C<my($x,$y) if 0> */
	    const OP *o2 = other;
	    if ( ! (o2->op_type == OP_LIST
		    && (( o2 = cUNOPx(o2)->op_first))
		    && o2->op_type == OP_PUSHMARK
		    && (( o2 = o2->op_sibling)) )
	    )
		o2 = other;
	    if ((o2->op_type == OP_PADSV)
		&& o2->op_private & OPpLVAL_INTRO
		&& ckWARN(WARN_DEPRECATED))
	    {
		Perl_warner(aTHX_ packWARN(WARN_DEPRECATED),
			    "Deprecated use of my() in false conditional");
	    }

	    *otherp = NULL;
	    if (first->op_type == OP_CONST)
		first->op_private |= OPpCONST_SHORTCIRCUIT;
	    if (PL_madskills) {
		first = newUNOP(OP_NULL, 0, first, location);
		op_getmad(other, first, '2');
		first->op_targ = type;	/* set "was" field */
	    }
	    else
		op_free(other);
	    return first;
	}
    }
    else if ((first->op_flags & OPf_KIDS) && type != OP_DOR
	&& ckWARN(WARN_MISC)) /* [#24076] Don't warn for <FH> err FOO. */
    {
	const OP * const k1 = ((UNOP*)first)->op_first;
	const OP * const k2 = k1->op_sibling;
	OPCODE warnop = 0;
	switch (first->op_type)
	{
	case OP_NULL:
	    if (k2 && k2->op_type == OP_READLINE
		  && (k2->op_flags & OPf_STACKED)
		  && ((k1->op_flags & OPf_WANT) == OPf_WANT_SCALAR))
	    {
		warnop = k2->op_type;
	    }
	    break;

	case OP_SASSIGN:
	    if (k1->op_type == OP_READDIR
		  || k1->op_type == OP_GLOB
		  || (k1->op_type == OP_NULL && k1->op_targ == OP_GLOB)
		  || k1->op_type == OP_EACH)
	    {
		warnop = ((k1->op_type == OP_NULL)
			  ? (OPCODE)k1->op_targ : k1->op_type);
	    }
	    break;
	}
	if (warnop) {
	    Perl_warner(aTHX_ packWARN(WARN_MISC),
		 "Value of %s%s can be \"0\"; test with defined()",
		 PL_op_desc[warnop],
		 ((warnop == OP_READLINE || warnop == OP_GLOB)
		  ? " construct" : "() operator"));
	}
    }

    if (!other)
	return first;

    NewOp(1101, logop, 1, LOGOP);

    logop->op_type = (OPCODE)type;
    logop->op_ppaddr = PL_ppaddr[type];
    logop->op_first = first;
    logop->op_flags = (U8)(flags | OPf_KIDS);
    logop->op_other = LINKLIST(other);
    logop->op_private = (U8)(1 | (flags >> 8));
    logop->op_location = SvREFCNT_inc(location);

    /* establish postfix order */
    logop->op_next = LINKLIST(first);
    first->op_next = (OP*)logop;
    first->op_sibling = other;

    CHECKOP(type,logop);

    o = newUNOP(OP_NULL, 0, (OP*)logop, location);
    other->op_next = o;

    return o;
}

OP *
Perl_newCONDOP(pTHX_ OPFLAGS flags, OP *first, OP *trueop, OP *falseop, SV *location)
{
    dVAR;
    LOGOP *logop;
    OP *start;
    OP *o;

    PERL_ARGS_ASSERT_NEWCONDOP;

    if (!falseop)
	return newLOGOP(OP_AND, 0, first, trueop, location);
    if (!trueop)
	return newLOGOP(OP_OR, 0, first, falseop, location);

    scalarboolean(first);
    if (first->op_type == OP_CONST) {
	/* Left or right arm of the conditional?  */
	const bool left = SvTRUE(((SVOP*)first)->op_sv);
	OP *live = left ? trueop : falseop;
	OP *const dead = left ? falseop : trueop;
        if (first->op_private & OPpCONST_BARE &&
	    first->op_private & OPpCONST_STRICT) {
	    no_bareword_allowed(first);
	}
	if (PL_madskills) {
	    /* This is all dead code when PERL_MAD is not defined.  */
	    live = newUNOP(OP_NULL, 0, live, location);
#ifdef PERL_MAD
	    op_getmad(first, live, 'C');
	    op_getmad(dead, live, left ? 'e' : 't');
	    append_madprops_pv("const_cond", live, '<');
#endif
	} else {
	    op_free(first);
	    op_free(dead);
	}
	return live;
    }
    NewOp(1101, logop, 1, LOGOP);
    logop->op_type = OP_COND_EXPR;
    logop->op_ppaddr = PL_ppaddr[OP_COND_EXPR];
    logop->op_first = first;
    logop->op_flags = (U8)(flags | OPf_KIDS);
    logop->op_private = (U8)(1 | (flags >> 8));
    logop->op_other = LINKLIST(trueop);
    logop->op_next = LINKLIST(falseop);
    logop->op_location = SvREFCNT_inc(location);

    CHECKOP(OP_COND_EXPR, /* that's logop->op_type */
	    logop);

    /* establish postfix order */
    start = LINKLIST(first);
    first->op_next = (OP*)logop;

    first->op_sibling = trueop;
    trueop->op_sibling = falseop;
    o = newUNOP(OP_NULL, 0, (OP*)logop, location);

    trueop->op_next = falseop->op_next = o;

    o->op_next = start;
    return o;
}

OP *
Perl_newLOOPOP(pTHX_ OPFLAGS flags, I32 debuggable, OP *expr, OP *block, bool once, SV *location)
{
    dVAR;
    OP* listop;
    OP* o;

    PERL_UNUSED_ARG(debuggable);

    if (expr) {
	if (once && expr->op_type == OP_CONST && !SvTRUE(((SVOP*)expr)->op_sv))
	    return block;	/* do {} while 0 does once */
	if (expr->op_type == OP_READLINE || expr->op_type == OP_GLOB
	    || (expr->op_type == OP_NULL && expr->op_targ == OP_GLOB)) {
	    expr = newUNOP(OP_DEFINED, 0,
			   newASSIGNOP(0, newDEFSVOP(location), 0, expr, location), location );
	} else if (expr->op_flags & OPf_KIDS) {
	    const OP * const k1 = ((UNOP*)expr)->op_first;
	    const OP * const k2 = k1 ? k1->op_sibling : NULL;
	    switch (expr->op_type) {
	      case OP_NULL:
		if (k2 && k2->op_type == OP_READLINE
		      && (k2->op_flags & OPf_STACKED)
		      && ((k1->op_flags & OPf_WANT) == OPf_WANT_SCALAR))
		    expr = newUNOP(OP_DEFINED, 0, expr, location);
		break;

	      case OP_SASSIGN:
		if (k1 && (k1->op_type == OP_READDIR
		      || k1->op_type == OP_GLOB
		      || (k1->op_type == OP_NULL && k1->op_targ == OP_GLOB)
		      || k1->op_type == OP_EACH))
		    expr = newUNOP(OP_DEFINED, 0, expr, location);
		break;
	    }
	}
    }

    /* if block is null, the next append_elem() would put UNSTACK, a scalar
     * op, in listop. This is wrong. [perl #27024] */
    if (!block)
	block = newOP(OP_NULL, 0, location);
    listop = append_elem(OP_LINESEQ, block, newOP(OP_UNSTACK, 0, location));
    o = new_logop(OP_AND, 0, &expr, &listop, location);

    if (listop)
	((LISTOP*)listop)->op_last->op_next = LINKLIST(o);

    if (once && o != listop)
	o->op_next = ((LOGOP*)cUNOPo->op_first)->op_other;

    if (o == listop)
	o = newUNOP(OP_NULL, 0, o, o->op_location);	/* or do {} while 1 loses outer block */

    o->op_flags |= flags;
    o = scope(o);
    o->op_flags |= OPf_SPECIAL;	/* suppress POPBLOCK curpm restoration*/
    SVcpREPLACE(o->op_location, location);
    return o;
}

OP *
Perl_newWHILEOP(pTHX_ OPFLAGS flags, I32 debuggable, LOOP *loop, SV* location,
		OP *expr, OP *block, OP *cont, I32 has_my)
{
    dVAR;
    OP *redo;
    OP *next = NULL;
    OP *listop;
    OP *o;
    U8 loopflags = 0;

    PERL_UNUSED_ARG(debuggable);

    if (expr) {
	if (expr->op_type == OP_READLINE || expr->op_type == OP_GLOB
		     || (expr->op_type == OP_NULL && expr->op_targ == OP_GLOB)) {
	    expr = newUNOP(OP_DEFINED, 0,
			   newASSIGNOP(0, newDEFSVOP(location), 0, expr, expr->op_location), expr->op_location  );
	} else if (expr->op_flags & OPf_KIDS) {
	    const OP * const k1 = ((UNOP*)expr)->op_first;
	    const OP * const k2 = (k1) ? k1->op_sibling : NULL;
	    switch (expr->op_type) {
	      case OP_NULL:
		if (k2 && k2->op_type == OP_READLINE
		      && (k2->op_flags & OPf_STACKED)
		      && ((k1->op_flags & OPf_WANT) == OPf_WANT_SCALAR))
		    expr = newUNOP(OP_DEFINED, 0, expr, expr->op_location);
		break;

	      case OP_SASSIGN:
		if (k1 && (k1->op_type == OP_READDIR
		      || k1->op_type == OP_GLOB
		      || (k1->op_type == OP_NULL && k1->op_targ == OP_GLOB)
		      || k1->op_type == OP_EACH))
		    expr = newUNOP(OP_DEFINED, 0, expr, expr->op_location);
		break;
	    }
	}
    }

    if (!block)
	block = newOP(OP_NULL, 0, location);
    else if (cont || has_my) {
	block = scope(block);
    }

    if (cont) {
	next = LINKLIST(cont);
    }
    if (expr) {
	OP * const unstack = newOP(OP_UNSTACK, 0, location);
	if (!next)
	    next = unstack;
	cont = append_elem(OP_LINESEQ, cont, unstack);
    }

    assert(block);
    listop = append_list(OP_LINESEQ, (LISTOP*)block, (LISTOP*)cont);
    assert(listop);
    redo = LINKLIST(listop);

    if (expr) {
	scalar(listop);
	o = new_logop(OP_AND, 0, &expr, &listop, location);
	if (o == expr && o->op_type == OP_CONST && !SvTRUE(cSVOPo->op_sv)) {
	    op_free(expr);		/* oops, it's a while (0) */
	    op_free((OP*)loop);
	    return NULL;		/* listop already freed by new_logop */
	}
	if (listop)
	    ((LISTOP*)listop)->op_last->op_next =
		(o == listop ? redo : LINKLIST(o));
    }
    else
	o = listop;

    if (!loop) {
	NewOp(1101,loop,1,LOOP);
	loop->op_type = OP_ENTERLOOP;
	loop->op_ppaddr = PL_ppaddr[OP_ENTERLOOP];
	loop->op_private = 0;
	loop->op_next = (OP*)loop;
	loop->op_location = SvREFCNT_inc(location);
    }

    o = newBINOP(OP_LEAVELOOP, 0, (OP*)loop, o, location);

    loop->op_redoop = redo;
    loop->op_lastop = o;
    o->op_private |= loopflags;

    if (next)
	loop->op_nextop = next;
    else
	loop->op_nextop = o;

    o->op_flags |= flags;
    o->op_private |= (flags >> 8);
    return o;
}

OP *
Perl_newFOROP(pTHX_ OPFLAGS flags, char *label, OP *sv, OP *expr, OP *block, OP *cont, SV *location)
{
    dVAR;
    LOOP *loop;
    OP *wop;
    PADOFFSET padoff = 0;
    I32 iterflags = 0;
    I32 iterpflags = 0;
    OP *madsv = NULL;

    PERL_ARGS_ASSERT_NEWFOROP;

    if (sv) {
	if (sv->op_type == OP_RV2SV) {	/* symbol table variable */
	    iterpflags = sv->op_private & OPpOUR_INTRO; /* for our $x () */
	    sv->op_type = OP_RV2GV;
	    sv->op_ppaddr = PL_ppaddr[OP_RV2GV];

	    /* The op_type check is needed to prevent a possible segfault
	     * if the loop variable is undeclared and 'strict vars' is in
	     * effect. This is illegal but is nonetheless parsed, so we
	     * may reach this point with an OP_CONST where we're expecting
	     * an OP_GV.
	     */
	    if (cUNOPx(sv)->op_first->op_type == OP_GV
	     && cGVOPx_gv(cUNOPx(sv)->op_first) == PL_defgv)
		iterpflags |= OPpITER_DEF;
	}
	else if (sv->op_type == OP_PADSV) { /* private variable */
	    iterpflags = sv->op_private & OPpLVAL_INTRO; /* for my $x () */
	    padoff = sv->op_targ;
	    if (PL_madskills)
		madsv = sv;
	    else {
		sv->op_targ = 0;
		op_free(sv);
	    }
	    sv = NULL;
	}
	else
	    Perl_croak(aTHX_ "Can't use %s for loop variable", PL_op_desc[sv->op_type]);
	if (padoff) {
	    SV *const namesv = PAD_COMPNAME_SV(padoff);
	    STRLEN len;
	    const char *const name = SvPV_const(namesv, len);

	    if (len == 2 && name[0] == '$' && name[1] == '_')
		iterpflags |= OPpITER_DEF;
	}
    }
    else {
        const PADOFFSET offset = pad_findmy("$_");
	if (offset == NOT_IN_PAD || PAD_COMPNAME_FLAGS_isOUR(offset)) {
	    sv = newGVOP(OP_GV, 0, PL_defgv, location);
	}
	else {
	    padoff = offset;
	}
	iterpflags |= OPpITER_DEF;
    }
    if (expr->op_type == OP_RV2AV || expr->op_type == OP_RV2SV 
	|| expr->op_type == OP_PADSV || expr->op_type == OP_ASLICE
	|| expr->op_type == OP_VALUES ) {
	expr->op_flags |= OPf_SPECIAL;
	expr = mod(expr, OP_GREPSTART);
	iterflags |= OPf_STACKED;
    }
    else if (expr->op_type == OP_RANGE)
    {
	/* Basically turn for($x..$y) into the same as for($x,$y), but we
	 * set the SPECIAL flag to indicate that these values are to be
	 * treated as min/max values by 'pp_iterinit'.
	 */
	BINOP* const range = (BINOP*)expr;
	OP* const left  = range->op_first;
	OP* const right = range->op_last;
	LISTOP* listop;

	listop = (LISTOP*)newLISTOP(OP_LIST, 0, left, right, location);
	range->op_first = NULL;
	range->op_last = NULL;

#ifdef PERL_MAD
	op_getmad(expr,(OP*)listop,'O');
#else
	op_free(expr);
#endif
	expr = (OP*)(listop);
        op_null(expr);
	iterflags |= OPf_SPECIAL;
    }
    else {
        expr = mod(expr, OP_GREPSTART);
    }

    loop = (LOOP*)list(convert(OP_ENTERITER, iterflags,
	    append_elem(OP_LIST, expr, scalar(sv)), location));
    assert(!loop->op_next);
    /* for my  $x () sets OPpLVAL_INTRO;
     * for our $x () sets OPpOUR_INTRO */
    loop->op_private = (U8)iterpflags;
#ifdef PL_OP_SLAB_ALLOC
    {
	LOOP *tmp;
	NewOp(1234,tmp,1,LOOP);
	Copy(loop,tmp,1,LISTOP);
	S_op_destroy(aTHX_ (OP*)loop);
	loop = tmp;
    }
#else
    loop = (LOOP*)PerlMemShared_realloc(loop, sizeof(LOOP));
#endif
    loop->op_targ = padoff;
    wop = newWHILEOP(flags, 1, loop, location, newOP(OP_ITER, 0, location), block, cont, 0);
    if (madsv)
	op_getmad(madsv, (OP*)loop, 'v');
    return newSTATEOP(0, label, wop, location);
}

OP*
Perl_newLOOPEX(pTHX_ I32 type, OP *label)
{
    dVAR;
    OP *o;

    PERL_ARGS_ASSERT_NEWLOOPEX;

    {
	/* "last()" means "last" */
	if (label->op_type == OP_STUB && (label->op_flags & OPf_PARENS))
	    o = newOP(type, OPf_SPECIAL, label->op_location);
	else {
	    o = newPVOP(type, 0, savesharedpv(label->op_type == OP_CONST
					? SvPV_nolen_const(((SVOP*)label)->op_sv)
					      : ""), label->op_location);
	}
#ifdef PERL_MAD
	op_getmad(label,o,'L');
#else
	op_free(label);
#endif
    }
    PL_hints |= HINT_BLOCK_SCOPE;
    return o;
}

OP*
Perl_newPRIVATEVAROP(pTHX_ const char* varname, SV* location) {
    PADOFFSET tmp = 0;
    GV* gv;
    OP* gvop;
    const STRLEN varname_len = strlen(varname);
    /* All routes through this function want to know if there is a colon.  */
    const char *const has_colon = (const char*) memchr (varname, ':', varname_len);
    OP* o;

    PERL_ARGS_ASSERT_NEWPRIVATEVAROP;

    /* if we're in a my(), we can't allow dynamics here.
       if it's a legal name, the OP is a PADANY.
    */
    if (PL_parser->in_my) {
        if (PL_parser->in_my == KEY_our) {	/* "our" is merely analogous to "my" */
            if (has_colon)
                yyerror(Perl_form(aTHX_ "No package name allowed for "
                                  "variable %s in \"our\"",
                                  varname));
            tmp = allocmy(varname);
        }
        else {
            if (has_colon)
                yyerror(Perl_form(aTHX_ PL_no_myglob,
			    PL_parser->in_my == KEY_my ? "my" : "state", varname));

            o = newOP(OP_PADSV, 0, location);
            o->op_targ = allocmy(varname);
            return o;
        }
    }

    /*
       build the ops for accesses to a my() variable.

       Deny my($a) or my($b) in a sort block, *if* $a or $b is
       then used in a comparison.  This catches most, but not
       all cases.  For instance, it catches
           sort { my($a); $a <=> $b }
       but not
           sort { my($a); $a < $b ? -1 : $a == $b ? 0 : 1; }
       (although why you'd do that is anyone's guess).
    */

    if (!has_colon) {
	if (!PL_parser->in_my)
	    tmp = pad_findmy(varname);
        if (tmp != NOT_IN_PAD) {
            /* might be an "our" variable" */
            if (PAD_COMPNAME_FLAGS_isOUR(tmp)) {
                /* build ops for a bareword */
		GV *  const ourgv = PAD_COMPNAME_OURGV(tmp);
		OP * gvop = (OP*)newGVOP(OP_GV, 0, ourgv, location);
		o = newUNOP(
		    (*varname == '%' ? OP_RV2HV : *varname == '@' ? OP_RV2AV : OP_RV2SV),
			0, gvop, location);
                return o;
            }

            o = newOP(OP_PADSV, 0, location);
            o->op_targ = tmp;
            return o;
        }
    }

    if (varname[1] == '^'
	|| ( varname[1] >= '0' && varname[1] <= '9' ) ) {
	if ( ! is_magicsv(&varname[1]) ) {
	    Perl_croak(aTHX_ "unknown magical variable %s", varname);
	}
	o = newSVOP(OP_MAGICSV, 0,
	    newSVpvn(varname+1, varname_len-1),
	    location);
	return o;
    }

    /* build ops for a global variable */
    gv = gv_fetchpvn_flags(
	    varname + 1, varname_len - 1,
	    /* If the identifier refers to a stash, don't autovivify it.
	     * Change 24660 had the side effect of causing symbol table
	     * hashes to always be defined, even if they were freshly
	     * created and the only reference in the entire program was
	     * the single statement with the defined %foo::bar:: test.
	     * It appears that all code in the wild doing this actually
	     * wants to know whether sub-packages have been loaded, so
	     * by avoiding auto-vivifying symbol tables, we ensure that
	     * defined %foo::bar:: continues to be false, and the existing
	     * tests still give the expected answers, even though what
	     * they're actually testing has now changed subtly.
	     */
	    (PL_in_eval ? (GV_ADDMULTI | GV_ADDINEVAL) : GV_ADD),
	    ((varname[0] == '$') ? SVt_PV
	     : (varname[0] == '@') ? SVt_PVAV
	     : SVt_PVHV));
    if ( ! gv )
	Perl_croak(aTHX_ "variable %s does not exist", varname);
    gvop = (OP*)newGVOP(OP_GV, 0, gv, location);
    o = newUNOP(
	(*varname == '%' ? OP_RV2HV : *varname == '@' ? OP_RV2AV : OP_RV2SV),
	    0, gvop, location);
    return o;
}

/*
=for apidoc cv_undef

Clear out all the active components of a CV. This can happen either
by an explicit C<undef &foo>, or by the reference count going to zero.
In the former case, we keep the CvOUTSIDE pointer, so that any anonymous
children can still follow the full lexical scope chain.

=cut
*/

void
Perl_cv_undef(pTHX_ CV *cv)
{
    dVAR;

    PERL_ARGS_ASSERT_CV_UNDEF;

    DEBUG_X(PerlIO_printf(Perl_debug_log,
	  "CV undef: cv=0x%"UVxf" comppad=0x%"UVxf"\n",
	    PTR2UV(cv), PTR2UV(PL_comppad))
    );

    if (!CvISXSUB(cv) && CvROOT(cv)) {
	ROOTOPcpNULL(CvROOT(cv));
	CvSTART(cv) = NULL;
    }
    SvPOK_off(MUTABLE_SV(cv));		/* forget prototype */

    pad_undef(cv);

    if (CvCONST(cv)) {
	SvREFCNT_dec(MUTABLE_SV(CvXSUBANY(cv).any_ptr));
	CvCONST_off(cv);
    }
    if (CvISXSUB(cv) && CvXSUB(cv)) {
	CvXSUB(cv) = NULL;
    }
    /* delete all flags */
    CvFLAGS(cv) = 0;
}

void
Perl_cv_tmprefcnt(pTHX_ CV *cv)
{
    dVAR;

    PERL_ARGS_ASSERT_CV_TMPREFCNT;

    if (CvFLAGS(cv) & CVf_TMPREFCNT)
	return;
    CvFLAGS(cv) |= CVf_TMPREFCNT;
	    
    pad_tmprefcnt(cv);

    if (CvCONST(cv)) {
	SvTMPREFCNT_inc((SV*)CvXSUBANY(cv).any_ptr);
    }
}

static void const_sv_xsub(pTHX_ CV* cv);

/*

=head1 Optree Manipulation Functions

=for apidoc cv_const_sv

If C<cv> is a constant sub eligible for inlining. returns the constant
value returned by the sub.  Otherwise, returns NULL.

Constant subs can be created with C<newCONSTSUB> or as described in
L<perlsub/"Constant Functions">.

=cut
*/
SV *
Perl_cv_const_sv(pTHX_ const CV *const cv)
{
    PERL_UNUSED_CONTEXT;
    if (!cv)
	return NULL;
    if (!(SvTYPE(cv) == SVt_PVCV))
	return NULL;
    return CvCONST(cv) ? MUTABLE_SV(CvXSUBANY(cv).any_ptr) : NULL;
}

#ifdef PERL_MAD
OP *
#else
void
#endif
Perl_newMYSUB(pTHX_ I32 floor, OP *o, OP *proto, OP *attrs, OP *block)
{
#if 0
    /* This would be the return value, but the return cannot be reached.  */
    OP* pegop = newOP(OP_NULL, 0);
#endif

    PERL_UNUSED_ARG(floor);

    if (o)
	SAVEFREEOP(o);
    if (proto)
	SAVEFREEOP(proto);
    if (attrs)
	SAVEFREEOP(attrs);
    if (block)
	SAVEFREEOP(block);
    Perl_croak(aTHX_ "\"my sub\" not yet implemented");
#ifdef PERL_MAD
    NORETURN_FUNCTION_END;
#endif
}

CV *
Perl_newNAMEDSUB(pTHX_ I32 floor, OP *o, OP *proto, OP *block)
{
    dVAR;
    GV *gv;
    register CV *cv = NULL;

    /* If the subroutine has no body, no attributes, and no builtin attributes
       then it's just a sub declaration, and we may be able to get away with
       storing with a placeholder scalar in the symbol table, rather than a
       full GV and CV.  If anything is present then it will take a full CV to
       store it.  */
    const I32 gv_fetch_flags =  GV_ADDMULTI ;
    const char * const name = SvPV_nolen_const(cSVOPo->op_sv);

    cv = newSUB(floor, proto, block);

    SVcpREPLACE(SvLOCATION(cv), o->op_location);

    gv = gv_fetchsv(cSVOPo->op_sv, gv_fetch_flags, SVt_PVCV);

    if (!PL_madskills) {
	if (o)
	    SAVEFREEOP(o);
    }

    if (SvTYPE(gv) != SVt_PVGV) {	/* Maybe prototype now, and had at
					   maximum a prototype before. */
	if (SvTYPE(gv) > SVt_NULL) {
	    if (!SvPOK((SV*)gv) && !(SvIOK((SV*)gv) && I_SvIV((SV*)gv) == -1)
		&& ckWARN_d(WARN_PROTOTYPE))
	    {
		Perl_warner(aTHX_ packWARN(WARN_PROTOTYPE), "Runaway prototype");
	    }
	}

	CVcpNULL(PL_compcv);
	cv = NULL;
	return NULL;
    }

    if (GvCV(gv)) {
	if (ckWARN(WARN_REDEFINE)) {
	    Perl_warner_at(aTHX_ 
		SvLOCATION(cv),
		packWARN(WARN_REDEFINE),
		CvCONST(cv)
		? "Constant subroutine %s redefined"
		: "Subroutine %s redefined",
		name);
	}
	CvREFCNT_dec(GvCV(gv));
    }
    GvCV(gv) = CvREFCNT_inc(cv);

    if (SvAVOK(SvLOCATION((SV*)cv))) {
	SV* namesv = newSVpv(HvNAME_get(GvSTASH(gv)), 0);
	sv_catpvf(aTHX_ namesv, "::%s", GvNAME_get(gv));
	av_store(svTav(SvLOCATION((SV*)cv)), 3, namesv);
    }

    GvCVGEN(gv) = 0;
    mro_method_changed_in(GvSTASH(gv)); /* sub Foo::bar { (shift)+1 } */

    return cv;
}

CV *
Perl_newSUB(pTHX_ I32 floor, OP *proto, OP *block)
{
    dVAR;
    register CV *cv = NULL;

    cv = NULL;

    cv = PL_compcv;
    SVcpSTEAL(SvLOCATION(cv), newSVsv(PL_curcop->op_location));

    CvN_MINARGS(cv) = 0;
    CvN_MAXARGS(cv) = -1;

    if (PL_parser && PL_parser->error_count) {
	op_free(block);
	block = NULL;
    }
    if (!block)
	goto done;

    /* This makes sub {}; work as expected.  */
    if (block->op_type == OP_STUB) {
	OP* const newblock = newSTATEOP(0, NULL, 0, block->op_location);
#ifdef PERL_MAD
	op_getmad(block,newblock,'B');
#else
	op_free(block);
#endif
	block = newblock;
    }

    {
	OP* leaveop;
	OP* proto_block;
#ifndef PERL_MAD
	if (proto && proto->op_type == OP_STUB) {
	    CvN_MINARGS(cv) = 0;
	    CvN_MAXARGS(cv) = 0;
	    proto_block = block;
	    op_free(proto);
	}
	else
#endif
        if (proto) {
	    I32 min_modcount = 0;
	    I32 max_modcount = 0;
	    I32 arg_mod = cv_assignarg_flag(cv) ? 1 : cv_optassignarg_flag(cv) ? 2 : 0;
	    OP* kid;
	    LISTOP* list = cLISTOPx(my(convert(OP_LIST, 0, proto, proto->op_location)));
	    OP* pushmark = list->op_first;
	    list->op_first = pushmark->op_sibling;
	    op_free(pushmark);
	    for (kid = list->op_first; kid; kid = kid->op_sibling)
		assign(kid, TRUE, &min_modcount, &max_modcount);
	    CvN_MINARGS(cv) = min_modcount - arg_mod;
	    CvN_MAXARGS(cv) = max_modcount == -1 ? -1 : max_modcount - arg_mod;
#ifdef PERL_MAD
	    block = newUNOP(OP_NULL, 0, block, block->op_location);
	    if (cv_optassignarg_flag(cv))
		append_madprops_pv("optassignarg", list, 'J');
	    else if (cv_assignarg_flag(cv))
		append_madprops_pv("assignarg", list, 'J');
#endif
	    proto_block = append_list(OP_LINESEQ, list, (LISTOP*)block);
	}
	else {
	    proto_block = block;
	}
	   
	leaveop = newUNOP(OP_LEAVESUB, 0,
	    scalarseq(proto_block), block->op_location);
	CvSTART(cv) = LINKLIST(leaveop);
	leaveop->op_next = 0;
	CvROOT(cv) = newROOTOP(leaveop, block->op_location);
    }
    CALL_PEEP(CvSTART(cv));

    /* now that optimizer has done its work, adjust pad values */

    pad_tidy(CvCLONE(cv) ? padtidy_SUBCLONE : padtidy_SUB);

  done:
    CvREFCNT_inc(cv);
    LEAVE_SCOPE(floor);
    return cv;
}

void
Perl_process_special_block(pTHX_ const I32 key, CV *const cv)
{
    PERL_ARGS_ASSERT_PROCESS_SPECIAL_BLOCK;

    if (PL_parser && PL_parser->error_count) {
	const char not_safe[] =
	    "BEGIN not safe after errors--compilation aborted";
	if (PL_in_eval & EVAL_KEEPERR)
	    Perl_croak(aTHX_ not_safe);
	else {
	    /* force display of errors found but not reported */
	                   sv_catpv(ERRSV, not_safe);
			   Perl_croak(aTHX_ "%"SVf, SVfARG(ERRSV));
	}
    }

    CvSPECIAL_on(cv);

    switch(key) {
    case KEY_BEGIN:
    {
	AV* call_av;
	const I32 oldscope = PL_scopestack_ix;
	ENTER_named("BEGIN-block");

	if ( ! SvLOCATION(cvTsv(cv)) )
	    SvLOCATION(cvTsv(cv)) = avTsv(newAV());
	if (SvAVOK(SvLOCATION((SV*)cv))) {
	    av_store(svTav(SvLOCATION((SV*)cv)),
		LOC_NAME_INDEX,
		newSVpv("BEGIN", 0));
	}

	call_av = av_2mortal(newAV());
	av_push(call_av, SvREFCNT_inc(cvTsv(cv)));
	call_list(oldscope, call_av);

	PL_curcop = &PL_compiling;
	CopHINTS_set(&PL_compiling, PL_hints);
	LEAVE_named("BEGIN-block");
        break;
    }
    case KEY_END:
	Perl_av_create_and_unshift_one(aTHX_ &PL_endav, SvREFCNT_inc(cvTsv(cv)));
	break;
    case KEY_UNITCHECK:
	/* It's never too late to run a unitcheck block */
	Perl_av_create_and_unshift_one(aTHX_ &PL_unitcheckav, SvREFCNT_inc(cvTsv(cv)));
	break;
    case KEY_CHECK:
	if (PL_main_start && ckWARN(WARN_VOID))
	    Perl_warner(aTHX_ packWARN(WARN_VOID),
		"Too late to run CHECK block");
	Perl_av_create_and_unshift_one(aTHX_ &PL_checkav, SvREFCNT_inc(cvTsv(cv)));
	break;
    case KEY_INIT:
	if (PL_main_start && ckWARN(WARN_VOID))
	    Perl_warner(aTHX_ packWARN(WARN_VOID),
		"Too late to run INIT block");
	Perl_av_create_and_push(aTHX_ &PL_initav, SvREFCNT_inc(cvTsv(cv)));
	break;
    default:
	Perl_croak(aTHX_ "panic: Unknown special block key");
    }
}

/*
=for apidoc newCONSTSUB

Creates a constant sub equivalent to Perl C<sub FOO () { 123 }> which is
eligible for inlining at compile-time.

=cut
*/

CV *
Perl_newCONSTSUB(pTHX_ const char *name, SV *sv)
{
    dVAR;
    CV* cv;
    SV *const temp_sv = LocationFilename(PL_curcop->op_location);
    const char *const file = temp_sv ? SvPV_nolen_const(temp_sv) : NULL;
    PERL_ARGS_ASSERT_NEWCONSTSUB;

    ENTER_named("newCONSTSUB");

    if (IN_PERL_RUNTIME) {
	/* at runtime, it's not safe to manipulate PL_curcop: it may be
	 * an op shared between threads. Use a non-shared COP for our
	 * dirty work */
	 SAVEVPTR(PL_curcop);
	 PL_curcop = &PL_compiling;
    }

    SAVEHINTS();
    PL_hints &= ~HINT_BLOCK_SCOPE;

    /* file becomes the CvFILE. For an XS, it's supposed to be static storage,
       and so doesn't get free()d.  (It's expected to be from the C pre-
       processor __FILE__ directive). But we need a dynamically allocated one,
       and we need it to get freed.  */
    cv = newXS_flags(name, const_sv_xsub, file ? file : "", "",
		     XS_DYNAMIC_FILENAME);
    CvXSUBANY(cv).any_ptr = sv;
    CvCONST_on(cv);

    LEAVE_named("newCONSTSUB");

    return cv;
}

CV *
Perl_newXS_flags(pTHX_ const char *name, XSUBADDR_t subaddr,
		 const char *const filename, const char *const proto,
		 U32 flags)
{
    CV *cv = newXS(name, subaddr, filename);
    PERL_UNUSED_ARG(flags);

    PERL_ARGS_ASSERT_NEWXS_FLAGS;

    if (proto) {
	const char* proto_i = proto;
	I32 n_minargs = 0;
	I32 n_maxargs = 0;
	while (*proto_i && *proto_i != ';' && *proto_i != '=' && *proto_i != '?' && *proto_i != '@') {
	    if (*proto_i == '\\')
		++proto_i;
	    if (*proto_i == '[') {
		while (*proto_i && *proto_i != ']')
		    ++proto_i;
	    }
	    ++n_minargs;
	    ++proto_i;
	}
	n_maxargs = n_minargs;
	if (*proto_i == ';') {
	    ++proto_i;
	    while (*proto_i && *proto_i != ';' && *proto_i != '=' && *proto_i != '?' && *proto_i != '@') {
		if (*proto_i == '\\')
		    ++proto_i;
		if (*proto_i == '[') {
		    while (*proto_i && *proto_i != ']')
			++proto_i;
		}
		++n_maxargs;
		++proto_i;
	    }
	}
	if (*proto_i == '@')
	    n_maxargs = -1;
	    
	if (*proto_i == '?' && proto_i[1] == '=') {
	    CvFLAGS(cv) |= CVf_OPTASSIGNARG;
	}
	if (proto_i[0] == '=') {
	    CvFLAGS(cv) |= CVf_ASSIGNARG;
	}
	CvN_MINARGS(cv) = n_minargs;
	CvN_MAXARGS(cv) = n_maxargs;
    }

    return cv;
}

/*
=for apidoc U||newXS

Used by C<xsubpp> to hook up XSUBs as Perl subs.  I<filename> needs to be
static storage, as it is used directly as CvFILE(), without a copy being made.

=cut
*/

CV *
Perl_newXS(pTHX_ const char *name, XSUBADDR_t subaddr, const char *filename)
{
    dVAR;
    GV * const gv = name ? gv_fetchpv(name, GV_ADDMULTI, SVt_PVCV) : NULL;
    register CV *cv;

    PERL_ARGS_ASSERT_NEWXS;

    if (!subaddr)
	Perl_croak(aTHX_ "panic: no address for '%s' in '%s'", name, filename);

    if (gv) {
	if (GvCV(gv)) {
	    if (ckWARN(WARN_REDEFINE)) {
		Perl_warner(aTHX_ packWARN(WARN_REDEFINE),
		    CvCONST(GvCV(gv))
		    ? "Constant subroutine %s redefined"
		    : "Subroutine %s redefined",
		    name);
	    }
	    CvREFCNT_dec(GvCV(gv));
	}
    }

    cv = (CV*)newSV_type(SVt_PVCV);

    if (gv) {
	GvCV(gv) = cv;
	GvCVGEN(gv) = 0;
	mro_method_changed_in(GvSTASH(gv)); /* newXS */
    }

    CvISXSUB_on(cv);
    CvXSUB(cv) = subaddr;
    CvN_MINARGS(cv) = 0;
    CvN_MAXARGS(cv) = -1;

    if ( ! name)
	CvANON_on(cv);

    SvLOCATION(cv) = avTsv(newAV());
    av_store(svTav(SvLOCATION((SV*)cv)), 3, newSVpv(name, 0));

    return cv;
}

OP *
Perl_newANONARRAY(pTHX_ OP *o, SV* location)
{
    return convert(OP_ANONARRAY, 0, o, location);
}

OP *
Perl_newANONHASH(pTHX_ OP *o, SV* location)
{
    return convert(OP_ANONHASH, 0, o, location);
}

OP *
Perl_newANONSUB(pTHX_ I32 floor, OP *proto, OP *block)
{
    SV* location = sv_mortalcopy(block->op_location);
    SV* sub = (SV*)newSUB(floor, proto, block);
    if (CvPADLIST(sub)) {
	SV* padflags = PADLIST_NAMESV(CvPADLIST(sub), PAD_FLAGS_INDEX);
	SvIV_set(padflags, SvIV(padflags) & ~PADf_LATE);
    }
    SVcpREPLACE(SvLOCATION(sub), location);
    if (SvLOCATION(sub) && SvAVOK(SvLOCATION(sub))) {
	SV* namesv = newSVpv(HvNAME_get(PL_curstash), 0);
	sv_catpvf(aTHX_ namesv, "::__ANON__");
	av_store(svTav(SvLOCATION(sub)), 3, namesv);
    }
    return newSVOP(OP_ANONCODE, 0, sub, location);
}

OP *
Perl_newAVREF(pTHX_ OP *o, SV* location)
{
    dVAR;

    PERL_ARGS_ASSERT_NEWAVREF;

    if ((o->op_type == OP_RV2AV || o->op_type == OP_ANONARRAY )) {
	yyerror(Perl_form(aTHX_ "Array may not be used as a reference"));
    }
    return newUNOP(OP_RV2AV, 0, scalar(o), location);
}

OP *
Perl_newGVREF(pTHX_ I32 type, OP *o, SV* location)
{
    if (type == OP_MAPSTART || type == OP_GREPSTART || type == OP_SORT)
	return newUNOP(OP_NULL, 0, o, location);
    return ref(newUNOP(OP_RV2GV, OPf_REF, o, location), type);
}

OP *
Perl_newHVREF(pTHX_ OP *o, SV* location)
{
    dVAR;

    PERL_ARGS_ASSERT_NEWHVREF;

    if (o->op_type == OP_RV2HV || o->op_type == OP_ANONHASH) {
	yyerror(Perl_form(aTHX_ "Hash may not be used as a reference"));
    }
    return newUNOP(OP_RV2HV, 0, scalar(o), location);
}

OP *
Perl_newCVREF(pTHX_ OPFLAGS flags, OP *o, SV* location)
{
    return newUNOP(OP_RV2CV, flags, scalar(o), location);
}

OP *
Perl_newSVREF(pTHX_ OP *o, SV* location)
{
    dVAR;

    PERL_ARGS_ASSERT_NEWSVREF;

    return newUNOP(OP_RV2SV, 0, scalar(o), location);
}

/* Check routines. See the comments at the top of this file for details
 * on when these are called */

OP *
Perl_ck_anoncode(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_ANONCODE;

    cSVOPo->op_targ = pad_add_anon(cSVOPo->op_sv, o->op_type);
    if (!PL_madskills)
	cSVOPo->op_sv = NULL;
    return o;
}

OP *
Perl_ck_bitop(pTHX_ OP *o)
{
    dVAR;

    PERL_ARGS_ASSERT_CK_BITOP;

#define OP_IS_NUMCOMPARE(op) \
	((op) == OP_LT   || (op) == OP_I_LT || \
	 (op) == OP_GT   || (op) == OP_I_GT || \
	 (op) == OP_LE   || (op) == OP_I_LE || \
	 (op) == OP_GE   || (op) == OP_I_GE || \
	 (op) == OP_EQ   || (op) == OP_I_EQ || \
	 (op) == OP_NE   || (op) == OP_I_NE || \
	 (op) == OP_NCMP || (op) == OP_I_NCMP)
    o->op_private = (U8)(PL_hints & HINT_INTEGER);
    if (!(o->op_flags & OPf_STACKED) /* Not an assignment */
	    && (o->op_type == OP_BIT_OR
	     || o->op_type == OP_BIT_AND
	     || o->op_type == OP_BIT_XOR))
    {
	const OP * const left = cBINOPo->op_first;
	const OP * const right = left->op_sibling;
	if ((OP_IS_NUMCOMPARE(left->op_type) &&
		(left->op_flags & OPf_PARENS) == 0) ||
	    (OP_IS_NUMCOMPARE(right->op_type) &&
		(right->op_flags & OPf_PARENS) == 0))
	    if (ckWARN(WARN_PRECEDENCE))
		Perl_warner(aTHX_ packWARN(WARN_PRECEDENCE),
			"Possible precedence problem on bitwise ^%c^ operator",
			o->op_type == OP_BIT_OR ? '|'
			    : o->op_type == OP_BIT_AND ? '&' : '^'
			);
    }
    return o;
}

OP *
Perl_ck_concat(pTHX_ OP *o)
{
    const OP * const kid = cUNOPo->op_first;

    PERL_ARGS_ASSERT_CK_CONCAT;
    PERL_UNUSED_CONTEXT;

    if (kid->op_type == OP_CONCAT && !(kid->op_flags & OPf_TARGET_MY) &&
	    !(kUNOP->op_first->op_flags & OPf_MOD))
        o->op_flags |= OPf_STACKED;
    return o;
}

OP *
Perl_ck_delete(pTHX_ OP *o)
{
    OP * kid;
    PERL_ARGS_ASSERT_CK_DELETE;

    o = ck_fun(o);
    o->op_private = 0;
    if (!(o->op_flags & OPf_KIDS)) {
        assert(PL_parser->error_count);
        return o;
    }
    kid = cUNOPo->op_first;
    switch (kid->op_type) {
    case OP_ASLICE:
        o->op_flags |= OPf_SPECIAL;
        /* FALL THROUGH */
    case OP_HSLICE:
        o->op_private |= OPpSLICE;
        break;
    case OP_AELEM:
        o->op_flags |= OPf_SPECIAL;
        /* FALL THROUGH */
    case OP_HELEM:
        break;
    default:
        yyerror(Perl_form(aTHX_ "%s argument is not a HASH or ARRAY element or slice",
                OP_DESC(o)));
        return o;
    }
    o->op_private |= kid->op_private & OPpELEM_OPTIONAL;
    op_null(kid);
    o = op_mod_assign(o,
        o->op_private & OPpSLICE
        ? &(cBINOPx(cBINOPo->op_first)->op_last)
        : &(cBINOPx(cBINOPo->op_first)->op_first),
        o->op_type);
    return o;
}

OP *
Perl_ck_die(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_DIE;

#ifdef VMS
    if (VMSISH_HUSHED) o->op_private |= OPpHUSH_VMSISH;
#endif
    return ck_fun(o);
}

OP *
Perl_ck_eof(pTHX_ OP *o)
{
    dVAR;

    PERL_ARGS_ASSERT_CK_EOF;

    if (o->op_flags & OPf_KIDS) {
	if (cLISTOPo->op_first->op_type == OP_STUB) {
	    OP * const newop
		= newUNOP(o->op_type, OPf_SPECIAL, newGVOP(OP_GV, 0, PL_argvgv, o->op_location), o->op_location);
#ifdef PERL_MAD
	    op_getmad(o,newop,'O');
#else
	    op_free(o);
#endif
	    o = newop;
	}
	return ck_fun(o);
    }
    return o;
}

OP *
Perl_ck_eval(pTHX_ OP *o)
{
    dVAR;

    PERL_ARGS_ASSERT_CK_EVAL;

    PL_hints |= HINT_BLOCK_SCOPE;
    if (o->op_flags & OPf_KIDS) {
	SVOP * const kid = (SVOP*)cUNOPo->op_first;

	if (!kid) {
	    o->op_flags &= ~OPf_KIDS;
	    op_null(o);
	}
	else {
	    scalar((OP*)kid);
	    PL_cv_has_eval = 1;
	}
    }
    else {
#ifdef PERL_MAD
	OP* const oldo = o;
#else
	op_free(o);
#endif
	o = newUNOP(OP_ENTEREVAL, 0, newDEFSVOP(o->op_location), o->op_location);
	op_getmad(oldo,o,'O');
    }
    o->op_targ = (PADOFFSET)PL_hints;
    if ((PL_hints & HINT_LOCALIZE_HH) != 0 && PL_hinthv) {
	/* Store a copy of %^H that pp_entereval can pick up. */
	OP *hhop = newSVOP(OP_HINTSEVAL, 0,
	    newSVsv(hvTsv(PL_hinthv)), o->op_location);
	cUNOPo->op_first->op_sibling = hhop;
	o->op_private |= OPpEVAL_HAS_HH;
    }
    pad_savelex(
	PADLIST_PADNAMES(CvPADLIST(PL_compcv)),
        PADLIST_BASEPAD(CvPADLIST(PL_compcv)),
	PL_cop_seqmax
	);
    return o;
}

OP *
Perl_ck_try(pTHX_ OP *o)
{
    dVAR;

    PERL_ARGS_ASSERT_CK_EVAL;

    PL_hints |= HINT_BLOCK_SCOPE;
    if (o->op_flags & OPf_KIDS) {
	SVOP * const kid = (SVOP*)cUNOPo->op_first;

	if (!kid) {
	    o->op_flags &= ~OPf_KIDS;
	    op_null(o);
	}
	else if (kid->op_type == OP_LINESEQ || kid->op_type == OP_STUB
#ifdef PERL_MAD
	    || kid->op_type == OP_NULL
#endif
	    ) {
	    LOGOP *enter;
	    OP* const oldo = o;

	    cUNOPo->op_first = 0;

	    NewOp(1101, enter, 1, LOGOP);
	    enter->op_type = OP_ENTERTRY;
	    enter->op_ppaddr = PL_ppaddr[OP_ENTERTRY];
	    enter->op_private = 0;
	    enter->op_location = SvREFCNT_inc(oldo->op_location);

	    /* establish postfix order */
	    enter->op_next = (OP*)enter;

	    o = prepend_elem(OP_LINESEQ, (OP*)enter, (OP*)kid);
	    o->op_type = OP_LEAVETRY;
	    o->op_ppaddr = PL_ppaddr[OP_LEAVETRY];
	    enter->op_other = o;
	    op_getmad(oldo,o,'O');
#ifndef PERL_MAD
	    op_free(oldo);
#endif
	    return o;
	}
    }
    yyerror(Perl_form(aTHX_ "invalid arguments to 'try'"));
    return o;
}

OP *
Perl_ck_exit(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_EXIT;

#ifdef VMS
    HV * const table = PL_hinthv;
    if (table) {
       SV * const * const svp = hv_fetchs(table, "vmsish_exit", FALSE);
       if (svp && *svp && SvTRUE(*svp))
           o->op_private |= OPpEXIT_VMSISH;
    }
    if (VMSISH_HUSHED) o->op_private |= OPpHUSH_VMSISH;
#endif
    return ck_fun(o);
}

OP *
Perl_ck_exec(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_EXEC;

    if (o->op_flags & OPf_STACKED) {
        OP *kid;
	o = ck_fun(o);
	kid = cUNOPo->op_first->op_sibling;
	if (kid->op_type == OP_RV2GV)
	    op_null(kid);
    }
    else
	o = listkids(o);
    return o;
}

OP *
Perl_ck_exists(pTHX_ OP *o)
{
    dVAR;

    PERL_ARGS_ASSERT_CK_EXISTS;

    o = ck_fun(o);
    if (o->op_flags & OPf_KIDS) {
	OP * const kid = cUNOPo->op_first;
	if (kid->op_type == OP_RV2CV) {
	    o->op_private |= OPpEXISTS_SUB;
	}
	else if (kid->op_type == OP_AELEM)
	    o->op_flags |= OPf_SPECIAL;
	else if (kid->op_type != OP_HELEM)
	    yyerror(Perl_form(aTHX_ "%s argument is not a HASH or ARRAY element or a subroutine",
		    OP_DESC(o)));
	op_null(kid);
    }
    return o;
}

OP *
Perl_ck_rvconst(pTHX_ register OP *o)
{
    dVAR;
    SVOP * const kid = (SVOP*)cUNOPo->op_first;

    PERL_ARGS_ASSERT_CK_RVCONST;

    if (o->op_type == OP_RV2CV)
	o->op_private &= ~1;

    if (kid->op_type == OP_CONST) {
	int iscv;
	GV *gv;
	SV * const kidsv = kid->op_sv;

	/* Is it a constant from cv_const_sv()? */
	if (SvROK(kidsv) && SvREADONLY(kidsv)) {
	    SV * const rsv = SvRV(kidsv);
	    const svtype type = SvTYPE(rsv);
            const char *badtype = NULL;

	    switch (o->op_type) {
	    case OP_RV2SV:
		if (type > SVt_PVMG)
		    badtype = "a SCALAR";
		break;
	    case OP_RV2AV:
		if (type != SVt_PVAV)
		    badtype = "an ARRAY";
		break;
	    case OP_RV2HV:
		if (type != SVt_PVHV)
		    badtype = "a HASH";
		break;
	    case OP_RV2CV:
		if (type != SVt_PVCV)
		    badtype = "a CODE";
		break;
	    }
	    if (badtype)
		Perl_croak(aTHX_ "Constant is not %s reference", badtype);
	    return o;
	}
	if ((kid->op_private & OPpCONST_BARE)) {
	    const char *badthing;
	    switch (o->op_type) {
	    case OP_RV2SV:
		badthing = "a SCALAR";
		break;
	    case OP_RV2AV:
		badthing = "an ARRAY";
		break;
	    case OP_RV2HV:
		badthing = "a HASH";
		break;
	    default:
		badthing = NULL;
		break;
	    }
	    if (badthing)
		yyerror(Perl_form(aTHX_
				  "Can't use bareword (\"%"SVf"\") as %s ref while \"strict refs\" in use",
				  SVfARG(kidsv), badthing));
	}
	/*
	 * This is a little tricky.  We only want to add the symbol if we
	 * didn't add it in the lexer.  Otherwise we get duplicate strict
	 * warnings.  But if we didn't add it in the lexer, we must at
	 * least pretend like we wanted to add it even if it existed before,
	 * or we get possible typo warnings.  OPpCONST_ENTERED says
	 * whether the lexer already added THIS instance of this symbol.
	 */
	iscv = (o->op_type == OP_RV2CV) * 2;
	do {
	    gv = gv_fetchsv(kidsv,
		iscv | !(kid->op_private & OPpCONST_ENTERED),
		iscv
		    ? SVt_PVCV
		    : o->op_type == OP_RV2SV
			? SVt_PV
			: o->op_type == OP_RV2AV
			    ? SVt_PVAV
			    : o->op_type == OP_RV2HV
				? SVt_PVHV
				: SVt_PVGV);
	} while (!gv && !(kid->op_private & OPpCONST_ENTERED) && !iscv++);
	if (gv) {
	    kid->op_type = OP_GV;
	    SvREFCNT_dec(kid->op_sv);
	    kid->op_sv = SvREFCNT_inc_NN(gvTsv(gv));
	    kid->op_private = 0;
	    kid->op_ppaddr = PL_ppaddr[OP_GV];
	}
    }
    return o;
}

OP *
Perl_ck_ftst(pTHX_ OP *o)
{
    dVAR;
    const I32 type = o->op_type;

    PERL_ARGS_ASSERT_CK_FTST;

    if (o->op_flags & OPf_REF) {
	NOOP;
    }
    else if (o->op_flags & OPf_KIDS && cUNOPo->op_first->op_type != OP_STUB) {
	SVOP * const kid = (SVOP*)cUNOPo->op_first;
	const OPCODE kidtype = kid->op_type;

	if (kidtype == OP_PLACEHOLDER) {
	    OP * const newop = newGVOP(type, OPf_REF,
		gv_fetchpv("_", GV_ADD, SVt_PVIO),
		kid->op_location);
#ifdef PERL_MAD
	    op_getmad(o,newop,'O');
#else
	    op_free(o);
#endif
	    return newop;
	}
	if ((PL_hints & HINT_FILETEST_ACCESS) && OP_IS_FILETEST_ACCESS(o->op_type))
	    o->op_private |= OPpFT_ACCESS;
	if (PL_check[kidtype] == MEMBER_TO_FPTR(Perl_ck_ftst)
		&& kidtype != OP_STAT && kidtype != OP_LSTAT)
	    o->op_private |= OPpFT_STACKED;
    }
    else {
	OP* const oldo = o;
	o = newUNOP(type, 0, newDEFSVOP(o->op_location), oldo->op_location);
#ifdef PERL_MAD
	op_getmad(oldo,o,'O');
#else
	op_free(oldo);
#endif
    }
    return o;
}

OP *
Perl_ck_anonarray(pTHX_ OP*o)
{
    dVAR;
    register OP *kid;
    PERL_ARGS_ASSERT_CK_ANONARRAY;
    if (o->op_flags & OPf_SPECIAL)
	return o;
    for( kid = cLISTOPo->op_first ; kid ; kid = kid->op_sibling ) {
	list(kid);
    }
    return o;
}

OP *
Perl_ck_fun(pTHX_ OP *o)
{
    dVAR;
    const int type = o->op_type;
    register I32 oa = PL_opargs[type] >> OASHIFT;

    PERL_ARGS_ASSERT_CK_FUN;

    if (o->op_flags & OPf_STACKED) {
	if ((oa & OA_OPTIONAL) && (oa >> 4) && !((oa >> 4) & OA_OPTIONAL))
	    oa &= ~OA_OPTIONAL;
	else
	    return no_fh_allowed(o);
    }

    if (o->op_flags & OPf_KIDS) {
        OP **tokid = &cLISTOPo->op_first;
        register OP *kid = cLISTOPo->op_first;
        OP *sibl;
        I32 numargs = 0;

	if (kid->op_type == OP_PUSHMARK ||
	    (kid->op_type == OP_NULL && kid->op_targ == OP_PUSHMARK))
	{
	    tokid = &kid->op_sibling;
	    kid = kid->op_sibling;
	}
	if (!kid && PL_opargs[type] & OA_DEFGV)
	    *tokid = kid = newDEFSVOP(o->op_location);

	while (oa && kid) {
	    numargs++;
	    sibl = kid->op_sibling;
#ifdef PERL_MAD
	    if (!sibl && kid->op_type == OP_STUB) {
		numargs--;
		break;
	    }
#endif
	    switch (oa & 7) {
	    case OA_SCALAR:
		/* list seen where single (scalar) arg expected? */
		if (numargs == 1 && !(oa >> 4)
		    && kid->op_type == OP_LIST && type != OP_SCALAR)
		{
		    return too_many_arguments(o,PL_op_desc[type]);
		}
		if ((type == OP_PUSH || type == OP_UNSHIFT)
		    && !kid->op_sibling && ckWARN(WARN_SYNTAX))
		    Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
			"Useless use of %s with no values",
			PL_op_desc[type]);

		scalar(kid);
#ifdef PERL_MAD
		addmad(newMADsv('c', newSVpvn("$", 1), 0, 0), &kid->op_madprop, 0);
#endif
		break;
	    case OA_LIST:
		if (oa < 16) {
		    kid = 0;
		    continue;
		}
		else
		    list(kid);
		break;
	    case OA_AVREF:
		*tokid = kid = mod(kid, type);
#ifdef PERL_MAD
		addmad(newMADsv('c', newSVpvn("@", 1), 0, 0), &kid->op_madprop, 0);
#endif
		break;
	    case OA_HVREF:
		*tokid = kid = mod(kid, type);
#ifdef PERL_MAD
		addmad(newMADsv('c', newSVpvn("%", 1), 0, 0), &kid->op_madprop, 0);
#endif
		break;
	    case OA_CVREF:
		{
		    scalar(kid);
		}
		break;
	    case OA_FILEREF:
		if (kid->op_type != OP_GV && kid->op_type != OP_RV2GV) {
		    if (kid->op_type == OP_CONST)
		    {
			Perl_croak_at(aTHX_ kid->op_location,
			    "%s not allowed as fileref", OP_DESC(kid));
		    }
		    else if (kid->op_type == OP_READLINE) {
			/* neophyte patrol: open(<FH>), close(<FH>) etc. */
			bad_type(numargs, "HANDLE", OP_DESC(o), kid);
		    }
		    else {
			OPFLAGS flags = OPf_SPECIAL;
			I32 priv = 0;
			PADOFFSET targ = 0;

			/* is this op a FH constructor? */
			if (is_handle_constructor(o,numargs)) {
                            const char *name = NULL;
			    STRLEN len = 0;

			    flags = 0;
			    /* Set a flag to tell rv2gv to vivify
			     * need to "prove" flag does not mean something
			     * else already - NI-S 1999/05/07
			     */
			    priv = OPpDEREF;
			    if (kid->op_type == OP_PADSV) {
				SV *const namesv
				    = PAD_COMPNAME_SV(kid->op_targ);
				name = SvPV_const(namesv, len);
			    }
			    else if (kid->op_type == OP_RV2SV
				     && kUNOP->op_first->op_type == OP_GV)
			    {
				GV * const gv = cGVOPx_gv(kUNOP->op_first);
				name = GvNAME(gv);
				len = GvNAMELEN(gv);
			    }
			    else if (kid->op_type == OP_AELEM
				     || kid->op_type == OP_HELEM)
			    {
				 OP *firstop;
				 OP *op = ((BINOP*)kid)->op_first;
				 name = NULL;
				 if (op) {
				      SV *tmpstr = NULL;
				      const char * const a =
					   kid->op_type == OP_AELEM ?
					   "[]" : "{}";
				      if (((op->op_type == OP_RV2AV) ||
					   (op->op_type == OP_RV2HV)) &&
					  (firstop = ((UNOP*)op)->op_first) &&
					  (firstop->op_type == OP_GV)) {
					   /* packagevar $a[] or $h{} */
					   GV * const gv = cGVOPx_gv(firstop);
					   if (gv)
						tmpstr =
						     Perl_newSVpvf(aTHX_
								   "%s%c...%c",
								   GvNAME(gv),
								   a[0], a[1]);
				      }
				      if (tmpstr) {
					   name = SvPV_const(tmpstr, len);
					   sv_2mortal(tmpstr);
				      }
				 }
				 if (!name) {
				      name = "__ANONIO__";
				      len = 10;
				 }
				 *tokid = kid = mod(kid, type);
			    }
			    if (name) {
				SV *namesv;
				targ = pad_alloc(OP_RV2GV, SVs_PADTMP);
				namesv = PAD_SVl(targ);
				SvUPGRADE(namesv, SVt_PV);
				if (*name != '$')
				    sv_setpvs(namesv, "$");
				sv_catpvn(namesv, name, len);
			    }
			}
			kid->op_sibling = 0;
			kid = newUNOP(OP_RV2GV, flags, scalar(kid), kid->op_location);
			kid->op_targ = targ;
			kid->op_private |= priv;
		    }
		    kid->op_sibling = sibl;
		    *tokid = kid;
		}
		scalar(kid);
		break;
	    case OA_SCALARREF:
		*tokid = kid = mod(scalar(kid), type);
		break;
	    }
	    oa >>= 4;
	    tokid = &kid->op_sibling;
	    kid = kid->op_sibling;
	}
#ifdef PERL_MAD
	if (kid && kid->op_type != OP_STUB)
	    return too_many_arguments(o,OP_DESC(o));
	o->op_private |= numargs;
#else
	/* FIXME - should the numargs move as for the PERL_MAD case?  */
	o->op_private |= numargs;
	if (kid)
	    return too_many_arguments(o,OP_DESC(o));
#endif
	listkids(o);
    }
    else if (PL_opargs[type] & OA_DEFGV) {
	/* Ordering of these two is important to keep f_map.t passing.  */
	OP *newop = newUNOP(type, 0, newDEFSVOP(o->op_location), o->op_location);
#ifdef PERL_MAD
	op_getmad(o,newop,'O');
#else
	op_free(o);
#endif
	return newop;
    }

    if (oa) {
	while (oa & OA_OPTIONAL)
	    oa >>= 4;
	if (oa && oa != OA_LIST)
	    return too_few_arguments(o,OP_DESC(o));
    }
    return o;
}

OP *
Perl_ck_glob(pTHX_ OP *o)
{
    dVAR;
    GV *gv;

    PERL_ARGS_ASSERT_CK_GLOB;

    o = ck_fun(o);
    if ((o->op_flags & OPf_KIDS) && !cLISTOPo->op_first->op_sibling)
	append_elem(OP_GLOB, o, newDEFSVOP(o->op_location));

    if (!((gv = gv_fetchpvs("glob", GV_NOTQUAL, SVt_PVCV))
	  && GvCVu(gv) && GvIMPORTED_CV(gv)))
    {
	gv = gv_fetchpvs("CORE::GLOBAL::glob", 0, SVt_PVCV);
    }

#if !defined(PERL_EXTERNAL_GLOB)
    /* XXX this can be tightened up and made more failsafe. */
    if (!(gv && GvCVu(gv) && GvIMPORTED_CV(gv))) {
	GV *glob_gv;
	ENTER_named("load_glob");
	Perl_load_module(aTHX_ PERL_LOADMOD_NOIMPORT,
		newSVpvs("File::Glob"), NULL, NULL, NULL);
	gv = gv_fetchpvs("CORE::GLOBAL::glob", 0, SVt_PVCV);
	glob_gv = gv_fetchpvs("File::Glob::csh_glob", 0, SVt_PVCV);
	GvCV(gv) = GvCV(glob_gv);
	SvREFCNT_inc_void(MUTABLE_SV(GvCV(gv)));
	GvIMPORTED_CV_on(gv);
	LEAVE_named("load_glob");
    }
#endif /* PERL_EXTERNAL_GLOB */

    if (!(gv && GvCVu(gv) && GvIMPORTED_CV(gv))) {
	GV *glob_gv;
	ENTER_named("load_PP_glob");
	Perl_load_module(aTHX_ PERL_LOADMOD_NOIMPORT,
		newSVpvs("File::GlobPP"), NULL, NULL, NULL);
	gv = gv_fetchpvs("CORE::GLOBAL::glob", 1, SVt_PVCV);
	glob_gv = gv_fetchpvs("File::GlobPP::glob", 0, SVt_PVCV);
	if ( ! glob_gv )
	    Perl_croak_at(aTHX_ o->op_location, "Failed loading File::GlobPP::glob");
	GvCV(gv) = GvCV(glob_gv);
	SvREFCNT_inc_void((SV*)GvCV(gv));
	GvIMPORTED_CV_on(gv);
	LEAVE_named("load_PP_glob");
    }

    if ( ! (gv && GvCVu(gv) && GvIMPORTED_CV(gv)) ) {
	Perl_croak(aTHX_ "Failed loading glob routine");
    }

    append_elem(OP_GLOB, o,
		newSVOP(OP_CONST, 0, newSViv(PL_glob_index++), o->op_location));
    o->op_type = OP_LIST;
    o->op_ppaddr = PL_ppaddr[OP_LIST];
    cLISTOPo->op_first->op_type = OP_PUSHMARK;
    cLISTOPo->op_first->op_ppaddr = PL_ppaddr[OP_PUSHMARK];
    cLISTOPo->op_first->op_targ = 0;
    o = newUNOP(OP_ENTERSUB, OPf_STACKED,
		append_elem(OP_LIST, o,
			    scalar(newUNOP(OP_RV2CV, 0,
					   newGVOP(OP_GV, 0, gv, o->op_location),
					   o->op_location
				       ))), o->op_location);
    o = newUNOP(OP_NULL, 0, ck_subr(o), o->op_location);
    o->op_targ = OP_GLOB;           /* hint at what it used to be */
    return o;
}

OP *
Perl_ck_grep(pTHX_ OP *o)
{
    dVAR;
    LOGOP *gwop = NULL;
    UNOP* entersubop;
    OP *kid;
    const OPCODE type = o->op_type == OP_GREPSTART ? OP_GREPWHILE : OP_MAPWHILE;

    PERL_ARGS_ASSERT_CK_GREP;

    o->op_ppaddr = PL_ppaddr[OP_GREPSTART];
    /* don't allocate gwop here, as we may leak it if PL_parser->error_count > 0 */

    o = ck_fun(o);
    if (PL_parser && PL_parser->error_count)
	return o;
    kid = cLISTOPo->op_first->op_sibling;

    NewOp(11011, gwop, 1, LOGOP);
    gwop->op_type = type;
    gwop->op_ppaddr = PL_ppaddr[type];
    gwop->op_location = SvREFCNT_inc(o->op_location);

    NewOp(11011, entersubop, 1, UNOP);
    entersubop->op_type = OP_ENTERSUB;
    entersubop->op_flags = OPf_STACKED;
    entersubop->op_ppaddr = PL_ppaddr[OP_ENTERSUB];
    entersubop->op_location = SvREFCNT_inc(o->op_location);
    
    gwop->op_flags |= OPf_KIDS;
    gwop->op_first = o;
    gwop->op_other = (OP*)entersubop;
    o->op_sibling = (OP*)entersubop;

    return (OP*)gwop;
}

OP *
Perl_ck_index(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_INDEX;

    if (o->op_flags & OPf_KIDS) {
	OP *kid = cLISTOPo->op_first->op_sibling;	/* get past pushmark */
	if (kid)
	    kid = kid->op_sibling;			/* get past "big" */
	if (kid && kid->op_type == OP_CONST)
	    fbm_compile(((SVOP*)kid)->op_sv, 0);
    }
    return ck_fun(o);
}

OP *
Perl_ck_lfun(pTHX_ OP *o)
{
    const OPCODE type = o->op_type;

    PERL_ARGS_ASSERT_CK_LFUN;

    o = ck_fun(o);
    if ((cBINOPo->op_flags & OPf_KIDS) && cBINOPo->op_first) {
	OP** kidp;
	if (cBINOPo->op_first->op_type == OP_PUSHMARK)
	    kidp = &(cBINOPo->op_first->op_sibling);
	else
	    kidp = &(cBINOPo->op_first);
	o = op_mod_assign(o, kidp, type);
    }
    return o;
}

OP *
Perl_ck_defined(pTHX_ OP *o)		/* 19990527 MJD */
{
    PERL_ARGS_ASSERT_CK_DEFINED;

    if (o->op_flags & OPf_KIDS) {
	if (cUNOPo->op_first->op_type == OP_RV2CV)
	    cUNOPo->op_first->op_flags |= OPf_SPECIAL;
    }
    return ck_rfun(o);
}

OP *
Perl_ck_readline(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_READLINE;

    if (!(o->op_flags & OPf_KIDS)) {
	Perl_croak_at(aTHX_ o->op_location, "readline expected argument");
    }
    return o;
}

OP *
Perl_ck_rfun(pTHX_ OP *o)
{
    const OPCODE type = o->op_type;

    PERL_ARGS_ASSERT_CK_RFUN;

    return refkids(ck_fun(o), type);
}

OP *
Perl_ck_listiob(pTHX_ OP *o)
{
    register OP *kid;

    PERL_ARGS_ASSERT_CK_LISTIOB;

    kid = cLISTOPo->op_first;
    if (!kid) {
	o = force_list(o);
	kid = cLISTOPo->op_first;
    }
    if (kid->op_type == OP_PUSHMARK)
	kid = kid->op_sibling;
    if (kid && o->op_flags & OPf_STACKED)
	kid = kid->op_sibling;
    else if (kid && !kid->op_sibling) {		/* print HANDLE; */
	if (kid->op_type == OP_CONST && kid->op_private & OPpCONST_BARE) {
	    o->op_flags |= OPf_STACKED;	/* make it a filehandle */
	    kid = newUNOP(OP_RV2GV, OPf_REF, scalar(kid), o->op_location);
	    cLISTOPo->op_first->op_sibling = kid;
	    cLISTOPo->op_last = kid;
	    kid = kid->op_sibling;
	}
    }

    if (!kid)
	append_elem(o->op_type, o, newDEFSVOP(o->op_location));

    return listkids(o);
}

OP *
Perl_ck_compsub(pTHX_ OP *o)
{
    OP * const first = cBINOPo->op_first;
    OP * newop;
    SV * sv;

    dSP;

    SV* args_b = NULL;

    ENTER_named("ck_compsub");
    PUSHMARK(SP);
    if (first->op_sibling) {
	args_b = newSV(0);
	sv_setiv(newSVrv(args_b, "B::LISTOP"), PTR2IV(first->op_sibling));
	XPUSHs(args_b);
    }
    PUTBACK;

    sv = call_sv(cSVOPx_sv(first), G_SCALAR);

    SPAGAIN;
    newop = INT2PTR(OP*, SvIV(SvRV(sv)));

    if (!newop)
	Perl_die(aTHX_ "No opcode returned by the compsub");

    if (args_b && SvREFCNT(args_b) != 1)
	Perl_die(aTHX_ "reference to B::OP argument kept");
    SvREFCNT_dec(args_b);

    LEAVE_named("ck_compsub");

    cBINOPo->op_first->op_sibling = NULL;
    op_free(o);

    return newop;
}

OP *
Perl_ck_sassign(pTHX_ OP *o)
{
    dVAR;
    OP * const kid = cLISTOPo->op_first;

    PERL_ARGS_ASSERT_CK_SASSIGN;

    /* has a disposable target? */
    if ((PL_opargs[kid->op_type] & OA_TARGLEX)
	&& !(kid->op_flags & OPf_STACKED)
	/* Cannot steal the second time! */
	&& !(kid->op_flags & OPf_TARGET_MY)
	/* Keep the full thing for madskills */
	&& !PL_madskills
	)
    {
	OP * const kkid = kid->op_sibling;

	/* Can just relocate the target. */
	if (kkid && kkid->op_type == OP_PADSV
	    && !(kkid->op_private & OPpLVAL_INTRO))
	{
	    kid->op_targ = kkid->op_targ;
	    kkid->op_targ = 0;
	    /* Now we do not need PADSV and SASSIGN and PUSHMARK. */
	    kid->op_sibling = o->op_sibling;	/* NULL */
	    cLISTOPo->op_first = NULL;
/* 	    op_free(o->op_sibling); */
	    op_free(o);
	    op_free(kkid);
	    kid->op_flags |= OPf_TARGET_MY;	/* Used for context settings */
	    return kid;
	}
    }
    return o;
}

OP *
Perl_ck_match(pTHX_ OP *o)
{
    dVAR;

    PERL_ARGS_ASSERT_CK_MATCH;

    if (o->op_type != OP_QR && PL_compcv) {
	const PADOFFSET offset = pad_findmy("$_");
	if (offset != NOT_IN_PAD && !(PAD_COMPNAME_FLAGS_isOUR(offset))) {
	    o->op_targ = offset;
	    o->op_flags |= OPf_TARGET_MY;
	}
    }
    if (o->op_type == OP_MATCH || o->op_type == OP_QR)
	o->op_private |= OPpRUNTIME;
    return o;
}

OP *
Perl_ck_method(pTHX_ OP *o)
{
    OP * const kid = cUNOPo->op_first;

    PERL_ARGS_ASSERT_CK_METHOD;

    if (kid->op_type == OP_CONST) {
	SV* sv = kSVOP->op_sv;
	const char * const method = SvPVX_const(sv);
	if (!(strchr(method, ':') || strchr(method, '\''))) {
	    OP *cmop;
	    if (!SvREADONLY(sv) || !SvFAKE(sv)) {
		sv = newSVpvn_share(method, SvCUR(sv), 0);
	    }
	    else {
		kSVOP->op_sv = NULL;
	    }
	    cmop = newSVOP(OP_METHOD_NAMED, 0, sv, o->op_location);
#ifdef PERL_MAD
	    op_getmad(o,cmop,'O');
#else
	    op_free(o);
#endif
	    return cmop;
	}
    }
    return o;
}

OP *
Perl_ck_dotdotdot(pTHX_ OP *o)
{
/*     Perl_croak_at(aTHX_ o->op_location, */
/* 	"%s can only be used inside a pattern assignment", OP_DESC(o)); */
    return o;
}

OP *
Perl_ck_null(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_NULL;
    PERL_UNUSED_CONTEXT;
    return o;
}

OP *
Perl_ck_open(pTHX_ OP *o)
{
    dVAR;
    HV * const table = PL_hinthv;

    PERL_ARGS_ASSERT_CK_OPEN;

    if (table) {
	SV **svp = hv_fetchs(table, "open_IN", FALSE);
	if (svp && *svp) {
	    STRLEN len = 0;
	    const char *d = SvPV_const(*svp, len);
	    const I32 mode = mode_from_discipline(d, len);
	    if (mode & O_BINARY)
		o->op_private |= OPpOPEN_IN_RAW;
	    else if (mode & O_TEXT)
		o->op_private |= OPpOPEN_IN_CRLF;
	}

	svp = hv_fetchs(table, "open_OUT", FALSE);
	if (svp && *svp) {
	    STRLEN len = 0;
	    const char *d = SvPV_const(*svp, len);
	    const I32 mode = mode_from_discipline(d, len);
	    if (mode & O_BINARY)
		o->op_private |= OPpOPEN_OUT_RAW;
	    else if (mode & O_TEXT)
		o->op_private |= OPpOPEN_OUT_CRLF;
	}
    }
    if (o->op_type == OP_BACKTICK) {
	if (!(o->op_flags & OPf_KIDS)) {
	    OP * const newop = newUNOP(OP_BACKTICK, 0, newDEFSVOP(o->op_location), o->op_location);
#ifdef PERL_MAD
	    op_getmad(o,newop,'O');
#else
	    op_free(o);
#endif
	    return newop;
	}
	return o;
    }
    {
	 /* In case of three-arg dup open remove strictness
	  * from the last arg if it is a bareword. */
	 OP * const first = cLISTOPx(o)->op_first; /* The pushmark. */
	 OP * const last  = cLISTOPx(o)->op_last;  /* The bareword. */
	 OP *oa;
	 const char *mode;

	 if ((last->op_type == OP_CONST) &&		/* The bareword. */
	     (last->op_private & OPpCONST_BARE) &&
	     (last->op_private & OPpCONST_STRICT) &&
	     (oa = first->op_sibling) &&		/* The fh. */
	     (oa = oa->op_sibling) &&			/* The mode. */
	     (oa->op_type == OP_CONST) &&
	     SvPOK(((SVOP*)oa)->op_sv) &&
	     (mode = SvPVX_const(((SVOP*)oa)->op_sv)) &&
	     mode[0] == '>' && mode[1] == '&' &&	/* A dup open. */
	     (last == oa->op_sibling))			/* The bareword. */
	      last->op_private &= ~OPpCONST_STRICT;
    }
    return ck_fun(o);
}

OP *
Perl_ck_require(pTHX_ OP *o)
{
    dVAR;
    GV* gv = NULL;

    PERL_ARGS_ASSERT_CK_REQUIRE;

    if (o->op_flags & OPf_KIDS) {	/* Shall we supply missing .pm? */
	SVOP * const kid = (SVOP*)cUNOPo->op_first;

	if (kid->op_type == OP_CONST && (kid->op_private & OPpCONST_BARE)) {
	    SV * const sv = kid->op_sv;
	    U32 was_readonly = SvREADONLY(sv);
	    char *s;
	    STRLEN len;
	    const char *end;

	    if (was_readonly) {
		if (SvFAKE(sv)) {
		    sv_force_normal_flags(sv, 0);
		    assert(!SvREADONLY(sv));
		    was_readonly = 0;
		} else {
		    SvREADONLY_off(sv);
		}
	    }   

	    s = SvPVX_mutable(sv);
	    len = SvCUR(sv);
	    end = s + len;
	    for (; s < end; s++) {
		if (*s == ':' && s[1] == ':') {
		    *s = '/';
		    Move(s+2, s+1, end - s - 1, char);
		    --end;
		}
	    }
	    SvEND_set(sv, end);
	    sv_catpvs(sv, ".pm");
	    SvFLAGS(sv) |= was_readonly;
	}
    }

    if (!(o->op_flags & OPf_SPECIAL)) { /* Wasn't written as CORE::require */
	/* handle override, if any */
	gv = gv_fetchpvs("require", GV_NOTQUAL, SVt_PVCV);
	if (!(gv && GvCVu(gv) && GvIMPORTED_CV(gv))) {
	    GV * const * const gvp = (GV**)hv_fetchs(PL_globalstash, "require", FALSE);
	    gv = gvp ? *gvp : NULL;
	}
    }

    if (gv && GvCVu(gv) && GvIMPORTED_CV(gv)) {
	OP * const kid = cUNOPo->op_first;
	OP * newop;

	cUNOPo->op_first = 0;
	newop = ck_subr(newUNOP(OP_ENTERSUB, OPf_STACKED,
				append_elem(OP_LIST, kid,
					    scalar(newUNOP(OP_RV2CV, 0,
							   newGVOP(OP_GV, 0,
								   gv, o->op_location), 
							   o->op_location))),
				o->op_location
			    ));
#ifndef PERL_MAD
	op_free(o);
#endif
	op_getmad(o,newop,'O');
	return newop;
    }

    return ck_fun(o);
}

OP *
Perl_ck_shift(pTHX_ OP *o)
{
    dVAR;
    const I32 type = o->op_type;

    PERL_ARGS_ASSERT_CK_SHIFT;

    if (!(o->op_flags & OPf_KIDS)) {
#ifdef PERL_MAD
	OP * const oldo = o;
#endif

	const PADOFFSET offset = pad_findmy("@_");
	OP * const argop = newOP(OP_PADSV, 0, o->op_location);
	argop->op_targ = offset;
	if (offset == NOT_IN_PAD) {
	    yyerror_at(o->op_location, "shift requires lexical @_");
	    argop->op_targ = 0;
	}

#ifdef PERL_MAD
	o = newUNOP(type, 0, scalar(argop), argop->op_location);
	op_getmad(oldo,o,'O');
	return o;
#else
	op_free(o);
	return newUNOP(type, 0, scalar(argop), argop->op_location);
#endif
    }
    return scalar(ck_lfun(o));
}

OP *
Perl_ck_sort(pTHX_ OP *o)
{
    dVAR;
    OP *firstkid;

    PERL_ARGS_ASSERT_CK_SORT;

    if ((PL_hints & HINT_LOCALIZE_HH) != 0) {
	HV * const hinthv = PL_hinthv;
	if (hinthv) {
	    SV ** const svp = hv_fetchs(hinthv, "sort", FALSE);
	    if (svp) {
		const I32 sorthints = (I32)SvIV(*svp);
		if ((sorthints & HINT_SORT_QUICKSORT) != 0)
		    o->op_private |= OPpSORT_QSORT;
		if ((sorthints & HINT_SORT_STABLE) != 0)
		    o->op_private |= OPpSORT_STABLE;
	    }
	}
    }

    simplify_sort(o);
    firstkid = cLISTOPo->op_first->op_sibling;		/* get past pushmark */
    if (o->op_flags & OPf_STACKED) {			/* may have been cleared */
	OP *k = NULL;
	OP *kid = cUNOPx(firstkid)->op_first;		/* get past null */

	if (kid->op_type == OP_SCOPE || kid->op_type == OP_LEAVE) {
	    linklist(kid);
	    if (kid->op_type == OP_SCOPE) {
		k = kid->op_next;
		kid->op_next = 0;
	    }
	    else if (kid->op_type == OP_LEAVE) {
		if (o->op_type == OP_SORT) {
		    op_null(kid);			/* wipe out leave */
		    kid->op_next = kid;

		    for (k = kLISTOP->op_first->op_next; k; k = k->op_next) {
			if (k->op_next == kid)
			    k->op_next = 0;
			/* don't descend into loops */
			else if (k->op_type == OP_ENTERLOOP
				 || k->op_type == OP_ENTERITER)
			{
			    k = cLOOPx(k)->op_lastop;
			}
		    }
		}
		else
		    kid->op_next = 0;		/* just disconnect the leave */
		k = kLISTOP->op_first;
	    }
	    CALL_PEEP(k);

	    kid = firstkid;
	    if (o->op_type == OP_SORT) {
		/* provide scalar context for comparison function/block */
		kid = scalar(kid);
		kid->op_next = kid;
	    }
	    else
		kid->op_next = k;
	    o->op_flags |= OPf_SPECIAL;
	}
	else if (kid->op_type == OP_RV2SV || kid->op_type == OP_PADSV)
	    op_null(firstkid);

	firstkid = firstkid->op_sibling;
    }

    /* provide list context for arguments */
    if (o->op_type == OP_SORT)
	list(firstkid);

    return o;
}

STATIC void
S_simplify_sort(pTHX_ OP *o)
{
    dVAR;
    register OP *kid = cLISTOPo->op_first->op_sibling;	/* get past pushmark */
    OP *k;
    int descending;
    GV *gv;
    const char *gvname;

    PERL_ARGS_ASSERT_SIMPLIFY_SORT;

    if (!(o->op_flags & OPf_STACKED))
	return;
    GvMULTI_on(gv_fetchpvs("a", GV_ADD|GV_NOTQUAL, SVt_PV));
    GvMULTI_on(gv_fetchpvs("b", GV_ADD|GV_NOTQUAL, SVt_PV));
    kid = kUNOP->op_first;				/* get past null */
    if (kid->op_type != OP_SCOPE)
	return;
    kid = kLISTOP->op_last;				/* get past scope */
    switch(kid->op_type) {
	case OP_NCMP:
	case OP_I_NCMP:
	case OP_SCMP:
	    break;
	default:
	    return;
    }
    k = kid;						/* remember this node*/
    if (kBINOP->op_first->op_type != OP_RV2SV)
	return;
    kid = kBINOP->op_first;				/* get past cmp */
    if (kUNOP->op_first->op_type != OP_GV)
	return;
    kid = kUNOP->op_first;				/* get past rv2sv */
    gv = kGVOP_gv;
    if (GvSTASH(gv) != PL_curstash)
	return;
    gvname = GvNAME(gv);
    if (*gvname == 'a' && gvname[1] == '\0')
	descending = 0;
    else if (*gvname == 'b' && gvname[1] == '\0')
	descending = 1;
    else
	return;

    kid = k;						/* back to cmp */
    if (kBINOP->op_last->op_type != OP_RV2SV)
	return;
    kid = kBINOP->op_last;				/* down to 2nd arg */
    if (kUNOP->op_first->op_type != OP_GV)
	return;
    kid = kUNOP->op_first;				/* get past rv2sv */
    gv = kGVOP_gv;
    if (GvSTASH(gv) != PL_curstash)
	return;
    gvname = GvNAME(gv);
    if ( descending
	 ? !(*gvname == 'a' && gvname[1] == '\0')
	 : !(*gvname == 'b' && gvname[1] == '\0'))
	return;
    o->op_flags &= ~(OPf_STACKED | OPf_SPECIAL);
    if (descending)
	o->op_private |= OPpSORT_DESCEND;
    if (k->op_type == OP_NCMP)
	o->op_private |= OPpSORT_NUMERIC;
    if (k->op_type == OP_I_NCMP)
	o->op_private |= OPpSORT_NUMERIC | OPpSORT_INTEGER;
    kid = cLISTOPo->op_first->op_sibling;
    cLISTOPo->op_first->op_sibling = kid->op_sibling; /* bypass old block */
#ifdef PERL_MAD
    op_getmad(kid,o,'S');			      /* then delete it */
#else
    op_free(kid);				      /* then delete it */
#endif
}

OP *
Perl_ck_split(pTHX_ OP *o)
{
    dVAR;
    register OP *kid;

    PERL_ARGS_ASSERT_CK_SPLIT;

    if (o->op_flags & OPf_STACKED)
	return no_fh_allowed(o);

    kid = cLISTOPo->op_first;
    if (kid->op_type != OP_NULL)
	Perl_croak(aTHX_ "panic: ck_split");
    kid = kid->op_sibling;
    op_free(cLISTOPo->op_first);
    cLISTOPo->op_first = kid;
    if (!kid) {
	cLISTOPo->op_first = kid = newSVOP(OP_CONST, 0, newSVpvs(" "), o->op_location);
	cLISTOPo->op_last = kid; /* There was only one element previously */
    }

    if (kid->op_type != OP_MATCH || kid->op_flags & OPf_STACKED) {
	OP * const sibl = kid->op_sibling;
	kid->op_sibling = 0;
	kid = pmruntime( newPMOP(OP_MATCH, OPf_SPECIAL, o->op_location), kid, 0);
	if (cLISTOPo->op_first == cLISTOPo->op_last)
	    cLISTOPo->op_last = kid;
	cLISTOPo->op_first = kid;
	kid->op_sibling = sibl;
    }

    kid->op_type = OP_PUSHRE;
    kid->op_ppaddr = PL_ppaddr[OP_PUSHRE];
    scalar(kid);
    if (((PMOP *)kid)->op_pmflags & PMf_GLOBAL && ckWARN(WARN_REGEXP)) {
      Perl_warner(aTHX_ packWARN(WARN_REGEXP),
                  "Use of /g modifier is meaningless in split");
    }

    if (!kid->op_sibling)
	append_elem(OP_SPLIT, o, newDEFSVOP(o->op_location));

    kid = kid->op_sibling;
    scalar(kid);

    if (!kid->op_sibling)
	append_elem(OP_SPLIT, o, newSVOP(OP_CONST, 0, newSViv(0), o->op_location));
    assert(kid->op_sibling);

    kid = kid->op_sibling;
    scalar(kid);

    if (kid->op_sibling)
	return too_many_arguments(o,OP_DESC(o));

    return o;
}

OP *
Perl_ck_subr(pTHX_ OP *o)
{
    dVAR;
    OP *prev = ((cUNOPo->op_first->op_sibling)
	     ? cUNOPo : ((UNOP*)cUNOPo->op_first))->op_first;
    OP *o2 = prev->op_sibling;
    OP *cvop;
    I32 n_minargs = 0;
    I32 n_maxargs = -1;
    CV *cv = NULL;
    I32 arg = 0;
    bool variable_args = 0;
    SV** namesv;

    PERL_ARGS_ASSERT_CK_SUBR;

    o->op_private |= OPpENTERSUB_HASTARG;
    for (cvop = o2; cvop->op_sibling; cvop = cvop->op_sibling) ;
    if (cvop->op_type == OP_VAR) {
	o->op_private |= (cvop->op_private & OPpENTERSUB_AMPER);
	if ( ! ( o->op_flags & OPpENTERSUB_AMPER ) ) {
	    SV* sv = cSVOPx(cvop)->op_sv;
	    if (SvTYPE(sv) == SVt_PVCV)
		cv = svTcv(sv);
	}
	if (cv) {
	    n_minargs = CvN_MINARGS(cv);
	    n_maxargs = CvN_MAXARGS(cv);
	}
    }
    else if (cvop->op_type == OP_METHOD || cvop->op_type == OP_METHOD_NAMED) {
	if (o2->op_type == OP_CONST)
	    o2->op_private &= ~OPpCONST_STRICT;
	else if (o2->op_type == OP_LIST) {
	    OP * const sib = ((UNOP*)o2)->op_first->op_sibling;
	    if (sib && sib->op_type == OP_CONST)
		sib->op_private &= ~OPpCONST_STRICT;
	}
    }
    if (PERLDB_SUB && PL_curstash != PL_debstash)
	o->op_private |= OPpENTERSUB_DB;
    if (cv && SvLOCATION(cv) && SvAVOK(SvLOCATION(cv)))
	namesv = av_fetch(svTav(SvLOCATION(cv)), 3, 0);
    while (o2 != cvop) {
	OP* o3;
	if (PL_madskills && o2->op_type == OP_NULL)
	    o3 = ((UNOP*)o2)->op_first;
	else
	    o3 = o2;
	if (PL_opargs[o3->op_type] & OA_RETSCALAR)
	    arg++;
	else
	    variable_args = 1;
	if ( n_maxargs != -1 && arg > n_maxargs )
	    return too_many_arguments(o, 
		namesv ? SvPVX_const(*namesv) : "subroutine");
	list(o2);
	prev->op_sibling = o2 = mod(o2, OP_ENTERSUB);
	prev = o2;
	o2 = o2->op_sibling;
    } /* while */
    if (arg < n_minargs && ! variable_args) {
	return too_few_arguments(o, 
	    namesv ? SvPVX_const(*namesv) : "subroutine");
    }
    return o;
}

OP *
Perl_ck_svconst(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_SVCONST;
    PERL_UNUSED_CONTEXT;
    SvREADONLY_on(cSVOPo->op_sv);
    return o;
}

OP *
Perl_ck_chdir(pTHX_ OP *o)
{
    if (o->op_flags & OPf_KIDS) {
	SVOP * const kid = (SVOP*)cUNOPo->op_first;

	if (kid && kid->op_type == OP_CONST &&
	    (kid->op_private & OPpCONST_BARE))
	{
	    o->op_flags |= OPf_SPECIAL;
	    kid->op_private &= ~OPpCONST_STRICT;
	}
    }
    return ck_fun(o);
}

OP *
Perl_ck_trunc(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_TRUNC;

    if (o->op_flags & OPf_KIDS) {
	SVOP *kid = (SVOP*)cUNOPo->op_first;

	if (kid->op_type == OP_NULL)
	    kid = (SVOP*)kid->op_sibling;
	if (kid && kid->op_type == OP_CONST &&
	    (kid->op_private & OPpCONST_BARE))
	{
	    o->op_flags |= OPf_SPECIAL;
	    kid->op_private &= ~OPpCONST_STRICT;
	}
    }
    return ck_fun(o);
}

OP *
Perl_ck_unpack(pTHX_ OP *o)
{
    OP *kid = cLISTOPo->op_first;

    PERL_ARGS_ASSERT_CK_UNPACK;

    if (kid->op_sibling) {
	kid = kid->op_sibling;
	if (!kid->op_sibling)
	    kid->op_sibling = newDEFSVOP(o->op_location);
    }
    return ck_fun(o);
}

OP *
Perl_ck_substr(pTHX_ OP *o)
{
    PERL_ARGS_ASSERT_CK_SUBSTR;

    o = ck_fun(o);
    if ((o->op_flags & OPf_KIDS) && (o->op_private == 4)) {
	OP *kid = cLISTOPo->op_first;

	if (kid->op_type == OP_NULL)
	    kid = kid->op_sibling;
	if (kid)
	    kid->op_flags |= OPf_MOD;

    }
    return o;
}

/* A peephole optimizer.  We visit the ops in the order they're to execute.
 * See the comments at the top of this file for more details about when
 * peep() is called */

void
Perl_peep(pTHX_ register OP *o)
{
    dVAR;
    register OP* oldop = NULL;

    if (!o || o->op_opt)
	return;
    ENTER_named("peep");
    SAVEOP();
    SAVEVPTR(PL_curcop);
    for (; o; o = o->op_next) {
	if (o->op_opt)
	    break;
	/* By default, this op has now been optimised. A couple of cases below
	   clear this again.  */
	o->op_opt = 1;
	PL_op = o;
	switch (o->op_type) {
	case OP_NEXTSTATE:
	case OP_DBSTATE:
	    PL_curcop = ((COP*)o);		/* for warnings */
	    break;

	case OP_CONST:
	    if (cSVOPo->op_private & OPpCONST_STRICT)
		no_bareword_allowed(o);
	    break;

	case OP_CONCAT:
	    if (o->op_next && o->op_next->op_type == OP_STRINGIFY) {
		if (o->op_next->op_flags & OPf_TARGET_MY) {
		    if (o->op_flags & OPf_STACKED) /* chained concats */
			break; /* ignore_optimization */
		    else {
			/* assert(PL_opargs[o->op_type] & OA_TARGLEX); */
			o->op_targ = o->op_next->op_targ;
			o->op_next->op_targ = 0;
			o->op_flags |= OPf_TARGET_MY;
		    }
		}
		op_null(o->op_next);
	    }
	    break;
	case OP_STUB:
	    if ((o->op_flags & OPf_WANT) != OPf_WANT_LIST) {
		break; /* Scalar stub must produce undef.  List stub is noop */
	    }
	    goto nothin;
	case OP_NULL:
	    if (o->op_targ == OP_NEXTSTATE
		|| o->op_targ == OP_DBSTATE)
	    {
		PL_curcop = ((COP*)o);
	    }
	    /* XXX: We avoid setting op_seq here to prevent later calls
	       to peep() from mistakenly concluding that optimisation
	       has already occurred. This doesn't fix the real problem,
	       though (See 20010220.007). AMS 20010719 */
	    /* op_seq functionality is now replaced by op_opt */
	    o->op_opt = 0;
	    /* FALL THROUGH */
	case OP_SCALAR:
	case OP_LINESEQ:
	case OP_SCOPE:
	nothin:
	    if (oldop && o->op_next) {
		oldop->op_next = o->op_next;
		o->op_opt = 0;
		continue;
	    }
	    break;

	case OP_GV:
	    if (o->op_next->op_type == OP_RV2AV) {
		OP* const pop = o->op_next->op_next;
		IV i;
		if (pop && pop->op_type == OP_CONST &&
		    ((PL_op = pop->op_next)) &&
		    pop->op_next->op_type == OP_AELEM &&
		    !(pop->op_next->op_private &
		      (OPpLVAL_INTRO|OPpDEREF|OPpELEM_ADD|OPpELEM_OPTIONAL)) &&
		    (i = SvIV(((SVOP*)pop)->op_sv))
				<= 255 &&
		    i >= 0)
		{
		    GV *gv;
		    if (cSVOPx(pop)->op_private & OPpCONST_STRICT)
			no_bareword_allowed(pop);
		    if (o->op_type == OP_GV)
			op_null(o->op_next);
		    op_null(pop->op_next);
		    op_null(pop);
		    o->op_flags |= pop->op_next->op_flags & (OPf_MOD|OPf_ASSIGN|OPf_ASSIGN_PART|OPf_OPTIONAL);
		    o->op_next = pop->op_next->op_next;
		    o->op_ppaddr = PL_ppaddr[OP_AELEMFAST];
		    o->op_private = (U8)i;
		    if (o->op_type == OP_GV) {
			gv = cGVOPo_gv;
			GvAVn(gv);
		    }
		    else
			o->op_flags |= OPf_SPECIAL;
		    o->op_type = OP_AELEMFAST;
		}
		break;
	    }

	    if (o->op_next->op_type == OP_RV2SV) {
		if (!(o->op_next->op_private & OPpDEREF)) {
		    op_null(o->op_next);
		    o->op_private |= o->op_next->op_private & (OPpLVAL_INTRO
							       | OPpOUR_INTRO);
		    o->op_flags |= o->op_next->op_flags & (OPf_ASSIGN|OPf_ASSIGN_PART|OPf_OPTIONAL|OPf_MOD);
		    o->op_next = o->op_next->op_next;
		    o->op_type = OP_GVSV;
		    o->op_ppaddr = PL_ppaddr[OP_GVSV];
		}
	    }
	    else if (o->op_next->op_type == OP_READLINE
		    && o->op_next->op_next->op_type == OP_CONCAT
		    && (o->op_next->op_next->op_flags & OPf_STACKED)
         	    && !PL_madskills)
	    {
		/* Turn "$a .= <FH>" into an OP_RCATLINE. AMS 20010917 */
		o->op_type   = OP_RCATLINE;
		o->op_flags |= OPf_STACKED;
		o->op_ppaddr = PL_ppaddr[OP_RCATLINE];
		op_null(o->op_next->op_next);
		op_null(o->op_next);
	    }

	    break;

	case OP_MAPWHILE:
	case OP_GREPWHILE:
	case OP_AND:
	case OP_OR:
	case OP_DOR:
	case OP_ANDASSIGN:
	case OP_ORASSIGN:
	case OP_DORASSIGN:
	case OP_COND_EXPR:
	    while (cLOGOP->op_other->op_type == OP_NULL)
		cLOGOP->op_other = cLOGOP->op_other->op_next;
	    peep(cLOGOP->op_other); /* Recursive calls are not replaced by fptr calls */
	    break;

	case OP_ENTERLOOP:
	case OP_ENTERITER:
	    while (cLOOP->op_redoop->op_type == OP_NULL)
		cLOOP->op_redoop = cLOOP->op_redoop->op_next;
	    peep(cLOOP->op_redoop);
	    while (cLOOP->op_nextop->op_type == OP_NULL)
		cLOOP->op_nextop = cLOOP->op_nextop->op_next;
	    peep(cLOOP->op_nextop);
	    while (cLOOP->op_lastop->op_type == OP_NULL)
		cLOOP->op_lastop = cLOOP->op_lastop->op_next;
	    peep(cLOOP->op_lastop);
	    break;

	case OP_SUBST:
	    while (cPMOP->op_pmstashstartu.op_pmreplstart &&
		   cPMOP->op_pmstashstartu.op_pmreplstart->op_type == OP_NULL)
		cPMOP->op_pmstashstartu.op_pmreplstart
		    = cPMOP->op_pmstashstartu.op_pmreplstart->op_next;
	    peep(cPMOP->op_pmstashstartu.op_pmreplstart);
	    break;

	case OP_EXEC:
	    if (o->op_next && o->op_next->op_type == OP_NEXTSTATE
		&& ckWARN(WARN_SYNTAX))
	    {
		if (o->op_next->op_sibling) {
		    const OPCODE type = o->op_next->op_sibling->op_type;
		    if (type != OP_EXIT && type != OP_WARN && type != OP_DIE) {
			Perl_warner(aTHX_ packWARN(WARN_EXEC),
				    "Statement unlikely to be reached");
			Perl_warner(aTHX_ packWARN(WARN_EXEC),
				    "        (Maybe you meant system() when you said exec()?)\n");
		    }
		}
	    }
	    break;

	case OP_HELEM: {
	    UNOP *rop;
            SV *lexname;
	    SV **svp, *sv;
	    const char *key = NULL;
	    STRLEN keylen;

	    if (((BINOP*)o)->op_last->op_type != OP_CONST)
		break;

	    /* Make the CONST have a shared SV */
	    svp = cSVOPx_svp(((BINOP*)o)->op_last);
	    if (!SvFAKE(sv = *svp) || !SvREADONLY(sv)) {
		key = SvPV_const(sv, keylen);
		lexname = newSVpvn_share(key, (I32)keylen, 0);
		SvREFCNT_dec(sv);
		*svp = lexname;
	    }

	    if ((o->op_private & (OPpLVAL_INTRO)))
		break;

	    rop = (UNOP*)((BINOP*)o)->op_first;
	    if (rop->op_type != OP_RV2HV || rop->op_first->op_type != OP_PADSV)
		break;
	    lexname = *av_fetch(PL_comppad_name, rop->op_first->op_targ, TRUE);
            break;
        }

	case OP_HSLICE: {
	    UNOP *rop;
	    SV *lexname;

	    if ((o->op_private & (OPpLVAL_INTRO))
		/* I bet there's always a pushmark... */
		|| ((LISTOP*)o)->op_first->op_sibling->op_type != OP_LIST)
		/* hmmm, no optimization if list contains only one key. */
		break;
	    rop = (UNOP*)((LISTOP*)o)->op_last;
	    if (rop->op_type != OP_RV2HV)
		break;
	    if (rop->op_first->op_type == OP_PADSV)
		/* @$hash{qw(keys here)} */
		rop = (UNOP*)rop->op_first;
	    else {
		/* @{$hash}{qw(keys here)} */
		if (rop->op_first->op_type == OP_SCOPE 
		    && cLISTOPx(rop->op_first)->op_last->op_type == OP_PADSV)
		{
		    rop = (UNOP*)cLISTOPx(rop->op_first)->op_last;
		}
		else
		    break;
	    }
		    
	    lexname = *av_fetch(PL_comppad_name, rop->op_targ, TRUE);
	    break;
	}

	case OP_SORT: {
	    /* check that RHS of sort is a single plain array */
	    OP *oright = cUNOPo->op_first;
	    if (!oright || oright->op_type != OP_PUSHMARK)
		break;

	    /* reverse sort ... can be optimised.  */
	    if (!cUNOPo->op_sibling) {
		/* Nothing follows us on the list. */
		OP * const reverse = o->op_next;

		if (reverse->op_type == OP_REVERSE &&
		    (reverse->op_flags & OPf_WANT) == OPf_WANT_LIST) {
		    OP * const pushmark = cUNOPx(reverse)->op_first;
		    if (pushmark && (pushmark->op_type == OP_PUSHMARK)
			&& (cUNOPx(pushmark)->op_sibling == o)) {
			/* reverse -> pushmark -> sort */
			o->op_private |= OPpSORT_REVERSE;
			op_null(reverse);
			pushmark->op_next = oright->op_next;
			op_null(oright);
		    }
		}
	    }

	    break;
	}

	case OP_REVERSE: {
	    OP *ourmark, *theirmark, *ourlast, *iter, *expushmark, *rv2av;
	    OP *gvop = NULL;
	    LISTOP *enter, *exlist;

	    enter = (LISTOP *) o->op_next;
	    if (!enter)
		break;
	    if (enter->op_type == OP_NULL) {
		enter = (LISTOP *) enter->op_next;
		if (!enter)
		    break;
	    }
	    /* for $a (...) will have OP_GV then OP_RV2GV here.
	       for (...) just has an OP_GV.  */
	    if (enter->op_type == OP_GV) {
		gvop = (OP *) enter;
		enter = (LISTOP *) enter->op_next;
		if (!enter)
		    break;
		if (enter->op_type == OP_RV2GV) {
		  enter = (LISTOP *) enter->op_next;
		  if (!enter)
		    break;
		}
	    }

	    if (enter->op_type != OP_ENTERITER)
		break;

	    iter = enter->op_next;
	    if (!iter || iter->op_type != OP_ITER)
		break;
	    
	    expushmark = enter->op_first;
	    if (!expushmark || expushmark->op_type != OP_NULL
		|| expushmark->op_targ != OP_PUSHMARK)
		break;

	    exlist = (LISTOP *) expushmark->op_sibling;
	    if (!exlist || exlist->op_type != OP_NULL
		|| exlist->op_targ != OP_LIST)
		break;

	    if (exlist->op_last != o) {
		/* Mmm. Was expecting to point back to this op.  */
		break;
	    }
	    theirmark = exlist->op_first;
	    if (!theirmark || theirmark->op_type != OP_PUSHMARK)
		break;

	    if (theirmark->op_sibling != o) {
		/* There's something between the mark and the reverse, eg
		   for (1, reverse (...))
		   so no go.  */
		break;
	    }

	    ourmark = ((LISTOP *)o)->op_first;
	    if (!ourmark || ourmark->op_type != OP_PUSHMARK)
		break;

	    ourlast = ((LISTOP *)o)->op_last;
	    if (!ourlast || ourlast->op_next != o)
		break;

	    rv2av = ourmark->op_sibling;
	    if (rv2av && rv2av->op_type == OP_RV2AV && rv2av->op_sibling == 0
		&& rv2av->op_flags == (OPf_WANT_LIST | OPf_KIDS)
		&& enter->op_flags == (OPf_WANT_LIST | OPf_KIDS)) {
		/* We're just reversing a single array.  */
		rv2av->op_flags = OPf_WANT_SCALAR | OPf_KIDS | OPf_REF;
		enter->op_flags |= OPf_STACKED;
	    }

	    /* We don't have control over who points to theirmark, so sacrifice
	       ours.  */
	    theirmark->op_next = ourmark->op_next;
	    theirmark->op_flags = ourmark->op_flags;
	    ourlast->op_next = gvop ? gvop : (OP *) enter;
	    op_null(ourmark);
	    op_null(o);
	    enter->op_private |= OPpITER_REVERSED;
	    iter->op_private |= OPpITER_REVERSED;
	    
	    break;
	}

	case OP_QR:
	case OP_MATCH:
	    assert (!cPMOP->op_pmstashstartu.op_pmreplstart);
	    break;
	}
	oldop = o;
    }
    LEAVE_named("peep");
}

const char*
Perl_custom_op_name(pTHX_ const OP* o)
{
    dVAR;
    const IV index = PTR2IV(o->op_ppaddr);
    SV* keysv;
    HE* he;

    PERL_ARGS_ASSERT_CUSTOM_OP_NAME;

    if (!PL_custom_op_names) /* This probably shouldn't happen */
        return (char *)PL_op_name[OP_CUSTOM];

    keysv = sv_2mortal(newSViv(index));

    he = hv_fetch_ent(PL_custom_op_names, keysv, 0, 0);
    if (!he)
        return (char *)PL_op_name[OP_CUSTOM]; /* Don't know who you are */

    return SvPV_nolen(HeVAL(he));
}

const char*
Perl_custom_op_desc(pTHX_ const OP* o)
{
    dVAR;
    const IV index = PTR2IV(o->op_ppaddr);
    SV* keysv;
    HE* he;

    PERL_ARGS_ASSERT_CUSTOM_OP_DESC;

    if (!PL_custom_op_descs)
        return (char *)PL_op_desc[OP_CUSTOM];

    keysv = sv_2mortal(newSViv(index));

    he = hv_fetch_ent(PL_custom_op_descs, keysv, 0, 0);
    if (!he)
        return (char *)PL_op_desc[OP_CUSTOM];

    return SvPV_nolen(HeVAL(he));
}

#include "XSUB.h"

/* Efficient sub that returns a constant scalar value. */
static void
const_sv_xsub(pTHX_ CV* cv)
{
    dVAR;
    dXSARGS;
    if (items != 0) {
	NOOP;
    }
    EXTEND(sp, 1);
    ST(0) = MUTABLE_SV(XSANY.any_ptr);
    XSRETURN(1);
}

void
Perl_rootop_ll_tmprefcnt(pTHX) {
    ROOTOP* rootop;
    rootop = PL_rootop_ll;
    while (rootop) {
	op_tmprefcnt((OP*)rootop);
	rootop = rootop->op_next_root;
    }
}

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: f
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
