/*    sv.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000,
 *    2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009 by Larry Wall
 *    and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * 'I wonder what the Entish is for "yes" and "no",' he thought.
 *                                                      --Pippin
 *
 *     [p.480 of _The Lord of the Rings_, III/iv: "Treebeard"]
 */

/*
 *
 *
 * This file contains the code that creates, manipulates and destroys
 * scalar values (SVs). The other types (AV, HV, GV, etc.) reuse the
 * structure of an SV, so their creation and destruction is handled
 * here; higher-level functions are in av.c, hv.c, and so on. Opcode
 * level functions (eg. substr, split, join) for each of the types are
 * in the pp*.c files.
 */

#include "EXTERN.h"
#define PERL_IN_SV_C
#include "perl.h"
#include "regcomp.h"

#define FCALL *f

#ifdef __Lynx__
/* Missing proto on LynxOS */
  char *gconvert(double, int, int,  char *);
#endif

#ifdef PERL_UTF8_CACHE_ASSERT
/* if adding more checks watch out for the following tests:
 *   t/op/index.t t/op/length.t t/op/pat.t t/op/substr.t
 *   lib/utf8.t lib/Unicode/Collate/t/index.t
 * --jhi
 */
#   define ASSERT_UTF8_CACHE(cache) \
    STMT_START { if (cache) { assert((cache)[0] <= (cache)[1]); \
			      assert((cache)[2] <= (cache)[3]); \
			      assert((cache)[3] <= (cache)[1]);} \
			      } STMT_END
#else
#   define ASSERT_UTF8_CACHE(cache) NOOP
#endif

#ifdef PERL_OLD_COPY_ON_WRITE
#define SV_COW_NEXT_SV(sv)	INT2PTR(SV *,SvUVX(sv))
#define SV_COW_NEXT_SV_SET(current,next)	SvUV_set(current, PTR2UV(next))
/* This is a pessimistic view. Scalar must be purely a read-write PV to copy-
   on-write.  */
#endif

/* ============================================================================

=head1 Allocation and deallocation of SVs.

An SV (or AV, HV, etc.) is allocated in two parts: the head (struct
sv, av, hv...) contains type and reference count information, and for
many types, a pointer to the body (struct xrv, xpv, xpviv...), which
contains fields specific to each type.  Some types store all they need
in the head, so don't have a body.

In all but the most memory-paranoid configuations (ex: PURIFY), heads
and bodies are allocated out of arenas, which by default are
approximately 4K chunks of memory parcelled up into N heads or bodies.
Sv-bodies are allocated by their sv-type, guaranteeing size
consistency needed to allocate safely from arrays.

For SV-heads, the first slot in each arena is reserved, and holds a
link to the next arena, some flags, and a note of the number of slots.
Snaked through each arena chain is a linked list of free items; when
this becomes empty, an extra arena is allocated and divided up into N
items which are threaded into the free list.

SV-bodies are similar, but they use arena-sets by default, which
separate the link and info from the arena itself, and reclaim the 1st
slot in the arena.  SV-bodies are further described later.

The following global variables are associated with arenas:

    PL_sv_arenaroot	pointer to list of SV arenas
    PL_sv_root		pointer to list of free SV structures

    PL_body_arenas	head of linked-list of body arenas
    PL_body_roots[]	array of pointers to list of free bodies of svtype
			arrays are indexed by the svtype needed

A few special SV heads are not allocated from an arena, but are
instead directly created in the interpreter structure, eg PL_sv_undef.
The size of arenas can be changed from the default by setting
PERL_ARENA_SIZE appropriately at compile time.

The SV arena serves the secondary purpose of allowing still-live SVs
to be located and destroyed during final cleanup.

At the lowest level, the macros new_SV() and del_SV() grab and free
an SV head.  (If debugging with -DD, del_SV() calls the function S_del_sv()
to return the SV to the free list with error checking.) new_SV() calls
more_sv() / sv_add_arena() to add an extra arena if the free list is empty.
SVs in the free list have their SvTYPE field set to all ones.

At the time of very final cleanup, sv_free_arenas() is called from
perl_destruct() to physically free all the arenas allocated since the
start of the interpreter.

The function visit() scans the SV arenas list, and calls a specified
function for each SV it finds which is still live - ie which has an SvTYPE
other than all 1's, and a non-zero SvREFCNT. visit() is used by the
following functions (specified as [function that calls visit()] / [function
called by visit() for each SV]):

    sv_report_used() / do_report_used()
			dump all remaining SVs (debugging aid)

=head2 Arena allocator API Summary

Private API to rest of sv.c

    new_SV(),  del_SV(),

    new_XIV(), del_XIV(),
    new_XNV(), del_XNV(),
    etc

Public API:

    sv_report_used(), sv_free_arenas()

=cut

 * ========================================================================= */

/*
 * "A time to plant, and a time to uproot what was planted..."
 */

void
Perl_offer_nice_chunk(pTHX_ void *const chunk, const U32 chunk_size)
{
    dVAR;
    void *new_chunk;
    U32 new_chunk_size;

    PERL_ARGS_ASSERT_OFFER_NICE_CHUNK;

    VALGRIND_MAKE_MEM_UNDEFINED(chunk, chunk_size);

    new_chunk = (void *)(chunk);
    new_chunk_size = (chunk_size);
    if (new_chunk_size > PL_nice_chunk_size) {
	Safefree(PL_nice_chunk);
	PL_nice_chunk = (char *) new_chunk;
	PL_nice_chunk_size = new_chunk_size;
    } else {
	Safefree(chunk);
    }
}

#ifdef DEBUG_LEAKING_SCALARS
#  define DEBUG_SV_SERIAL(sv)						    \
    DEBUG_m(PerlIO_printf(Perl_debug_log, "0x%"UVxf": (%05ld) del_SV\n",    \
	    PTR2UV(sv), (long)(sv)->sv_debug_serial))
#else
#  define DEBUG_SV_SERIAL(sv)	NOOP
#endif

#ifdef PERL_POISON
#  define SvARENA_CHAIN(sv)	((sv)->sv_u.svu_rv)
#  define SvARENA_CHAIN_SET(sv,val)	(sv)->sv_u.svu_rv = MUTABLE_SV((val))
/* Whilst I'd love to do this, it seems that things like to check on
   unreferenced scalars
#  define POSION_SV_HEAD(sv)	PoisonNew(sv, 1, struct STRUCT_SV)
*/
#  define POSION_SV_HEAD(sv)	PoisonNew(&SvANY(sv), 1, void *), \
				PoisonNew(&SvREFCNT(sv), 1, U32)
#else
#  define SvARENA_CHAIN(sv)	SvANY(sv)
#  define SvARENA_CHAIN_SET(sv,val)	SvANY(sv) = (void *)(val)
#  define POSION_SV_HEAD(sv)
#endif

/* Mark an SV head as unused, and add to free list.
 *
 * If SVf_BREAK is set, skip adding it to the free list, as this SV had
 * its refcount artificially decremented during global destruction, so
 * there may be dangling pointers to it. The last thing we want in that
 * case is for it to be reused. */

#define plant_SV(p) \
    STMT_START {					\
	DEBUG_SV_SERIAL(p);				\
	POSION_SV_HEAD(p);				\
	SvARENA_CHAIN_SET(p, PL_sv_root);		\
	SvFLAGS(p) = SVTYPEMASK;			\
	VALGRIND_MAKE_MEM_UNDEFINED(p, sizeof(SV));     \
	VALGRIND_MAKE_MEM_DEFINED(&SvARENA_CHAIN(p), sizeof(void*));	\
	VALGRIND_MAKE_MEM_NOACCESS(&SvARENA_CHAIN(p), sizeof(void*));	\
	VALGRIND_MAKE_MEM_DEFINED(&SvFLAGS(p), sizeof(U32));	\
	VALGRIND_MAKE_MEM_DEFINED(&SvREFCNT(p), sizeof(U32));	\
	PL_sv_root = (p);					\
	--PL_sv_count;					\
    } STMT_END

#define uproot_SV(p) \
    STMT_START {					\
	(p) = PL_sv_root;				\
	VALGRIND_MAKE_MEM_DEFINED(&SvARENA_CHAIN(p), sizeof(void*));	\
	PL_sv_root = (SV*)SvARENA_CHAIN(p);		\
	VALGRIND_MAKE_MEM_NOACCESS(&SvARENA_CHAIN(p), sizeof(void*));	\
	++PL_sv_count;					\
    } STMT_END


/* make some more SVs by adding another arena */

STATIC SV*
S_more_sv(pTHX)
{
    dVAR;
    SV* sv;

    if (PL_nice_chunk) {
	sv_add_arena(PL_nice_chunk, PL_nice_chunk_size, 0);
	PL_nice_chunk = NULL;
        PL_nice_chunk_size = 0;
    }
    else {
	char *chunk;                /* must use New here to match call to */
	Newx(chunk,PERL_ARENA_SIZE,char);  /* Safefree() in sv_free_arenas() */
	sv_add_arena(chunk, PERL_ARENA_SIZE, 0);
    }
    uproot_SV(sv);
    return sv;
}

/* new_SV(): return a new, empty SV head */

/* provide a real function for a debugger to play with */
STATIC SV*
S_new_SV(pTHX)
{
    SV* sv;

    if (PL_sv_root)
	uproot_SV(sv);
    else
	sv = S_more_sv(aTHX);
    VALGRIND_MAKE_MEM_UNDEFINED(sv, sizeof(SV));
    SvANY(sv) = 0;
    SvREFCNT(sv) = 1;
    SvFLAGS(sv) = 0;
    SvLOCATION(sv) = NULL;
#ifdef DEBUG_LEAKING_SCALARS
    sv->sv_debug_optype = PL_op ? PL_op->op_type : 0;
    sv->sv_debug_line = (U16) (PL_parser ? PL_parser->lex_line_number : 0 );
    sv->sv_debug_inpad = 0;
    sv->sv_debug_cloned = 0;
    sv->sv_debug_file = (PL_parser && PL_parser->lex_filename) ? SvPVX_const(PL_parser->lex_filename) : NULL ;
    
    sv->sv_debug_serial = PL_sv_serial++;

#endif /* DEBUG_LEAKING_SCALARS */

    return sv;
}
#  define new_SV(p) (p)=S_new_SV(aTHX)


/* del_SV(): return an empty SV head to the free list */

#ifdef DEBUGGING

#define del_SV(p) \
    STMT_START {					\
	if (DEBUG_D_TEST)				\
	    del_sv(p);					\
	else						\
	    plant_SV(p);				\
    } STMT_END

STATIC void
S_del_sv(pTHX_ SV *p)
{
    dVAR;

    PERL_ARGS_ASSERT_DEL_SV;

    if (DEBUG_D_TEST) {
	SV* sva;
	bool ok = 0;
	for (sva = PL_sv_arenaroot; sva; sva = MUTABLE_SV(SvANY(sva))) {
	    const SV * const sv = sva + 1;
	    const SV * const svend = &sva[SvREFCNT(sva)];
	    if (p >= sv && p < svend) {
		ok = 1;
		break;
	    }
	}
	if (!ok) {
	    if (ckWARN_d(WARN_INTERNAL))	
	        Perl_warner(aTHX_ packWARN(WARN_INTERNAL),
			    "Attempt to free non-arena SV: 0x%"UVxf
                            pTHX__FORMAT, PTR2UV(p) pTHX__VALUE);
	    return;
	}
    }
    plant_SV(p);
}

#else /* ! DEBUGGING */

#define del_SV(p)   plant_SV(p)

#endif /* DEBUGGING */


/*
=head1 SV Manipulation Functions

=for apidoc sv_add_arena

Given a chunk of memory, link it to the head of the list of arenas,
and split it into a list of free SVs.

=cut
*/

static void
S_sv_add_arena(pTHX_ char *const ptr, const U32 size, const U32 flags)
{
    dVAR;
    SV *const sva = MUTABLE_SV(ptr);
    register SV* sv;
    register SV* svend;

    PERL_ARGS_ASSERT_SV_ADD_ARENA;

    /* The first SV in an arena isn't an SV. */
    SvANY(sva) = (void *) PL_sv_arenaroot;		/* ptr to next arena */
    SvREFCNT(sva) = size / sizeof(SV);		/* number of SV slots */
    SvFLAGS(sva) = flags;			/* FAKE if not to be freed */

    PL_sv_arenaroot = sva;
    PL_sv_root = sva + 1;

    svend = &sva[SvREFCNT(sva) - 1];
    sv = sva + 1;
    while (sv < svend) {
	SvARENA_CHAIN_SET(sv, (sv + 1));
#ifdef DEBUGGING
	SvREFCNT(sv) = 0;
#endif
	/* Must always set typemask because it's always checked in on cleanup
	   when the arenas are walked looking for objects.  */
	SvFLAGS(sv) = SVTYPEMASK;
	sv++;
    }
    SvARENA_CHAIN_SET(sv, 0);
#ifdef DEBUGGING
    SvREFCNT(sv) = 0;
#endif
    SvFLAGS(sv) = SVTYPEMASK;
}

/* visit(): call the named function for each non-free SV in the arenas
 * whose flags field matches the flags/mask args. */

STATIC I32
S_visit(pTHX_ SVFUNC_t f, const U32 flags, const U32 mask)
{
    dVAR;
    SV* sva;
    I32 visited = 0;

    PERL_ARGS_ASSERT_VISIT;

    for (sva = PL_sv_arenaroot; sva; sva = MUTABLE_SV(SvANY(sva))) {
	register const SV * const svend = &sva[SvREFCNT(sva)];
	register SV* sv;
	for (sv = sva + 1; sv < svend; ++sv) {
	    if (SvTYPE(sv) != SVTYPEMASK
		    && (sv->sv_flags & mask) == flags
		    && SvREFCNT(sv))
	    {
		(FCALL)(aTHX_ sv);
		++visited;
	    }
	}
    }
    return visited;
}

#ifdef DEBUGGING

/* called by sv_report_used() for each live SV */

static void
do_report_used(pTHX_ SV *const sv)
{
    if (SvTYPE(sv) != SVTYPEMASK) {
	PerlIO_printf(Perl_debug_log, "****\n");
	sv_dump(sv);
    }
}
#endif

/*
=for apidoc sv_report_used

Dump the contents of all SVs not yet freed. (Debugging aid).

=cut
*/

void
Perl_sv_report_used(pTHX)
{
#ifdef DEBUGGING
    visit(do_report_used, 0, 0);
#else
    PERL_UNUSED_CONTEXT;
#endif
}

/*
  ARENASETS: a meta-arena implementation which separates arena-info
  into struct arena_set, which contains an array of struct
  arena_descs, each holding info for a single arena.  By separating
  the meta-info from the arena, we recover the 1st slot, formerly
  borrowed for list management.  The arena_set is about the size of an
  arena, avoiding the needless malloc overhead of a naive linked-list.

  The cost is 1 arena-set malloc per ~320 arena-mallocs, + the unused
  memory in the last arena-set (1/2 on average).  In trade, we get
  back the 1st slot in each arena (ie 1.7% of a CV-arena, less for
  smaller types).  The recovery of the wasted space allows use of
  small arenas for large, rare body types, by changing array* fields
  in body_details_by_type[] below.
*/
struct arena_desc {
    char       *arena;		/* the raw storage, allocated aligned */
    size_t      size;		/* its size ~4k typ */
    U32		misc;		/* type, and in future other things. */
};

struct arena_set;

/* Get the maximum number of elements in set[] such that struct arena_set
   will fit within PERL_ARENA_SIZE, which is probably just under 4K, and
   therefore likely to be 1 aligned memory page.  */

#define ARENAS_PER_SET  ((PERL_ARENA_SIZE - sizeof(struct arena_set*) \
			  - 2 * sizeof(int)) / sizeof (struct arena_desc))

struct arena_set {
    struct arena_set* next;
    unsigned int   set_size;	/* ie ARENAS_PER_SET */
    unsigned int   curr;	/* index of next available arena-desc */
    struct arena_desc set[ARENAS_PER_SET];
};

/*
=for apidoc sv_free_arenas

Deallocate the memory used by all arenas. Note that all the individual SV
heads and bodies within the arenas must already have been freed.

=cut
*/
void
Perl_sv_free_arenas(pTHX)
{
    dVAR;
    SV* sva;
    SV* svanext;
    unsigned int i;

    /* Free arenas here, but be careful about fake ones.  (We assume
       contiguity of the fake ones with the corresponding real ones.) */

    for (sva = PL_sv_arenaroot; sva; sva = svanext) {
	svanext = MUTABLE_SV(SvANY(sva));
	while (svanext && SvFAKE(svanext))
	    svanext = MUTABLE_SV(SvANY(svanext));

	if (!SvFAKE(sva)) {
	    Safefree(sva);
	}
    }

    {
	struct arena_set *aroot = (struct arena_set*) PL_body_arenas;

	while (aroot) {
	    struct arena_set *current = aroot;
	    i = aroot->curr;
	    while (i--) {
		assert(aroot->set[i].arena);
		Safefree(aroot->set[i].arena);
	    }
	    aroot = aroot->next;
	    Safefree(current);
	}
    }
    PL_body_arenas = 0;

    i = PERL_ARENA_ROOTS_SIZE;
    while (i--)
	PL_body_roots[i] = 0;

    Safefree(PL_nice_chunk);
    PL_nice_chunk = NULL;
    PL_nice_chunk_size = 0;
    PL_sv_arenaroot = 0;
    PL_sv_root = 0;
}

/*
  Here are mid-level routines that manage the allocation of bodies out
  of the various arenas.  There are 5 kinds of arenas:

  1. SV-head arenas, which are discussed and handled above
  2. regular body arenas
  3. arenas for reduced-size bodies
  4. Hash-Entry arenas
  5. pte arenas (thread related)

  Arena types 2 & 3 are chained by body-type off an array of
  arena-root pointers, which is indexed by svtype.  Some of the
  larger/less used body types are malloced singly, since a large
  unused block of them is wasteful.  Also, several svtypes dont have
  bodies; the data fits into the sv-head itself.  The arena-root
  pointer thus has a few unused root-pointers (which may be hijacked
  later for arena types 4,5)

  3 differs from 2 as an optimization; some body types have several
  unused fields in the front of the structure (which are kept in-place
  for consistency).  These bodies can be allocated in smaller chunks,
  because the leading fields arent accessed.  Pointers to such bodies
  are decremented to point at the unused 'ghost' memory, knowing that
  the pointers are used with offsets to the real memory.

  HE, HEK arenas are managed separately, with separate code, but may
  be merge-able later..

  PTE arenas are not sv-bodies, but they share these mid-level
  mechanics, so are considered here.  The new mid-level mechanics rely
  on the sv_type of the body being allocated, so we just reserve one
  of the unused body-slots for PTEs, then use it in those (2) PTE
  contexts below (line ~10k)
*/

/* get_arena(size): this creates custom-sized arenas
   TBD: export properly for hv.c: S_more_he().
*/
void*
Perl_get_arena(pTHX_ const size_t arena_size, const U32 misc)
{
    dVAR;
    struct arena_desc* adesc;
    struct arena_set *aroot = (struct arena_set*) PL_body_arenas;
    unsigned int curr;

    /* shouldnt need this
    if (!arena_size)	arena_size = PERL_ARENA_SIZE;
    */

    /* may need new arena-set to hold new arena */
    if (!aroot || aroot->curr >= aroot->set_size) {
	struct arena_set *newroot;
	Newxz(newroot, 1, struct arena_set);
	newroot->set_size = ARENAS_PER_SET;
	newroot->next = aroot;
	aroot = newroot;
	PL_body_arenas = (void *) newroot;
	DEBUG_m(PerlIO_printf(Perl_debug_log, "new arenaset %p\n", (void*)aroot));
    }

    /* ok, now have arena-set with at least 1 empty/available arena-desc */
    curr = aroot->curr++;
    adesc = &(aroot->set[curr]);
    assert(!adesc->arena);
    
    Newx(adesc->arena, arena_size, char);
    adesc->size = arena_size;
    adesc->misc = misc;
    DEBUG_m(PerlIO_printf(Perl_debug_log, "arena %d added: %p size %"UVuf"\n", 
			  curr, (void*)adesc->arena, (UV)arena_size));

    return adesc->arena;
}


/* return a thing to the free list */

#define del_body(thing, root)			\
    STMT_START {				\
	void ** const thing_copy = (void **)thing;\
	*thing_copy = *root;			\
	*root = (void*)thing_copy;		\
    } STMT_END

/* 

=head1 SV-Body Allocation

Allocation of SV-bodies is similar to SV-heads, differing as follows;
the allocation mechanism is used for many body types, so is somewhat
more complicated, it uses arena-sets, and has no need for still-live
SV detection.

At the outermost level, (new|del)_X*V macros return bodies of the
appropriate type.  These macros call either (new|del)_body_type or
(new|del)_body_allocated macro pairs, depending on specifics of the
type.  Most body types use the former pair, the latter pair is used to
allocate body types with "ghost fields".

"ghost fields" are fields that are unused in certain types, and
consequently don't need to actually exist.  They are declared because
they're part of a "base type", which allows use of functions as
methods.  The simplest examples are AVs and HVs, 2 aggregate types
which don't use the fields which support SCALAR semantics.

For these types, the arenas are carved up into appropriately sized
chunks, we thus avoid wasted memory for those unaccessed members.
When bodies are allocated, we adjust the pointer back in memory by the
size of the part not allocated, so it's as if we allocated the full
structure.  (But things will all go boom if you write to the part that
is "not there", because you'll be overwriting the last members of the
preceding structure in memory.)

We calculate the correction using the STRUCT_OFFSET macro on the first
member present. If the allocated structure is smaller (no initial NV
actually allocated) then the net effect is to subtract the size of the NV
from the pointer, to return a new pointer as if an initial NV were actually
allocated. (We were using structures named *_allocated for this, but
this turned out to be a subtle bug, because a structure without an NV
could have a lower alignment constraint, but the compiler is allowed to
optimised accesses based on the alignment constraint of the actual pointer
to the full structure, for example, using a single 64 bit load instruction
because it "knows" that two adjacent 32 bit members will be 8-byte aligned.)

This is the same trick as was used for NV and IV bodies. Ironically it
doesn't need to be used for NV bodies any more, because NV is now at
the start of the structure. IV bodies don't need it either, because
they are no longer allocated.

In turn, the new_body_* allocators call S_new_body(), which invokes
new_body_inline macro, which takes a lock, and takes a body off the
linked list at PL_body_roots[sv_type], calling S_more_bodies() if
necessary to refresh an empty list.  Then the lock is released, and
the body is returned.

S_more_bodies calls get_arena(), and carves it up into an array of N
bodies, which it strings into a linked list.  It looks up arena-size
and body-size from the body_details table described below, thus
supporting the multiple body-types.

If PURIFY is defined, or PERL_ARENA_SIZE=0, arenas are not used, and
the (new|del)_X*V macros are mapped directly to malloc/free.

*/

/* 

For each sv-type, struct body_details bodies_by_type[] carries
parameters which control these aspects of SV handling:

Arena_size determines whether arenas are used for this body type, and if
so, how big they are.  PURIFY or PERL_ARENA_SIZE=0 set this field to
zero, forcing individual mallocs and frees.

Body_size determines how big a body is, and therefore how many fit into
each arena.  Offset carries the body-pointer adjustment needed for
"ghost fields", and is used in *_allocated macros.

But its main purpose is to parameterize info needed in
Perl_sv_upgrade().  The info here dramatically simplifies the function
vs the implementation in 5.8.8, making it table-driven.  All fields
are used for this, except for arena_size.

For the sv-types that have no bodies, arenas are not used, so those
PL_body_roots[sv_type] are unused, and can be overloaded.  In
something of a special case, SVt_NULL is borrowed for HE arenas;
PL_body_roots[HE_SVSLOT=SVt_NULL] is filled by S_more_he, but the
bodies_by_type[SVt_NULL] slot is not used, as the table is not
available in hv.c.

PTEs also use arenas, but are never seen in Perl_sv_upgrade. Nonetheless,
they get their own slot in bodies_by_type[PTE_SVSLOT =SVt_IV], so they can
just use the same allocation semantics.  At first, PTEs were also
overloaded to a non-body sv-type, but this yielded hard-to-find malloc
bugs, so was simplified by claiming a new slot.  This choice has no
consequence at this time.

*/

struct body_details {
    U8 body_size;	/* Size to allocate  */
    U8 copy;		/* Size of structure to copy (may be shorter)  */
    U8 offset;
    unsigned int type : 4;	    /* We have space for a sanity check.  */
    unsigned int cant_upgrade : 1;  /* Cannot upgrade this type */
    unsigned int zero_nv : 1;	    /* zero the NV when upgrading from this */
    unsigned int arena : 1;	    /* Allocated from an arena */
    size_t arena_size;		    /* Size of arena to allocate */
};

#define HADNV FALSE
#define NONV TRUE


#ifdef PURIFY
/* With -DPURFIY we allocate everything directly, and don't use arenas.
   This seems a rather elegant way to simplify some of the code below.  */
#define HASARENA FALSE
#else
#define HASARENA TRUE
#endif
#define NOARENA FALSE

/* Size the arenas to exactly fit a given number of bodies.  A count
   of 0 fits the max number bodies into a PERL_ARENA_SIZE.block,
   simplifying the default.  If count > 0, the arena is sized to fit
   only that many bodies, allowing arenas to be used for large, rare
   bodies (XPVIO) without undue waste.  The arena size is
   limited by PERL_ARENA_SIZE, so we can safely oversize the
   declarations.
 */
#define FIT_ARENA0(body_size)				\
    ((size_t)(PERL_ARENA_SIZE / body_size) * body_size)
#define FIT_ARENAn(count,body_size)			\
    ( count * body_size <= PERL_ARENA_SIZE)		\
    ? count * body_size					\
    : FIT_ARENA0 (body_size)
#define FIT_ARENA(count,body_size)			\
    count 						\
    ? FIT_ARENAn (count, body_size)			\
    : FIT_ARENA0 (body_size)

/* Calculate the length to copy. Specifically work out the length less any
   final padding the compiler needed to add.  See the comment in sv_upgrade
   for why copying the padding proved to be a bug.  */

#define copy_length(type, last_member) \
	STRUCT_OFFSET(type, last_member) \
	+ sizeof (((type*)SvANY((const SV *)0))->last_member)

static const struct body_details bodies_by_type[] = {
    { sizeof(HE), 0, 0, SVt_NULL,
      FALSE, NONV, NOARENA, FIT_ARENA(0, sizeof(HE)) },

    /* The bind placeholder pretends to be an RV for now.
       Also it's marked as "can't upgrade" to stop anyone using it before it's
       implemented.  */
    { 0, 0, 0, SVt_BIND, TRUE, NONV, NOARENA, 0 },

    /* IVs are in the head, so the allocation size is 0.
       However, the slot is overloaded for PTEs.  */
    { sizeof(struct ptr_tbl_ent), /* This is used for PTEs.  */
      sizeof(IV), /* This is used to copy out the IV body.  */
      STRUCT_OFFSET(XPVIV, xiv_iv), SVt_IV, FALSE, NONV,
      NOARENA /* IVS don't need an arena  */,
      /* But PTEs need to know the size of their arena  */
      FIT_ARENA(0, sizeof(struct ptr_tbl_ent))
    },

    /* 8 bytes on most ILP32 with IEEE doubles */
    { sizeof(NV), sizeof(NV), 0, SVt_NV, FALSE, HADNV, HASARENA,
      FIT_ARENA(0, sizeof(NV)) },

    /* 8 bytes on most ILP32 with IEEE doubles */
    { sizeof(XPV) - STRUCT_OFFSET(XPV, xpv_cur),
      copy_length(XPV, xpv_len) - STRUCT_OFFSET(XPV, xpv_cur),
      + STRUCT_OFFSET(XPV, xpv_cur),
      SVt_PV, FALSE, NONV, HASARENA,
      FIT_ARENA(0, sizeof(XPV) - STRUCT_OFFSET(XPV, xpv_cur)) },

    /* 12 */
    { sizeof(XPVIV) - STRUCT_OFFSET(XPV, xpv_cur),
      copy_length(XPVIV, xiv_u) - STRUCT_OFFSET(XPV, xpv_cur),
      + STRUCT_OFFSET(XPVIV, xpv_cur),
      SVt_PVIV, FALSE, NONV, HASARENA,
      FIT_ARENA(0, sizeof(XPV) - STRUCT_OFFSET(XPV, xpv_cur)) },

    /* 20 */
    { sizeof(XPVNV), copy_length(XPVNV, xiv_u), 0, SVt_PVNV, FALSE, HADNV,
      HASARENA, FIT_ARENA(0, sizeof(XPVNV)) },

    /* 28 */
    { sizeof(XPVMG), copy_length(XPVMG, xmg_stash), 0, SVt_PVMG, FALSE, HADNV,
      HASARENA, FIT_ARENA(0, sizeof(XPVMG)) },

    /* something big */
    { sizeof(regexp) - STRUCT_OFFSET(regexp, xpv_cur),
      sizeof(regexp) - STRUCT_OFFSET(regexp, xpv_cur),
      + STRUCT_OFFSET(regexp, xpv_cur),
      SVt_REGEXP, FALSE, NONV, HASARENA,
      FIT_ARENA(0, sizeof(regexp) - STRUCT_OFFSET(regexp, xpv_cur))
    },

    /* 48 */
    { sizeof(XPVGV), sizeof(XPVGV), 0, SVt_PVGV, TRUE, HADNV,
      HASARENA, FIT_ARENA(0, sizeof(XPVGV)) },
    
    /* 64 */
    { sizeof(XPVAV) - STRUCT_OFFSET(XPVAV, xav_fill),
      copy_length(XPVAV, xmg_stash) - STRUCT_OFFSET(XPVAV, xav_fill),
      + STRUCT_OFFSET(XPVAV, xav_fill),
      SVt_PVAV, TRUE, NONV, HASARENA,
      FIT_ARENA(0, sizeof(XPVAV) - STRUCT_OFFSET(XPVAV, xav_fill)) },

    { sizeof(XPVHV) - STRUCT_OFFSET(XPVHV, xhv_fill),
      copy_length(XPVHV, xmg_stash) - STRUCT_OFFSET(XPVHV, xhv_fill),
      + STRUCT_OFFSET(XPVHV, xhv_fill),
      SVt_PVHV, TRUE, NONV, HASARENA,
      FIT_ARENA(0, sizeof(XPVHV) - STRUCT_OFFSET(XPVHV, xhv_fill)) },

    /* 56 */
    { sizeof(XPVCV) - STRUCT_OFFSET(XPVCV, xpv_cur),
      sizeof(XPVCV) - STRUCT_OFFSET(XPVCV, xpv_cur),
      + STRUCT_OFFSET(XPVCV, xpv_cur),
      SVt_PVCV, TRUE, NONV, HASARENA,
      FIT_ARENA(0, sizeof(XPVCV) - STRUCT_OFFSET(XPVCV, xpv_cur)) },

    /* XPVIO is 84 bytes, fits 48x */
    { sizeof(XPVIO) - STRUCT_OFFSET(XPVIO, xpv_cur),
      sizeof(XPVIO) - STRUCT_OFFSET(XPVIO, xpv_cur),
      + STRUCT_OFFSET(XPVIO, xpv_cur),
      SVt_PVIO, TRUE, NONV, HASARENA,
      FIT_ARENA(24, sizeof(XPVIO) - STRUCT_OFFSET(XPVIO, xpv_cur)) },
};

#define new_body_type(sv_type)		\
    (void *)((char *)S_new_body(aTHX_ sv_type))

#define del_body_type(p, sv_type)	\
    del_body(p, &PL_body_roots[sv_type])


#define new_body_allocated(sv_type)		\
    (void *)((char *)S_new_body(aTHX_ sv_type)	\
	     - bodies_by_type[sv_type].offset)

void Perl_del_body_allocated(pTHX_ void* p, svtype sv_type) {
    PERL_ARGS_ASSERT_DEL_BODY_ALLOCATED;
    del_body((void*)((char *)p + bodies_by_type[sv_type].offset), &PL_body_roots[sv_type]);
}

#define my_safemalloc(s)	(void*)safemalloc(s)
#define my_safecalloc(s)	(void*)safecalloc(s, 1)
#define my_safefree(p)	safefree((char*)p)

#ifdef PURIFY

#define new_XNV()	my_safemalloc(sizeof(XPVNV))
#define del_XNV(p)	my_safefree(p)

#define new_XPVNV()	my_safemalloc(sizeof(XPVNV))
#define del_XPVNV(p)	my_safefree(p)

#define new_XPVAV()	my_safemalloc(sizeof(XPVAV))
#define del_XPVAV(p)	my_safefree(p)

#define new_XPVHV()	my_safemalloc(sizeof(XPVHV))
#define del_XPVHV(p)	my_safefree(p)

#define new_XPVMG()	my_safemalloc(sizeof(XPVMG))
#define del_XPVMG(p)	my_safefree(p)

#define new_XPVGV()	my_safemalloc(sizeof(XPVGV))
#define del_XPVGV(p)	my_safefree(p)

#else /* !PURIFY */

#define new_XNV()	new_body_type(SVt_NV)
#define del_XNV(p)	del_body_type(p, SVt_NV)

#define new_XPVNV()	new_body_type(SVt_PVNV)
#define del_XPVNV(p)	del_body_type(p, SVt_PVNV)

#define new_XPVAV()	new_body_allocated(SVt_PVAV)
#define del_XPVAV(p)	del_body_allocated(p, SVt_PVAV)

#define new_XPVHV()	new_body_allocated(SVt_PVHV)
#define del_XPVHV(p)	del_body_allocated(p, SVt_PVHV)

#define new_XPVMG()	new_body_type(SVt_PVMG)
#define del_XPVMG(p)	del_body_type(p, SVt_PVMG)

#define new_XPVGV()	new_body_type(SVt_PVGV)
#define del_XPVGV(p)	del_body_type(p, SVt_PVGV)

#endif /* PURIFY */

/* no arena for you! */

#define new_NOARENA(details) \
	my_safemalloc((details)->body_size + (details)->offset)
#define new_NOARENAZ(details) \
	my_safecalloc((details)->body_size + (details)->offset)

STATIC void *
S_more_bodies (pTHX_ const svtype sv_type)
{
    dVAR;
    void ** const root = &PL_body_roots[sv_type];
    const struct body_details * const bdp = &bodies_by_type[sv_type];
    const size_t body_size = bdp->body_size;
    char *start;
    const char *end;
    const size_t arena_size = Perl_malloc_good_size(bdp->arena_size);
#if defined(DEBUGGING) && !defined(PERL_GLOBAL_STRUCT_PRIVATE)
    static bool done_sanity_check;

    /* PERL_GLOBAL_STRUCT_PRIVATE cannot coexist with global
     * variables like done_sanity_check. */
    if (!done_sanity_check) {
	unsigned int i = SVt_LAST;

	done_sanity_check = TRUE;

	while (i--)
	    assert (bodies_by_type[i].type == i);
    }
#endif

    assert(bdp->arena_size);

    start = (char*) Perl_get_arena(aTHX_ arena_size, sv_type);

    end = start + arena_size - 2 * body_size;

    /* computed count doesnt reflect the 1st slot reservation */
#if defined(MYMALLOC) || defined(HAS_MALLOC_GOOD_SIZE)
    DEBUG_m(PerlIO_printf(Perl_debug_log,
			  "arena %p end %p arena-size %d (from %d) type %d "
			  "size %d ct %d\n",
			  (void*)start, (void*)end, (int)arena_size,
			  (int)bdp->arena_size, sv_type, (int)body_size,
			  (int)arena_size / (int)body_size));
#else
    DEBUG_m(PerlIO_printf(Perl_debug_log,
			  "arena %p end %p arena-size %d type %d size %d ct %d\n",
			  (void*)start, (void*)end,
			  (int)bdp->arena_size, sv_type, (int)body_size,
			  (int)bdp->arena_size / (int)body_size));
#endif
    *root = (void *)start;

    while (start <= end) {
	char * const next = start + body_size;
	*(void**) start = (void *)next;
	start = next;
    }
    *(void **)start = 0;

    return *root;
}

/* grab a new thing from the free list, allocating more if necessary.
   The inline version is used for speed in hot routines, and the
   function using it serves the rest (unless PURIFY).
*/
#define new_body_inline(xpv, sv_type) \
    STMT_START { \
	void ** const r3wt = &PL_body_roots[sv_type]; \
	xpv = (PTR_TBL_ENT_t*) (*((void **)(r3wt))      \
	  ? *((void **)(r3wt)) : more_bodies(sv_type)); \
	*(r3wt) = *(void**)(xpv); \
    } STMT_END

#ifndef PURIFY

STATIC void *
S_new_body(pTHX_ const svtype sv_type)
{
    dVAR;
    void *xpv;
    new_body_inline(xpv, sv_type);
    return xpv;
}

#endif

static const struct body_details fake_rv =
    { 0, 0, 0, SVt_IV, FALSE, NONV, NOARENA, 0 };

/*
=for apidoc sv_upgrade

Upgrade an SV to a more complex form.  Generally adds a new body type to the
SV, then copies across as much information as possible from the old body.
You generally want to use the C<SvUPGRADE> macro wrapper. See also C<svtype>.

=cut
*/

void
Perl_sv_upgrade(pTHX_ register SV *const sv, svtype new_type)
{
    dVAR;
    void*	old_body;
    void*	new_body;
    svtype old_type = SvTYPE(sv);
    const struct body_details *new_type_details;
    const struct body_details *old_type_details
	= bodies_by_type + old_type;
    SV *referant = NULL;

    PERL_ARGS_ASSERT_SV_UPGRADE;

    if (old_type == new_type)
	return;

    /* This clause was purposefully added ahead of the early return above to
       the shared string hackery for (sort {$a <=> $b} keys %hash), with the
       inference by Nick I-S that it would fix other troublesome cases. See
       changes 7162, 7163 (f130fd4589cf5fbb24149cd4db4137c8326f49c1 and parent)

       Given that shared hash key scalars are no longer PVIV, but PV, there is
       no longer need to unshare so as to free up the IVX slot for its proper
       purpose. So it's safe to move the early return earlier.  */

    if (new_type != SVt_PV && SvIsCOW(sv)) {
	sv_force_normal_flags(sv, 0);
    }

    old_body = SvANY(sv);

    /* Copying structures onto other structures that have been neatly zeroed
       has a subtle gotcha. Consider XPVMG

       +------+------+------+------+------+-------+-------+
       |     NV      | CUR  | LEN  |  IV  | MAGIC | STASH |
       +------+------+------+------+------+-------+-------+
       0      4      8     12     16     20      24      28

       where NVs are aligned to 8 bytes, so that sizeof that structure is
       actually 32 bytes long, with 4 bytes of padding at the end:

       +------+------+------+------+------+-------+-------+------+
       |     NV      | CUR  | LEN  |  IV  | MAGIC | STASH | ???  |
       +------+------+------+------+------+-------+-------+------+
       0      4      8     12     16     20      24      28     32

       so what happens if you allocate memory for this structure:

       +------+------+------+------+------+-------+-------+------+------+...
       |     NV      | CUR  | LEN  |  IV  | MAGIC | STASH |  GP  | NAME |
       +------+------+------+------+------+-------+-------+------+------+...
       0      4      8     12     16     20      24      28     32     36

       zero it, then copy sizeof(XPVMG) bytes on top of it? Not quite what you
       expect, because you copy the area marked ??? onto GP. Now, ??? may have
       started out as zero once, but it's quite possible that it isn't. So now,
       rather than a nicely zeroed GP, you have it pointing somewhere random.
       Bugs ensue.

       (In fact, GP ends up pointing at a previous GP structure, because the
       principle cause of the padding in XPVMG getting garbage is a copy of
       sizeof(XPVMG) bytes from a XPVGV structure in sv_unglob. Right now
       this happens to be moot because XPVGV has been re-ordered, with GP
       no longer after STASH)

       So we are careful and work out the size of used parts of all the
       structures.  */

    switch (old_type) {
    case SVt_NULL:
	break;
    case SVt_IV:
	if (SvROK(sv)) {
	    referant = SvRV(sv);
	    old_type_details = &fake_rv;
	    if (new_type == SVt_NV)
		new_type = SVt_PVNV;
	} else {
	    if (new_type < SVt_PVIV) {
		new_type = (new_type == SVt_NV)
		    ? SVt_PVNV : SVt_PVIV;
	    }
	}
	break;
    case SVt_NV:
	if (new_type < SVt_PVNV) {
	    new_type = SVt_PVNV;
	}
	break;
    case SVt_PV:
	assert(new_type > SVt_PV);
	assert(SVt_IV < SVt_PV);
	assert(SVt_NV < SVt_PV);
	break;
    case SVt_PVIV:
	break;
    case SVt_PVNV:
	break;
    case SVt_PVMG:
	break;
    case SVt_PVAV:
    case SVt_PVHV:
    case SVt_PVCV:
	if (new_type == SVt_PVMG)
	    return;
	Perl_sv_clear_body(aTHX_ sv);
	old_type = SvTYPE(sv);
	old_type_details = bodies_by_type + old_type;
	break;
    default:
	if (old_type > new_type)
	    return;
	if (old_type_details->cant_upgrade)
	    Perl_croak(aTHX_ "Can't upgrade %s (%" UVuf ") to %" UVuf,
		       sv_reftype(sv, 0), (UV) old_type, (UV) new_type);
    }

    if (old_type > new_type)
	return;

    /* Because the XPVMG of PL_mess_sv isn't allocated from the arena,
       there's no way that it can be safely upgraded, because perl.c
       expects to Safefree(SvANY(PL_mess_sv))  */
    assert(sv != PL_mess_sv);

    new_type_details = bodies_by_type + new_type;

    SvFLAGS(sv) &= ~SVTYPEMASK;
    SvFLAGS(sv) |= new_type;

    /* This can't happen, as SVt_NULL is <= all values of new_type, so one of
       the return statements above will have triggered.  */
    assert (new_type != SVt_NULL);
    switch (new_type) {
    case SVt_IV:
	assert(old_type == SVt_NULL);
	SvANY(sv) = (XPVIV*)((char*)&(sv->sv_u.svu_iv) - STRUCT_OFFSET(XPVIV, xiv_iv));
	SvIV_set(sv, 0);
	return;
    case SVt_NV:
	assert(old_type == SVt_NULL);
	SvANY(sv) = new_XNV();
	SvNV_set(sv, 0);
	return;
    case SVt_PVHV:
    case SVt_PVAV:
	assert(new_type_details->body_size);

#ifndef PURIFY	
	assert(new_type_details->arena);
	assert(new_type_details->arena_size);
	/* This points to the start of the allocated area.  */
	new_body_inline(new_body, new_type);
	Zero(new_body, new_type_details->body_size, char);
	new_body = ((char *)new_body) - new_type_details->offset;
#else
	/* We always allocated the full length item with PURIFY. To do this
	   we fake things so that arena is false for all 16 types..  */
	new_body = new_NOARENAZ(new_type_details);
#endif
	SvANY(sv) = new_body;
	if (new_type == SVt_PVAV) {
	    AvMAX(sv)	= -1;
	    AvFILLp(sv)	= -1;
	    AvREAL_only(sv);
	    if (old_type_details->body_size) {
		AvALLOC(sv) = 0;
	    } else {
		/* It will have been zeroed when the new body was allocated.
		   Lets not write to it, in case it confuses a write-back
		   cache.  */
	    }
	} else {
	    assert(!SvPVOK(sv));
	    SvPVOK_off(sv);
#ifndef NODEFAULT_SHAREKEYS
	    HvSHAREKEYS_on(sv);         /* key-sharing on by default */
#endif
	    HvMAX(sv) = 7; /* (start with 8 buckets) */
	    if (old_type_details->body_size) {
		HvFILL(sv) = 0;
	    } else {
		/* It will have been zeroed when the new body was allocated.
		   Lets not write to it, in case it confuses a write-back
		   cache.  */
	    }
	}

	/* SVt_NULL isn't the only thing upgraded to AV or HV.
	   The target created by newSVrv also is, and it can have magic.
	   However, it never has SvPVX set.
	*/
	if (old_type == SVt_IV) {
	    assert(!SvROK(sv));
	} else if (old_type >= SVt_PV) {
	    assert(sv->sv_u.svu_pv == NULL);
	}

	if (old_type >= SVt_PVMG) {
	    SvMAGIC_set(sv, ((XPVMG*)old_body)->xmg_u.xmg_magic);
	    SvSTASH_set(sv, ((XPVMG*)old_body)->xmg_stash);
	} else {
	    sv->sv_u.svu_array = NULL; /* or svu_hash  */
	}
	break;


    case SVt_PVIV:
	/* XXX Is this still needed?  Was it ever needed?   Surely as there is
	   no route from NV to PVIV, NOK can never be true  */
	assert(!SvNOKp(sv));
	assert(!SvNOK(sv));
    case SVt_PVIO:
    case SVt_PVGV:
    case SVt_PVCV:
    case SVt_REGEXP:
    case SVt_PVMG:
    case SVt_PVNV:
    case SVt_PV:

	assert(new_type_details->body_size);
	/* We always allocated the full length item with PURIFY. To do this
	   we fake things so that arena is false for all 16 types..  */
	if(new_type_details->arena) {
	    /* This points to the start of the allocated area.  */
	    new_body_inline(new_body, new_type);
	    Zero(new_body, new_type_details->body_size, char);
	    new_body = ((char *)new_body) - new_type_details->offset;
	} else {
	    new_body = new_NOARENAZ(new_type_details);
	}
	SvANY(sv) = new_body;

	if (old_type_details->copy) {
	    /* There is now the potential for an upgrade from something without
	       an offset (PVNV or PVMG) to something with one (PVCV)  */
	    int offset = old_type_details->offset;
	    int length = old_type_details->copy;

	    if (new_type_details->offset > old_type_details->offset) {
		const int difference
		    = new_type_details->offset - old_type_details->offset;
		offset += difference;
		length -= difference;
	    }
	    assert (length >= 0);
		
	    Copy((char *)old_body + offset, (char *)new_body + offset, length,
		 char);
	}

#ifndef NV_ZERO_IS_ALLBITS_ZERO
	/* If NV 0.0 is stores as all bits 0 then Zero() already creates a
	 * correct 0.0 for us.  Otherwise, if the old body didn't have an
	 * NV slot, but the new one does, then we need to initialise the
	 * freshly created NV slot with whatever the correct bit pattern is
	 * for 0.0  */
	if (old_type_details->zero_nv && !new_type_details->zero_nv
	    && !isGV_with_GP(sv))
	    SvNV_set(sv, 0);
#endif

	if (new_type == SVt_PVIO) {
	    IO * const io = MUTABLE_IO(sv);
	    GV *iogv;

	    SvOBJECT_on(io);
	    /* Clear the stashcache because a new IO could overrule a package
	       name */
	    hv_clear(PL_stashcache);

	    iogv = gv_fetchpvs("IO::Handle::", GV_ADD, SVt_PVHV);
	    SvSTASH_set(io, HvREFCNT_inc(GvHV(iogv)));
	}
	if (old_type < SVt_PV) {
	    /* referant will be NULL unless the old type was SVt_IV emulating
	       SVt_RV */
	    sv->sv_u.svu_rv = referant;
	}
	break;
    default:
	Perl_croak(aTHX_ "panic: sv_upgrade to unknown type %lu",
		   (unsigned long)new_type);
    }

    if (old_type_details->arena) {
	/* If there was an old body, then we need to free it.
	   Note that there is an assumption that all bodies of types that
	   can be upgraded came from arenas. Only the more complex non-
	   upgradable types are allowed to be directly malloc()ed.  */
	if (old_type == SVt_PVCV) {
	    if ( ((XPVCV*)old_body)->xcv_n_add_refs)
		((XPVCV*)old_body)->xcv_n_add_refs -= 1;
	    else
		Perl_del_body_allocated(aTHX_ old_body, old_type);
	}
	else
	    Perl_del_body_allocated(aTHX_ old_body, old_type);
    }
    else if (old_type_details->body_size) {
	if (old_type > SVt_IV)
	    my_safefree(old_body);
    }
}

/*
=for apidoc sv_backoff

Remove any string offset. You should normally use the C<SvOOK_off> macro
wrapper instead.

=cut
*/

int
Perl_sv_backoff(pTHX_ register SV *const sv)
{
    STRLEN delta;
    const char * const s = SvPVX_const(sv);

    PERL_ARGS_ASSERT_SV_BACKOFF;
    PERL_UNUSED_CONTEXT;

    assert(SvOOK(sv));
    assert(SvTYPE(sv) != SVt_PVHV);
    assert(SvTYPE(sv) != SVt_PVAV);

    SvOOK_offset(sv, delta);
    
    SvLEN_set(sv, SvLEN(sv) + delta);
    SvPV_set(sv, SvPVX_mutable(sv) - delta);
    Move(s, SvPVX_mutable(sv), SvCUR(sv)+1, char);
    SvFLAGS(sv) &= ~SVf_OOK;
    return 0;
}

/*
=for apidoc sv_grow

Expands the character buffer in the SV.  If necessary, uses C<sv_unref> and
upgrades the SV to C<SVt_PV>.  Returns a pointer to the character buffer.
Use the C<SvGROW> wrapper instead.

=cut
*/

char *
Perl_sv_grow(pTHX_ register SV *const sv, register STRLEN newlen)
{
    register char *s;

    PERL_ARGS_ASSERT_SV_GROW;

    if (PL_madskills && newlen >= 0x100000) {
	PerlIO_printf(Perl_debug_log,
		      "Allocation too large: %"UVxf"\n", (UV)newlen);
    }
#ifdef HAS_64K_LIMIT
    if (newlen >= 0x10000) {
	PerlIO_printf(Perl_debug_log,
		      "Allocation too large: %"UVxf"\n", (UV)newlen);
	my_exit(1);
    }
#endif /* HAS_64K_LIMIT */
    if (SvROK(sv))
	sv_unref(sv);
    if (SvTYPE(sv) < SVt_PV) {
	sv_upgrade(sv, SVt_PV);
	s = SvPVX_mutable(sv);
    }
    else if (SvOOK(sv)) {	/* pv is offset? */
	sv_backoff(sv);
	s = SvPVX_mutable(sv);
	if (newlen > SvLEN(sv))
	    newlen += 10 * (newlen - SvCUR(sv)); /* avoid copy each time */
#ifdef HAS_64K_LIMIT
	if (newlen >= 0x10000)
	    newlen = 0xFFFF;
#endif
    }
    else
	s = SvPVX_mutable(sv);

    if (newlen > SvLEN(sv)) {		/* need more room? */
#ifndef Perl_safesysmalloc_size
	newlen = PERL_STRLEN_ROUNDUP(newlen);
#endif
	if (SvLEN(sv) && s) {
	    s = (char*)saferealloc(s, newlen);
	}
	else {
	    s = (char*)safemalloc(newlen);
	    if (SvPVX_const(sv) && SvCUR(sv)) {
	        Move(SvPVX_const(sv), s, (newlen < SvCUR(sv)) ? newlen : SvCUR(sv), char);
	    }
	}
	SvPV_set(sv, s);
#ifdef Perl_safesysmalloc_size
	/* Do this here, do it once, do it right, and then we will never get
	   called back into sv_grow() unless there really is some growing
	   needed.  */
	SvLEN_set(sv, Perl_safesysmalloc_size(s));
#else
        SvLEN_set(sv, newlen);
#endif
    }
    return s;
}

/*
=for apidoc sv_setiv

Makes the sv a reference to the dst sv.
Does not increment the reference count of dst.
Does not handle 'set' magic.  See also C<sv_setrv_mg>.

=cut
*/

void
Perl_sv_setrv(pTHX_ register SV *const sv, SV* dst)
{
    PERL_ARGS_ASSERT_SV_SETRV;
    prepare_SV_for_RV(sv);
    SvROK_on(sv);
    SvRV_set(sv, dst);
}

void
Perl_sv_setrv_mg(pTHX_ register SV *const sv, SV* dst)
{
    PERL_ARGS_ASSERT_SV_SETRV_MG;
    sv_setrv(sv, dst);
    SvSETMAGIC(sv);
}

/*
=for apidoc sv_setiv

Copies an integer into the given SV, upgrading first if necessary.
Does not handle 'set' magic.  See also C<sv_setiv_mg>.

=cut
*/

void
Perl_sv_setiv(pTHX_ register SV *const sv, const IV i)
{
    dVAR;

    PERL_ARGS_ASSERT_SV_SETIV;

    SV_CHECK_THINKFIRST_COW_DROP(sv);
    switch (SvTYPE(sv)) {
    case SVt_NULL:
    case SVt_NV:
	sv_upgrade(sv, SVt_IV);
	break;
    case SVt_PV:
	sv_upgrade(sv, SVt_PVIV);
	break;

    case SVt_PVGV:
	if (!isGV_with_GP(sv))
	    break;
    case SVt_PVAV:
    case SVt_PVHV:
    case SVt_PVCV:
    case SVt_PVIO:
	Perl_croak(aTHX_ "Can't coerce %s to integer in %s", sv_reftype(sv,0),
		   OP_DESC(PL_op));
    default: NOOP;
    }
    (void)SvIOK_only(sv);			/* validate number */
    SvIV_set(sv, i);
}

/*
=for apidoc sv_setiv_mg

Like C<sv_setiv>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_setiv_mg(pTHX_ register SV *const sv, const IV i)
{
    PERL_ARGS_ASSERT_SV_SETIV_MG;

    sv_setiv(sv,i);
    SvSETMAGIC(sv);
}

/*
=for apidoc sv_setuv

Copies an unsigned integer into the given SV, upgrading first if necessary.
Does not handle 'set' magic.  See also C<sv_setuv_mg>.

=cut
*/

void
Perl_sv_setuv(pTHX_ register SV *const sv, const UV u)
{
    PERL_ARGS_ASSERT_SV_SETUV;

    /* With these two if statements:
       u=1.49  s=0.52  cu=72.49  cs=10.64  scripts=270  tests=20865

       without
       u=1.35  s=0.47  cu=73.45  cs=11.43  scripts=270  tests=20865

       If you wish to remove them, please benchmark to see what the effect is
    */
    if (u <= (UV)IV_MAX) {
       sv_setiv(sv, (IV)u);
       return;
    }
    sv_setiv(sv, 0);
    SvIsUV_on(sv);
    SvUV_set(sv, u);
}

/*
=for apidoc sv_setuv_mg

Like C<sv_setuv>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_setuv_mg(pTHX_ register SV *const sv, const UV u)
{
    PERL_ARGS_ASSERT_SV_SETUV_MG;

    sv_setuv(sv,u);
    SvSETMAGIC(sv);
}

/*
=for apidoc sv_setnv

Copies a double into the given SV, upgrading first if necessary.
Does not handle 'set' magic.  See also C<sv_setnv_mg>.

=cut
*/

void
Perl_sv_setnv(pTHX_ register SV *const sv, const NV num)
{
    dVAR;

    PERL_ARGS_ASSERT_SV_SETNV;

    SV_CHECK_THINKFIRST_COW_DROP(sv);
    switch (SvTYPE(sv)) {
    case SVt_NULL:
    case SVt_IV:
	sv_upgrade(sv, SVt_NV);
	break;
    case SVt_PV:
    case SVt_PVIV:
	sv_upgrade(sv, SVt_PVNV);
	break;

    case SVt_PVGV:
	if (!isGV_with_GP(sv))
	    break;
    case SVt_PVAV:
    case SVt_PVHV:
    case SVt_PVCV:
    case SVt_PVIO:
	Perl_croak(aTHX_ "Can't coerce %s to number in %s", sv_reftype(sv,0),
		   OP_NAME(PL_op));
    default: NOOP;
    }
    SvNV_set(sv, num);
    (void)SvNOK_only(sv);			/* validate number */
}

/*
=for apidoc sv_setnv_mg

Like C<sv_setnv>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_setnv_mg(pTHX_ register SV *const sv, const NV num)
{
    PERL_ARGS_ASSERT_SV_SETNV_MG;

    sv_setnv(sv,num);
    SvSETMAGIC(sv);
}

/* Print an "isn't numeric" warning, using a cleaned-up,
 * printable version of the offending string
 */

STATIC void
S_not_a_number(pTHX_ SV *const sv)
{
     dVAR;
     SV *dsv;
     const char *pv;

     PERL_ARGS_ASSERT_NOT_A_NUMBER;

     dsv = newSVpvs_flags("", SVs_TEMP);
     pv = sv_uni_display(dsv, sv, 10, UNI_DISPLAY_QQ);

    if (PL_op)
	Perl_warner(aTHX_ packWARN(WARN_NUMERIC),
		    "Argument \"%s\" isn't numeric in %s", pv,
		    OP_DESC(PL_op));
    else
	Perl_warner(aTHX_ packWARN(WARN_NUMERIC),
		    "Argument \"%s\" isn't numeric", pv);
}

/*
=for apidoc looks_like_number

Test if the content of an SV looks like a number (or is a number).
C<Inf> and C<Infinity> are treated as numbers (so will not issue a
non-numeric warning), even if your atof() doesn't grok them.

=cut
*/

I32
Perl_looks_like_number(pTHX_ SV *const sv)
{
    register const char *sbegin;
    STRLEN len;

    PERL_ARGS_ASSERT_LOOKS_LIKE_NUMBER;

    if (SvPOK(sv)) {
	sbegin = SvPVX_const(sv);
	len = SvCUR(sv);
    }
    else if (SvPOKp(sv))
	sbegin = SvPV_const(sv, len);
    else
	return SvFLAGS(sv) & (SVf_NOK|SVp_NOK|SVf_IOK|SVp_IOK);
    return grok_number(sbegin, len, NULL);
}

/* Actually, ISO C leaves conversion of UV to IV undefined, but
   until proven guilty, assume that things are not that bad... */

/*
   NV_PRESERVES_UV:

   As 64 bit platforms often have an NV that doesn't preserve all bits of
   an IV (an assumption perl has been based on to date) it becomes necessary
   to remove the assumption that the NV always carries enough precision to
   recreate the IV whenever needed, and that the NV is the canonical form.
   Instead, IV/UV and NV need to be given equal rights. So as to not lose
   precision as a side effect of conversion (which would lead to insanity
   and the dragon(s) in t/op/numconvert.t getting very angry) the intent is
   1) to distinguish between IV/UV/NV slots that have cached a valid
      conversion where precision was lost and IV/UV/NV slots that have a
      valid conversion which has lost no precision
   2) to ensure that if a numeric conversion to one form is requested that
      would lose precision, the precise conversion (or differently
      imprecise conversion) is also performed and cached, to prevent
      requests for different numeric formats on the same SV causing
      lossy conversion chains. (lossless conversion chains are perfectly
      acceptable (still))


   flags are used:
   SvIOKp is true if the IV slot contains a valid value
   SvIOK  is true only if the IV value is accurate (UV if SvIOK_UV true)
   SvNOKp is true if the NV slot contains a valid value
   SvNOK  is true only if the NV value is accurate

   so
   while converting from PV to NV, check to see if converting that NV to an
   IV(or UV) would lose accuracy over a direct conversion from PV to
   IV(or UV). If it would, cache both conversions, return NV, but mark
   SV as IOK NOKp (ie not NOK).

   While converting from PV to IV, check to see if converting that IV to an
   NV would lose accuracy over a direct conversion from PV to NV. If it
   would, cache both conversions, flag similarly.

   Before, the SV value "3.2" could become NV=3.2 IV=3 NOK, IOK quite
   correctly because if IV & NV were set NV *always* overruled.
   Now, "3.2" will become NV=3.2 IV=3 NOK, IOKp, because the flag's meaning
   changes - now IV and NV together means that the two are interchangeable:
   SvIV == (IV) SvNVX && SvNVX == (NV) SvIVX;

   The benefit of this is that operations such as pp_add know that if
   SvIOK is true for both left and right operands, then integer addition
   can be used instead of floating point (for cases where the result won't
   overflow). Before, floating point was always used, which could lead to
   loss of precision compared with integer addition.

   * making IV and NV equal status should make maths accurate on 64 bit
     platforms
   * may speed up maths somewhat if pp_add and friends start to use
     integers when possible instead of fp. (Hopefully the overhead in
     looking for SvIOK and checking for overflow will not outweigh the
     fp to integer speedup)
   * will slow down integer operations (callers of SvIV) on "inaccurate"
     values, as the change from SvIOK to SvIOKp will cause a call into
     sv_2iv each time rather than a macro access direct to the IV slot
   * should speed up number->string conversion on integers as IV is
     favoured when IV and NV are equally accurate

   ####################################################################
   You had better be using SvIOK_notUV if you want an IV for arithmetic:
   SvIOK is true if (IV or UV), so you might be getting (IV)SvUV.
   On the other hand, SvUOK is true iff UV.
   ####################################################################

   Your mileage will vary depending your CPU's relative fp to integer
   performance ratio.
*/

#ifndef NV_PRESERVES_UV
#  define IS_NUMBER_UNDERFLOW_IV 1
#  define IS_NUMBER_UNDERFLOW_UV 2
#  define IS_NUMBER_IV_AND_UV    2
#  define IS_NUMBER_OVERFLOW_IV  4
#  define IS_NUMBER_OVERFLOW_UV  5
#endif /* NV_PRESERVES_UV */

/*
=for apidoc sv_2iv

Return the integer value of an SV, doing any necessary string
conversion.
Normally used via the C<SvIV(sv)> function.

=cut
*/

IV
Perl_sv_2iv(pTHX_ register SV *const sv)
{
    dVAR;
    if (!sv)
	return 0;
    assert( ! (SvTYPE(sv) == SVt_PVMG && SvVALID(sv)) ); /* FBMs are never used as ivs */
    if (SvTHINKFIRST(sv)) {
	if (SvROK(sv)) {
	    Perl_croak(aTHX_ "%s used as a number", Ddesc(sv));
	}
	if (SvIsCOW(sv)) {
	    sv_force_normal_flags(sv, 0);
	}
	if (SvREADONLY(sv) && !SvOK(sv)) {
	    if (ckWARN(WARN_UNINITIALIZED))
		report_uninit(sv);
	    return 0;
	}
    }
    if (!SvIOKp(sv)) {

	if (SvAVOK(sv))
	    Perl_croak(aTHX_ "Array may not be used as a number");
	if (SvHVOK(sv))
	    Perl_croak(aTHX_ "Hash may not be used as a number");

	if (SvNOKp(sv)) {
	    return I_V(SvNVX(sv));
	}
	if (SvPOKp(sv) && SvLEN(sv)) {
	    UV value;
	    const int numtype
		= grok_number(SvPVX_const(sv), SvCUR(sv), &value);

	    if ((numtype & (IS_NUMBER_IN_UV | IS_NUMBER_NOT_INT))
		== IS_NUMBER_IN_UV) {
		/* It's definitely an integer */
		if (numtype & IS_NUMBER_NEG) {
		    if (value < (UV)IV_MIN)
			return -(IV)value;
		} else {
		    if (value < (UV)IV_MAX)
			return (IV)value;
		}
	    }
	    if (!numtype) {
		if (ckWARN(WARN_NUMERIC))
		    not_a_number(sv);
	    }
	    return I_V(Atof(SvPVX_const(sv)));
	}
	if (isGV_with_GP(sv))
	    Perl_croak(aTHX_ "Tried to use glob as number");

	if (!(SvFLAGS(sv) & SVs_PADTMP)) {
	    if (!PL_localizing && ckWARN(WARN_UNINITIALIZED))
		report_uninit(sv);
	}
	return 0;
    }
    DEBUG_c(PerlIO_printf(Perl_debug_log, "0x%"UVxf" 2iv(%"IVdf")\n",
	PTR2UV(sv),I_SvIV(sv)));
    return SvIsUV(sv) ? (IV)SvUVX(sv) : I_SvIV(sv);
}

/*
=for apidoc sv_2uv

Return the unsigned integer value of an SV, doing any necessary string
conversion.
Normally used via the C<SvUV(sv)> and C<SvUVx(sv)> macros.

=cut
*/

UV
Perl_sv_2uv(pTHX_ register SV *const sv)
{
    dVAR;
    if (!sv)
	return 0;
    if ((SvTYPE(sv) == SVt_PVGV && SvVALID(sv))) {
	/* FBMs use the same flag bit as SVf_IVisUV, so must let them
	   cache IVs just in case.  */
	if (SvIOKp(sv))
	    return SvUVX(sv);
	if (SvNOKp(sv))
	    return U_V(SvNVX(sv));
	if (SvPOKp(sv) && SvLEN(sv)) {
	    UV value;
	    const int numtype
		= grok_number(SvPVX_const(sv), SvCUR(sv), &value);

	    if ((numtype & (IS_NUMBER_IN_UV | IS_NUMBER_NOT_INT))
		== IS_NUMBER_IN_UV) {
		/* It's definitely an integer */
		if (!(numtype & IS_NUMBER_NEG))
		    return value;
	    }
	    if (!numtype) {
		if (ckWARN(WARN_NUMERIC))
		    not_a_number(sv);
	    }
	    return U_V(Atof(SvPVX_const(sv)));
	}
        if (SvROK(sv)) {
	    goto return_rok;
	}
	assert(SvTYPE(sv) >= SVt_PVMG);
	/* This falls through to the report_uninit inside S_sv_2iuv_common.  */
    } else if (SvTHINKFIRST(sv)) {
	if (SvROK(sv)) {
	return_rok:
	    Perl_croak(aTHX_ "%s used as a number", Ddesc(sv));
	}
	if (SvIsCOW(sv)) {
	    sv_force_normal_flags(sv, 0);
	}
	if (SvREADONLY(sv) && !SvOK(sv)) {
	    if (ckWARN(WARN_UNINITIALIZED))
		report_uninit(sv);
	    return 0;
	}
    }
    if (!SvIOKp(sv)) {

	if (SvAVOK(sv))
	    Perl_croak(aTHX_ "Array may not be used as a number");
	if (SvHVOK(sv))
	    Perl_croak(aTHX_ "Hash may not be used as a number");

	if (SvNOKp(sv)) {
#if defined(NAN_COMPARE_BROKEN) && defined(Perl_isnan)
	    if (Perl_isnan(SvNVX(sv))) {
		return 0;
	    }
#endif
	    if (SvNVX(sv) < (NV)IV_MAX + 0.5) {
		return (UV)I_V(SvNVX(sv));
	    }
	    else {
		return U_V(SvNVX(sv));
	    }
	}
	if (SvPOKp(sv) && SvLEN(sv)) {
	    UV value;
	    const int numtype = grok_number(SvPVX_const(sv), SvCUR(sv), &value);
	    /* We want to avoid a possible problem when we cache an IV/ a UV which
	       may be later translated to an NV, and the resulting NV is not
	       the same as the direct translation of the initial string
	       (eg 123.456 can shortcut to the IV 123 with atol(), but we must
	       be careful to ensure that the value with the .456 is around if the
	       NV value is requested in the future).
	
	       This means that if we cache such an IV/a UV, we need to cache the
	       NV as well.  Moreover, we trade speed for space, and do not
	       cache the NV if we are sure it's not needed.
	    */

	    /* If NVs preserve UVs then we only use the UV value if we know that
	       we aren't going to call atof() below. If NVs don't preserve UVs
	       then the value returned may have more precision than atof() will
	       return, even though value isn't perfectly accurate.  */
	    if ((numtype & (IS_NUMBER_IN_UV | IS_NUMBER_NOT_INT
		     )) == IS_NUMBER_IN_UV) {
		if (!(numtype & IS_NUMBER_NEG)) {
		    return value;
		} else {
		    /* 2s complement assumption  */
		    if (value <= (UV)IV_MIN) {
			IV x = -(IV)value;
			return (UV)x;
		    } else {
			return (UV)IV_MIN;
		    }
		}
	    }
  	    if (numtype) {
		/* It wasn't an (integer that doesn't overflow the UV). */
		NV nv = Atof(SvPVX_const(sv));

		if (nv < (NV)IV_MAX + 0.5) {
		    return (UV)I_V(nv);
		} else {
		    if (nv > (NV)UV_MAX) {
			return UV_MAX;
		    } else {
			return U_V(nv);
		    }
		}
	    }

		 assert(!numtype);
		 if (ckWARN(WARN_NUMERIC))
		     not_a_number(sv);
		 return 0;
	}
        if (isGV_with_GP(sv))
	    Perl_croak(aTHX_ "Tried to use glob as number");

	if (!(SvFLAGS(sv) & SVs_PADTMP)) {
	    if (!PL_localizing && ckWARN(WARN_UNINITIALIZED))
		report_uninit(sv);
	}
	return 0;
    }

    DEBUG_c(PerlIO_printf(Perl_debug_log, "0x%"UVxf" 2uv(%"UVuf")\n",
			  PTR2UV(sv),SvUVX(sv)));
    return SvIsUV(sv) ? SvUVX(sv) : (UV)I_SvIV(sv);
}

/*
=for apidoc sv_2nv

Return the num value of an SV, doing any necessary string or integer
conversion, magic etc. Normally used via the C<SvNV(sv)> and C<SvNVx(sv)>
macros.

=cut
*/

NV
Perl_sv_2nv(pTHX_ register SV *const sv)
{
    dVAR;
    if (!sv)
	return 0.0;
    if ( SvOK(sv) && ! SvPVOK(sv) ) {
	Perl_croak(aTHX_ "%s used as a number", Ddesc(sv));
    }
    if ((SvTYPE(sv) == SVt_PVGV && SvVALID(sv))) {
	/* FBMs use the same flag bit as SVf_IVisUV, so must let them
	   cache IVs just in case.  */
	if (SvNOKp(sv))
	    return SvNVX(sv);
	if ((SvPOKp(sv) && SvLEN(sv)) && !SvIOKp(sv)) {
	    if (!SvIOKp(sv) && ckWARN(WARN_NUMERIC) &&
		!grok_number(SvPVX_const(sv), SvCUR(sv), NULL))
		not_a_number(sv);
	    return Atof(SvPVX_const(sv));
	}
	if (SvIOKp(sv)) {
	    if (SvIsUV(sv))
		return (NV)SvUVX(sv);
	    else
		return (NV)I_SvIV(sv);
	}
        if (SvROK(sv)) {
	    goto return_rok;
	}
	assert(SvTYPE(sv) >= SVt_PVMG);
	/* This falls through to the report_uninit near the end of the
	   function. */
    } else if (SvTHINKFIRST(sv)) {
	if (SvROK(sv)) {
	return_rok:
	    Perl_croak(aTHX_ "%s used as a number", Ddesc(sv));
	}
	if (SvIsCOW(sv)) {
	    sv_force_normal_flags(sv, 0);
	}
	if (SvREADONLY(sv) && !SvOK(sv)) {
	    if (ckWARN(WARN_UNINITIALIZED))
		report_uninit(sv);
	    return 0.0;
	}
    }
    if (SvTYPE(sv) < SVt_NV) {
	/* The logic to use SVt_PVNV if necessary is in sv_upgrade.  */
	sv_upgrade(sv, SVt_NV);
#ifdef USE_LONG_DOUBLE
	DEBUG_c({
	    STORE_NUMERIC_LOCAL_SET_STANDARD();
	    PerlIO_printf(Perl_debug_log,
			  "0x%"UVxf" num(%" PERL_PRIgldbl ")\n",
			  PTR2UV(sv), SvNVX(sv));
	    RESTORE_NUMERIC_LOCAL();
	});
#else
	DEBUG_c({
	    PerlIO_printf(Perl_debug_log, "0x%"UVxf" num(%"NVgf")\n",
			  PTR2UV(sv), SvNVX(sv));
	});
#endif
    }
    else if (SvTYPE(sv) < SVt_PVNV)
	sv_upgrade(sv, SVt_PVNV);
    if (SvNOKp(sv)) {
        return SvNVX(sv);
    }
    if (SvIOKp(sv)) {
	SvNV_set(sv, SvIsUV(sv) ? (NV)SvUVX(sv) : (NV)I_SvIV(sv));
#ifdef NV_PRESERVES_UV
	if (SvIOK(sv))
	    SvNOK_on(sv);
	else
	    SvNOKp_on(sv);
#else
	/* Only set the public NV OK flag if this NV preserves the IV  */
	/* Check it's not 0xFFFFFFFFFFFFFFFF */
	if (SvIOK(sv) &&
	    SvIsUV(sv) ? ((SvUVX(sv) != UV_MAX)&&(SvUVX(sv) == U_V(SvNVX(sv))))
		       : (I_SvIV(sv) == I_V(SvNVX(sv))))
	    SvNOK_on(sv);
	else
	    SvNOKp_on(sv);
#endif
    }
    else if (SvPOKp(sv) && SvLEN(sv)) {
	UV value;
	const int numtype = grok_number(SvPVX_const(sv), SvCUR(sv), &value);
	if (!SvIOKp(sv) && !numtype && ckWARN(WARN_NUMERIC))
	    not_a_number(sv);
#ifdef NV_PRESERVES_UV
	if ((numtype & (IS_NUMBER_IN_UV | IS_NUMBER_NOT_INT))
	    == IS_NUMBER_IN_UV) {
	    /* It's definitely an integer */
	    SvNV_set(sv, (numtype & IS_NUMBER_NEG) ? -(NV)value : (NV)value);
	} else
	    SvNV_set(sv, Atof(SvPVX_const(sv)));
	if (numtype)
	    SvNOK_on(sv);
	else
	    SvNOKp_on(sv);
#else
	SvNV_set(sv, Atof(SvPVX_const(sv)));
	/* Only set the public NV OK flag if this NV preserves the value in
	   the PV at least as well as an IV/UV would.
	   Not sure how to do this 100% reliably. */
	/* if that shift count is out of range then Configure's test is
	   wonky. We shouldn't be in here with NV_PRESERVES_UV_BITS ==
	   UV_BITS */
	if (((UV)1 << NV_PRESERVES_UV_BITS) >
	    U_V(SvNVX(sv) > 0 ? SvNVX(sv) : -SvNVX(sv))) {
	    SvNOK_on(sv); /* Definitely small enough to preserve all bits */
	} else if (!(numtype & IS_NUMBER_IN_UV)) {
            /* Can't use strtol etc to convert this string, so don't try.
               sv_2iv and sv_2uv will use the NV to convert, not the PV.  */
            SvNOK_on(sv);
        } else {
            /* value has been set.  It may not be precise.  */
	    if ((numtype & IS_NUMBER_NEG) && (value > (UV)IV_MIN)) {
		/* 2s complement assumption for (UV)IV_MIN  */
                SvNOK_on(sv); /* Integer is too negative.  */
            } else {
                SvNOKp_on(sv);
                SvIOKp_on(sv);

                if (numtype & IS_NUMBER_NEG) {
                    SvIV_set(sv, -(IV)value);
                } else if (value <= (UV)IV_MAX) {
		    SvIV_set(sv, (IV)value);
		} else {
		    SvUV_set(sv, value);
		    SvIsUV_on(sv);
		}

                if (numtype & IS_NUMBER_NOT_INT) {
                    /* I believe that even if the original PV had decimals,
                       they are lost beyond the limit of the FP precision.
                       However, neither is canonical, so both only get p
                       flags.  NWC, 2000/11/25 */
                    /* Both already have p flags, so do nothing */
                } else {
		    const NV nv = SvNVX(sv);
                    if (SvNVX(sv) < (NV)IV_MAX + 0.5) {
                        if (I_SvIV(sv) == I_V(nv)) {
                            SvNOK_on(sv);
                        } else {
                            /* It had no "." so it must be integer.  */
                        }
			SvIOK_on(sv);
                    } else {
                        /* between IV_MAX and NV(UV_MAX).
                           Could be slightly > UV_MAX */

                        if (numtype & IS_NUMBER_NOT_INT) {
                            /* UV and NV both imprecise.  */
                        } else {
			    const UV nv_as_uv = U_V(nv);

                            if (value == nv_as_uv && SvUVX(sv) != UV_MAX) {
                                SvNOK_on(sv);
                            }
			    SvIOK_on(sv);
                        }
                    }
                }
            }
        }
	/* It might be more code efficient to go through the entire logic above
	   and conditionally set with SvNOKp_on() rather than SvNOK(), but it
	   gets complex and potentially buggy, so more programmer efficient
	   to do it this way, by turning off the public flags:  */
	if (!numtype)
	    SvFLAGS(sv) &= ~(SVf_IOK|SVf_NOK);
#endif /* NV_PRESERVES_UV */
    }
    else  {
	if ( SvOK(sv) ) {
	    Perl_croak(aTHX_ "%s used as a number", Ddesc(sv));
	}

	if (!PL_localizing && !(SvFLAGS(sv) & SVs_PADTMP) && ckWARN(WARN_UNINITIALIZED))
	    report_uninit(sv);
	assert (SvTYPE(sv) >= SVt_NV);
	/* Typically the caller expects that sv_any is not NULL now.  */
	/* XXX Ilya implies that this is a bug in callers that assume this
	   and ideally should be fixed.  */
	return 0.0;
    }
#if defined(USE_LONG_DOUBLE)
    DEBUG_c({
	PerlIO_printf(Perl_debug_log, "0x%"UVxf" 2nv(%" PERL_PRIgldbl ")\n",
		      PTR2UV(sv), SvNVX(sv));
    });
#else
    DEBUG_c({
	PerlIO_printf(Perl_debug_log, "0x%"UVxf" 1nv(%"NVgf")\n",
		      PTR2UV(sv), SvNVX(sv));
    });
#endif
    return SvNVX(sv);
}

/*
=for apidoc sv_2num

Return an SV with the numeric value of the source SV, doing any necessary
reference or overload conversion.  You must use the C<SvNUM(sv)> macro to
access this function.

=cut
*/

SV *
Perl_sv_2num(pTHX_ register SV *const sv)
{
    PERL_ARGS_ASSERT_SV_2NUM;

    if (SvROK(sv)) {
	Perl_croak(aTHX_ "Reference can't be used as a number");
    }
    if (SvAVOK(sv))
	Perl_croak(aTHX_ "Array can't be used as a number");
    if (SvHVOK(sv))
	Perl_croak(aTHX_ "Hash can't be used as a number");
    return sv;
}

/* uiv_2buf(): private routine for use by sv_2pv_flags(): print an IV or
 * UV as a string towards the end of buf, and return pointers to start and
 * end of it.
 *
 * We assume that buf is at least TYPE_CHARS(UV) long.
 */

static char *
S_uiv_2buf(char *const buf, const IV iv, UV uv, const int is_uv, char **const peob)
{
    char *ptr = buf + TYPE_CHARS(UV);
    char * const ebuf = ptr;
    int sign;

    PERL_ARGS_ASSERT_UIV_2BUF;

    if (is_uv)
	sign = 0;
    else if (iv >= 0) {
	uv = iv;
	sign = 0;
    } else {
	uv = -iv;
	sign = 1;
    }
    do {
	*--ptr = '0' + (char)(uv % 10);
    } while (uv /= 10);
    if (sign)
	*--ptr = '-';
    *peob = ebuf;
    return ptr;
}

/*
=for apidoc sv_2pv_flags

Returns a pointer to the string value of an SV, and sets *lp to its length.
Coerces sv to a string if necessary.
Normally invoked via the C<SvPV_flags> macro. C<sv_2pv()> and C<sv_2pv_nomg>
usually end up here too.

=cut
*/

char *
Perl_sv_2pv_flags(pTHX_ register SV *const sv, STRLEN *const lp, const I32 flags)
{
    dVAR;
    register char *s;

    if (!sv) {
	if (lp)
	    *lp = 0;
	return (char *)"";
    }

    if (SvTHINKFIRST(sv)) {
	if (SvROK(sv)) {
	    {
		const SV *const referent = (SV*)SvRV(sv);

		if (referent && SvTYPE(referent) == SVt_REGEXP) {
		    REGEXP * const re = (REGEXP *)referent;
		    I32 seen_evals = 0;

		    assert(re);
                       
		    if ((seen_evals = RX_SEEN_EVALS(re)))
			PL_reginterp_cnt += seen_evals;

		    if (lp)
			*lp = RX_WRAPLEN(re);
 
		    return RX_WRAPPED(re);
		}
	    }
	    Perl_croak(aTHX_ "Tried to use reference as string in %s", OP_DESC(PL_op));
	}
	if (SvREADONLY(sv) && !SvOK(sv)) {
	    if (lp)
		*lp = 0;
	    if (flags & SV_UNDEF_RETURNS_NULL)
		return NULL;
	    if (ckWARN(WARN_UNINITIALIZED))
		report_uninit(sv);
	    return (char *)"";
	}
    }

    if (SvOK(sv) && ! SvPVOK(sv)) {
	Perl_croak(aTHX_ "%s can not be used as a string", Ddesc(sv));
    }

    if (SvIOK(sv) || ((SvIOKp(sv) && !SvNOKp(sv)))) {
	/* I'm assuming that if both IV and NV are equally valid then
	   converting the IV is going to be more efficient */
	const U32 isUIOK = SvIsUV(sv);
	char buf[TYPE_CHARS(UV)];
	char *ebuf, *ptr;
	STRLEN len;

	if (SvTYPE(sv) < SVt_PVIV)
	    sv_upgrade(sv, SVt_PVIV);
 	ptr = uiv_2buf(buf, I_SvIV(sv), SvUVX(sv), isUIOK, &ebuf);
	len = ebuf - ptr;
	/* inlined from sv_setpvn */
	s = SvGROW_mutable(sv, len + 1);
	Move(ptr, s, len, char);
	s += len;
	*s = '\0';
    }
    else if (SvNOKp(sv)) {
	dSAVE_ERRNO;
	if (SvTYPE(sv) < SVt_PVNV)
	    sv_upgrade(sv, SVt_PVNV);
	/* The +20 is pure guesswork.  Configure test needed. --jhi */
	s = SvGROW_mutable(sv, NV_DIG + 20);
	/* some Xenix systems wipe out errno here */
#ifdef apollo
	if (SvNVX(sv) == 0.0)
	    my_strlcpy(s, "0", SvLEN(sv));
	else
#endif /*apollo*/
	{
	    Gconvert(SvNVX(sv), NV_DIG, 0, s);
	}
	RESTORE_ERRNO;
#ifdef FIXNEGATIVEZERO
        if (*s == '-' && s[1] == '0' && !s[2]) {
	    s[0] = '0';
	    s[1] = 0;
	}
#endif
	while (*s) s++;
#ifdef hcx
	if (s[-1] == '.')
	    *--s = '\0';
#endif
    }
    else {
	if (isGV_with_GP(sv))
	    Perl_croak(aTHX_ "Tried to use glob as string in %s", OP_DESC(PL_op));

	if (SvTYPE(sv) == SVt_PVAV || SvTYPE(sv) == SVt_PVHV)
	    Perl_croak(aTHX_ "%s may not be used as a string in %s",
		       Ddesc(sv), OP_DESC(PL_op) );

	if (lp)
	    *lp = 0;
	if (flags & SV_UNDEF_RETURNS_NULL)
	    return NULL;
	if (!PL_localizing && !(SvFLAGS(sv) & SVs_PADTMP) && ckWARN(WARN_UNINITIALIZED))
	    report_uninit(sv);
	if (SvTYPE(sv) < SVt_PV)
	    /* Typically the caller expects that sv_any is not NULL now.  */
	    sv_upgrade(sv, SVt_PV);
	return (char *)"";
    }
    {
	const STRLEN len = s - SvPVX_const(sv);
	if (lp) 
	    *lp = len;
	SvCUR_set(sv, len);
    }
    SvPOK_on(sv);
    DEBUG_c(PerlIO_printf(Perl_debug_log, "0x%"UVxf" 2pv(%s)\n",
			  PTR2UV(sv),SvPVX_const(sv)));
    if (flags & SV_CONST_RETURN)
	return (char *)SvPVX_const(sv);
    if (flags & SV_MUTABLE_RETURN)
	return SvPVX_mutable(sv);
    return SvPVX_mutable(sv);
}

/*
=for apidoc sv_copypv

Copies a stringified representation of the source SV into the
destination SV.  Automatically performs any necessary 
coercion of numeric values into strings.  Guaranteed to preserve
UTF8 flag even from overloaded objects.  Similar in nature to
sv_2pv[_flags] but operates directly on an SV instead of just the
string.  Mostly uses sv_2pv_flags to do its work, except when that
would lose the UTF-8'ness of the PV.

=cut
*/

void
Perl_sv_copypv(pTHX_ SV *const dsv, register SV *const ssv)
{
    STRLEN len;
    const char * const s = SvPV_const(ssv,len);

    PERL_ARGS_ASSERT_SV_COPYPV;

    sv_setpvn(dsv,s,len);
}

/*
=for apidoc sv_2bool

This function is only called on magical items, and is only used by
sv_true() or its macro equivalent.

=cut
*/

bool
Perl_sv_2bool(pTHX_ register SV *const sv)
{
    dVAR;

    PERL_ARGS_ASSERT_SV_2BOOL;

    if (SvTYPE(sv) == SVt_PVAV) {
	return av_len((AV*)sv) != -1;
    }
    if (SvTYPE(sv) == SVt_PVHV) {
	return HvUSEDKEYS((HV*)sv) != 0;
    }
    if (SvTYPE(sv) == SVt_PVCV)
	return 1;

    if (!SvOK(sv))
	return 0;
    if (SvROK(sv)) {
	return SvRV(sv) != 0;
    }
    if (SvPOKp(sv)) {
	register XPV* const Xpvtmp = (XPV*)SvANY(sv);
	if (Xpvtmp &&
		(*sv->sv_u.svu_pv > '0' ||
		Xpvtmp->xpv_cur > 1 ||
		(Xpvtmp->xpv_cur && *sv->sv_u.svu_pv != '0')))
	    return 1;
	else
	    return 0;
    }
    else {
	if (SvIOKp(sv))
	    return I_SvIV(sv) != 0;
	else {
	    if (SvNOKp(sv))
		return SvNVX(sv) != 0.0;
	    else {
		if (isGV_with_GP(sv))
		    return TRUE;
		else
		    return FALSE;
	    }
	}
    }
}

/*

=for apidoc sv_setsv

Copies the contents of the source SV C<ssv> into the destination SV
C<dsv>.  The source SV may be destroyed if it is mortal, so don't use this
function if the source SV needs to be reused. Does not handle 'set' magic.
Loosely speaking, it performs a copy-by-value, obliterating any previous
content of the destination.

You probably want to use one of the assortment of wrappers, such as
C<SvSetSV>, C<SvSetSV_nosteal>, C<SvSetMagicSV> and
C<SvSetMagicSV_nosteal>.

=for apidoc sv_setsv_flags

Copies the contents of the source SV C<ssv> into the destination SV
C<dsv>.  The source SV may be destroyed if it is mortal, so don't use this
function if the source SV needs to be reused. Does not handle 'set' magic.
Loosely speaking, it performs a copy-by-value, obliterating any previous
content of the destination.
If the C<flags> parameter has the
C<NOSTEAL> bit set then the buffers of temps will not be stolen. <sv_setsv>
and C<sv_setsv_nomg> are implemented in terms of this function.

This is the primary function for copying scalars, and most other
copy-ish functions and macros use this underneath.

=cut
*/

static void
S_glob_assign_ref(pTHX_ SV *const dstr, SV *const sstr)
{
    SV * const sref = SvROK(sstr) ? SvREFCNT_inc(SvRV(sstr)) : SvREFCNT_inc(sstr);
    SV *dref = NULL;
    const int intro = GvINTRO(dstr);
    SV **location;
    U8 import_flag = 0;
    const U32 stype = SvTYPE(sref);
    bool mro_changes = FALSE;

    PERL_ARGS_ASSERT_GLOB_ASSIGN_REF;

#ifdef GV_UNIQUE_CHECK
    if (GvUNIQUE((GV*)dstr)) {
	Perl_croak(aTHX_ PL_no_modify);
    }
#endif

    if (intro) {
	GvINTRO_off(dstr);	/* one-shot flag */
	GvEGV(dstr) = (GV*)dstr;
    }
    GvMULTI_on(dstr);
    switch (stype) {
    case SVt_PVCV:
	location = (SV **) &GvCV(dstr);
	import_flag = GVf_IMPORTED_CV;
	goto common;
    case SVt_PVHV:
	location = (SV **) &GvHV(dstr);
	import_flag = GVf_IMPORTED_HV;
	goto common;
    case SVt_PVAV:
	location = (SV **) &GvAV(dstr);
        if (strEQ(GvNAME((GV*)dstr), "ISA"))
	    mro_changes = TRUE;
	import_flag = GVf_IMPORTED_AV;
	goto common;
    case SVt_PVIO:
	location = (SV **) &GvIOp(dstr);
	goto common;
    default:
	location = &GvSV(dstr);
	import_flag = GVf_IMPORTED_SV;
    common:
	if (intro) {
	    if (stype == SVt_PVCV) {
		/*if (GvCVGEN(dstr) && (GvCV(dstr) != (const CV *)sref || GvCVGEN(dstr))) {*/
		if (GvCVGEN(dstr)) {
		    CvREFCNT_dec(GvCV(dstr));
		    GvCV(dstr) = NULL;
		    GvCVGEN(dstr) = 0; /* Switch off cacheness. */
		}
	    }
	    SAVEGENERICSV(*location);
	}
	else
	    dref = *location;
	if (stype == SVt_PVCV && (*location != sref || GvCVGEN(dstr))) {
	    CV* const cv = MUTABLE_CV(*location);
	    if (cv) {
		if (!GvCVGEN((const GV *)dstr) &&
		    (CvROOT(cv) || CvXSUB(cv)))
		    {
			/* Redefining a sub - warning is mandatory if
			   it was a const and its value changed. */
			if (CvCONST(cv)	&& CvCONST((const CV *)sref)
			    && cv_const_sv(cv)
			    == cv_const_sv((const CV *)sref)) {
			    NOOP;
			    /* They are 2 constant subroutines generated from
			       the same constant. This probably means that
			       they are really the "same" proxy subroutine
			       instantiated in 2 places. Most likely this is
			       when a constant is exported twice.  Don't warn.
			    */
			}
			else if (ckWARN(WARN_REDEFINE)
				 || (CvCONST(cv)
				     && (!CvCONST((const CV *)sref)
					 || sv_cmp(cv_const_sv(cv),
						   cv_const_sv((const CV *)
							       sref))))) {
			    Perl_warner(aTHX_ packWARN(WARN_REDEFINE),
					(const char *)
					(CvCONST(cv)
					 ? "Constant subroutine %s::%s redefined"
					 : "Subroutine %s::%s redefined"),
					HvNAME_get(GvSTASH((const GV *)dstr)),
					GvENAME(MUTABLE_GV(dstr)));
			}
		    }
	    }
	    GvCVGEN(dstr) = 0; /* Switch off cacheness. */
	    GvASSUMECV_on(dstr);
	    if(GvSTASH(dstr)) mro_method_changed_in(GvSTASH(dstr)); /* sub foo { 1 } sub bar { 2 } *bar = \&foo */
	}
	*location = sref;
	if (import_flag && !(GvFLAGS(dstr) & import_flag)
	    && CopSTASH_ne(PL_curcop, GvSTASH(dstr))) {
	    GvFLAGS(dstr) |= import_flag;
	}
	break;
    }
    SvREFCNT_dec(dref);
    if (mro_changes) mro_isa_changed_in(GvSTASH(dstr));
    return;
}

void
Perl_sv_setsv_flags(pTHX_ SV *dstr, register SV* sstr, const I32 flags)
{
    dVAR;
    U32 sflags;
    svtype dtype;
    svtype stype;
    bool sstr_ref_incremented = FALSE;

    PERL_ARGS_ASSERT_SV_SETSV_FLAGS;

    if (sstr == dstr) {
	return;
    }

    if (SvIS_FREED(dstr)) {
	Perl_croak(aTHX_ "panic: attempt to copy value %" SVf
		   " to a freed scalar %p", SVfARG(sstr), (void *)dstr);
    }
    SV_CHECK_THINKFIRST_COW_DROP(dstr);
    if (!sstr)
	sstr = &PL_sv_undef;
    if (SvIS_FREED(sstr)) {
	Perl_croak(aTHX_ "panic: attempt to copy freed scalar %p to %p",
		   (void*)sstr, (void*)dstr);
    }
    stype = SvTYPE(sstr);
    dtype = SvTYPE(dstr);

    /* glob assignment */
    if (dtype == SVt_PVGV) {
	if (SvROK(sstr)) {
	    if (isGV_with_GP(dstr) && dtype == SVt_PVGV
		&& SvTYPE(SvRV(sstr)) == SVt_PVGV) {
		sstr = SvRV(sstr);
		if (sstr == dstr) {
		    if (GvIMPORTED(dstr) != GVf_IMPORTED
			&& CopSTASH_ne(PL_curcop, GvSTASH(dstr)))
			{
			    GvIMPORTED_on(dstr);
			}
		    GvMULTI_on(dstr);
		    return;
		}
		Perl_croak(aTHX_ "glob to glob assignment have been removed");
		return;
	    }
	}

	if (! SvOK(sstr))
	    Perl_croak(aTHX_ "Undefined value assigned to glob");

	if (isGV_with_GP(dstr)) {
	    glob_assign_ref(dstr, sstr);
	    return;
	}

	return;
    }

    /* clear the destination sv if it will be upgraded to a hash or an array */
    if ( ( ( dtype == SVt_PVHV || dtype == SVt_PVAV
		|| stype == SVt_PVAV || stype == SVt_PVHV )
	    && dtype != stype ) 
	|| (dtype == SVt_PVCV || stype == SVt_PVCV)  /* always free the old body with a PVCV */
	) {

	/* Make sure the sstr stays alive during the assignment */
	SvREFCNT_inc(sstr);
	sstr_ref_incremented = TRUE;

	if (SvOBJECT(dstr)) {
	    HV* package = SvSTASH(dstr);
	    Perl_sv_clear_body(aTHX_ dstr);
	    sv_upgrade( dstr, SVt_PVMG);
	    SvFLAGS(dstr) |= SVs_OBJECT;
	    SvSTASH(dstr) = package;
	}
	else {
	    Perl_sv_clear_body(aTHX_ dstr);
	}
	dtype = SvTYPE(dstr);
    }

    /* There's a lot of redundancy below but we're going for speed here */

    switch (stype) {
    case SVt_NULL:
      undef_sstr:
	(void)SvOK_off(dstr);
	return;
    case SVt_IV:
	if (SvIOK(sstr)) {
	    switch (dtype) {
	    case SVt_NULL:
		sv_upgrade(dstr, SVt_IV);
		break;
	    case SVt_NV:
	    case SVt_PV:
		sv_upgrade(dstr, SVt_PVIV);
		break;
	    case SVt_PVGV:
		goto end_of_first_switch;
	    default:
		break;
	    }
	    (void)SvIOK_only(dstr);
	    SvIV_set(dstr, I_SvIV(sstr));
	    if (SvIsUV(sstr))
		SvIsUV_on(dstr);
	    return;
	}
	if (!SvROK(sstr))
	    goto undef_sstr;
	if (dtype < SVt_PV && dtype != SVt_IV)
	    sv_upgrade(dstr, SVt_IV);
	break;

    case SVt_NV:
	if (SvNOK(sstr)) {
	    switch (dtype) {
	    case SVt_NULL:
	    case SVt_IV:
		sv_upgrade(dstr, SVt_NV);
		break;
	    case SVt_PV:
	    case SVt_PVIV:
		sv_upgrade(dstr, SVt_PVNV);
		break;
	    case SVt_PVGV:
		goto end_of_first_switch;
	    default:
		break;
	    }
	    SvNV_set(dstr, SvNVX(sstr));
	    (void)SvNOK_only(dstr);
	    return;
	}
	goto undef_sstr;

    case SVt_REGEXP:
    case SVt_PV:
	if (dtype < SVt_PV)
	    sv_upgrade(dstr, SVt_PV);
	break;
    case SVt_PVIV:
	if (dtype < SVt_PVIV)
	    sv_upgrade(dstr, SVt_PVIV);
	break;
    case SVt_PVNV:
	if (dtype < SVt_PVNV)
	    sv_upgrade(dstr, SVt_PVNV);
	break;
    case SVt_PVAV:
    case SVt_PVHV:
	if (dtype != stype)
	    sv_upgrade(dstr, stype);
	break;
    case SVt_PVCV:
	break;

    default:
	{
	const char * const type = sv_reftype(sstr,0);
	if (PL_op)
	    Perl_croak(aTHX_ "Bizarre copy of %s in %s", type, OP_NAME(PL_op));
	else
	    Perl_croak(aTHX_ "Bizarre copy of %s", type);
	}
	break;

	/* case SVt_BIND: */
    case SVt_PVGV:
	if (isGV_with_GP(sstr) && dtype <= SVt_PVGV) {
	    Perl_croak(aTHX_ "glob to glob assignment have been removed");
	    return;
	}
	/* SvVALID means that this PVGV is playing at being an FBM.  */
	/*FALLTHROUGH*/

    case SVt_PVMG:
	SvUPGRADE(dstr, (svtype)stype);
    }
 end_of_first_switch:

    /* dstr may have been upgraded.  */
    dtype = SvTYPE(dstr);
    sflags = SvFLAGS(sstr);

    if (stype == SVt_PVCV) {
	assert(dtype == SVt_NULL);
	SvFLAGS(dstr) &= ~SVTYPEMASK;
	SvFLAGS(dstr) |= SVt_PVCV;

	SVcpSTEAL(SvLOCATION(dstr), newSVsv(SvLOCATION(sstr)));

	SvANY(dstr) = SvANY(sstr);
	++CvN_ADD_REFS(dstr);

    } else if (dtype == SVt_PVAV) {
	int i;
	int len = av_len( (AV*)sstr);
	bool magic = SvMAGICAL( dstr ) != 0;
	if ( ! sstr_ref_incremented ) {
	    SvREFCNT_inc(sstr);
	    sstr_ref_incremented = TRUE;
	}
	av_clear( (AV*)dstr );
	av_extend( (AV*)dstr, len );
	for (i=0; i<=len; i++) {
	    SV** val = av_fetch( (AV*)sstr, i, 0);
	    SV* sv = val ? newSVsv(*val) : NULL;
	    SV** didstore = av_store( (AV*)dstr, i, sv);
	    if (magic) {
		if (SvSMAGICAL(sv))
		    mg_set(sv);
		if (!didstore)
		    sv_2mortal(sv);
	    }
	}
	if (PL_delaymagic & DM_ARRAY)
	    SvSETMAGIC( dstr );
	PL_delaymagic = 0;
	
    }
    else if (dtype == SVt_PVHV) {
	if ( ! sstr_ref_incremented ) {
	    SvREFCNT_inc(sstr);
	    sstr_ref_incremented = TRUE;
	}
	hv_sethv( (HV*)dstr, (HV*)sstr);
    }
    else if (dtype == SVt_PVCV) {
	CvFLAGS(dstr) = CvFLAGS(sstr);
	SvANY(dstr) = SvANY(sstr);
    }
    else if (sflags & SVf_ROK) {
	if (dtype >= SVt_PV) {
	    if (SvPVX_const(dstr)) {
		SvPV_free(dstr);
		SvLEN_set(dstr, 0);
                SvCUR_set(dstr, 0);
	    }
	}
	(void)SvOK_off(dstr);
	SvRV_set(dstr, SvREFCNT_inc(SvRV(sstr)));
	SvFLAGS(dstr) |= sflags & SVf_ROK;
	assert(!(sflags & SVp_NOK));
	assert(!(sflags & SVp_IOK));
	assert(!(sflags & SVf_NOK));
	assert(!(sflags & SVf_IOK));
    }
    else if (dtype == SVt_PVGV && isGV_with_GP(dstr)) {
	Perl_croak(aTHX_ "non-ref value assigned to glob");
    }
    else if (sflags & SVp_POK) {
        bool isSwipe = 0;

	/*
	 * Check to see if we can just swipe the string.  If so, it's a
	 * possible small lose on short strings, but a big win on long ones.
	 * It might even be a win on short strings if SvPVX_const(dstr)
	 * has to be allocated and SvPVX_const(sstr) has to be freed.
	 * Likewise if we can set up COW rather than doing an actual copy, we
	 * drop to the else clause, as the swipe code and the COW setup code
	 * have much in common.
	 */

	/* Whichever path we take through the next code, we want this true,
	   and doing it now facilitates the COW check.  */
	(void)SvPOK_only(dstr);

	if (
	    /* If we're already COW then this clause is not true, and if COW
	       is allowed then we drop down to the else and make dest COW 
	       with us.  If caller hasn't said that we're allowed to COW
	       shared hash keys then we don't do the COW setup, even if the
	       source scalar is a shared hash key scalar.  */
            (((flags & SV_COW_SHARED_HASH_KEYS)
	       ? (sflags & (SVf_FAKE|SVf_READONLY)) != (SVf_FAKE|SVf_READONLY)
	       : 1 /* If making a COW copy is forbidden then the behaviour we
		       desire is as if the source SV isn't actually already
		       COW, even if it is.  So we act as if the source flags
		       are not COW, rather than actually testing them.  */
	      )
#ifndef PERL_OLD_COPY_ON_WRITE
	     /* The change that added SV_COW_SHARED_HASH_KEYS makes the logic
		when PERL_OLD_COPY_ON_WRITE is defined a little wrong.
		Conceptually PERL_OLD_COPY_ON_WRITE being defined should
		override SV_COW_SHARED_HASH_KEYS, because it means "always COW"
		but in turn, it's somewhat dead code, never expected to go
		live, but more kept as a placeholder on how to do it better
		in a newer implementation.  */
	     /* If we are COW and dstr is a suitable target then we drop down
		into the else and make dest a COW of us.  */
	     || (SvFLAGS(dstr) & CAN_COW_MASK) != CAN_COW_FLAGS
#endif
	     )
            &&
            !(isSwipe =
                 (sflags & SVs_TEMP) &&   /* slated for free anyway? */
                 !(sflags & SVf_OOK) &&   /* and not involved in OOK hack? */
	         (!(flags & SV_NOSTEAL)) &&
					/* and we're allowed to steal temps */
                 SvREFCNT(sstr) == 1 &&   /* and no other references to it? */
                 SvLEN(sstr)	  /* and really is a string */
	    			/* and won't be needed again, potentially */
	      )
#ifdef PERL_OLD_COPY_ON_WRITE
            && ((flags & SV_COW_SHARED_HASH_KEYS)
		? (!((sflags & CAN_COW_MASK) == CAN_COW_FLAGS
		     && (SvFLAGS(dstr) & CAN_COW_MASK) == CAN_COW_FLAGS
		     && SvTYPE(sstr) >= SVt_PVIV))
		: 1)
#endif
            ) {
            /* Failed the swipe test, and it's not a shared hash key either.
               Have to copy the string.  */
	    STRLEN len = SvCUR(sstr);
            SvGROW(dstr, len + 1);	/* inlined from sv_setpvn */
            Move(SvPVX_const(sstr),SvPVX_mutable(dstr),len,char);
            SvCUR_set(dstr, len);
            *SvEND(dstr) = '\0';
        } else {
            /* If PERL_OLD_COPY_ON_WRITE is not defined, then isSwipe will always
               be true in here.  */
            /* Either it's a shared hash key, or it's suitable for
               copy-on-write or we can swipe the string.  */
            if (DEBUG_C_TEST) {
                PerlIO_printf(Perl_debug_log, "Copy on write: sstr --> dstr\n");
                sv_dump(sstr);
                sv_dump(dstr);
            }
#ifdef PERL_OLD_COPY_ON_WRITE
            if (!isSwipe) {
                if ((sflags & (SVf_FAKE | SVf_READONLY))
                    != (SVf_FAKE | SVf_READONLY)) {
                    SvREADONLY_on(sstr);
                    SvFAKE_on(sstr);
                    /* Make the source SV into a loop of 1.
                       (about to become 2) */
                    SV_COW_NEXT_SV_SET(sstr, sstr);
                }
            }
#endif
            /* Initial code is common.  */
	    if (SvPVX_const(dstr)) {	/* we know that dtype >= SVt_PV */
		SvPV_free(dstr);
	    }

            if (!isSwipe) {
                /* making another shared SV.  */
                STRLEN cur = SvCUR(sstr);
                STRLEN len = SvLEN(sstr);
#ifdef PERL_OLD_COPY_ON_WRITE
                if (len) {
		    assert (SvTYPE(dstr) >= SVt_PVIV);
                    /* SvIsCOW_normal */
                    /* splice us in between source and next-after-source.  */
                    SV_COW_NEXT_SV_SET(dstr, SV_COW_NEXT_SV(sstr));
                    SV_COW_NEXT_SV_SET(sstr, dstr);
                    SvPV_set(dstr, SvPVX_mutable(sstr));
                } else
#endif
		{
                    /* SvIsCOW_shared_hash */
                    DEBUG_C(PerlIO_printf(Perl_debug_log,
                                          "Copy on write: Sharing hash\n"));

		    assert (SvTYPE(dstr) >= SVt_PV);
                    SvPV_set(dstr,
			     HEK_KEY(share_hek_hek(SvSHARED_HEK_FROM_PV(SvPVX_const(sstr)))));
		}
                SvLEN_set(dstr, len);
                SvCUR_set(dstr, cur);
                SvREADONLY_on(dstr);
                SvFAKE_on(dstr);
            }
            else
                {	/* Passes the swipe test.  */
                SvPV_set(dstr, SvPVX_mutable(sstr));
                SvLEN_set(dstr, SvLEN(sstr));
                SvCUR_set(dstr, SvCUR(sstr));

                SvTEMP_off(dstr);
                (void)SvOK_off(sstr);	/* NOTE: nukes most SvFLAGS on sstr */
                SvPV_set(sstr, NULL);
                SvLEN_set(sstr, 0);
                SvCUR_set(sstr, 0);
                SvTEMP_off(sstr);
            }
        }
	if (sflags & SVp_NOK) {
	    SvNV_set(dstr, SvNVX(sstr));
	}
	if (sflags & SVp_IOK) {
	    SvIV_set(dstr, I_SvIV(sstr));
	    /* Must do this otherwise some other overloaded use of 0x80000000
	       gets confused. I guess SVpbm_VALID */
	    if (sflags & SVf_IVisUV)
		SvIsUV_on(dstr);
	}
	SvFLAGS(dstr) |= sflags & (SVf_IOK|SVp_IOK|SVf_NOK|SVp_NOK);
    }
    else if (sflags & (SVp_IOK|SVp_NOK)) {
	(void)SvOK_off(dstr);
	SvFLAGS(dstr) |= sflags & (SVf_IOK|SVp_IOK|SVf_IVisUV|SVf_NOK|SVp_NOK);
	if (sflags & SVp_IOK) {
	    /* XXXX Do we want to set IsUV for IV(ROK)?  Be extra safe... */
	    SvIV_set(dstr, I_SvIV(sstr));
	}
	if (sflags & SVp_NOK) {
	    SvNV_set(dstr, SvNVX(sstr));
	}
    }
    else {
	if (isGV_with_GP(sstr)) {
	    gv_efullname3(dstr, (GV *)sstr, "*");
	}
	else
	    (void)SvOK_off(dstr);
    }
    if (sstr_ref_incremented)
	SvREFCNT_dec(sstr);
}

/*
=for apidoc sv_setsv_mg

Like C<sv_setsv>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_setsv_mg(pTHX_ SV *const dstr, register SV *const sstr)
{
    PERL_ARGS_ASSERT_SV_SETSV_MG;

    sv_setsv(dstr,sstr);
    SvSETMAGIC(dstr);
}

#ifdef PERL_OLD_COPY_ON_WRITE
SV *
Perl_sv_setsv_cow(pTHX_ SV *dstr, SV *sstr)
{
    STRLEN cur = SvCUR(sstr);
    STRLEN len = SvLEN(sstr);
    register char *new_pv;

    PERL_ARGS_ASSERT_SV_SETSV_COW;

    if (DEBUG_C_TEST) {
	PerlIO_printf(Perl_debug_log, "Fast copy on write: %p -> %p\n",
		      (void*)sstr, (void*)dstr);
	sv_dump(sstr);
	if (dstr)
		    sv_dump(dstr);
    }

    if (dstr) {
	if (SvTHINKFIRST(dstr))
	    sv_force_normal_flags(dstr, SV_COW_DROP_PV);
	else if (SvPVX_const(dstr))
	    Safefree(SvPVX_const(dstr));
    }
    else
	new_SV(dstr);
    SvUPGRADE(dstr, SVt_PVIV);

    assert (SvPOK(sstr));
    assert (SvPOKp(sstr));
    assert (!SvIOK(sstr));
    assert (!SvIOKp(sstr));
    assert (!SvNOK(sstr));
    assert (!SvNOKp(sstr));

    if (SvIsCOW(sstr)) {

	if (SvLEN(sstr) == 0) {
	    /* source is a COW shared hash key.  */
	    DEBUG_C(PerlIO_printf(Perl_debug_log,
				  "Fast copy on write: Sharing hash\n"));
	    new_pv = HEK_KEY(share_hek_hek(SvSHARED_HEK_FROM_PV(SvPVX_const(sstr))));
	    goto common_exit;
	}
	SV_COW_NEXT_SV_SET(dstr, SV_COW_NEXT_SV(sstr));
    } else {
	assert ((SvFLAGS(sstr) & CAN_COW_MASK) == CAN_COW_FLAGS);
	SvUPGRADE(sstr, SVt_PVIV);
	SvREADONLY_on(sstr);
	SvFAKE_on(sstr);
	DEBUG_C(PerlIO_printf(Perl_debug_log,
			      "Fast copy on write: Converting sstr to COW\n"));
	SV_COW_NEXT_SV_SET(dstr, sstr);
    }
    SV_COW_NEXT_SV_SET(sstr, dstr);
    new_pv = SvPVX_mutable(sstr);

  common_exit:
    SvPV_set(dstr, new_pv);
    SvFLAGS(dstr) = (SVt_PVIV|SVf_POK|SVp_POK|SVf_FAKE|SVf_READONLY);
    SvLEN_set(dstr, len);
    SvCUR_set(dstr, cur);
    if (DEBUG_C_TEST) {
	sv_dump(dstr);
    }
    return dstr;
}
#endif

/*
=for apidoc sv_setpvn

Copies a string into an SV.  The C<len> parameter indicates the number of
bytes to be copied.  If the C<ptr> argument is NULL the SV will become
undefined.  Does not handle 'set' magic.  See C<sv_setpvn_mg>.

=cut
*/

void
Perl_sv_setpvn(pTHX_ register SV *const sv, register const char *const ptr, register const STRLEN len)
{
    dVAR;
    register char *dptr;

    PERL_ARGS_ASSERT_SV_SETPVN;

    SV_CHECK_THINKFIRST_COW_DROP(sv);
    if (!ptr) {
	(void)SvOK_off(sv);
	return;
    }
    else {
        /* len is STRLEN which is unsigned, need to copy to signed */
	const IV iv = len;
	if (iv < 0)
	    Perl_croak(aTHX_ "panic: sv_setpvn called with negative strlen");
    }
    SvUPGRADE(sv, SVt_PV);

    dptr = SvGROW(sv, len + 1);
    Move(ptr,dptr,len,char);
    dptr[len] = '\0';
    SvCUR_set(sv, len);
    (void)SvPOK_only(sv);		/* validate pointer */
}

/*
=for apidoc sv_setpvn_mg

Like C<sv_setpvn>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_setpvn_mg(pTHX_ register SV *const sv, register const char *const ptr, register const STRLEN len)
{
    PERL_ARGS_ASSERT_SV_SETPVN_MG;

    sv_setpvn(sv,ptr,len);
    SvSETMAGIC(sv);
}

/*
=for apidoc sv_setpv

Copies a string into an SV.  The string must be null-terminated.  Does not
handle 'set' magic.  See C<sv_setpv_mg>.

=cut
*/

void
Perl_sv_setpv(pTHX_ register SV *const sv, register const char *const ptr)
{
    dVAR;
    register STRLEN len;

    PERL_ARGS_ASSERT_SV_SETPV;

    SV_CHECK_THINKFIRST_COW_DROP(sv);
    if (!ptr) {
	(void)SvOK_off(sv);
	return;
    }
    len = strlen(ptr);
    SvUPGRADE(sv, SVt_PV);

    SvGROW(sv, len + 1);
    Move(ptr,SvPVX_mutable(sv),len+1,char);
    SvCUR_set(sv, len);
    (void)SvPOK_only(sv);		/* validate pointer */
}

/*
=for apidoc sv_setpv_mg

Like C<sv_setpv>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_setpv_mg(pTHX_ register SV *const sv, register const char *const ptr)
{
    PERL_ARGS_ASSERT_SV_SETPV_MG;

    sv_setpv(sv,ptr);
    SvSETMAGIC(sv);
}

/*
=for apidoc sv_usepvn_flags

Tells an SV to use C<ptr> to find its string value.  Normally the
string is stored inside the SV but sv_usepvn allows the SV to use an
outside string.  The C<ptr> should point to memory that was allocated
by C<malloc>.  The string length, C<len>, must be supplied.  By default
this function will realloc (i.e. move) the memory pointed to by C<ptr>,
so that pointer should not be freed or used by the programmer after
giving it to sv_usepvn, and neither should any pointers from "behind"
that pointer (e.g. ptr + 1) be used.

If C<flags> & SV_SMAGIC is true, will call SvSETMAGIC. If C<flags> &
SV_HAS_TRAILING_NUL is true, then C<ptr[len]> must be NUL, and the realloc
will be skipped. (i.e. the buffer is actually at least 1 byte longer than
C<len>, and already meets the requirements for storing in C<SvPVX>)

=cut
*/

void
Perl_sv_usepvn_flags(pTHX_ SV *const sv, char *ptr, const STRLEN len, const U32 flags)
{
    dVAR;
    STRLEN allocate;

    PERL_ARGS_ASSERT_SV_USEPVN_FLAGS;

    SV_CHECK_THINKFIRST_COW_DROP(sv);
    SvUPGRADE(sv, SVt_PV);
    if (!ptr) {
	(void)SvOK_off(sv);
	if (flags & SV_SMAGIC)
	    SvSETMAGIC(sv);
	return;
    }
    if (SvPVX_const(sv))
	SvPV_free(sv);

#ifdef DEBUGGING
    if (flags & SV_HAS_TRAILING_NUL)
	assert(ptr[len] == '\0');
#endif

    allocate = (flags & SV_HAS_TRAILING_NUL)
	? len + 1 :
#ifdef Perl_safesysmalloc_size
	len + 1;
#else 
	PERL_STRLEN_ROUNDUP(len + 1);
#endif
    if (flags & SV_HAS_TRAILING_NUL) {
	/* It's long enough - do nothing.
	   Specfically Perl_newCONSTSUB is relying on this.  */
    } else {
#ifdef DEBUGGING
	/* Force a move to shake out bugs in callers.  */
	char *new_ptr = (char*)safemalloc(allocate);
	Copy(ptr, new_ptr, len, char);
	PoisonFree(ptr,len,char);
	Safefree(ptr);
	ptr = new_ptr;
#else
	ptr = (char*) saferealloc (ptr, allocate);
#endif
    }
#ifdef Perl_safesysmalloc_size
    SvLEN_set(sv, Perl_safesysmalloc_size(ptr));
#else
    SvLEN_set(sv, allocate);
#endif
    SvCUR_set(sv, len);
    SvPV_set(sv, ptr);
    if (!(flags & SV_HAS_TRAILING_NUL)) {
	ptr[len] = '\0';
    }
    (void)SvPOK_only(sv);		/* validate pointer */
    if (flags & SV_SMAGIC)
	SvSETMAGIC(sv);
}

#ifdef PERL_OLD_COPY_ON_WRITE
/* Need to do this *after* making the SV normal, as we need the buffer
   pointer to remain valid until after we've copied it.  If we let go too early,
   another thread could invalidate it by unsharing last of the same hash key
   (which it can do by means other than releasing copy-on-write Svs)
   or by changing the other copy-on-write SVs in the loop.  */
STATIC void
S_sv_release_COW(pTHX_ register SV *sv, const char *pvx, SV *after)
{
    PERL_ARGS_ASSERT_SV_RELEASE_COW;

    { /* this SV was SvIsCOW_normal(sv) */
         /* we need to find the SV pointing to us.  */
        SV *current = SV_COW_NEXT_SV(after);

        if (current == sv) {
            /* The SV we point to points back to us (there were only two of us
               in the loop.)
               Hence other SV is no longer copy on write either.  */
            SvFAKE_off(after);
            SvREADONLY_off(after);
        } else {
            /* We need to follow the pointers around the loop.  */
            SV *next;
            while ((next = SV_COW_NEXT_SV(current)) != sv) {
                assert (next);
                current = next;
                 /* don't loop forever if the structure is bust, and we have
                    a pointer into a closed loop.  */
                assert (current != after);
                assert (SvPVX_const(current) == pvx);
            }
            /* Make the SV before us point to the SV after us.  */
            SV_COW_NEXT_SV_SET(current, after);
        }
    }
}
#endif
/*
=for apidoc sv_force_normal_flags

Undo various types of fakery on an SV: if the PV is a shared string, make
a private copy; if we're a ref, stop refing; if we're a glob, downgrade to
an xpvmg; if we're a copy-on-write scalar, this is the on-write time when
we do the copy, and is also used locally. If C<SV_COW_DROP_PV> is set
then a copy-on-write scalar drops its PV buffer (if any) and becomes
SvPOK_off rather than making a copy. (Used where this scalar is about to be
set to some other value.) In addition, the C<flags> parameter gets passed to
C<sv_unref_flags()> when unrefing. C<sv_force_normal> calls this function
with flags set to 0.

=cut
*/

void
Perl_sv_force_normal_flags(pTHX_ register SV *const sv, const U32 flags)
{
    dVAR;

    PERL_ARGS_ASSERT_SV_FORCE_NORMAL_FLAGS;

#ifdef PERL_OLD_COPY_ON_WRITE
    if (SvREADONLY(sv)) {
	if (SvFAKE(sv)) {
	    const char * const pvx = SvPVX_const(sv);
	    const STRLEN len = SvLEN(sv);
	    const STRLEN cur = SvCUR(sv);
	    /* next COW sv in the loop.  If len is 0 then this is a shared-hash
	       key scalar, so we mustn't attempt to call SV_COW_NEXT_SV(), as
	       we'll fail an assertion.  */
	    SV * const next = len ? SV_COW_NEXT_SV(sv) : 0;

            if (DEBUG_C_TEST) {
                PerlIO_printf(Perl_debug_log,
                              "Copy on write: Force normal %ld\n",
                              (long) flags);
                sv_dump(sv);
            }
            SvFAKE_off(sv);
            SvREADONLY_off(sv);
            /* This SV doesn't own the buffer, so need to Newx() a new one:  */
            SvPV_set(sv, NULL);
            SvLEN_set(sv, 0);
            if (flags & SV_COW_DROP_PV) {
                /* OK, so we don't need to copy our buffer.  */
                SvPOK_off(sv);
            } else {
                SvGROW(sv, cur + 1);
                Move(pvx,SvPVX_mutable(sv),cur,char);
                SvCUR_set(sv, cur);
                *SvEND(sv) = '\0';
            }
	    if (len) {
		sv_release_COW(sv, pvx, next);
	    } else {
		unshare_hek(SvSHARED_HEK_FROM_PV(pvx));
	    }
            if (DEBUG_C_TEST) {
                sv_dump(sv);
            }
	}
	else if (IN_PERL_RUNTIME)
	    Perl_croak(aTHX_ "%s", PL_no_modify);
    }
#else
    if (SvREADONLY(sv)) {
	if (SvFAKE(sv)) {
	    const char * const pvx = SvPVX_const(sv);
	    const STRLEN len = SvCUR(sv);
	    SvFAKE_off(sv);
	    SvREADONLY_off(sv);
	    SvPV_set(sv, NULL);
	    SvLEN_set(sv, 0);
	    SvGROW(sv, len + 1);
	    Move(pvx,SvPVX_mutable(sv),len,char);
	    *SvEND(sv) = '\0';
	    unshare_hek(SvSHARED_HEK_FROM_PV(pvx));
	}
	else if (IN_PERL_RUNTIME)
	    Perl_croak(aTHX_ "%s", PL_no_modify);
    }
#endif
    if (SvROK(sv))
	sv_unref_flags(sv, flags);
    else if (SvTYPE(sv) == SVt_PVGV)
	sv_unglob(sv);
}

/*
=for apidoc sv_chop

Efficient removal of characters from the beginning of the string buffer.
SvPOK(sv) must be true and the C<ptr> must be a pointer to somewhere inside
the string buffer.  The C<ptr> becomes the first character of the adjusted
string. Uses the "OOK hack".
Beware: after this function returns, C<ptr> and SvPVX_const(sv) may no longer
refer to the same chunk of data.

=cut
*/

void
Perl_sv_chop(pTHX_ register SV *const sv, register const char *const ptr)
{
    STRLEN delta;
    STRLEN old_delta;
    U8 *p;
#ifdef DEBUGGING
    const U8 *real_start;
#endif
    STRLEN max_delta;

    PERL_ARGS_ASSERT_SV_CHOP;

    if (!ptr || !SvPOKp(sv))
	return;
    delta = ptr - SvPVX_const(sv);
    if (!delta) {
	/* Nothing to do.  */
	return;
    }
    /* SvPVX(sv) may move in SV_CHECK_THINKFIRST(sv), but after this line,
       nothing uses the value of ptr any more.  */
    max_delta = SvLEN(sv) ? SvLEN(sv) : SvCUR(sv);
    if (ptr <= SvPVX_const(sv))
	Perl_croak(aTHX_ "panic: sv_chop ptr=%p, start=%p, end=%p",
		   ptr, SvPVX_const(sv), SvPVX_const(sv) + max_delta);
    SV_CHECK_THINKFIRST(sv);
    if (delta > max_delta)
	Perl_croak(aTHX_ "panic: sv_chop ptr=%p (was %p), start=%p, end=%p",
		   SvPVX_const(sv) + delta, ptr, SvPVX_const(sv),
		   SvPVX_const(sv) + max_delta);

    if (!SvOOK(sv)) {
	if (!SvLEN(sv)) { /* make copy of shared string */
	    const char *pvx = SvPVX_const(sv);
	    const STRLEN len = SvCUR(sv);
	    SvGROW(sv, len + 1);
	    Move(pvx,SvPVX_mutable(sv),len,char);
	    *SvEND(sv) = '\0';
	}
	SvFLAGS(sv) |= SVf_OOK;
	old_delta = 0;
    } else {
	SvOOK_offset(sv, old_delta);
    }
    SvLEN_set(sv, SvLEN(sv) - delta);
    SvCUR_set(sv, SvCUR(sv) - delta);
    SvPV_set(sv, SvPVX_mutable(sv) + delta);

    p = (U8 *)SvPVX_const(sv);

    delta += old_delta;

#ifdef DEBUGGING
    real_start = p - delta;
#endif

    assert(delta);
    if (delta < 0x100) {
	*--p = (U8) delta;
    } else {
	*--p = 0;
	p -= sizeof(STRLEN);
	Copy((U8*)&delta, p, sizeof(STRLEN), U8);
    }

#ifdef DEBUGGING
    /* Fill the preceding buffer with sentinals to verify that no-one is
       using it.  */
    while (p > real_start) {
	--p;
	*p = (U8)PTR2UV(p);
    }
#endif
}

/*
=for apidoc sv_catpvn

Concatenates the string onto the end of the string which is in the SV.  The
C<len> indicates number of bytes to copy.  If the SV has the UTF-8
status set, then the bytes appended should be valid UTF-8.
Handles 'get' magic, but not 'set' magic.  See C<sv_catpvn_mg>.

=for apidoc sv_catpvn_flags

Concatenates the string onto the end of the string which is in the SV.  The
C<len> indicates number of bytes to copy.  If the SV has the UTF-8
status set, then the bytes appended should be valid UTF-8.
C<sv_catpvn> and C<sv_catpvn_nomg> are implemented
in terms of this function.

=cut
*/

void
Perl_sv_catpvn_flags(pTHX_ register SV *const dsv, register const char *sstr, register const STRLEN slen, const I32 flags)
{
    dVAR;
    STRLEN dlen;
    const char * const dstr = SvPV_force_flags(dsv, dlen, flags);

    PERL_ARGS_ASSERT_SV_CATPVN_FLAGS;

    SvGROW(dsv, dlen + slen + 1);
    if (sstr == dstr)
	sstr = SvPVX_const(dsv);
    Move(sstr, SvPVX_mutable(dsv) + dlen, slen, char);
    SvCUR_set(dsv, SvCUR(dsv) + slen);
    *SvEND(dsv) = '\0';
    (void)SvPOK_only(dsv);		/* validate pointer */
    if (flags & SV_SMAGIC)
	SvSETMAGIC(dsv);
}

/*
=for apidoc sv_catsv

Concatenates the string from SV C<ssv> onto the end of the string in
SV C<dsv>.  Modifies C<dsv> but not C<ssv>.  Handles 'get' magic, but
not 'set' magic.  See C<sv_catsv_mg>.

=for apidoc sv_catsv_flags

Concatenates the string from SV C<ssv> onto the end of the string in
SV C<dsv>.  Modifies C<dsv> but not C<ssv>. C<sv_catsv>
and C<sv_catsv_nomg> are implemented in terms of this function.

=cut */

void
Perl_sv_catsv_flags(pTHX_ SV *const dsv, register SV *const ssv, const I32 flags)
{
    dVAR;
 
    PERL_ARGS_ASSERT_SV_CATSV_FLAGS;

   if (ssv) {
	STRLEN slen;
	const char *spv = SvPV_const(ssv, slen);
	if (spv) {
	    sv_catpvn_nomg(dsv, spv, slen);
	}
    }
    if (flags & SV_SMAGIC)
	SvSETMAGIC(dsv);
}

/*
=for apidoc sv_catpv

Concatenates the string onto the end of the string which is in the SV.
If the SV has the UTF-8 status set, then the bytes appended should be
valid UTF-8.  Handles 'get' magic, but not 'set' magic.  See C<sv_catpv_mg>.

=cut */

void
Perl_sv_catpv(pTHX_ register SV *const sv, register const char *ptr)
{
    dVAR;
    register STRLEN len;
    STRLEN tlen;
    char *junk;

    PERL_ARGS_ASSERT_SV_CATPV;

    if (!ptr)
	return;
    junk = SvPV_force(sv, tlen);
    len = strlen(ptr);
    SvGROW(sv, tlen + len + 1);
    if (ptr == junk)
	ptr = SvPVX_const(sv);
    Move(ptr,SvPVX_mutable(sv)+tlen,len+1,char);
    SvCUR_set(sv, SvCUR(sv) + len);
    (void)SvPOK_only(sv);		/* validate pointer */
}

/*
=for apidoc sv_catpv_mg

Like C<sv_catpv>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_catpv_mg(pTHX_ register SV *const sv, register const char *const ptr)
{
    PERL_ARGS_ASSERT_SV_CATPV_MG;

    sv_catpv(sv,ptr);
    SvSETMAGIC(sv);
}

/*
=for apidoc newSV

Creates a new SV.  A non-zero C<len> parameter indicates the number of
bytes of preallocated string space the SV should have.  An extra byte for a
trailing NUL is also reserved.  (SvPOK is not set for the SV even if string
space is allocated.)  The reference count for the new SV is set to 1.

In 5.9.3, newSV() replaces the older NEWSV() API, and drops the first
parameter, I<x>, a debug aid which allowed callers to identify themselves.
This aid has been superseded by a new build option, PERL_MEM_LOG (see
L<perlhack/PERL_MEM_LOG>).  The older API is still there for use in XS
modules supporting older perls.

=cut
*/

SV *
Perl_newSV(pTHX_ const STRLEN len)
{
    dVAR;
    register SV *sv;

    new_SV(sv);
    if (len) {
	sv_upgrade(sv, SVt_PV);
	SvGROW(sv, len + 1);
    }
    return sv;
}
/*
=for apidoc sv_magicext

Adds magic to an SV, upgrading it if necessary. Applies the
supplied vtable and returns a pointer to the magic added.

Note that C<sv_magicext> will allow things that C<sv_magic> will not.
In particular, you can add magic to SvREADONLY SVs, and add more than
one instance of the same 'how'.

If C<namlen> is greater than zero then a C<savepvn> I<copy> of C<name> is
stored, if C<namlen> is zero then C<name> is stored as-is and - as another
special case - if C<(name && namlen == HEf_SVKEY)> then C<name> is assumed
to contain an C<SV*> and is stored as-is with its REFCNT incremented.

(This is now used as a subroutine by C<sv_magic>.)

=cut
*/
MAGIC *	
Perl_sv_magicext(pTHX_ SV *const sv, SV *const obj, const int how, 
                const MGVTBL *const vtable, const char *const name, const I32 namlen)
{
    dVAR;
    MAGIC* mg;

    PERL_ARGS_ASSERT_SV_MAGICEXT;

    SvUPGRADE(sv, SVt_PVMG);
    Newxz(mg, 1, MAGIC);
    mg->mg_moremagic = SvMAGIC(sv);
    SvMAGIC_set(sv, mg);

    /* Sometimes a magic contains a reference loop, where the sv and
       object refer to each other.  To prevent a reference loop that
       would prevent such objects being freed, we look for such loops
       and if we find one we avoid incrementing the object refcount.

       Note we cannot do this to avoid self-tie loops as intervening RV must
       have its REFCNT incremented to keep it in existence.

    */
    if (!obj || obj == sv ||
	how == PERL_MAGIC_symtab ||
	(SvTYPE(obj) == SVt_PVGV &&
	    (GvSV(obj) == sv || GvHV(obj) == (HV*)sv || GvAV(obj) == (AV*)sv ||
	    GvCV(obj) == (CV*)sv || GvIOp(obj) == (IO*)sv)))
    {
	mg->mg_obj = obj;
    }
    else {
	mg->mg_obj = SvREFCNT_inc(obj);
	mg->mg_flags |= MGf_REFCOUNTED;
    }

    mg->mg_type = how;
    mg->mg_len = namlen;
    if (name) {
	if (namlen > 0)
	    mg->mg_ptr = savepvn(name, namlen);
	else if (namlen == HEf_SVKEY)
	    mg->mg_ptr = (char*)SvREFCNT_inc_NN((SV*)name);
	else
	    mg->mg_ptr = (char *) name;
    }
    mg->mg_virtual = (MGVTBL *) vtable;

    mg_magical(sv);
    return mg;
}

/*
=for apidoc sv_magic

Adds magic to an SV. First upgrades C<sv> to type C<SVt_PVMG> if necessary,
then adds a new magic item of type C<how> to the head of the magic list.

See C<sv_magicext> (which C<sv_magic> now calls) for a description of the
handling of the C<name> and C<namlen> arguments.

You need to use C<sv_magicext> to add magic to SvREADONLY SVs and also
to add more than one instance of the same 'how'.

=cut
*/

void
Perl_sv_magic(pTHX_ register SV *const sv, SV *const obj, const int how, 
             const char *const name, const I32 namlen)
{
    dVAR;
    const MGVTBL *vtable;
    MAGIC* mg;

    PERL_ARGS_ASSERT_SV_MAGIC;

#ifdef PERL_OLD_COPY_ON_WRITE
    if (SvIsCOW(sv))
        sv_force_normal_flags(sv, 0);
#endif
    if (SvREADONLY(sv)) {
	if (
	    /* its okay to attach magic to shared strings; the subsequent
	     * upgrade to PVMG will unshare the string */
	    !(SvFAKE(sv) && SvTYPE(sv) < SVt_PVMG)

	    && IN_PERL_RUNTIME
	    && how != PERL_MAGIC_regex_global
	    && how != PERL_MAGIC_bm
	    && how != PERL_MAGIC_backref
	   )
	{
	    Perl_croak(aTHX_ "%s", PL_no_modify);
	}
    }
    if (SvMAGICAL(sv)) {
	if (SvMAGIC(sv) && (mg = mg_find(sv, how))) {
	    /* sv_magic() refuses to add a magic of the same 'how' as an
	       existing one
	     */
	    return;
	}
    }

    switch (how) {
    case PERL_MAGIC_bm:
	vtable = &PL_vtbl_bm;
	break;
    case PERL_MAGIC_regex_global:
	vtable = &PL_vtbl_mglob;
	break;
    case PERL_MAGIC_isa:
	vtable = &PL_vtbl_isa;
	break;
    case PERL_MAGIC_isaelem:
	vtable = &PL_vtbl_isaelem;
	break;
    case PERL_MAGIC_dbfile:
	vtable = NULL;
	break;
    case PERL_MAGIC_dbline:
	vtable = &PL_vtbl_dbline;
	break;
    case PERL_MAGIC_qr:
	vtable = &PL_vtbl_regexp;
	break;
    case PERL_MAGIC_uvar:
	vtable = &PL_vtbl_uvar;
	break;
    case PERL_MAGIC_rhash:
    case PERL_MAGIC_symtab:
    case PERL_MAGIC_vstring:
	vtable = NULL;
	break;
    case PERL_MAGIC_utf8:
	vtable = &PL_vtbl_utf8;
	break;
    case PERL_MAGIC_backref:
	vtable = &PL_vtbl_backref;
	break;
    case PERL_MAGIC_ext:
	/* Reserved for use by extensions not perl internals.	        */
	/* Useful for attaching extension internal data to perl vars.	*/
	/* Note that multiple extensions may clash if magical scalars	*/
	/* etc holding private data from one are passed to another.	*/
	vtable = NULL;
	break;
    default:
	Perl_croak(aTHX_ "Don't know how to handle magic of type \\%o", how);
    }

    /* Rest of work is done else where */
    mg = sv_magicext(sv,obj,how,vtable,name,namlen);

    switch (how) {
    case PERL_MAGIC_ext:
    case PERL_MAGIC_dbfile:
	SvRMAGICAL_on(sv);
	break;
    }
}

/*
=for apidoc sv_unmagic

Removes all magic of type C<type> from an SV.

=cut
*/

int
Perl_sv_unmagic(pTHX_ SV *const sv, const int type)
{
    MAGIC* mg;
    MAGIC** mgp;

    PERL_ARGS_ASSERT_SV_UNMAGIC;

    if (SvTYPE(sv) < SVt_PVMG || !SvMAGIC(sv))
	return 0;
    mgp = &(((XPVMG*) SvANY(sv))->xmg_u.xmg_magic);
    for (mg = *mgp; mg; mg = *mgp) {
	if (mg->mg_type == type) {
            const MGVTBL* const vtbl = mg->mg_virtual;
	    *mgp = mg->mg_moremagic;
	    if (vtbl && vtbl->svt_free)
		CALL_FPTR(vtbl->svt_free)(aTHX_ sv, mg);
	    if (mg->mg_ptr && mg->mg_type != PERL_MAGIC_regex_global) {
		if (mg->mg_len > 0)
		    Safefree(mg->mg_ptr);
		else if (mg->mg_len == HEf_SVKEY)
		    SvREFCNT_dec(MUTABLE_SV(mg->mg_ptr));
		else if (mg->mg_type == PERL_MAGIC_utf8)
		    Safefree(mg->mg_ptr);
            }
	    if (mg->mg_flags & MGf_REFCOUNTED)
		SvREFCNT_dec(mg->mg_obj);
	    Safefree(mg);
	}
	else
	    mgp = &mg->mg_moremagic;
    }
    if (!SvMAGIC(sv)) {
	SvMAGICAL_off(sv);
	SvFLAGS(sv) |= (SvFLAGS(sv) & (SVp_IOK|SVp_NOK|SVp_POK)) >> PRIVSHIFT;
	SvMAGIC_set(sv, NULL);
    }

    return 0;
}

/*
=for apidoc sv_rvweaken

Weaken a reference: set the C<SvWEAKREF> flag on this RV; give the
referred-to SV C<PERL_MAGIC_backref> magic if it hasn't already; and
push a back-reference to this RV onto the array of backreferences
associated with that magic. If the RV is magical, set magic will be
called after the RV is cleared.

=cut
*/

SV *
Perl_sv_rvweaken(pTHX_ SV *const sv)
{
    SV *tsv;

    PERL_ARGS_ASSERT_SV_RVWEAKEN;

    if (!SvOK(sv))  /* let undefs pass */
	return sv;
    if (!SvROK(sv))
	Perl_croak(aTHX_ "Can't weaken a nonreference");
    else if (SvWEAKREF(sv)) {
	if (ckWARN(WARN_MISC))
	    Perl_warner(aTHX_ packWARN(WARN_MISC), "Reference is already weak");
	return sv;
    }
    tsv = SvRV(sv);
    Perl_sv_add_backref(aTHX_ tsv, sv);
    SvWEAKREF_on(sv);
    SvREFCNT_dec(tsv);
    return sv;
}

/* Give tsv backref magic if it hasn't already got it, then push a
 * back-reference to sv onto the array associated with the backref magic.
 */

/* A discussion about the backreferences array and its refcount:
 *
 * The AV holding the backreferences is pointed to either as the mg_obj of
 * PERL_MAGIC_backref, or in the specific case of a HV that has the hv_aux
 * structure, from the xhv_backreferences field. (A HV without hv_aux will
 * have the standard magic instead.) The array is created with a refcount
 * of 2. This means that if during global destruction the array gets
 * picked on first to have its refcount decremented by the random zapper,
 * it won't actually be freed, meaning it's still theere for when its
 * parent gets freed.
 * When the parent SV is freed, in the case of magic, the magic is freed,
 * Perl_magic_killbackrefs is called which decrements one refcount, then
 * mg_obj is freed which kills the second count.
 * In the vase of a HV being freed, one ref is removed by
 * Perl_hv_kill_backrefs, the other by Perl_sv_kill_backrefs, which it
 * calls.
 */

void
Perl_sv_add_backref(pTHX_ SV *const tsv, SV *const sv)
{
    dVAR;
    AV *av;

    PERL_ARGS_ASSERT_SV_ADD_BACKREF;

    if (SvTYPE(tsv) == SVt_PVHV) {
	AV **const avp = Perl_hv_backreferences_p(aTHX_ MUTABLE_HV(tsv));

	av = *avp;
	if (!av) {
	    av = newAV();
	    AvREAL_off(av);
	    *avp = av;
	}
    } else {
	const MAGIC *const mg
	    = SvMAGICAL(tsv) ? mg_find(tsv, PERL_MAGIC_backref) : NULL;
	if (mg)
	    av = MUTABLE_AV(mg->mg_obj);
	else {
	    av = newAV();
	    AvREAL_off(av);
	    sv_magic(tsv, (SV*)av, PERL_MAGIC_backref, NULL, 0);
	    AvREFCNT_dec(av);
	}
    }
    if (AvFILLp(av) >= AvMAX(av)) {
        av_extend(av, AvFILLp(av)+1);
    }
    AvARRAY(av)[++AvFILLp(av)] = sv; /* av_push() */
}

/* delete a back-reference to ourselves from the backref magic associated
 * with the SV we point to.
 */

STATIC void
S_sv_del_backref(pTHX_ SV *const tsv, SV *const sv)
{
    dVAR;
    AV *av = NULL;
    SV **svp;
    I32 i;

    PERL_ARGS_ASSERT_SV_DEL_BACKREF;

    if (SvTYPE(tsv) == SVt_PVHV && SvOOK(tsv)) {
	av = *Perl_hv_backreferences_p(aTHX_ MUTABLE_HV(tsv));
	/* We mustn't attempt to "fix up" the hash here by moving the
	   backreference array back to the hv_aux structure, as that is stored
	   in the main HvARRAY(), and hfreentries assumes that no-one
	   reallocates HvARRAY() while it is running.  */
    }
    if (!av) {
	const MAGIC *const mg
	    = SvMAGICAL(tsv) ? mg_find(tsv, PERL_MAGIC_backref) : NULL;
	if (mg)
	    av = MUTABLE_AV(mg->mg_obj);
    }

    if (!av)
	Perl_croak(aTHX_ "panic: del_backref");

    assert(!SvIS_FREED(av));

    svp = AvARRAY(av);
    /* We shouldn't be in here more than once, but for paranoia reasons lets
       not assume this.  */
    for (i = AvFILLp(av); i >= 0; i--) {
	if (svp[i] == sv) {
	    const SSize_t fill = AvFILLp(av);
	    if (i != fill) {
		/* We weren't the last entry.
		   An unordered list has this property that you can take the
		   last element off the end to fill the hole, and it's still
		   an unordered list :-)
		*/
		svp[i] = svp[fill];
	    }
	    svp[fill] = NULL;
	    AvFILLp(av) = fill - 1;
	}
    }
}

int
Perl_sv_kill_backrefs(pTHX_ SV *const sv, AV *const av)
{
    SV **svp = AvARRAY(av);

    PERL_ARGS_ASSERT_SV_KILL_BACKREFS;
    PERL_UNUSED_ARG(sv);

    assert(!svp || !SvIS_FREED(av));
    if (svp) {
	SV *const *const last = svp + AvFILLp(av);

	while (svp <= last) {
	    if (*svp) {
		SV *const referrer = *svp;
		if (SvWEAKREF(referrer)) {
		    /* XXX Should we check that it hasn't changed? */
		    SvRV_set(referrer, 0);
		    SvOK_off(referrer);
		    SvWEAKREF_off(referrer);
		    SvSETMAGIC(referrer);
		} else if (SvTYPE(referrer) == SVt_PVGV) {
		    /* You lookin' at me?  */
		    assert(GvSTASH(referrer));
		    assert(GvSTASH(referrer) == (const HV *)sv);
		    GvSTASH(referrer) = 0;
		} else {
		    Perl_croak(aTHX_
			       "panic: magic_killbackrefs (flags=%"UVxf")",
			       (UV)SvFLAGS(referrer));
		}

		*svp = NULL;
	    }
	    svp++;
	}
    }
    return 0;
}

/*
=for apidoc sv_insert

Inserts a string at the specified offset/length within the SV. Similar to
the Perl substr() function. Handles get magic.

=for apidoc sv_insert_flags

Same as C<sv_insert>, but the extra C<flags> are passed the C<SvPV_force_flags> that applies to C<bigstr>.

=cut
*/

void
Perl_sv_insert_flags(pTHX_ SV *const bigstr, const STRLEN offset, const STRLEN len, const char *const little, const STRLEN littlelen, const U32 flags)
{
    dVAR;
    register char *big;
    register char *mid;
    register char *midend;
    register char *bigend;
    register I32 i;
    STRLEN curlen;

    PERL_ARGS_ASSERT_SV_INSERT_FLAGS;

    if (!bigstr)
	Perl_croak(aTHX_ "Can't modify non-existent substring");
    SvPV_force_flags(bigstr, curlen, flags);
    (void)SvPOK_only(bigstr);
    if (offset + len > curlen) {
	SvGROW(bigstr, offset+len+1);
	Zero(SvPVX_mutable(bigstr)+curlen, offset+len-curlen, char);
	SvCUR_set(bigstr, offset+len);
    }

    i = littlelen - len;
    if (i > 0) {			/* string might grow */
	big = SvGROW(bigstr, SvCUR(bigstr) + i + 1);
	mid = big + offset + len;
	midend = bigend = big + SvCUR(bigstr);
	bigend += i;
	*bigend = '\0';
	while (midend > mid)		/* shove everything down */
	    *--bigend = *--midend;
	Move(little,big+offset,littlelen,char);
	SvCUR_set(bigstr, SvCUR(bigstr) + i);
	SvSETMAGIC(bigstr);
	return;
    }
    else if (i == 0) {
	Move(little,SvPVX_mutable(bigstr)+offset,len,char);
	SvSETMAGIC(bigstr);
	return;
    }

    big = SvPVX_mutable(bigstr);
    mid = big + offset;
    midend = mid + len;
    bigend = big + SvCUR(bigstr);

    if (midend > bigend)
	Perl_croak(aTHX_ "panic: sv_insert");

    if (mid - big > bigend - midend) {	/* faster to shorten from end */
	if (littlelen) {
	    Move(little, mid, littlelen,char);
	    mid += littlelen;
	}
	i = bigend - midend;
	if (i > 0) {
	    Move(midend, mid, i,char);
	    mid += i;
	}
	*mid = '\0';
	SvCUR_set(bigstr, mid - big);
    }
    else if ((i = mid - big)) {	/* faster from front */
	midend -= littlelen;
	mid = midend;
	Move(big, midend - i, i, char);
	sv_chop(bigstr,midend-i);
	if (littlelen)
	    Move(little, mid, littlelen,char);
    }
    else if (littlelen) {
	midend -= littlelen;
	sv_chop(bigstr,midend);
	Move(little,midend,littlelen,char);
    }
    else {
	sv_chop(bigstr,midend);
    }
    SvSETMAGIC(bigstr);
}

/*
=for apidoc sv_replace

Make the first argument a copy of the second, then delete the original.
The target SV physically takes over ownership of the body of the source SV
and inherits its flags; however, the target keeps any magic it owns,
and any magic in the source is discarded.
Note that this is a rather specialist SV copying operation; most of the
time you'll want to use C<sv_setsv> or one of its many macro front-ends.

=cut
*/

void
Perl_sv_replace(pTHX_ register SV *const sv, register SV *const nsv)
{
    dVAR;
    const U32 refcnt = SvREFCNT(sv);

    PERL_ARGS_ASSERT_SV_REPLACE;

    SV_CHECK_THINKFIRST_COW_DROP(sv);
    if (SvREFCNT(nsv) != 1) {
	Perl_croak(aTHX_ "panic: reference miscount on nsv in sv_replace()"
		   " (%" UVuf " != 1)", (UV) SvREFCNT(nsv));
    }
    if (SvMAGICAL(sv)) {
	if (SvMAGICAL(nsv))
	    mg_free(nsv);
	else
	    sv_upgrade(nsv, SVt_PVMG);
	SvMAGIC_set(nsv, SvMAGIC(sv));
	SvFLAGS(nsv) |= SvMAGICAL(sv);
	SvMAGICAL_off(sv);
	SvMAGIC_set(sv, NULL);
    }
    SvREFCNT(sv) = 0;
    sv_clear(sv);
    assert(!SvREFCNT(sv));
    StructCopy(nsv,sv,SV);
    if(SvTYPE(sv) == SVt_IV) {
	SvANY(sv)
	    = (XPVIV*)((char*)&(sv->sv_u.svu_iv) - STRUCT_OFFSET(XPVIV, xiv_iv));
    }
	

#ifdef PERL_OLD_COPY_ON_WRITE
    if (SvIsCOW_normal(nsv)) {
	/* We need to follow the pointers around the loop to make the
	   previous SV point to sv, rather than nsv.  */
	SV *next;
	SV *current = nsv;
	while ((next = SV_COW_NEXT_SV(current)) != nsv) {
	    assert(next);
	    current = next;
	    assert(SvPVX_const(current) == SvPVX_const(nsv));
	}
	/* Make the SV before us point to the SV after us.  */
	if (DEBUG_C_TEST) {
	    PerlIO_printf(Perl_debug_log, "previous is\n");
	    sv_dump(current);
	    PerlIO_printf(Perl_debug_log,
                          "move it from 0x%"UVxf" to 0x%"UVxf"\n",
			  (UV) SV_COW_NEXT_SV(current), (UV) sv);
	}
	SV_COW_NEXT_SV_SET(current, sv);
    }
#endif
    SvREFCNT(sv) = refcnt;
    SvFLAGS(nsv) |= SVTYPEMASK;		/* Mark as freed */
    SvREFCNT(nsv) = 0;
    del_SV(nsv);
}

/*
=for apidoc sv_clear

Clear an SV: call any destructors, free up any memory used by the body,
and free the body itself. The SV's head is I<not> freed, although
its type is set to all 1's so that it won't inadvertently be assumed
to be live during global destruction etc.
This function should only be called when REFCNT is zero. Most of the time
you'll want to call C<sv_free()> (or its macro wrapper C<SvREFCNT_dec>)
instead.

=cut

=pod sv_clear_body

clears the sv, except keep the object

=cut

*/

void
Perl_sv_clear_body(pTHX_ SV *const sv)
{
    dVAR;
    const U32 type = SvTYPE(sv);
    const struct body_details *const sv_type_details
	= bodies_by_type + type;
    HV *stash;
    PERL_ARGS_ASSERT_SV_CLEAR_BODY;

    if (type <= SVt_IV) {
	/* See the comment in sv.h about the collusion between this early
	   return and the overloading of the NULL and IV slots in the size
	   table.  */
	if (SvROK(sv)) {
	    SV * const target = SvRV(sv);
	    if (SvWEAKREF(sv))
	        sv_del_backref(target, sv);
	    else
	        SvREFCNT_dec(target);
	}
	SvFLAGS(sv) = SVt_NULL;
	return;
    }

    if (type == SVt_PVCV) {
	if ( CvN_ADD_REFS(sv) ) {
	    --CvN_ADD_REFS(sv);
	    SvFLAGS(sv) = SVt_NULL;
	    return;
	}
    }

    if (type >= SVt_PVMG) {
	if (type == SVt_PVMG && SvPAD_OUR(sv)) {
	    GvREFCNT_dec(SvOURGV(sv));
	} else if (SvMAGIC(sv))
	    mg_free(sv);
    }
    switch (type) {
	/* case SVt_BIND: */
    case SVt_PVIO:
	if (IoIFP(sv) &&
	    IoIFP(sv) != PerlIO_stdin() &&
	    IoIFP(sv) != PerlIO_stdout() &&
	    IoIFP(sv) != PerlIO_stderr())
	{
	    io_close(MUTABLE_IO(sv), FALSE);
	}
	if (IoDIRP(sv) && !(IoFLAGS(sv) & IOf_FAKE_DIRP))
	    PerlDir_close(IoDIRP(sv));
	IoDIRP(sv) = (DIR*)NULL;
	goto freescalar;
    case SVt_REGEXP:
	/* FIXME for plugins */
	pregfree2((REGEXP*) sv);
	goto freescalar;
    case SVt_PVCV:
	cv_undef(MUTABLE_CV(sv));
	break;
    case SVt_PVHV:
	Perl_hv_kill_backrefs(aTHX_ MUTABLE_HV(sv));
	hv_undef(MUTABLE_HV(sv));
	break;
    case SVt_PVAV:
	av_undef(MUTABLE_AV(sv));
	break;
    case SVt_PVGV:
	if (isGV_with_GP(sv)) {
            if(GvCVu((const GV *)sv) && (stash = GvSTASH(MUTABLE_GV(sv)))
	       && HvNAME_get(stash))
                mro_method_changed_in(stash);
	    gp_free(MUTABLE_GV(sv));
	    if (GvNAME_HEK(sv))
		unshare_hek(GvNAME_HEK(sv));
	    /* If we're in a stash, we don't own a reference to it. However it does
	       have a back reference to us, which needs to be cleared.  */
	    if (!SvVALID(sv) && (stash = GvSTASH(sv)))
		    sv_del_backref(MUTABLE_SV(stash), sv);
	}
    case SVt_PVMG:
    case SVt_PVNV:
    case SVt_PVIV:
    case SVt_PV:
      freescalar:
	/* Don't bother with SvOOK_off(sv); as we're only going to free it.  */
	if (SvOOK(sv)) {
	    STRLEN offset;
	    SvOOK_offset(sv, offset);
	    SvPV_set(sv, SvPVX_mutable(sv) - offset);
	    /* Don't even bother with turning off the OOK flag.  */
	}
	if (SvROK(sv)) {
	    SV * const target = SvRV(sv);
	    if (SvWEAKREF(sv))
	        sv_del_backref(target, sv);
	    else
	        SvREFCNT_dec(target);
	}
#ifdef PERL_OLD_COPY_ON_WRITE
	else if (SvPVX_const(sv)) {
            if (SvIsCOW(sv)) {
                if (DEBUG_C_TEST) {
                    PerlIO_printf(Perl_debug_log, "Copy on write: clear\n");
                    sv_dump(sv);
                }
		if (SvLEN(sv)) {
		    sv_release_COW(sv, SvPVX_const(sv), SV_COW_NEXT_SV(sv));
		} else {
		    unshare_hek(SvSHARED_HEK_FROM_PV(SvPVX_const(sv)));
		}

                SvFAKE_off(sv);
            } else if (SvLEN(sv)) {
                Safefree(SvPVX_const(sv));
            }
	}
#else
	else if (I_SvPVX(sv) && SvLEN(sv))
	    Safefree(I_SvPVX(sv));
	else if (I_SvPVX(sv) && SvREADONLY(sv) && SvFAKE(sv)) {
	    unshare_hek(SvSHARED_HEK_FROM_PV(I_SvPVX(sv)));
	    SvFAKE_off(sv);
	}
#endif
	break;
    case SVt_NV:
	break;
    }

    if (sv_type_details->arena) {
	del_body(((char *)SvANY(sv) + sv_type_details->offset),
		 &PL_body_roots[type]);
    }
    else if (sv_type_details->body_size) {
	my_safefree(SvANY(sv));
    }

    SvFLAGS(sv) = SVt_NULL;
}

void
Perl_call_destructors(pTHX) {
    AV* destroyav = av_2mortal(PL_destroyav);
    PL_destroyav = NULL;

    while (av_len(destroyav) != -1) {
	dSP;

	ENTER_named("call_destructor");
	SAVETMPS;

	{
	    SV* sv = sv_2mortal(av_shift(destroyav));
	    SV* destructor = sv_2mortal(av_shift(destroyav));

	    PUSHSTACKi(PERLSI_DESTROY);
	    EXTEND(SP, 2);
	    PUSHMARK(SP);
	    mPUSHs(newRV(sv));
	    PUTBACK;
	    call_sv(destructor, G_DISCARD|G_EVAL|G_KEEPERR|G_VOID);
		
	    POPSTACK;
	    SPAGAIN;

	    if (SvOBJECT(sv)) {
		HvREFCNT_dec(SvSTASH(sv));	/* possibly of changed persuasion */
		SvOBJECT_off(sv);	/* Curse the object. */
		if (SvTYPE(sv) != SVt_PVIO)
		    --PL_sv_objcount;	/* XXX Might want something more general */
	    }

	}

	FREETMPS;
	LEAVE_named("call_destructor");
    }
}

void
Perl_sv_clear(pTHX_ register SV *const sv)
{
    dVAR;

    PERL_ARGS_ASSERT_SV_CLEAR;
    assert(SvREFCNT(sv) == 0);
    assert(SvTYPE(sv) != SVTYPEMASK);

    if (SvOBJECT(sv)) {
	if (PL_defstash) {		/* Still have a symbol table? */
	    CV* destructor = gv_fetchmethod(SvSTASH(sv), "DESTROY");
	    if (destructor) {
		if ( ! PL_destroyav )
		    PL_destroyav = newAV();
		av_push(PL_destroyav, SvREFCNT_inc(sv));
		av_push(PL_destroyav, SvREFCNT_inc(cvTsv(destructor)));
		return;
	    }
	}

	if (SvOBJECT(sv)) {
	    HvREFCNT_dec(SvSTASH(sv));	/* possibly of changed persuasion */
	    SvOBJECT_off(sv);	/* Curse the object. */
	    if (SvTYPE(sv) != SVt_PVIO)
		--PL_sv_objcount;	/* XXX Might want something more general */
	}
    }

    Perl_sv_clear_body(aTHX_ sv);
    SvFLAGS(sv) &= SVf_BREAK;
    SvFLAGS(sv) |= SVTYPEMASK;
    SVcpNULL(SvLOCATION(sv));
}

/*
=for apidoc sv_newref

Increment an SV's reference count. Use the C<SvREFCNT_inc()> wrapper
instead.

=cut
*/

SV *
Perl_sv_newref(pTHX_ SV *const sv)
{
    PERL_UNUSED_CONTEXT;
    if (sv)
	(SvREFCNT(sv))++;
    return sv;
}

/*
=for apidoc sv_free

Decrement an SV's reference count, and if it drops to zero, call
C<sv_clear> to invoke destructors and free up any memory used by
the body; finally, deallocate the SV's head itself.
Normally called via a wrapper macro C<SvREFCNT_dec>.

=cut
*/

void
Perl_sv_free(pTHX_ SV *const sv)
{
    dVAR;
    if (!sv)
	return;
    if (SvREFCNT(sv) == 0) {
	if (SvFLAGS(sv) & SVf_BREAK)
	    /* this SV's refcnt has been artificially decremented to
	     * trigger cleanup */
	    return;
	if (PL_in_clean_all) /* All is fair */
	    return;
	if (SvREADONLY(sv) && SvIMMORTAL(sv)) {
	    /* make sure SvREFCNT(sv)==0 happens very seldom */
	    SvREFCNT(sv) = (~(U32)0)/2;
	    return;
	}
	if (ckWARN_d(WARN_INTERNAL)) {
	    /* This may not return:  */
	    Perl_warner(aTHX_ packWARN(WARN_INTERNAL),
                        "Attempt to free unreferenced scalar: SV 0x%"UVxf
                        pTHX__FORMAT, PTR2UV(sv) pTHX__VALUE);
	}
	return;
    }
    if (--(SvREFCNT(sv)) > 0)
	return;
    Perl_sv_free2(aTHX_ sv);
}

void
Perl_sv_free2(pTHX_ SV *const sv)
{
    dVAR;

    PERL_ARGS_ASSERT_SV_FREE2;

#ifdef DEBUGGING
    if (SvTEMP(sv)) {
	if (ckWARN_d(WARN_DEBUGGING))
	    Perl_warner(aTHX_ packWARN(WARN_DEBUGGING),
			"Attempt to free temp prematurely: SV 0x%"UVxf
                        pTHX__FORMAT, PTR2UV(sv) pTHX__VALUE);
	return;
    }
#endif
    if (SvREADONLY(sv) && SvIMMORTAL(sv)) {
	/* make sure SvREFCNT(sv)==0 happens very seldom */
	SvREFCNT(sv) = (~(U32)0)/2;
	return;
    }
    sv_clear(sv);
    if (SvREFCNT(sv) == 0) {
	del_SV(sv);
    }
}

/*
=for apidoc sv_len

Returns the length of the string in the SV. Handles magic and type
coercion.  See also C<SvCUR>, which gives raw access to the xpv_cur slot.

=cut
*/

STRLEN
Perl_sv_len(pTHX_ register SV *const sv)
{
    STRLEN len;

    if (!sv)
	return 0;

    (void)SvPV_const(sv, len);
    return len;
}

/*
=for apidoc sv_len_utf8

Returns the number of characters in the string in an SV, counting wide
UTF-8 bytes as a single character. Handles magic and type coercion.

=cut
*/

/*
 * The length is cached in PERL_UTF8_magic, in the mg_len field.  Also the
 * mg_ptr is used, by sv_pos_u2b() and sv_pos_b2u() - see the comments below.
 * (Note that the mg_len is not the length of the mg_ptr field.
 * This allows the cache to store the character length of the string without
 * needing to malloc() extra storage to attach to the mg_ptr.)
 *
 */

STRLEN
Perl_sv_len_utf8(pTHX_ register SV *const sv)
{
    if (!sv)
	return 0;

    {
	STRLEN len;
	const char *s = SvPV_const(sv, len);

	if (PL_utf8cache) {
	    STRLEN ulen;
	    MAGIC *mg = SvMAGICAL(sv) ? mg_find(sv, PERL_MAGIC_utf8) : NULL;

	    if (mg && mg->mg_len != -1) {
		ulen = mg->mg_len;
		if (PL_utf8cache < 0) {
		    const STRLEN real = Perl_utf8_length(aTHX_ s, s + len);
		    if (real != ulen) {
			/* Need to turn the assertions off otherwise we may
			   recurse infinitely while printing error messages.
			*/
			SAVEI8(PL_utf8cache);
			PL_utf8cache = 0;
			Perl_croak(aTHX_ "panic: sv_len_utf8 cache %"UVuf
				   " real %"UVuf" for %"SVf,
				   (UV) ulen, (UV) real, SVfARG(sv));
		    }
		}
	    }
	    else {
		ulen = Perl_utf8_length(aTHX_ s, s + len);
		if (!SvREADONLY(sv)) {
		    if (!mg) {
			mg = sv_magicext(sv, 0, PERL_MAGIC_utf8,
					 &PL_vtbl_utf8, 0, 0);
		    }
		    assert(mg);
		    mg->mg_len = ulen;
		}
	    }
	    return ulen;
	}
	return Perl_utf8_length(aTHX_ s, s + len);
    }
}

/* Walk forwards to find the byte corresponding to the passed in UTF-8
   offset.  */
static STRLEN
S_sv_pos_u2b_forwards(const char *const start, const char *const send,
		      STRLEN uoffset)
{
    const char *s = start;

    PERL_ARGS_ASSERT_SV_POS_U2B_FORWARDS;

    while (s < send && uoffset--)
	s += UTF8SKIP(s);
    if (s > send) {
	/* This is the existing behaviour. Possibly it should be a croak, as
	   it's actually a bounds error  */
	s = send;
    }
    return s - start;
}

/* Given the length of the string in both bytes and UTF-8 characters, decide
   whether to walk forwards or backwards to find the byte corresponding to
   the passed in UTF-8 offset.  */
static STRLEN
S_sv_pos_u2b_midway(const char *const start, const char *send,
		      const STRLEN uoffset, const STRLEN uend)
{
    STRLEN backw = uend - uoffset;

    PERL_ARGS_ASSERT_SV_POS_U2B_MIDWAY;

    if (uoffset < 2 * backw) {
	/* The assumption is that going forwards is twice the speed of going
	   forward (that's where the 2 * backw comes from).
	   (The real figure of course depends on the UTF-8 data.)  */
	return sv_pos_u2b_forwards(start, send, uoffset);
    }

    while (backw--) {
	send--;
	while (UTF8_IS_CONTINUATION(*send))
	    send--;
    }
    return send - start;
}

/* For the string representation of the given scalar, find the byte
   corresponding to the passed in UTF-8 offset.  uoffset0 and boffset0
   give another position in the string, *before* the sought offset, which
   (which is always true, as 0, 0 is a valid pair of positions), which should
   help reduce the amount of linear searching.
   If *mgp is non-NULL, it should point to the UTF-8 cache magic, which
   will be used to reduce the amount of linear searching. The cache will be
   created if necessary, and the found value offered to it for update.  */
static STRLEN
S_sv_pos_u2b_cached(pTHX_ SV *const sv, MAGIC **const mgp, const char *const start,
		    const char *const send, const STRLEN uoffset,
		    STRLEN uoffset0, STRLEN boffset0)
{
    STRLEN boffset = 0; /* Actually always set, but let's keep gcc happy.  */
    bool found = FALSE;

    PERL_ARGS_ASSERT_SV_POS_U2B_CACHED;

    assert (uoffset >= uoffset0);

    if (SvMAGICAL(sv) && !SvREADONLY(sv) && PL_utf8cache
	&& (*mgp || (*mgp = mg_find(sv, PERL_MAGIC_utf8)))) {
	if ((*mgp)->mg_ptr) {
	    STRLEN *cache = (STRLEN *) (*mgp)->mg_ptr;
	    if (cache[0] == uoffset) {
		/* An exact match. */
		return cache[1];
	    }
	    if (cache[2] == uoffset) {
		/* An exact match. */
		return cache[3];
	    }

	    if (cache[0] < uoffset) {
		/* The cache already knows part of the way.   */
		if (cache[0] > uoffset0) {
		    /* The cache knows more than the passed in pair  */
		    uoffset0 = cache[0];
		    boffset0 = cache[1];
		}
		if ((*mgp)->mg_len != -1) {
		    /* And we know the end too.  */
		    boffset = boffset0
			+ sv_pos_u2b_midway(start + boffset0, send,
					      uoffset - uoffset0,
					      (*mgp)->mg_len - uoffset0);
		} else {
		    boffset = boffset0
			+ sv_pos_u2b_forwards(start + boffset0,
						send, uoffset - uoffset0);
		}
	    }
	    else if (cache[2] < uoffset) {
		/* We're between the two cache entries.  */
		if (cache[2] > uoffset0) {
		    /* and the cache knows more than the passed in pair  */
		    uoffset0 = cache[2];
		    boffset0 = cache[3];
		}

		boffset = boffset0
		    + sv_pos_u2b_midway(start + boffset0,
					  start + cache[1],
					  uoffset - uoffset0,
					  cache[0] - uoffset0);
	    } else {
		boffset = boffset0
		    + sv_pos_u2b_midway(start + boffset0,
					  start + cache[3],
					  uoffset - uoffset0,
					  cache[2] - uoffset0);
	    }
	    found = TRUE;
	}
	else if ((*mgp)->mg_len != -1) {
	    /* If we can take advantage of a passed in offset, do so.  */
	    /* In fact, offset0 is either 0, or less than offset, so don't
	       need to worry about the other possibility.  */
	    boffset = boffset0
		+ sv_pos_u2b_midway(start + boffset0, send,
				      uoffset - uoffset0,
				      (*mgp)->mg_len - uoffset0);
	    found = TRUE;
	}
    }

    if (!found || PL_utf8cache < 0) {
	const STRLEN real_boffset
	    = boffset0 + sv_pos_u2b_forwards(start + boffset0,
					       send, uoffset - uoffset0);

	if (found && PL_utf8cache < 0) {
	    if (real_boffset != boffset) {
		/* Need to turn the assertions off otherwise we may recurse
		   infinitely while printing error messages.  */
		SAVEI8(PL_utf8cache);
		PL_utf8cache = 0;
		Perl_croak(aTHX_ "panic: sv_pos_u2b_cache cache %"UVuf
			   " real %"UVuf" for %"SVf,
			   (UV) boffset, (UV) real_boffset, SVfARG(sv));
	    }
	}
	boffset = real_boffset;
    }

    if (PL_utf8cache)
	utf8_mg_pos_cache_update(sv, mgp, boffset, uoffset, send - start);
    return boffset;
}


/*
=for apidoc sv_pos_u2b

Converts the value pointed to by offsetp from a count of UTF-8 chars from
the start of the string, to a count of the equivalent number of bytes; if
lenp is non-zero, it does the same to lenp, but this time starting from
the offset, rather than from the start of the string. Handles magic and
type coercion.

=cut
*/

/*
 * sv_pos_u2b() uses, like sv_pos_b2u(), the mg_ptr of the potential
 * PERL_UTF8_magic of the sv to store the mapping between UTF-8 and
 * byte offsets.  See also the comments of S_utf8_mg_pos_cache_update().
 *
 */

void
Perl_sv_pos_u2b(pTHX_ register SV *const sv, I32 *const offsetp, I32 *const lenp)
{
    const char *start;
    STRLEN len;

    PERL_ARGS_ASSERT_SV_POS_U2B;

    if (!sv)
	return;

    start = SvPV_const(sv, len);
    if (len) {
	STRLEN uoffset = (STRLEN) *offsetp;
	const char * const send = start + len;
	MAGIC *mg = NULL;
	const STRLEN boffset = sv_pos_u2b_cached(sv, &mg, start, send,
					     uoffset, 0, 0);

	*offsetp = (I32) boffset;

	if (lenp) {
	    /* Convert the relative offset to absolute.  */
	    const STRLEN uoffset2 = uoffset + (STRLEN) *lenp;
	    const STRLEN boffset2
		= sv_pos_u2b_cached(sv, &mg, start, send, uoffset2,
				      uoffset, boffset) - boffset;

	    *lenp = boffset2;
	}
    }
    else {
	 *offsetp = 0;
	 if (lenp)
	      *lenp = 0;
    }

    return;
}

/* Create and update the UTF8 magic offset cache, with the proffered utf8/
   byte length pairing. The (byte) length of the total SV is passed in too,
   as blen, because for some (more esoteric) SVs, the call to SvPV_const()
   may not have updated SvCUR, so we can't rely on reading it directly.

   The proffered utf8/byte length pairing isn't used if the cache already has
   two pairs, and swapping either for the proffered pair would increase the
   RMS of the intervals between known byte offsets.

   The cache itself consists of 4 STRLEN values
   0: larger UTF-8 offset
   1: corresponding byte offset
   2: smaller UTF-8 offset
   3: corresponding byte offset

   Unused cache pairs have the value 0, 0.
   Keeping the cache "backwards" means that the invariant of
   cache[0] >= cache[2] is maintained even with empty slots, which means that
   the code that uses it doesn't need to worry if only 1 entry has actually
   been set to non-zero.  It also makes the "position beyond the end of the
   cache" logic much simpler, as the first slot is always the one to start
   from.   
*/
static void
S_utf8_mg_pos_cache_update(pTHX_ SV *const sv, MAGIC **const mgp, const STRLEN byte,
                           const STRLEN utf8, const STRLEN blen)
{
    STRLEN *cache;

    PERL_ARGS_ASSERT_UTF8_MG_POS_CACHE_UPDATE;

    if (SvREADONLY(sv))
	return;

    if (!*mgp) {
	*mgp = sv_magicext(sv, 0, PERL_MAGIC_utf8, (MGVTBL*)&PL_vtbl_utf8, 0,
			   0);
	(*mgp)->mg_len = -1;
    }
    assert(*mgp);

    if (!(cache = (STRLEN *)(*mgp)->mg_ptr)) {
	Newxz(cache, PERL_MAGIC_UTF8_CACHESIZE * 2, STRLEN);
	(*mgp)->mg_ptr = (char *) cache;
    }
    assert(cache);

    if (PL_utf8cache < 0) {
	const char *start = SvPVX_const(sv);
	const STRLEN realutf8 = utf8_length(start, start + byte);

	if (realutf8 != utf8) {
	    /* Need to turn the assertions off otherwise we may recurse
	       infinitely while printing error messages.  */
	    SAVEI8(PL_utf8cache);
	    PL_utf8cache = 0;
	    Perl_croak(aTHX_ "panic: utf8_mg_pos_cache_update cache %"UVuf
		       " real %"UVuf" for %"SVf, (UV) utf8, (UV) realutf8, SVfARG(sv));
	}
    }

    /* Cache is held with the later position first, to simplify the code
       that deals with unbounded ends.  */
       
    ASSERT_UTF8_CACHE(cache);
    if (cache[1] == 0) {
	/* Cache is totally empty  */
	cache[0] = utf8;
	cache[1] = byte;
    } else if (cache[3] == 0) {
	if (byte > cache[1]) {
	    /* New one is larger, so goes first.  */
	    cache[2] = cache[0];
	    cache[3] = cache[1];
	    cache[0] = utf8;
	    cache[1] = byte;
	} else {
	    cache[2] = utf8;
	    cache[3] = byte;
	}
    } else {
#define THREEWAY_SQUARE(a,b,c,d) \
	    ((float)((d) - (c))) * ((float)((d) - (c))) \
	    + ((float)((c) - (b))) * ((float)((c) - (b))) \
	       + ((float)((b) - (a))) * ((float)((b) - (a)))

	/* Cache has 2 slots in use, and we know three potential pairs.
	   Keep the two that give the lowest RMS distance. Do the
	   calcualation in bytes simply because we always know the byte
	   length.  squareroot has the same ordering as the positive value,
	   so don't bother with the actual square root.  */
	const float existing = THREEWAY_SQUARE(0, cache[3], cache[1], blen);
	if (byte > cache[1]) {
	    /* New position is after the existing pair of pairs.  */
	    const float keep_earlier
		= THREEWAY_SQUARE(0, cache[3], byte, blen);
	    const float keep_later
		= THREEWAY_SQUARE(0, cache[1], byte, blen);

	    if (keep_later < keep_earlier) {
		if (keep_later < existing) {
		    cache[2] = cache[0];
		    cache[3] = cache[1];
		    cache[0] = utf8;
		    cache[1] = byte;
		}
	    }
	    else {
		if (keep_earlier < existing) {
		    cache[0] = utf8;
		    cache[1] = byte;
		}
	    }
	}
	else if (byte > cache[3]) {
	    /* New position is between the existing pair of pairs.  */
	    const float keep_earlier
		= THREEWAY_SQUARE(0, cache[3], byte, blen);
	    const float keep_later
		= THREEWAY_SQUARE(0, byte, cache[1], blen);

	    if (keep_later < keep_earlier) {
		if (keep_later < existing) {
		    cache[2] = utf8;
		    cache[3] = byte;
		}
	    }
	    else {
		if (keep_earlier < existing) {
		    cache[0] = utf8;
		    cache[1] = byte;
		}
	    }
	}
	else {
 	    /* New position is before the existing pair of pairs.  */
	    const float keep_earlier
		= THREEWAY_SQUARE(0, byte, cache[3], blen);
	    const float keep_later
		= THREEWAY_SQUARE(0, byte, cache[1], blen);

	    if (keep_later < keep_earlier) {
		if (keep_later < existing) {
		    cache[2] = utf8;
		    cache[3] = byte;
		}
	    }
	    else {
		if (keep_earlier < existing) {
		    cache[0] = cache[2];
		    cache[1] = cache[3];
		    cache[2] = utf8;
		    cache[3] = byte;
		}
	    }
	}
    }
    ASSERT_UTF8_CACHE(cache);
}

/* We already know all of the way, now we may be able to walk back.  The same
   assumption is made as in S_sv_pos_u2b_midway(), namely that walking
   backward is half the speed of walking forward. */
static STRLEN
S_sv_pos_b2u_midway(pTHX_ const char *s, const char *const target, const char *end,
		    STRLEN endu)
{
    const STRLEN forw = target - s;
    STRLEN backw = end - target;

    PERL_ARGS_ASSERT_SV_POS_B2U_MIDWAY;

    if (forw < 2 * backw) {
	return utf8_length(s, target);
    }

    while (end > target) {
	end--;
	while (UTF8_IS_CONTINUATION(*end)) {
	    end--;
	}
	endu--;
    }
    return endu;
}

/*
=for apidoc sv_pos_b2u

Converts the value pointed to by offsetp from a count of bytes from the
start of the string, to a count of the equivalent number of UTF-8 chars.
Handles magic and type coercion.

=cut
*/

/*
 * sv_pos_b2u() uses, like sv_pos_u2b(), the mg_ptr of the potential
 * PERL_UTF8_magic of the sv to store the mapping between UTF-8 and
 * byte offsets.
 *
 */
void
Perl_sv_pos_b2u(pTHX_ register SV *const sv, I32 *const offsetp)
{
    const char* s;
    const STRLEN byte = *offsetp;
    STRLEN len = 0; /* Actually always set, but let's keep gcc happy.  */
    STRLEN blen;
    MAGIC* mg = NULL;
    const char* send;
    bool found = FALSE;

    PERL_ARGS_ASSERT_SV_POS_B2U;

    if (!sv)
	return;

    s = SvPV_const(sv, blen);

    if (blen < byte)
	Perl_croak(aTHX_ "panic: sv_pos_b2u: bad byte offset");

    send = s + byte;

    if (SvMAGICAL(sv) && !SvREADONLY(sv) && PL_utf8cache
	&& (mg = mg_find(sv, PERL_MAGIC_utf8))) {
	if (mg->mg_ptr) {
	    STRLEN * const cache = (STRLEN *) mg->mg_ptr;
	    if (cache[1] == byte) {
		/* An exact match. */
		*offsetp = cache[0];
		return;
	    }
	    if (cache[3] == byte) {
		/* An exact match. */
		*offsetp = cache[2];
		return;
	    }

	    if (cache[1] < byte) {
		/* We already know part of the way. */
		if (mg->mg_len != -1) {
		    /* Actually, we know the end too.  */
		    len = cache[0]
			+ S_sv_pos_b2u_midway(aTHX_ s + cache[1], send,
					      s + blen, mg->mg_len - cache[0]);
		} else {
		    len = cache[0] + utf8_length(s + cache[1], send);
		}
	    }
	    else if (cache[3] < byte) {
		/* We're between the two cached pairs, so we do the calculation
		   offset by the byte/utf-8 positions for the earlier pair,
		   then add the utf-8 characters from the string start to
		   there.  */
		len = S_sv_pos_b2u_midway(aTHX_ s + cache[3], send,
					  s + cache[1], cache[0] - cache[2])
		    + cache[2];

	    }
	    else { /* cache[3] > byte */
		len = S_sv_pos_b2u_midway(aTHX_ s, send, s + cache[3],
					  cache[2]);

	    }
	    ASSERT_UTF8_CACHE(cache);
	    found = TRUE;
	} else if (mg->mg_len != -1) {
	    len = S_sv_pos_b2u_midway(aTHX_ s, send, s + blen, mg->mg_len);
	    found = TRUE;
	}
    }
    if (!found || PL_utf8cache < 0) {
	const STRLEN real_len = utf8_length(s, send);

	if (found && PL_utf8cache < 0) {
	    if (len != real_len) {
		/* Need to turn the assertions off otherwise we may recurse
		   infinitely while printing error messages.  */
		SAVEI8(PL_utf8cache);
		PL_utf8cache = 0;
		Perl_croak(aTHX_ "panic: sv_pos_b2u cache %"UVuf
			   " real %"UVuf" for %"SVf,
			   (UV) len, (UV) real_len, SVfARG(sv));
	    }
	}
	len = real_len;
    }
    *offsetp = len;

    if (PL_utf8cache)
	utf8_mg_pos_cache_update(sv, &mg, byte, len, blen);
}

/*
=for apidoc sv_eq

Returns a boolean indicating whether the strings in the two SVs are
identical. Is UTF-8 and 'use bytes' aware, handles get magic, and will
coerce its args to strings if necessary.

=cut
*/

I32
Perl_sv_eq(pTHX_ register SV *sv1, register SV *sv2)
{
    dVAR;
    const char *pv1;
    STRLEN cur1;
    const char *pv2;
    STRLEN cur2;
    I32  eq     = 0;
    char *tpv   = NULL;
    SV* svrecode = NULL;

    if (!sv1) {
	pv1 = "";
	cur1 = 0;
    }
    else {
	/* if pv1 and pv2 are the same, second SvPV_const call may
	 * invalidate pv1, so we may need to make a copy */
	if (sv1 == sv2 && (SvTHINKFIRST(sv1))) {
	    pv1 = SvPV_const(sv1, cur1);
	    sv1 = newSVpvn_flags(pv1, cur1, SVs_TEMP);
	}
	pv1 = SvPV_const(sv1, cur1);
    }

    if (!sv2){
	pv2 = "";
	cur2 = 0;
    }
    else
	pv2 = SvPV_const(sv2, cur2);

    if (cur1 == cur2)
	eq = (pv1 == pv2) || memEQ(pv1, pv2, cur1);
	
    SvREFCNT_dec(svrecode);
    if (tpv)
	Safefree(tpv);

    return eq;
}

/*
=for apidoc sv_cmp

Compares the strings in two SVs.  Returns -1, 0, or 1 indicating whether the
string in C<sv1> is less than, equal to, or greater than the string in
C<sv2>. Is UTF-8 and 'use bytes' aware, handles get magic, and will
coerce its args to strings if necessary.

=cut
*/

I32
Perl_sv_cmp(pTHX_ register SV *const sv1, register SV *const sv2)
{
    dVAR;
    STRLEN cur1, cur2;
    const char *pv1, *pv2;
    char *tpv = NULL;
    I32  cmp;
    SV *svrecode = NULL;

    if (!sv1) {
	pv1 = "";
	cur1 = 0;
    }
    else
	pv1 = SvPV_const(sv1, cur1);

    if (!sv2) {
	pv2 = "";
	cur2 = 0;
    }
    else
	pv2 = SvPV_const(sv2, cur2);

    if (!cur1) {
	cmp = cur2 ? -1 : 0;
    } else if (!cur2) {
	cmp = 1;
    } else {
        const I32 retval = memcmp((const void*)pv1, (const void*)pv2, cur1 < cur2 ? cur1 : cur2);

	if (retval) {
	    cmp = retval < 0 ? -1 : 1;
	} else if (cur1 == cur2) {
	    cmp = 0;
        } else {
	    cmp = cur1 < cur2 ? -1 : 1;
	}
    }

    SvREFCNT_dec(svrecode);
    if (tpv)
	Safefree(tpv);

    return cmp;
}

/*
=for apidoc sv_gets

Get a line from the filehandle and store it into the SV, optionally
appending to the currently-stored string.

=cut
*/

char *
Perl_sv_gets(pTHX_ register SV *const sv, register PerlIO *const fp, I32 append)
{
    dVAR;
    const char *rsptr;
    STRLEN rslen;
    register STDCHAR rslast;
    register STDCHAR *bp;
    register I32 cnt;
    I32 i = 0;
    I32 rspara = 0;

    PERL_ARGS_ASSERT_SV_GETS;

    if (SvTHINKFIRST(sv))
	sv_force_normal_flags(sv, append ? 0 : SV_COW_DROP_PV);
    /* XXX. If you make this PVIV, then copy on write can copy scalars read
       from <>.
       However, perlbench says it's slower, because the existing swipe code
       is faster than copy on write.
       Swings and roundabouts.  */
    SvUPGRADE(sv, SVt_PV);

    SvSCREAM_off(sv);

    SvPOK_only(sv);

    if (IN_PERL_COMPILETIME) {
	/* we always read code in line mode */
	rsptr = "\n";
	rslen = 1;
    }
    else if (RsSNARF(PL_rs)) {
    	/* If it is a regular disk file use size from stat() as estimate
	   of amount we are going to read -- may result in mallocing
	   more memory than we really need if the layers below reduce
	   the size we read (e.g. CRLF or a gzip layer).
	 */
	Stat_t st;
	if (!PerlLIO_fstat(PerlIO_fileno(fp), &st) && S_ISREG(st.st_mode))  {
	    const Off_t offset = PerlIO_tell(fp);
	    if (offset != (Off_t) -1 && st.st_size + append > offset) {
	     	(void) SvGROW(sv, (STRLEN)((st.st_size - offset) + append + 1));
	    }
	}
	rsptr = NULL;
	rslen = 0;
    }
    else if (RsRECORD(PL_rs)) {
      I32 bytesread;
      char *buffer;
      U32 recsize;
#ifdef VMS
      int fd;
#endif

      /* Grab the size of the record we're getting */
      recsize = SvUV(SvRV(PL_rs)); /* RsRECORD() guarantees > 0. */
      buffer = SvGROW(sv, (STRLEN)(recsize + append + 1)) + append;
      /* Go yank in */
#ifdef VMS
      /* VMS wants read instead of fread, because fread doesn't respect */
      /* RMS record boundaries. This is not necessarily a good thing to be */
      /* doing, but we've got no other real choice - except avoid stdio
         as implementation - perhaps write a :vms layer ?
       */
      fd = PerlIO_fileno(fp);
      if (fd == -1) { /* in-memory file from PerlIO::Scalar */
          bytesread = PerlIO_read(fp, buffer, recsize);
      }
      else {
          bytesread = PerlLIO_read(fd, buffer, recsize);
      }
#else
      bytesread = PerlIO_read(fp, buffer, recsize);
#endif
      if (bytesread < 0)
	  bytesread = 0;
      SvCUR_set(sv, bytesread + append);
      buffer[bytesread] = '\0';
      goto return_string_or_null;
    }
    else if (RsPARA(PL_rs)) {
	rsptr = "\n\n";
	rslen = 2;
	rspara = 1;
    }
    else {
	/* Get $/ i.e. PL_rs into same encoding as stream wants */
	rsptr = SvPV_const(PL_rs, rslen);
    }

    rslast = rslen ? rsptr[rslen - 1] : '\0';

    if (rspara) {		/* have to do this both before and after */
	do {			/* to make sure file boundaries work right */
	    if (PerlIO_eof(fp))
		return 0;
	    i = PerlIO_getc(fp);
	    if (i != '\n') {
		if (i == -1)
		    return 0;
		PerlIO_ungetc(fp,i);
		break;
	    }
	} while (i != EOF);
    }

    /* See if we know enough about I/O mechanism to cheat it ! */

    /* This used to be #ifdef test - it is made run-time test for ease
       of abstracting out stdio interface. One call should be cheap
       enough here - and may even be a macro allowing compile
       time optimization.
     */

    if (PerlIO_fast_gets(fp)) {

    /*
     * We're going to steal some values from the stdio struct
     * and put EVERYTHING in the innermost loop into registers.
     */
    register STDCHAR *ptr;
    STRLEN bpx;
    I32 shortbuffered;

#if defined(VMS) && defined(PERLIO_IS_STDIO)
    /* An ungetc()d char is handled separately from the regular
     * buffer, so we getc() it back out and stuff it in the buffer.
     */
    i = PerlIO_getc(fp);
    if (i == EOF) return 0;
    *(--((*fp)->_ptr)) = (unsigned char) i;
    (*fp)->_cnt++;
#endif

    /* Here is some breathtakingly efficient cheating */

    cnt = PerlIO_get_cnt(fp);			/* get count into register */
    /* make sure we have the room */
    if ((I32)(SvLEN(sv) - append) <= cnt + 1) {
    	/* Not room for all of it
	   if we are looking for a separator and room for some
	 */
	if (rslen && cnt > 80 && (I32)SvLEN(sv) > append) {
	    /* just process what we have room for */
	    shortbuffered = cnt - SvLEN(sv) + append + 1;
	    cnt -= shortbuffered;
	}
	else {
	    shortbuffered = 0;
	    /* remember that cnt can be negative */
	    SvGROW(sv, (STRLEN)(append + (cnt <= 0 ? 2 : (cnt + 1))));
	}
    }
    else
	shortbuffered = 0;
    bp = (STDCHAR*)SvPVX_const(sv) + append;  /* move these two too to registers */
    ptr = (STDCHAR*)PerlIO_get_ptr(fp);
    DEBUG_P(PerlIO_printf(Perl_debug_log,
	"Screamer: entering, ptr=%"UVuf", cnt=%ld\n",PTR2UV(ptr),(long)cnt));
    DEBUG_P(PerlIO_printf(Perl_debug_log,
	"Screamer: entering: PerlIO * thinks ptr=%"UVuf", cnt=%ld, base=%"UVuf"\n",
	       PTR2UV(PerlIO_get_ptr(fp)), (long)PerlIO_get_cnt(fp),
	       PTR2UV(PerlIO_has_base(fp) ? PerlIO_get_base(fp) : 0)));
    for (;;) {
      screamer:
	if (cnt > 0) {
	    if (rslen) {
		while (cnt > 0) {		     /* this     |  eat */
		    cnt--;
		    if ((*bp++ = *ptr++) == rslast)  /* really   |  dust */
			goto thats_all_folks;	     /* screams  |  sed :-) */
		}
	    }
	    else {
	        Copy(ptr, bp, cnt, char);	     /* this     |  eat */
		bp += cnt;			     /* screams  |  dust */
		ptr += cnt;			     /* louder   |  sed :-) */
		cnt = 0;
	    }
	}
	
	if (shortbuffered) {		/* oh well, must extend */
	    cnt = shortbuffered;
	    shortbuffered = 0;
	    bpx = bp - (STDCHAR*)SvPVX_const(sv); /* box up before relocation */
	    SvCUR_set(sv, bpx);
	    SvGROW(sv, SvLEN(sv) + append + cnt + 2);
	    bp = (STDCHAR*)SvPVX_const(sv) + bpx; /* unbox after relocation */
	    continue;
	}

	DEBUG_P(PerlIO_printf(Perl_debug_log,
			      "Screamer: going to getc, ptr=%"UVuf", cnt=%ld\n",
			      PTR2UV(ptr),(long)cnt));
	PerlIO_set_ptrcnt(fp, (STDCHAR*)ptr, cnt); /* deregisterize cnt and ptr */
#if 0
	DEBUG_P(PerlIO_printf(Perl_debug_log,
	    "Screamer: pre: FILE * thinks ptr=%"UVuf", cnt=%ld, base=%"UVuf"\n",
	    PTR2UV(PerlIO_get_ptr(fp)), (long)PerlIO_get_cnt(fp),
	    PTR2UV(PerlIO_has_base (fp) ? PerlIO_get_base(fp) : 0)));
#endif
	/* This used to call 'filbuf' in stdio form, but as that behaves like
	   getc when cnt <= 0 we use PerlIO_getc here to avoid introducing
	   another abstraction.  */
	i   = PerlIO_getc(fp);		/* get more characters */
#if 0
	DEBUG_P(PerlIO_printf(Perl_debug_log,
	    "Screamer: post: FILE * thinks ptr=%"UVuf", cnt=%ld, base=%"UVuf"\n",
	    PTR2UV(PerlIO_get_ptr(fp)), (long)PerlIO_get_cnt(fp),
	    PTR2UV(PerlIO_has_base (fp) ? PerlIO_get_base(fp) : 0)));
#endif
	cnt = PerlIO_get_cnt(fp);
	ptr = (STDCHAR*)PerlIO_get_ptr(fp);	/* reregisterize cnt and ptr */
	DEBUG_P(PerlIO_printf(Perl_debug_log,
	    "Screamer: after getc, ptr=%"UVuf", cnt=%ld\n",PTR2UV(ptr),(long)cnt));

	if (i == EOF)			/* all done for ever? */
	    goto thats_really_all_folks;

	bpx = bp - (STDCHAR*)SvPVX_const(sv);	/* box up before relocation */
	SvCUR_set(sv, bpx);
	SvGROW(sv, bpx + cnt + 2);
	bp = (STDCHAR*)SvPVX_const(sv) + bpx;	/* unbox after relocation */

	*bp++ = (STDCHAR)i;		/* store character from PerlIO_getc */

	if (rslen && (STDCHAR)i == rslast)  /* all done for now? */
	    goto thats_all_folks;
    }

thats_all_folks:
    if ((rslen > 1 && (STRLEN)(bp - (STDCHAR*)SvPVX_const(sv)) < rslen) ||
	  memNE((char*)bp - rslen, rsptr, rslen))
	goto screamer;				/* go back to the fray */
thats_really_all_folks:
    if (shortbuffered)
	cnt += shortbuffered;
	DEBUG_P(PerlIO_printf(Perl_debug_log,
	    "Screamer: quitting, ptr=%"UVuf", cnt=%ld\n",PTR2UV(ptr),(long)cnt));
    PerlIO_set_ptrcnt(fp, (STDCHAR*)ptr, cnt);	/* put these back or we're in trouble */
    DEBUG_P(PerlIO_printf(Perl_debug_log,
	"Screamer: end: FILE * thinks ptr=%"UVuf", cnt=%ld, base=%"UVuf"\n",
	PTR2UV(PerlIO_get_ptr(fp)), (long)PerlIO_get_cnt(fp),
	PTR2UV(PerlIO_has_base (fp) ? PerlIO_get_base(fp) : 0)));
    *bp = '\0';
    SvCUR_set(sv, bp - (STDCHAR*)SvPVX_const(sv));	/* set length */
    DEBUG_P(PerlIO_printf(Perl_debug_log,
	"Screamer: done, len=%ld, string=|%.*s|\n",
	(long)SvCUR(sv),(int)SvCUR(sv),SvPVX_const(sv)));
    }
   else
    {
       /*The big, slow, and stupid way. */
#ifdef USE_HEAP_INSTEAD_OF_STACK	/* Even slower way. */
	STDCHAR *buf = NULL;
	Newx(buf, 8192, STDCHAR);
	assert(buf);
#else
	STDCHAR buf[8192];
#endif

screamer2:
	if (rslen) {
            register const STDCHAR * const bpe = buf + sizeof(buf);
	    bp = buf;
	    while ((i = PerlIO_getc(fp)) != EOF && (*bp++ = (STDCHAR)i) != rslast && bp < bpe)
		; /* keep reading */
	    cnt = bp - buf;
	}
	else {
	    cnt = PerlIO_read(fp,(char*)buf, sizeof(buf));
	    /* Accomodate broken VAXC compiler, which applies char cast to
	     * both args of ?: operator, causing EOF to change into 255
	     */
	    if (cnt > 0)
		 i = (U8)buf[cnt - 1];
	    else
		 i = EOF;
	}

	if (cnt < 0)
	    cnt = 0;  /* we do need to re-set the sv even when cnt <= 0 */
	if (append)
	     sv_catpvn(sv, (char *) buf, cnt);
	else
	     sv_setpvn(sv, (char *) buf, cnt);

	if (i != EOF &&			/* joy */
	    (!rslen ||
	     SvCUR(sv) < rslen ||
	     memNE(SvPVX_const(sv) + SvCUR(sv) - rslen, rsptr, rslen)))
	{
	    append = -1;
	    /*
	     * If we're reading from a TTY and we get a short read,
	     * indicating that the user hit his EOF character, we need
	     * to notice it now, because if we try to read from the TTY
	     * again, the EOF condition will disappear.
	     *
	     * The comparison of cnt to sizeof(buf) is an optimization
	     * that prevents unnecessary calls to feof().
	     *
	     * - jik 9/25/96
	     */
	    if (!(cnt < (I32)sizeof(buf) && PerlIO_eof(fp)))
		goto screamer2;
	}

#ifdef USE_HEAP_INSTEAD_OF_STACK
	Safefree(buf);
#endif
    }

    if (rspara) {		/* have to do this both before and after */
        while (i != EOF) {	/* to make sure file boundaries work right */
	    i = PerlIO_getc(fp);
	    if (i != '\n') {
		PerlIO_ungetc(fp,i);
		break;
	    }
	}
    }

return_string_or_null:
    return (SvCUR(sv) - append) ? SvPVX_mutable(sv) : NULL;
}

/*
=for apidoc sv_inc

Auto-increment of the value in the SV, doing string to numeric conversion
if necessary. Handles 'get' magic.

=cut
*/

void
Perl_sv_inc(pTHX_ register SV *const sv)
{
    dVAR;
    register char *d;
    int flags;

    if (!sv)
	return;
    if (SvTHINKFIRST(sv)) {
	if (SvIsCOW(sv))
	    sv_force_normal_flags(sv, 0);
	if (SvREADONLY(sv)) {
	    if (IN_PERL_RUNTIME)
		Perl_croak(aTHX_ "%s", PL_no_modify);
	}
	if (SvROK(sv)) {
	    Perl_croak(aTHX_ "Can't coerce reference to number");
	}
    }
    if ( SvOK(sv) && ! SvPVOK(sv) )
	Perl_croak(aTHX_ "Can't coerce '%s' to a number", Ddesc(sv) );

    flags = SvFLAGS(sv);
    if ((flags & (SVp_NOK|SVp_IOK)) == SVp_NOK) {
	/* It's (privately or publicly) a float, but not tested as an
	   integer, so test it to see. */
	(void) SvIV(sv);
	flags = SvFLAGS(sv);
    }
    if ((flags & SVf_IOK) || ((flags & (SVp_IOK | SVp_NOK)) == SVp_IOK)) {
	/* It's publicly an integer, or privately an integer-not-float */
#ifdef PERL_PRESERVE_IVUV
      oops_its_int:
#endif
	if (SvIsUV(sv)) {
	    if (SvUVX(sv) == UV_MAX)
		sv_setnv(sv, UV_MAX_P1);
	    else
		(void)SvIOK_only_UV(sv);
		SvUV_set(sv, SvUVX(sv) + 1);
	} else {
	    if (I_SvIV(sv) == IV_MAX)
		sv_setuv(sv, (UV)IV_MAX + 1);
	    else {
		(void)SvIOK_only(sv);
		SvIV_set(sv, I_SvIV(sv) + 1);
	    }	
	}
	return;
    }
    if (flags & SVp_NOK) {
	const NV was = SvNVX(sv);
	if (NV_OVERFLOWS_INTEGERS_AT &&
	    was >= NV_OVERFLOWS_INTEGERS_AT && ckWARN(WARN_IMPRECISION)) {
	    Perl_warner(aTHX_ packWARN(WARN_IMPRECISION),
			"Lost precision when incrementing %" NVff " by 1",
			was);
	}
	(void)SvNOK_only(sv);
        SvNV_set(sv, was + 1.0);
	return;
    }

    if (!(flags & SVp_POK) || !*SvPVX_const(sv)) {
	if ((flags & SVTYPEMASK) < SVt_PVIV)
	    sv_upgrade(sv, ((flags & SVTYPEMASK) > SVt_IV ? SVt_PVIV : SVt_IV));
	(void)SvIOK_only(sv);
	SvIV_set(sv, 1);
	return;
    }
    d = SvPVX_mutable(sv);
    while (isALPHA(*d)) d++;
    while (isDIGIT(*d)) d++;
    if (*d) {
#ifdef PERL_PRESERVE_IVUV
	/* Got to punt this as an integer if needs be, but we don't issue
	   warnings. Probably ought to make the sv_iv_please() that does
	   the conversion if possible, and silently.  */
	const int numtype = grok_number(SvPVX_const(sv), SvCUR(sv), NULL);
	if (numtype && !(numtype & IS_NUMBER_INFINITY)) {
	    /* Need to try really hard to see if it's an integer.
	       9.22337203685478e+18 is an integer.
	       but "9.22337203685478e+18" + 0 is UV=9223372036854779904
	       so $a="9.22337203685478e+18"; $a+0; $a++
	       needs to be the same as $a="9.22337203685478e+18"; $a++
	       or we go insane. */
	
	    (void) sv_2iv(sv);
	    if (SvIOK(sv))
		goto oops_its_int;

	    /* sv_2iv *should* have made this an NV */
	    if (flags & SVp_NOK) {
		(void)SvNOK_only(sv);
                SvNV_set(sv, SvNVX(sv) + 1.0);
		return;
	    }
	    /* I don't think we can get here. Maybe I should assert this
	       And if we do get here I suspect that sv_setnv will croak. NWC
	       Fall through. */
#if defined(USE_LONG_DOUBLE)
	    DEBUG_c(PerlIO_printf(Perl_debug_log,"sv_inc punt failed to convert '%s' to IOK or NOKp, UV=0x%"UVxf" NV=%"PERL_PRIgldbl"\n",
				  SvPVX_const(sv), I_SvIV(sv), SvNVX(sv)));
#else
	    DEBUG_c(PerlIO_printf(Perl_debug_log,"sv_inc punt failed to convert '%s' to IOK or NOKp, UV=0x%"UVxf" NV=%"NVgf"\n",
				  SvPVX_const(sv), I_SvIV(sv), SvNVX(sv)));
#endif
	}
#endif /* PERL_PRESERVE_IVUV */
	sv_setnv(sv,Atof(SvPVX_const(sv)) + 1.0);
	return;
    }
    d--;
    while (d >= SvPVX_const(sv)) {
	if (isDIGIT(*d)) {
	    if (++*d <= '9')
		return;
	    *(d--) = '0';
	}
	else {
#ifdef EBCDIC
	    /* MKS: The original code here died if letters weren't consecutive.
	     * at least it didn't have to worry about non-C locales.  The
	     * new code assumes that ('z'-'a')==('Z'-'A'), letters are
	     * arranged in order (although not consecutively) and that only
	     * [A-Za-z] are accepted by isALPHA in the C locale.
	     */
	    if (*d != 'z' && *d != 'Z') {
		do { ++*d; } while (!isALPHA(*d));
		return;
	    }
	    *(d--) -= 'z' - 'a';
#else
	    ++*d;
	    if (isALPHA(*d))
		return;
	    *(d--) -= 'z' - 'a' + 1;
#endif
	}
    }
    /* oh,oh, the number grew */
    SvGROW(sv, SvCUR(sv) + 2);
    SvCUR_set(sv, SvCUR(sv) + 1);
    for (d = SvPVX_mutable(sv) + SvCUR(sv); d > SvPVX_const(sv); d--)
	*d = d[-1];
    if (isDIGIT(d[1]))
	*d = '1';
    else
	*d = d[1];
}

/*
=for apidoc sv_dec

Auto-decrement of the value in the SV, doing string to numeric conversion
if necessary. Handles 'get' magic.

=cut
*/

void
Perl_sv_dec(pTHX_ register SV *const sv)
{
    dVAR;
    int flags;

    if (!sv)
	return;
    if (SvTHINKFIRST(sv)) {
	if (SvIsCOW(sv))
	    sv_force_normal_flags(sv, 0);
	if (SvREADONLY(sv)) {
	    if (IN_PERL_RUNTIME)
		Perl_croak(aTHX_ "%s", PL_no_modify);
	}
	if (SvROK(sv)) {
	    Perl_croak(aTHX_ "Can't coerce reference to number");
	}
    }
    /* Unlike sv_inc we don't have to worry about string-never-numbers
       and keeping them magic. But we mustn't warn on punting */
    flags = SvFLAGS(sv);
    if ((flags & SVf_IOK) || ((flags & (SVp_IOK | SVp_NOK)) == SVp_IOK)) {
	/* It's publicly an integer, or privately an integer-not-float */
#ifdef PERL_PRESERVE_IVUV
      oops_its_int:
#endif
	if (SvIsUV(sv)) {
	    if (SvUVX(sv) == 0) {
		(void)SvIOK_only(sv);
		SvIV_set(sv, -1);
	    }
	    else {
		(void)SvIOK_only_UV(sv);
		SvUV_set(sv, SvUVX(sv) - 1);
	    }	
	} else {
	    if (I_SvIV(sv) == IV_MIN) {
		sv_setnv(sv, (NV)IV_MIN);
		goto oops_its_num;
	    }
	    else {
		(void)SvIOK_only(sv);
		SvIV_set(sv, I_SvIV(sv) - 1);
	    }	
	}
	return;
    }
    if (flags & SVp_NOK) {
    oops_its_num:
	{
	    const NV was = SvNVX(sv);
	    if (NV_OVERFLOWS_INTEGERS_AT &&
		was <= -NV_OVERFLOWS_INTEGERS_AT && ckWARN(WARN_IMPRECISION)) {
		Perl_warner(aTHX_ packWARN(WARN_IMPRECISION),
			    "Lost precision when decrementing %" NVff " by 1",
			    was);
	    }
	    (void)SvNOK_only(sv);
	    SvNV_set(sv, was - 1.0);
	    return;
	}
    }
    if (!(flags & SVp_POK)) {
	if ((flags & SVTYPEMASK) < SVt_PVIV)
	    sv_upgrade(sv, ((flags & SVTYPEMASK) > SVt_IV) ? SVt_PVIV : SVt_IV);
	SvIV_set(sv, -1);
	(void)SvIOK_only(sv);
	return;
    }
#ifdef PERL_PRESERVE_IVUV
    {
	const int numtype = grok_number(SvPVX_const(sv), SvCUR(sv), NULL);
	if (numtype && !(numtype & IS_NUMBER_INFINITY)) {
	    /* Need to try really hard to see if it's an integer.
	       9.22337203685478e+18 is an integer.
	       but "9.22337203685478e+18" + 0 is UV=9223372036854779904
	       so $a="9.22337203685478e+18"; $a+0; $a--
	       needs to be the same as $a="9.22337203685478e+18"; $a--
	       or we go insane. */
	
	    (void) sv_2iv(sv);
	    if (SvIOK(sv))
		goto oops_its_int;

	    /* sv_2iv *should* have made this an NV */
	    if (flags & SVp_NOK) {
		(void)SvNOK_only(sv);
                SvNV_set(sv, SvNVX(sv) - 1.0);
		return;
	    }
	    /* I don't think we can get here. Maybe I should assert this
	       And if we do get here I suspect that sv_setnv will croak. NWC
	       Fall through. */
#if defined(USE_LONG_DOUBLE)
	    DEBUG_c(PerlIO_printf(Perl_debug_log,"sv_dec punt failed to convert '%s' to IOK or NOKp, UV=0x%"UVxf" NV=%"PERL_PRIgldbl"\n",
				  SvPVX_const(sv), I_SvIV(sv), SvNVX(sv)));
#else
	    DEBUG_c(PerlIO_printf(Perl_debug_log,"sv_dec punt failed to convert '%s' to IOK or NOKp, UV=0x%"UVxf" NV=%"NVgf"\n",
				  SvPVX_const(sv), I_SvIV(sv), SvNVX(sv)));
#endif
	}
    }
#endif /* PERL_PRESERVE_IVUV */
    sv_setnv(sv,Atof(SvPVX_const(sv)) - 1.0);	/* punt */
}

/* this define is used to eliminate a chunk of duplicated but shared logic
 * it has the suffix __SV_C to signal that it isnt API, and isnt meant to be
 * used anywhere but here - yves
 */
#define PUSH_EXTEND_MORTAL__SV_C(AnSv) \
    STMT_START {      \
	EXTEND_MORTAL(1); \
	PL_tmps_stack[++PL_tmps_ix] = (AnSv); \
    } STMT_END

/*
=for apidoc sv_mortalcopy

Creates a new SV which is a copy of the original SV (using C<sv_setsv>).
The new SV is marked as mortal. It will be destroyed "soon", either by an
explicit call to FREETMPS, or by an implicit call at places such as
statement boundaries.  See also C<sv_newmortal> and C<sv_2mortal>.

=cut
*/

/* Make a string that will exist for the duration of the expression
 * evaluation.  Actually, it may have to last longer than that, but
 * hopefully we won't free it until it has been assigned to a
 * permanent location. */

SV *
Perl_sv_mortalcopy(pTHX_ SV *const oldstr)
{
    dVAR;
    register SV *sv;

    new_SV(sv);
    sv_setsv(sv,oldstr);
    PUSH_EXTEND_MORTAL__SV_C(sv);
    SvTEMP_on(sv);
    return sv;
}

/*
=for apidoc sv_newmortal

Creates a new null SV which is mortal.  The reference count of the SV is
set to 1. It will be destroyed "soon", either by an explicit call to
FREETMPS, or by an implicit call at places such as statement boundaries.
See also C<sv_mortalcopy> and C<sv_2mortal>.

=cut
*/

SV *
Perl_sv_newmortal(pTHX)
{
    dVAR;
    register SV *sv;

    new_SV(sv);
    SvFLAGS(sv) = SVs_TEMP;
    PUSH_EXTEND_MORTAL__SV_C(sv);
    return sv;
}


/*
=for apidoc newSVpvn_flags

Creates a new SV and copies a string into it.  The reference count for the
SV is set to 1.  Note that if C<len> is zero, Perl will create a zero length
string.  You are responsible for ensuring that the source string is at least
C<len> bytes long.  If the C<s> argument is NULL the new SV will be undefined.
Currently the only flag bits accepted are C<SVs_TEMP>.
If C<SVs_TEMP> is set, then C<sv2mortal()> is called on the result before
returning. 

=cut
*/

SV *
Perl_newSVpvn_flags(pTHX_ const char *const s, const STRLEN len, const U32 flags)
{
    dVAR;
    register SV *sv;

    /* All the flags we don't support must be zero.
       And we're new code so I'm going to assert this from the start.  */
    assert(!(flags & ~(SVs_TEMP)));
    new_SV(sv);
    sv_setpvn(sv,s,len);

    /* This code used to a sv_2mortal(), however we now unroll the call to sv_2mortal()
     * and do what it does outselves here.
     * Since we have asserted that flags can only have the SVf_UTF8 and/or SVs_TEMP flags
     * set above we can use it to enable the sv flags directly (bypassing SvTEMP_on), which
     * in turn means we dont need to mask out the SVf_UTF8 flag below, which means that we
     * eleminate quite a few steps than it looks - Yves (explaining patch by gfx)
     */

    SvFLAGS(sv) |= flags;

    if(flags & SVs_TEMP){
	PUSH_EXTEND_MORTAL__SV_C(sv);
    }

    return sv;
}

/*
=for apidoc sv_2mortal

Marks an existing SV as mortal.  The SV will be destroyed "soon", either
by an explicit call to FREETMPS, or by an implicit call at places such as
statement boundaries.  SvTEMP() is turned on which means that the SV's
string buffer can be "stolen" if this SV is copied. See also C<sv_newmortal>
and C<sv_mortalcopy>.

=cut
*/

SV *
Perl_sv_2mortal(pTHX_ register SV *const sv)
{
    dVAR;
    if (!sv)
	return NULL;
    if (SvREADONLY(sv) && SvIMMORTAL(sv))
	return sv;
    PUSH_EXTEND_MORTAL__SV_C(sv);
    SvTEMP_on(sv);
    return sv;
}

/*
=for apidoc newSVpv

Creates a new SV and copies a string into it.  The reference count for the
SV is set to 1.  If C<len> is zero, Perl will compute the length using
strlen().  For efficiency, consider using C<newSVpvn> instead.

=cut
*/

SV *
Perl_newSVpv(pTHX_ const char *const s, const STRLEN len)
{
    dVAR;
    register SV *sv;

    new_SV(sv);
    sv_setpvn(sv, s, len || s == NULL ? len : strlen(s));
    return sv;
}

/*
=for apidoc newSVpvn

Creates a new SV and copies a string into it.  The reference count for the
SV is set to 1.  Note that if C<len> is zero, Perl will create a zero length
string.  You are responsible for ensuring that the source string is at least
C<len> bytes long.  If the C<s> argument is NULL the new SV will be undefined.

=cut
*/

SV *
Perl_newSVpvn(pTHX_ const char *const s, const STRLEN len)
{
    dVAR;
    register SV *sv;

    new_SV(sv);
    sv_setpvn(sv,s,len);
    return sv;
}

/*
=for apidoc newSVhek

Creates a new SV from the hash key structure.  It will generate scalars that
point to the shared string table where possible. Returns a new (undefined)
SV if the hek is NULL.

=cut
*/

SV *
Perl_newSVhek(pTHX_ const HEK *const hek)
{
    dVAR;
    if (!hek) {
	SV *sv;

	new_SV(sv);
	return sv;
    }

    if (HEK_LEN(hek) == HEf_SVKEY) {
	return newSVsv(*(SV**)HEK_KEY(hek));
    } else {
	const int flags = HEK_FLAGS(hek);
	if (flags & (HVhek_REHASH|HVhek_UNSHARED)) {
	    /* We don't have a pointer to the hv, so we have to replicate the
	       flag into every HEK. This hv is using custom a hasing
	       algorithm. Hence we can't return a shared string scalar, as
	       that would contain the (wrong) hash value, and might get passed
	       into an hv routine with a regular hash.
	       Similarly, a hash that isn't using shared hash keys has to have
	       the flag in every key so that we know not to try to call
	       share_hek_kek on it.  */

	    SV * const sv = newSVpvn (HEK_KEY(hek), HEK_LEN(hek));
	    return sv;
	}
	/* This will be overwhelminly the most common case.  */
	{
	    /* Inline most of newSVpvn_share(), because share_hek_hek() is far
	       more efficient than sharepvn().  */
	    SV *sv;

	    new_SV(sv);
	    sv_upgrade(sv, SVt_PV);
	    SvPV_set(sv, (char *)HEK_KEY(share_hek_hek(hek)));
	    SvCUR_set(sv, HEK_LEN(hek));
	    SvLEN_set(sv, 0);
	    SvREADONLY_on(sv);
	    SvFAKE_on(sv);
	    SvPOK_on(sv);
	    return sv;
	}
    }
}

/*
=for apidoc newSVpvn_share

Creates a new SV with its SvPVX_const pointing to a shared string in the string
table. If the string does not already exist in the table, it is created
first.  Turns on READONLY and FAKE. If the C<hash> parameter is non-zero, that
value is used; otherwise the hash is computed. The string's hash can be later
be retrieved from the SV with the C<SvSHARED_HASH()> macro. The idea here is
that as the string table is used for shared hash keys these strings will have
SvPVX_const == HeKEY and hash lookup will avoid string compare.

=cut
*/

SV *
Perl_newSVpvn_share(pTHX_ const char *src, I32 len, U32 hash)
{
    dVAR;
    register SV *sv;
    const char *const orig_src = src;

    assert(len >= 0);

    if (!hash)
	PERL_HASH(hash, src, len);
    new_SV(sv);
    /* The logic for this is inlined in S_mro_get_linear_isa_dfs(), so if it
       changes here, update it there too.  */
    sv_upgrade(sv, SVt_PV);
    SvPV_set(sv, sharepvn(src, len, hash));
    SvLEN_set(sv, 0);
    SvCUR_set(sv, len);
    SvREADONLY_on(sv);
    SvFAKE_on(sv);
    SvPOK_on(sv);
    if (src != orig_src)
	Safefree(src);
    return sv;
}


/*
=for apidoc newSVpvf

Creates a new SV and initializes it with the string formatted like
C<sprintf>.

=cut
*/

SV *
Perl_newSVpvf(pTHX_ const char *const pat, ...)
{
    register SV *sv;
    va_list args;

    PERL_ARGS_ASSERT_NEWSVPVF;

    va_start(args, pat);
    sv = vnewSVpvf(pat, &args);
    va_end(args);
    return sv;
}

/* backend for newSVpvf() */

SV *
Perl_vnewSVpvf(pTHX_ const char *const pat, va_list *const args)
{
    dVAR;
    register SV *sv;

    PERL_ARGS_ASSERT_VNEWSVPVF;

    new_SV(sv);
    sv_vsetpvfn(sv, pat, strlen(pat), args, NULL, 0, NULL);
    return sv;
}

/*
=for apidoc newSVnv

Creates a new SV and copies a floating point value into it.
The reference count for the SV is set to 1.

=cut
*/

SV *
Perl_newSVnv(pTHX_ const NV n)
{
    dVAR;
    register SV *sv;

    new_SV(sv);
    sv_setnv(sv,n);
    return sv;
}

/*
=for apidoc newSViv

Creates a new SV and copies an integer into it.  The reference count for the
SV is set to 1.

=cut
*/

SV *
Perl_newSViv(pTHX_ const IV i)
{
    dVAR;
    register SV *sv;

    new_SV(sv);
    sv_setiv(sv,i);
    return sv;
}

/*
=for apidoc newSVuv

Creates a new SV and copies an unsigned integer into it.
The reference count for the SV is set to 1.

=cut
*/

SV *
Perl_newSVuv(pTHX_ const UV u)
{
    dVAR;
    register SV *sv;

    new_SV(sv);
    sv_setuv(sv,u);
    return sv;
}

/*
=for apidoc newSV_type

Creates a new SV, of the type specified.  The reference count for the new SV
is set to 1.

=cut
*/

SV *
Perl_newSV_type(pTHX_ const svtype type)
{
    register SV *sv;

    new_SV(sv);
    sv_upgrade(sv, type);
    return sv;
}

/*
=for apidoc newRV_noinc

Creates an RV wrapper for an SV.  The reference count for the original
SV is B<not> incremented.

=cut
*/

SV *
Perl_newRV_noinc(pTHX_ SV *const tmpRef)
{
    dVAR;
    register SV *sv = newSV_type(SVt_IV);

    PERL_ARGS_ASSERT_NEWRV_NOINC;

    SvTEMP_off(tmpRef);
    SvRV_set(sv, tmpRef);
    SvROK_on(sv);
    return sv;
}

/* newRV_inc is the official function name to use now.
 * newRV_inc is in fact #defined to newRV in sv.h
 */

SV *
Perl_newRV(pTHX_ SV *const sv)
{
    dVAR;

    PERL_ARGS_ASSERT_NEWRV;

    return newRV_noinc(SvREFCNT_inc_NN(sv));
}

/*
=for apidoc newSVsv

Creates a new SV which is an exact duplicate of the original SV.
(Uses C<sv_setsv>).

=cut
*/

SV *
Perl_newSVsv(pTHX_ register SV *const old)
{
    dVAR;
    register SV *sv;

    if (!old)
	return NULL;
    if (SvTYPE(old) == SVTYPEMASK) {
        if (ckWARN_d(WARN_INTERNAL))
	    Perl_warner(aTHX_ packWARN(WARN_INTERNAL), "semi-panic: attempt to dup freed string");
	return NULL;
    }
    new_SV(sv);
    /* SV_NOSTEAL prevents TEMP buffers being, well, stolen, and saves games
       with SvTEMP_off and SvTEMP_on round a call to sv_setsv.  */
    sv_setsv_flags(sv, old, SV_NOSTEAL);
    return sv;
}

/*
=for apidoc sv_2io

Using various gambits, try to get an IO from an SV: the IO slot if its a
GV; or the recursive result if we're an RV; or the IO slot of the symbol
named after the PV if we're a string.

=cut
*/

IO*
Perl_sv_2io(pTHX_ SV *const sv)
{
    IO* io;
    GV* gv;

    PERL_ARGS_ASSERT_SV_2IO;

    switch (SvTYPE(sv)) {
    case SVt_PVIO:
	io = MUTABLE_IO(sv);
	break;
    case SVt_PVGV:
	if (isGV_with_GP(sv)) {
	    gv = MUTABLE_GV(sv);
	    io = GvIO(gv);
	    if (!io)
		Perl_croak(aTHX_ "Bad filehandle: %s", GvNAME(gv));
	    break;
	}
	/* FALL THROUGH */
    default:
	if (!SvOK(sv))
	    Perl_croak(aTHX_ PL_no_usym, "filehandle");
	if (SvROK(sv))
	    return sv_2io(SvRV(sv));
	gv = gv_fetchsv(sv, 0, SVt_PVIO);
	if (gv)
	    io = GvIO(gv);
	else
	    io = 0;
	if (!io)
	    Perl_croak(aTHX_ "Bad filehandle: %"SVf, SVfARG(sv));
	break;
    }
    return io;
}

/*
=for apidoc sv_2cv

Using various gambits, try to get a CV from an SV; in addition, try if
possible to set C<*gvp> to the GV associated with it.
The flags in C<lref> are passed to sv_fetchsv.

=cut
*/

CV *
Perl_sv_2cv(pTHX_ SV *sv, GV **const gvp, const I32 lref)
{
    dVAR;
    GV *gv = NULL;
    CV *cv = NULL;

    PERL_ARGS_ASSERT_SV_2CV;

    switch (SvTYPE(sv)) {
    case SVt_PVCV:
	*gvp = NULL;
	return MUTABLE_CV(sv);
    case SVt_PVHV:
    case SVt_PVAV:
	Perl_croak(aTHX_ "Expected a CODE reference but got a %s", Ddesc(sv));
    case SVt_PVGV:
	gv = (GV*)sv;
	*gvp = gv;
	goto fix_gv;

    default:
	if (! SvROK(sv))
	    Perl_croak(aTHX_ "Expected a CODE reference but got a %s", Ddesc(sv));
	sv = SvRV(sv);
	if (SvTYPE(sv) == SVt_PVCV) {
	    cv = (CV*)sv;
	    *gvp = NULL;
	    return cv;
	}
	else if(isGV(sv)) {
	    gv = (GV*)sv;
	}
	else
	    Perl_croak(aTHX_ "Expected a CODE reference but got a %s reference", Ddesc(sv));
    fix_gv:
	if (lref && !GvCVu(gv)) {
	    SV* tmpsv = sv_2mortal(newSV(0));
	    gv_efullname3(tmpsv, gv, NULL);
	    Perl_croak(aTHX_ "Unknown named sub \"%"SVf"\"",
		       SVfARG(tmpsv));
	}
	*gvp = gv;
	return GvCVu(gv);
    }
}

/*
=for apidoc sv_pvn_force

Get a sensible string out of the SV somehow.
A private implementation of the C<SvPV_force> macro for compilers which
can't cope with complex macro expressions. Always use the macro instead.

=for apidoc sv_pvn_force_flags

Get a sensible string out of the SV somehow.
C<sv_pvn_force> and C<sv_pvn_force_nomg> are
implemented in terms of this function.
You normally want to use the various wrapper macros instead: see
C<SvPV_force> and C<SvPV_force_nomg>

=cut
*/

char *
Perl_sv_pvn_force_flags(pTHX_ SV *const sv, STRLEN *const lp, const I32 flags)
{
    dVAR;

    PERL_ARGS_ASSERT_SV_PVN_FORCE_FLAGS;

    if (SvTHINKFIRST(sv) && !SvROK(sv))
        sv_force_normal_flags(sv, 0);

    if (SvPOK(sv)) {
	if (lp)
	    *lp = SvCUR(sv);
    }
    else {
	char *s;
	STRLEN len;
 
	if (SvREADONLY(sv) && !(flags & SV_MUTABLE_RETURN)) {
	    const char * const ref = sv_reftype(sv,0);
	    if (PL_op)
		Perl_croak(aTHX_ "Can't coerce readonly %s to string in %s",
			   ref, OP_NAME(PL_op));
	    else
		Perl_croak(aTHX_ "Can't coerce readonly %s to string", ref);
	}
	if ((SvTYPE(sv) > SVt_PVGV)
	    || isGV_with_GP(sv))
	    Perl_croak(aTHX_ "Can't coerce %s to string in %s", sv_reftype(sv,0),
		OP_NAME(PL_op));
	s = sv_2pv_flags(sv, &len, flags);
	if (lp)
	    *lp = len;

	if (s != SvPVX_const(sv)) {	/* Almost, but not quite, sv_setpvn() */
	    if (SvROK(sv))
		sv_unref(sv);
	    SvUPGRADE(sv, SVt_PV);		/* Never FALSE */
	    SvGROW(sv, len + 1);
	    Move(s,SvPVX_mutable(sv),len,char);
	    SvCUR_set(sv, len);
	    SvPVX_mutable(sv)[len] = '\0';
	}
	if (!SvPOK(sv)) {
	    SvPOK_on(sv);		/* validate pointer */
	    DEBUG_c(PerlIO_printf(Perl_debug_log, "0x%"UVxf" 2pv(%s)\n",
				  PTR2UV(sv),SvPVX_const(sv)));
	}
    }
    return SvPVX_mutable(sv);
}

/*
=for apidoc sv_reftype

Returns a string describing what the SV is a reference to.

=cut
*/

const char *
Perl_sv_reftype(pTHX_ const SV *const sv, const int ob)
{
    PERL_ARGS_ASSERT_SV_REFTYPE;

    /* The fact that I don't need to downcast to char * everywhere, only in ?:
       inside return suggests a const propagation bug in g++.  */
    if (ob && SvOBJECT(sv)) {
	char * const name = HvNAME_get(SvSTASH(sv));
	return name ? name : (char *) "__ANON__";
    }
    else {
	switch (SvTYPE(sv)) {
	case SVt_NULL:
	case SVt_IV:
	case SVt_NV:
	case SVt_PV:
	case SVt_PVIV:
	case SVt_PVNV:
	case SVt_PVMG:
				if (SvROK(sv))
				    return "REF";
				else
				    return "SCALAR";

	case SVt_PVAV:		return "ARRAY";
	case SVt_PVHV:		return "HASH";
	case SVt_PVCV:		return "CODE";
	case SVt_PVGV:		return (char *) (isGV_with_GP(sv)
				    ? "GLOB" : "SCALAR");
	case SVt_PVIO:		return "IO";
	case SVt_BIND:		return "BIND";
	case SVt_REGEXP:	return "REGEXP"; 
	default:		return "UNKNOWN";
	}
    }
}

/*
=for apidoc sv_isobject

Returns a boolean indicating whether the SV is an RV pointing to a blessed
object.  If the SV is not an RV, or if the object is not blessed, then this
will return false.

=cut
*/

int
Perl_sv_isobject(pTHX_ SV *sv)
{
    if (!sv)
	return 0;
    if (!SvROK(sv))
	return 0;
    sv = SvRV(sv);
    if (!SvOBJECT(sv))
	return 0;
    return 1;
}

/*
=for apidoc sv_isa

Returns a boolean indicating whether the SV is blessed into the specified
class.  This does not check for subtypes; use C<sv_derived_from> to verify
an inheritance relationship.

=cut
*/

int
Perl_sv_isa(pTHX_ SV *sv, const char *const name)
{
    const char *hvname;

    PERL_ARGS_ASSERT_SV_ISA;

    if (!sv)
	return 0;
    if (!SvROK(sv))
	return 0;
    sv = SvRV(sv);
    if (!SvOBJECT(sv))
	return 0;
    hvname = HvNAME_get(SvSTASH(sv));
    if (!hvname)
	return 0;

    return strEQ(hvname, name);
}

/*
=for apidoc newSVrv

Creates a new SV for the RV, C<rv>, to point to.  If C<rv> is not an RV then
it will be upgraded to one.  If C<classname> is non-null then the new SV will
be blessed in the specified package.  The new SV is returned and its
reference count is 1.

=cut
*/

SV*
Perl_newSVrv(pTHX_ SV *const rv, const char *const classname)
{
    dVAR;
    SV *sv;

    PERL_ARGS_ASSERT_NEWSVRV;

    new_SV(sv);

    SV_CHECK_THINKFIRST_COW_DROP(rv);

    if (SvTYPE(rv) >= SVt_PVMG) {
	const U32 refcnt = SvREFCNT(rv);
	SvREFCNT(rv) = 0;
	sv_clear(rv);
	SvFLAGS(rv) = 0;
	SvREFCNT(rv) = refcnt;

	sv_upgrade(rv, SVt_IV);
    } else if (SvROK(rv)) {
	SvREFCNT_dec(SvRV(rv));
    } else {
	prepare_SV_for_RV(rv);
    }

    SvOK_off(rv);
    SvRV_set(rv, sv);
    SvROK_on(rv);

    if (classname) {
	HV* const stash = gv_stashpv(classname, GV_ADD);
	(void)sv_bless(rv, stash);
    }
    return sv;
}

/*
=for apidoc sv_setref_pv

Copies a pointer into a new SV, optionally blessing the SV.  The C<rv>
argument will be upgraded to an RV.  That RV will be modified to point to
the new SV.  If the C<pv> argument is NULL then C<PL_sv_undef> will be placed
into the SV.  The C<classname> argument indicates the package for the
blessing.  Set C<classname> to C<NULL> to avoid the blessing.  The new SV
will have a reference count of 1, and the RV will be returned.

Do not use with other Perl types such as HV, AV, SV, CV, because those
objects will become corrupted by the pointer copy process.

Note that C<sv_setref_pvn> copies the string while this copies the pointer.

=cut
*/

SV*
Perl_sv_setref_pv(pTHX_ SV *const rv, const char *const classname, void *const pv)
{
    dVAR;

    PERL_ARGS_ASSERT_SV_SETREF_PV;

    if (!pv) {
	sv_setsv(rv, &PL_sv_undef);
	SvSETMAGIC(rv);
    }
    else
	sv_setiv(newSVrv(rv,classname), PTR2IV(pv));
    return rv;
}

/*
=for apidoc sv_setref_iv

Copies an integer into a new SV, optionally blessing the SV.  The C<rv>
argument will be upgraded to an RV.  That RV will be modified to point to
the new SV.  The C<classname> argument indicates the package for the
blessing.  Set C<classname> to C<NULL> to avoid the blessing.  The new SV
will have a reference count of 1, and the RV will be returned.

=cut
*/

SV*
Perl_sv_setref_iv(pTHX_ SV *const rv, const char *const classname, const IV iv)
{
    PERL_ARGS_ASSERT_SV_SETREF_IV;

    sv_setiv(newSVrv(rv,classname), iv);
    return rv;
}

/*
=for apidoc sv_setref_uv

Copies an unsigned integer into a new SV, optionally blessing the SV.  The C<rv>
argument will be upgraded to an RV.  That RV will be modified to point to
the new SV.  The C<classname> argument indicates the package for the
blessing.  Set C<classname> to C<NULL> to avoid the blessing.  The new SV
will have a reference count of 1, and the RV will be returned.

=cut
*/

SV*
Perl_sv_setref_uv(pTHX_ SV *const rv, const char *const classname, const UV uv)
{
    PERL_ARGS_ASSERT_SV_SETREF_UV;

    sv_setuv(newSVrv(rv,classname), uv);
    return rv;
}

/*
=for apidoc sv_setref_nv

Copies a double into a new SV, optionally blessing the SV.  The C<rv>
argument will be upgraded to an RV.  That RV will be modified to point to
the new SV.  The C<classname> argument indicates the package for the
blessing.  Set C<classname> to C<NULL> to avoid the blessing.  The new SV
will have a reference count of 1, and the RV will be returned.

=cut
*/

SV*
Perl_sv_setref_nv(pTHX_ SV *const rv, const char *const classname, const NV nv)
{
    PERL_ARGS_ASSERT_SV_SETREF_NV;

    sv_setnv(newSVrv(rv,classname), nv);
    return rv;
}

/*
=for apidoc sv_setref_pvn

Copies a string into a new SV, optionally blessing the SV.  The length of the
string must be specified with C<n>.  The C<rv> argument will be upgraded to
an RV.  That RV will be modified to point to the new SV.  The C<classname>
argument indicates the package for the blessing.  Set C<classname> to
C<NULL> to avoid the blessing.  The new SV will have a reference count
of 1, and the RV will be returned.

Note that C<sv_setref_pv> copies the pointer while this copies the string.

=cut
*/

SV*
Perl_sv_setref_pvn(pTHX_ SV *const rv, const char *const classname,
                   const char *const pv, const STRLEN n)
{
    PERL_ARGS_ASSERT_SV_SETREF_PVN;

    sv_setpvn(newSVrv(rv,classname), pv, n);
    return rv;
}

/*
=for apidoc sv_bless

Blesses an SV into a specified package.  The SV must be an RV.  The package
must be designated by its stash (see C<gv_stashpv()>).  The reference count
of the SV is unaffected.

=cut
*/

SV*
Perl_sv_bless(pTHX_ SV *const sv, HV *const stash)
{
    dVAR;
    SV *tmpRef;

    PERL_ARGS_ASSERT_SV_BLESS;

    if (!SvROK(sv))
        Perl_croak(aTHX_ "Can't bless non-reference value");
    tmpRef = SvRV(sv);
    if (SvFLAGS(tmpRef) & (SVs_OBJECT|SVf_READONLY)) {
	if (SvIsCOW(tmpRef))
	    sv_force_normal_flags(tmpRef, 0);
	if (SvREADONLY(tmpRef))
	    Perl_croak(aTHX_ "%s", PL_no_modify);
	if (SvOBJECT(tmpRef)) {
	    if (SvTYPE(tmpRef) != SVt_PVIO)
		--PL_sv_objcount;
	    HvREFCNT_dec(SvSTASH(tmpRef));
	}
    }
    SvOBJECT_on(tmpRef);
    if (SvTYPE(tmpRef) != SVt_PVIO)
	++PL_sv_objcount;
    SvUPGRADE(tmpRef, SVt_PVMG);
    SvSTASH_set(tmpRef, HvREFCNT_inc(stash));

    if(SvSMAGICAL(tmpRef))
        if(mg_find(tmpRef, PERL_MAGIC_ext) || mg_find(tmpRef, PERL_MAGIC_uvar))
            mg_set(tmpRef);



    return sv;
}

/* Downgrades a PVGV to a PVMG.
 */

STATIC void
S_sv_unglob(pTHX_ SV *const sv)
{
    dVAR;
    void *xpvmg;
    HV *stash;
    SV * const temp = sv_newmortal();

    PERL_ARGS_ASSERT_SV_UNGLOB;

    assert(SvTYPE(sv) == SVt_PVGV);
    SvFAKE_off(sv);
    gv_efullname3(temp, MUTABLE_GV(sv), "*");

    if (GvGP(sv)) {
        if(GvCVu((const GV *)sv) && (stash = GvSTASH(MUTABLE_GV(sv)))
	   && HvNAME_get(stash))
            mro_method_changed_in(stash);
	gp_free(MUTABLE_GV(sv));
    }
    if (GvSTASH(sv)) {
	sv_del_backref(MUTABLE_SV(GvSTASH(sv)), sv);
	GvSTASH(sv) = NULL;
    }
    GvMULTI_off(sv);
    if (GvNAME_HEK(sv)) {
	unshare_hek(GvNAME_HEK(sv));
    }
    isGV_with_GP_off(sv);

    /* need to keep SvANY(sv) in the right arena */
    xpvmg = new_XPVMG();
    StructCopy(SvANY(sv), xpvmg, XPVMG);
    del_XPVGV(SvANY(sv));
    SvANY(sv) = xpvmg;

    SvFLAGS(sv) &= ~SVTYPEMASK;
    SvFLAGS(sv) |= SVt_PVMG;

    /* Intentionally not calling any local SET magic, as this isn't so much a
       set operation as merely an internal storage change.  */
    sv_setsv_flags(sv, temp, 0);
}

/*
=for apidoc sv_unref_flags

Unsets the RV status of the SV, and decrements the reference count of
whatever was being referenced by the RV.  This can almost be thought of
as a reversal of C<newSVrv>.  The C<cflags> argument can contain
C<SV_IMMEDIATE_UNREF> to force the reference count to be decremented
(otherwise the decrementing is conditional on the reference count being
different from one or the reference being a readonly SV).
See C<SvROK_off>.

=cut
*/

void
Perl_sv_unref_flags(pTHX_ SV *const ref, const U32 flags)
{
    SV* const target = SvRV(ref);

    PERL_ARGS_ASSERT_SV_UNREF_FLAGS;

    if (SvWEAKREF(ref)) {
    	sv_del_backref(target, ref);
	SvWEAKREF_off(ref);
	SvRV_set(ref, NULL);
	return;
    }
    SvRV_set(ref, NULL);
    SvROK_off(ref);
    /* You can't have a || SvREADONLY(target) here, as $a = $$a, where $a was
       assigned to as BEGIN {$a = \"Foo"} will fail.  */
    if (SvREFCNT(target) != 1 || (flags & SV_IMMEDIATE_UNREF))
	SvREFCNT_dec(target);
    else /* XXX Hack, but hard to make $a=$a->[1] work otherwise */
	sv_2mortal(target);	/* Schedule for freeing later */
}

/*
=for apidoc sv_setpviv

Copies an integer into the given SV, also updating its string value.
Does not handle 'set' magic.  See C<sv_setpviv_mg>.

=cut
*/

void
Perl_sv_setpviv(pTHX_ SV *const sv, const IV iv)
{
    char buf[TYPE_CHARS(UV)];
    char *ebuf;
    char * const ptr = uiv_2buf(buf, iv, 0, 0, &ebuf);

    PERL_ARGS_ASSERT_SV_SETPVIV;

    sv_setpvn(sv, ptr, ebuf - ptr);
}

/*
=for apidoc sv_setpviv_mg

Like C<sv_setpviv>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_setpviv_mg(pTHX_ SV *const sv, const IV iv)
{
    PERL_ARGS_ASSERT_SV_SETPVIV_MG;

    sv_setpviv(sv, iv);
    SvSETMAGIC(sv);
}

/*
=for apidoc sv_setpvf

Works like C<sv_catpvf> but copies the text into the SV instead of
appending it.  Does not handle 'set' magic.  See C<sv_setpvf_mg>.

=cut
*/

void
Perl_sv_setpvf(pTHX_ SV *const sv, const char *const pat, ...)
{
    va_list args;

    PERL_ARGS_ASSERT_SV_SETPVF;

    va_start(args, pat);
    sv_vsetpvf(sv, pat, &args);
    va_end(args);
}

/*
=for apidoc sv_vsetpvf

Works like C<sv_vcatpvf> but copies the text into the SV instead of
appending it.  Does not handle 'set' magic.  See C<sv_vsetpvf_mg>.

Usually used via its frontend C<sv_setpvf>.

=cut
*/

void
Perl_sv_vsetpvf(pTHX_ SV *const sv, const char *const pat, va_list *const args)
{
    PERL_ARGS_ASSERT_SV_VSETPVF;

    sv_vsetpvfn(sv, pat, strlen(pat), args, NULL, 0, NULL);
}

/*
=for apidoc sv_setpvf_mg

Like C<sv_setpvf>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_setpvf_mg(pTHX_ SV *const sv, const char *const pat, ...)
{
    va_list args;

    PERL_ARGS_ASSERT_SV_SETPVF_MG;

    va_start(args, pat);
    sv_vsetpvf_mg(sv, pat, &args);
    va_end(args);
}

/*
=for apidoc sv_vsetpvf_mg

Like C<sv_vsetpvf>, but also handles 'set' magic.

Usually used via its frontend C<sv_setpvf_mg>.

=cut
*/

void
Perl_sv_vsetpvf_mg(pTHX_ SV *const sv, const char *const pat, va_list *const args)
{
    PERL_ARGS_ASSERT_SV_VSETPVF_MG;

    sv_vsetpvfn(sv, pat, strlen(pat), args, NULL, 0, NULL);
    SvSETMAGIC(sv);
}

/*
=for apidoc sv_catpvf

Processes its arguments like C<sprintf> and appends the formatted
output to an SV.  If the appended data contains "wide" characters
(including, but not limited to, SVs with a UTF-8 PV formatted with %s,
and characters >255 formatted with %c), the original SV might get
upgraded to UTF-8.  Handles 'get' magic, but not 'set' magic.  See
C<sv_catpvf_mg>. If the original SV was UTF-8, the pattern should be
valid UTF-8; if the original SV was bytes, the pattern should be too.

=cut */

void
Perl_sv_catpvf(pTHX_ SV *const sv, const char *const pat, ...)
{
    va_list args;

    PERL_ARGS_ASSERT_SV_CATPVF;

    va_start(args, pat);
    sv_vcatpvf(sv, pat, &args);
    va_end(args);
}

/*
=for apidoc sv_vcatpvf

Processes its arguments like C<vsprintf> and appends the formatted output
to an SV.  Does not handle 'set' magic.  See C<sv_vcatpvf_mg>.

Usually used via its frontend C<sv_catpvf>.

=cut
*/

void
Perl_sv_vcatpvf(pTHX_ SV *const sv, const char *const pat, va_list *const args)
{
    PERL_ARGS_ASSERT_SV_VCATPVF;

    sv_vcatpvfn(sv, pat, strlen(pat), args, NULL, 0, NULL);
}

/*
=for apidoc sv_catpvf_mg

Like C<sv_catpvf>, but also handles 'set' magic.

=cut
*/

void
Perl_sv_catpvf_mg(pTHX_ SV *const sv, const char *const pat, ...)
{
    va_list args;

    PERL_ARGS_ASSERT_SV_CATPVF_MG;

    va_start(args, pat);
    sv_vcatpvf_mg(sv, pat, &args);
    va_end(args);
}

/*
=for apidoc sv_vcatpvf_mg

Like C<sv_vcatpvf>, but also handles 'set' magic.

Usually used via its frontend C<sv_catpvf_mg>.

=cut
*/

void
Perl_sv_vcatpvf_mg(pTHX_ SV *const sv, const char *const pat, va_list *const args)
{
    PERL_ARGS_ASSERT_SV_VCATPVF_MG;

    sv_vcatpvfn(sv, pat, strlen(pat), args, NULL, 0, NULL);
    SvSETMAGIC(sv);
}

/*
=for apidoc sv_vsetpvfn

Works like C<sv_vcatpvfn> but copies the text into the SV instead of
appending it.

Usually used via one of its frontends C<sv_vsetpvf> and C<sv_vsetpvf_mg>.

=cut
*/

void
Perl_sv_vsetpvfn(pTHX_ SV *const sv, const char *const pat, const STRLEN patlen,
                 va_list *const args, SV **const svargs, const I32 svmax, bool *const maybe_tainted)
{
    PERL_ARGS_ASSERT_SV_VSETPVFN;

    sv_setpvs(sv, "");
    sv_vcatpvfn(sv, pat, patlen, args, svargs, svmax, maybe_tainted);
}

STATIC I32
S_expect_number(pTHX_ char **const pattern)
{
    dVAR;
    I32 var = 0;

    PERL_ARGS_ASSERT_EXPECT_NUMBER;

    switch (**pattern) {
    case '1': case '2': case '3':
    case '4': case '5': case '6':
    case '7': case '8': case '9':
	var = *(*pattern)++ - '0';
	while (isDIGIT(**pattern)) {
	    const I32 tmp = var * 10 + (*(*pattern)++ - '0');
	    if (tmp < var)
		Perl_croak(aTHX_ "Integer overflow in format string for %s", (PL_op ? OP_NAME(PL_op) : "sv_vcatpvfn"));
	    var = tmp;
	}
    }
    return var;
}

STATIC char *
S_F0convert(NV nv, char *const endbuf, STRLEN *const len)
{
    const int neg = nv < 0;
    UV uv;

    PERL_ARGS_ASSERT_F0CONVERT;

    if (neg)
	nv = -nv;
    if (nv < UV_MAX) {
	char *p = endbuf;
	nv += 0.5;
	uv = (UV)nv;
	if (uv & 1 && uv == nv)
	    uv--;			/* Round to even */
	do {
	    const unsigned dig = uv % 10;
	    *--p = '0' + dig;
	} while (uv /= 10);
	if (neg)
	    *--p = '-';
	*len = endbuf - p;
	return p;
    }
    return NULL;
}


/*
=for apidoc sv_vcatpvfn

Processes its arguments like C<vsprintf> and appends the formatted output
to an SV.  Uses an array of SVs if the C style variable argument list is
missing (NULL).  When running with taint checks enabled, indicates via
C<maybe_tainted> if results are untrustworthy (often due to the use of
locales).

Usually used via one of its frontends C<sv_vcatpvf> and C<sv_vcatpvf_mg>.

=cut
*/


#define VECTORIZE_ARGS	vecsv = va_arg(*args, SV*);\
			vecstr = SvPV_const(vecsv,veclen);

/* XXX maybe_tainted is never assigned to, so the doc above is lying. */

void
Perl_sv_vcatpvfn(pTHX_ SV *const sv, const char *const pat, const STRLEN patlen,
                 va_list *const args, SV **const svargs, const I32 svmax, bool *const maybe_tainted)
{
    dVAR;
    char *p;
    char *q;
    const char *patend;
    STRLEN origlen;
    I32 svix = 0;
    static const char nullstr[] = "(null)";
    SV *argsv = NULL;
    /* Times 4: a decimal digit takes more than 3 binary digits.
     * NV_DIG: mantissa takes than many decimal digits.
     * Plus 32: Playing safe. */
    char ebuf[IV_DIG * 4 + NV_DIG + 32];
    /* large enough for "%#.#f" --chip */
    /* what about long double NVs? --jhi */

    PERL_ARGS_ASSERT_SV_VCATPVFN;
    PERL_UNUSED_ARG(maybe_tainted);

    /* no matter what, this is a string now */
    (void)SvPV_force(sv, origlen);

    /* special-case "", "%s", and "%-p" (SVf - see below) */
    if (patlen == 0)
	return;
    if (patlen == 2 && pat[0] == '%' && pat[1] == 's') {
	if (args) {
	    const char * const s = va_arg(*args, char*);
	    sv_catpv(sv, s ? s : nullstr);
	}
	else if (svix < svmax) {
	    sv_catsv(sv, *svargs);
	}
	return;
    }
    if (args && patlen == 3 && pat[0] == '%' &&
		pat[1] == '-' && pat[2] == 'p') {
	argsv = MUTABLE_SV(va_arg(*args, void*));
	sv_catsv(sv, argsv);
	return;
    }

#ifndef USE_LONG_DOUBLE
    /* special-case "%.<number>[gf]" */
    if ( !args && patlen <= 5 && pat[0] == '%' && pat[1] == '.'
	 && (pat[patlen-1] == 'g' || pat[patlen-1] == 'f') ) {
	unsigned digits = 0;
	const char *pp;

	pp = pat + 2;
	while (*pp >= '0' && *pp <= '9')
	    digits = 10 * digits + (*pp++ - '0');
	if (pp - pat == (int)patlen - 1) {
	    NV nv;

	    if (svix < svmax)
		nv = SvNV(*svargs);
	    else
		return;
	    if (*pp == 'g') {
		/* Add check for digits != 0 because it seems that some
		   gconverts are buggy in this case, and we don't yet have
		   a Configure test for this.  */
		if (digits && digits < sizeof(ebuf) - NV_DIG - 10) {
		     /* 0, point, slack */
		    Gconvert(nv, (int)digits, 0, ebuf);
		    sv_catpv(sv, ebuf);
		    if (*ebuf)	/* May return an empty string for digits==0 */
			return;
		}
	    } else if (!digits) {
		STRLEN l;

		if ((p = F0convert(nv, ebuf + sizeof ebuf, &l))) {
		    sv_catpvn(sv, p, l);
		    return;
		}
	    }
	}
    }
#endif /* !USE_LONG_DOUBLE */

    patend = (char*)pat + patlen;
    for (p = (char*)pat; p < patend; p = q) {
	bool alt = FALSE;
	bool left = FALSE;
	bool vectorize = FALSE;
	bool vectorarg = FALSE;
	char fill = ' ';
	char plus = 0;
	char intsize = 0;
	STRLEN width = 0;
	STRLEN zeros = 0;
	bool has_precis = FALSE;
	STRLEN precis = 0;
	const I32 osvix = svix;
	bool is_utf8 = FALSE;  /* is this item utf8?   */
#ifdef HAS_LDBL_SPRINTF_BUG
	/* This is to try to fix a bug with irix/nonstop-ux/powerux and
	   with sfio - Allen <allens@cpan.org> */
	bool fix_ldbl_sprintf_bug = FALSE;
#endif

	char esignbuf[4];
	char utf8buf[UTF8_MAXBYTES+1];
	STRLEN esignlen = 0;

	const char *eptr = NULL;
	const char *fmtstart;
	STRLEN elen = 0;
	SV *vecsv = NULL;
	const char *vecstr = NULL;
	STRLEN veclen = 0;
	char c = 0;
	int i;
	unsigned base = 0;
	IV iv = 0;
	UV uv = 0;
	/* we need a long double target in case HAS_LONG_DOUBLE but
	   not USE_LONG_DOUBLE
	*/
#if defined(HAS_LONG_DOUBLE) && LONG_DOUBLESIZE > DOUBLESIZE
	long double nv;
#else
	NV nv;
#endif
	STRLEN have;
	STRLEN need;
	STRLEN gap;
	const char *dotstr = ".";
	STRLEN dotstrlen = 1;
	I32 efix = 0; /* explicit format parameter index */
	I32 ewix = 0; /* explicit width index */
	I32 epix = 0; /* explicit precision index */
	I32 evix = 0; /* explicit vector index */
	bool asterisk = FALSE;

	/* echo everything up to the next format specification */
	for (q = p; q < patend && *q != '%'; ++q) ;
	if (q > p) {
	    sv_catpvn(sv, p, q - p);
	    p = q;
	}
	if (q++ >= patend)
	    break;

	fmtstart = q;

/*
    We allow format specification elements in this order:
	\d+\$              explicit format parameter index
	[-+ 0#]+           flags
	v|\*(\d+\$)?v      vector with optional (optionally specified) arg
	0		   flag (as above): repeated to allow "v02" 	
	\d+|\*(\d+\$)?     width using optional (optionally specified) arg
	\.(\d*|\*(\d+\$)?) precision using optional (optionally specified) arg
	[hlqLV]            size
    [%bcdefginopsuxDFOUX] format (mandatory)
*/

	if (args) {
/*  
	As of perl5.9.3, printf format checking is on by default.
	Internally, perl uses %p formats to provide an escape to
	some extended formatting.  This block deals with those
	extensions: if it does not match, (char*)q is reset and
	the normal format processing code is used.

	Currently defined extensions are:
		%p		include pointer address (standard)	
		%-p	(SVf)	include an SV (previously %_)
		%-<num>p	include an SV with precision <num>	
		%<num>p		reserved for future extensions

	Robin Barker 2005-07-14

		%1p	(VDf)	removed.  RMB 2007-10-19
*/
 	    char* r = q; 
	    bool sv = FALSE;	
	    STRLEN n = 0;
	    if (*q == '-')
		sv = *q++;
	    n = expect_number(&q);
	    if (*q++ == 'p') {
		if (sv) {			/* SVf */
		    if (n) {
			precis = n;
			has_precis = TRUE;
		    }
		    argsv = MUTABLE_SV(va_arg(*args, void*));
		    eptr = SvPV_const(argsv, elen);
		    goto string;
		}
		else if (n) {
		    if (ckWARN_d(WARN_INTERNAL))
			Perl_warner(aTHX_ packWARN(WARN_INTERNAL),
			"internal %%<num>p might conflict with future printf extensions");
		}
	    }
	    q = r; 
	}

	if ( (width = expect_number(&q)) ) {
	    if (*q == '$') {
		++q;
		efix = width;
	    } else {
		goto gotwidth;
	    }
	}

	/* FLAGS */

	while (*q) {
	    switch (*q) {
	    case ' ':
	    case '+':
		if (plus == '+' && *q == ' ') /* '+' over ' ' */
		    q++;
		else
		    plus = *q++;
		continue;

	    case '-':
		left = TRUE;
		q++;
		continue;

	    case '0':
		fill = *q++;
		continue;

	    case '#':
		alt = TRUE;
		q++;
		continue;

	    default:
		break;
	    }
	    break;
	}

      tryasterisk:
	if (*q == '*') {
	    q++;
	    if ( (ewix = expect_number(&q)) )
		if (*q++ != '$')
		    goto unknown;
	    asterisk = TRUE;
	}
	if (*q == 'v') {
	    q++;
	    if (vectorize)
		goto unknown;
	    if ((vectorarg = asterisk)) {
		evix = ewix;
		ewix = 0;
		asterisk = FALSE;
	    }
	    vectorize = TRUE;
	    goto tryasterisk;
	}

	if (!asterisk)
	{
	    if( *q == '0' )
		fill = *q++;
	    width = expect_number(&q);
	}

	if (vectorize) {
	    if (vectorarg) {
		if (args)
		    vecsv = va_arg(*args, SV*);
		else if (evix) {
		    vecsv = (evix > 0 && evix <= svmax)
			? svargs[evix-1] : &PL_sv_undef;
		} else {
		    vecsv = svix < svmax ? svargs[svix++] : &PL_sv_undef;
		}
		dotstr = SvPV_const(vecsv, dotstrlen);
	    }
	    if (args) {
		VECTORIZE_ARGS
	    }
	    else if (efix ? (efix > 0 && efix <= svmax) : svix < svmax) {
		vecsv = svargs[efix ? efix-1 : svix++];
		vecstr = SvPV_const(vecsv,veclen);

		/* if this is a version object, we need to convert
		 * back into v-string notation and then let the
		 * vectorize happen normally
		 */
		if (sv_derived_from(vecsv, "version")) {
		    char *version = savesvpv(vecsv);
		    if ( hv_exists(MUTABLE_HV(SvRV(vecsv)), "alpha", 5 ) ) {
			Perl_warner(aTHX_ packWARN(WARN_INTERNAL),
			"vector argument not supported with alpha versions");
			goto unknown;
		    }
		    vecsv = sv_newmortal();
		    scan_vstring(version, version + veclen, vecsv);
		    vecstr = SvPV_const(vecsv, veclen);
		    Safefree(version);
		}
	    }
	    else {
		vecstr = "";
		veclen = 0;
	    }
	}

	if (asterisk) {
	    if (args)
		i = va_arg(*args, int);
	    else
		i = (ewix ? ewix <= svmax : svix < svmax) ?
		    SvIV(svargs[ewix ? ewix-1 : svix++]) : 0;
	    left |= (i < 0);
	    width = (i < 0) ? -i : i;
	}
      gotwidth:

	/* PRECISION */

	if (*q == '.') {
	    q++;
	    if (*q == '*') {
		q++;
		if ( ((epix = expect_number(&q))) && (*q++ != '$') )
		    goto unknown;
		/* XXX: todo, support specified precision parameter */
		if (epix)
		    goto unknown;
		if (args)
		    i = va_arg(*args, int);
		else
		    i = (ewix ? ewix <= svmax : svix < svmax)
			? SvIV(svargs[ewix ? ewix-1 : svix++]) : 0;
		precis = i;
		has_precis = !(i < 0);
	    }
	    else {
		precis = 0;
		while (isDIGIT(*q))
		    precis = precis * 10 + (*q++ - '0');
		has_precis = TRUE;
	    }
	}

	/* SIZE */

	switch (*q) {
#ifdef WIN32
	case 'I':			/* Ix, I32x, and I64x */
#  ifdef WIN64
	    if (q[1] == '6' && q[2] == '4') {
		q += 3;
		intsize = 'q';
		break;
	    }
#  endif
	    if (q[1] == '3' && q[2] == '2') {
		q += 3;
		break;
	    }
#  ifdef WIN64
	    intsize = 'q';
#  endif
	    q++;
	    break;
#endif
#if defined(HAS_QUAD) || defined(HAS_LONG_DOUBLE)
	case 'L':			/* Ld */
	    /*FALLTHROUGH*/
#ifdef HAS_QUAD
	case 'q':			/* qd */
#endif
	    intsize = 'q';
	    q++;
	    break;
#endif
	case 'l':
#if defined(HAS_QUAD) || defined(HAS_LONG_DOUBLE)
	    if (*(q + 1) == 'l') {	/* lld, llf */
		intsize = 'q';
		q += 2;
		break;
	     }
#endif
	    /*FALLTHROUGH*/
	case 'h':
	    /*FALLTHROUGH*/
	case 'V':
	    intsize = *q++;
	    break;
	}

	/* CONVERSION */

	if (*q == '%') {
	    eptr = q++;
	    elen = 1;
	    if (vectorize) {
		c = '%';
		goto unknown;
	    }
	    goto string;
	}

	if (!vectorize && !args) {
	    if (efix) {
		const I32 i = efix-1;
		argsv = (i >= 0 && i < svmax) ? svargs[i] : &PL_sv_undef;
	    } else {
		argsv = (svix >= 0 && svix < svmax)
		    ? svargs[svix++] : &PL_sv_undef;
	    }
	}

	switch (c = *q++) {

	    /* STRINGS */

	case 'c':
	    if (vectorize)
		goto unknown;
	    uv = (args) ? va_arg(*args, int) : SvIV(argsv);
	    if ((!UNI_IS_INVARIANT(uv) && IN_CODEPOINTS)) {
		eptr = utf8buf;
		elen = uvchr_to_utf8(utf8buf, uv) - utf8buf;
		is_utf8 = TRUE;
	    }
	    else {
		if (uv > 255)
		    Perl_warner(aTHX_ packWARN(WARN_MISC),
				"character value > 255 without 'use codepoints'");
		c = (char)uv;
		eptr = &c;
		elen = 1;
	    }
	    goto string;

	case 'C':
	    if (vectorize)
		goto unknown;
	    uv = (args) ? va_arg(*args, int) : SvIV(argsv);
	    c = (char)uv;
	    eptr = &c;
	    elen = 1;
	    goto string;

	case 's':
	    if (vectorize)
		goto unknown;
	    if (args) {
		eptr = va_arg(*args, char*);
		if (eptr)
		    elen = strlen(eptr);
		else {
		    eptr = (char *)nullstr;
		    elen = sizeof nullstr - 1;
		}
	    }
	    else {
		eptr = SvPV_const(argsv, elen);
		if (IN_CODEPOINTS) {
		    STRLEN old_precis = precis;
		    if (has_precis && precis < elen) {
			STRLEN ulen = sv_len_utf8(argsv);
			I32 p = precis > ulen ? ulen : precis;
			sv_pos_u2b(argsv, &p, 0); /* sticks at end */
			precis = p;
		    }
		    if (width) { /* fudge width (can't fudge elen) */
			if (has_precis && precis < elen)
			    width += precis - old_precis;
			else
			    width += elen - sv_len_utf8(argsv);
		    }
		    is_utf8 = TRUE;
		}
	    }

	string:
	    if (has_precis && precis < elen)
		elen = precis;
	    break;

	    /* INTEGERS */

	case 'p':
	    if (alt || vectorize)
		goto unknown;
	    uv = PTR2UV(args ? va_arg(*args, void*) : argsv);
	    base = 16;
	    goto integer;

	case 'D':
#ifdef IV_IS_QUAD
	    intsize = 'q';
#else
	    intsize = 'l';
#endif
	    /*FALLTHROUGH*/
	case 'd':
	case 'i':
#if vdNUMBER
	format_vd:
#endif
	    if (vectorize) {
		STRLEN ulen;
		if (!veclen)
		    continue;
		if (IN_CODEPOINTS)
		    uv = utf8n_to_uvchr(vecstr, veclen, &ulen,
					UTF8_ALLOW_ANYUV);
		else {
		    uv = (U8)*vecstr;
		    ulen = 1;
		}
		vecstr += ulen;
		veclen -= ulen;
		if (plus)
		     esignbuf[esignlen++] = plus;
	    }
	    else if (args) {
		switch (intsize) {
		case 'h':	iv = (short)va_arg(*args, int); break;
		case 'l':	iv = va_arg(*args, long); break;
		case 'V':	iv = va_arg(*args, IV); break;
		default:	iv = va_arg(*args, int); break;
		case 'q':
#ifdef HAS_QUAD
				iv = va_arg(*args, Quad_t); break;
#else
				goto unknown;
#endif
		}
	    }
	    else {
		IV tiv = SvIV(argsv); /* work around GCC bug #13488 */
		switch (intsize) {
		case 'h':	iv = (short)tiv; break;
		case 'l':	iv = (long)tiv; break;
		case 'V':
		default:	iv = tiv; break;
		case 'q':
#ifdef HAS_QUAD
				iv = (Quad_t)tiv; break;
#else
				goto unknown;
#endif
		}
	    }
	    if ( !vectorize )	/* we already set uv above */
	    {
		if (iv >= 0) {
		    uv = iv;
		    if (plus)
			esignbuf[esignlen++] = plus;
		}
		else {
		    uv = -iv;
		    esignbuf[esignlen++] = '-';
		}
	    }
	    base = 10;
	    goto integer;

	case 'U':
#ifdef IV_IS_QUAD
	    intsize = 'q';
#else
	    intsize = 'l';
#endif
	    /*FALLTHROUGH*/
	case 'u':
	    base = 10;
	    goto uns_integer;

	case 'B':
	case 'b':
	    base = 2;
	    goto uns_integer;

	case 'O':
#ifdef IV_IS_QUAD
	    intsize = 'q';
#else
	    intsize = 'l';
#endif
	    /*FALLTHROUGH*/
	case 'o':
	    base = 8;
	    goto uns_integer;

	case 'X':
	case 'x':
	    base = 16;

	uns_integer:
	    if (vectorize) {
		STRLEN ulen;
	vector:
		if (!veclen)
		    continue;
		if (IN_CODEPOINTS)
		    uv = utf8n_to_uvchr(vecstr, veclen, &ulen,
					UTF8_ALLOW_ANYUV);
		else {
		    uv = (U8)*vecstr;
		    ulen = 1;
		}
		vecstr += ulen;
		veclen -= ulen;
	    }
	    else if (args) {
		switch (intsize) {
		case 'h':  uv = (unsigned short)va_arg(*args, unsigned); break;
		case 'l':  uv = va_arg(*args, unsigned long); break;
		case 'V':  uv = va_arg(*args, UV); break;
		default:   uv = va_arg(*args, unsigned); break;
		case 'q':
#ifdef HAS_QUAD
			   uv = va_arg(*args, Uquad_t); break;
#else
			   goto unknown;
#endif
		}
	    }
	    else {
		UV tuv = SvUV(argsv); /* work around GCC bug #13488 */
		switch (intsize) {
		case 'h':	uv = (unsigned short)tuv; break;
		case 'l':	uv = (unsigned long)tuv; break;
		case 'V':
		default:	uv = tuv; break;
		case 'q':
#ifdef HAS_QUAD
				uv = (Uquad_t)tuv; break;
#else
				goto unknown;
#endif
		}
	    }

	integer:
	    {
		char *ptr = ebuf + sizeof ebuf;
		bool tempalt = uv ? alt : FALSE; /* Vectors can't change alt */
		zeros = 0;

		switch (base) {
		    unsigned dig;
		case 16:
		    p = (char *)((c == 'X') ? PL_hexdigit + 16 : PL_hexdigit);
		    do {
			dig = uv & 15;
			*--ptr = p[dig];
		    } while (uv >>= 4);
		    if (tempalt) {
			esignbuf[esignlen++] = '0';
			esignbuf[esignlen++] = c;  /* 'x' or 'X' */
		    }
		    break;
		case 8:
		    do {
			dig = uv & 7;
			*--ptr = '0' + dig;
		    } while (uv >>= 3);
		    if (alt && *ptr != '0')
			*--ptr = '0';
		    break;
		case 2:
		    do {
			dig = uv & 1;
			*--ptr = '0' + dig;
		    } while (uv >>= 1);
		    if (tempalt) {
			esignbuf[esignlen++] = '0';
			esignbuf[esignlen++] = c;
		    }
		    break;
		default:		/* it had better be ten or less */
		    do {
			dig = uv % base;
			*--ptr = '0' + dig;
		    } while (uv /= base);
		    break;
		}
		elen = (ebuf + sizeof ebuf) - ptr;
		eptr = ptr;
		if (has_precis) {
		    if (precis > elen)
			zeros = precis - elen;
		    else if (precis == 0 && elen == 1 && *eptr == '0'
			     && !(base == 8 && alt)) /* "%#.0o" prints "0" */
			elen = 0;

		/* a precision nullifies the 0 flag. */
		    if (fill == '0')
			fill = ' ';
		}
	    }
	    break;

	    /* FLOATING POINT */

	case 'F':
	    c = 'f';		/* maybe %F isn't supported here */
	    /*FALLTHROUGH*/
	case 'e': case 'E':
	case 'f':
	case 'g': case 'G':
	    if (vectorize)
		goto unknown;

	    /* This is evil, but floating point is even more evil */

	    /* for SV-style calling, we can only get NV
	       for C-style calling, we assume %f is double;
	       for simplicity we allow any of %Lf, %llf, %qf for long double
	    */
	    switch (intsize) {
	    case 'V':
#if defined(USE_LONG_DOUBLE)
		intsize = 'q';
#endif
		break;
/* [perl #20339] - we should accept and ignore %lf rather than die */
	    case 'l':
		/*FALLTHROUGH*/
	    default:
#if defined(USE_LONG_DOUBLE)
		intsize = args ? 0 : 'q';
#endif
		break;
	    case 'q':
#if defined(HAS_LONG_DOUBLE)
		break;
#else
		/*FALLTHROUGH*/
#endif
	    case 'h':
		goto unknown;
	    }

	    /* now we need (long double) if intsize == 'q', else (double) */
	    nv = (args) ?
#if LONG_DOUBLESIZE > DOUBLESIZE
		intsize == 'q' ?
		    va_arg(*args, long double) :
		    va_arg(*args, double)
#else
		    va_arg(*args, double)
#endif
		: SvNV(argsv);

	    need = 0;
	    /* nv * 0 will be NaN for NaN, +Inf and -Inf, and 0 for anything
	       else. frexp() has some unspecified behaviour for those three */
	    if (c != 'e' && c != 'E' && (nv * 0) == 0) {
		i = PERL_INT_MIN;
		/* FIXME: if HAS_LONG_DOUBLE but not USE_LONG_DOUBLE this
		   will cast our (long double) to (double) */
		(void)Perl_frexp(nv, &i);
		if (i == PERL_INT_MIN)
		    Perl_die(aTHX_ "panic: frexp");
		if (i > 0)
		    need = BIT_DIGITS(i);
	    }
	    need += has_precis ? precis : 6; /* known default */

	    if (need < width)
		need = width;

#ifdef HAS_LDBL_SPRINTF_BUG
	    /* This is to try to fix a bug with irix/nonstop-ux/powerux and
	       with sfio - Allen <allens@cpan.org> */

#  ifdef DBL_MAX
#    define MY_DBL_MAX DBL_MAX
#  else /* XXX guessing! HUGE_VAL may be defined as infinity, so not using */
#    if DOUBLESIZE >= 8
#      define MY_DBL_MAX 1.7976931348623157E+308L
#    else
#      define MY_DBL_MAX 3.40282347E+38L
#    endif
#  endif

#  ifdef HAS_LDBL_SPRINTF_BUG_LESS1 /* only between -1L & 1L - Allen */
#    define MY_DBL_MAX_BUG 1L
#  else
#    define MY_DBL_MAX_BUG MY_DBL_MAX
#  endif

#  ifdef DBL_MIN
#    define MY_DBL_MIN DBL_MIN
#  else  /* XXX guessing! -Allen */
#    if DOUBLESIZE >= 8
#      define MY_DBL_MIN 2.2250738585072014E-308L
#    else
#      define MY_DBL_MIN 1.17549435E-38L
#    endif
#  endif

	    if ((intsize == 'q') && (c == 'f') &&
		((nv < MY_DBL_MAX_BUG) && (nv > -MY_DBL_MAX_BUG)) &&
		(need < DBL_DIG)) {
		/* it's going to be short enough that
		 * long double precision is not needed */

		if ((nv <= 0L) && (nv >= -0L))
		    fix_ldbl_sprintf_bug = TRUE; /* 0 is 0 - easiest */
		else {
		    /* would use Perl_fp_class as a double-check but not
		     * functional on IRIX - see perl.h comments */

		    if ((nv >= MY_DBL_MIN) || (nv <= -MY_DBL_MIN)) {
			/* It's within the range that a double can represent */
#if defined(DBL_MAX) && !defined(DBL_MIN)
			if ((nv >= ((long double)1/DBL_MAX)) ||
			    (nv <= (-(long double)1/DBL_MAX)))
#endif
			fix_ldbl_sprintf_bug = TRUE;
		    }
		}
		if (fix_ldbl_sprintf_bug == TRUE) {
		    double temp;

		    intsize = 0;
		    temp = (double)nv;
		    nv = (NV)temp;
		}
	    }

#  undef MY_DBL_MAX
#  undef MY_DBL_MAX_BUG
#  undef MY_DBL_MIN

#endif /* HAS_LDBL_SPRINTF_BUG */

	    need += 20; /* fudge factor */
	    if (PL_efloatsize < need) {
		Safefree(PL_efloatbuf);
		PL_efloatsize = need + 20; /* more fudge */
		Newx(PL_efloatbuf, PL_efloatsize, char);
		PL_efloatbuf[0] = '\0';
	    }

	    if ( !(width || left || plus || alt) && fill != '0'
		 && has_precis && intsize != 'q' ) {	/* Shortcuts */
		/* See earlier comment about buggy Gconvert when digits,
		   aka precis is 0  */
		if ( c == 'g' && precis) {
		    Gconvert((NV)nv, (int)precis, 0, PL_efloatbuf);
		    /* May return an empty string for digits==0 */
		    if (*PL_efloatbuf) {
			elen = strlen(PL_efloatbuf);
			goto float_converted;
		    }
		} else if ( c == 'f' && !precis) {
		    if ((eptr = F0convert(nv, ebuf + sizeof ebuf, &elen)))
			break;
		}
	    }
	    {
		char *ptr = ebuf + sizeof ebuf;
		*--ptr = '\0';
		*--ptr = c;
		/* FIXME: what to do if HAS_LONG_DOUBLE but not PERL_PRIfldbl? */
#if defined(HAS_LONG_DOUBLE) && defined(PERL_PRIfldbl)
		if (intsize == 'q') {
		    /* Copy the one or more characters in a long double
		     * format before the 'base' ([efgEFG]) character to
		     * the format string. */
		    static char const prifldbl[] = PERL_PRIfldbl;
		    char const *p = prifldbl + sizeof(prifldbl) - 3;
		    while (p >= prifldbl) { *--ptr = *p--; }
		}
#endif
		if (has_precis) {
		    base = precis;
		    do { *--ptr = '0' + (base % 10); } while (base /= 10);
		    *--ptr = '.';
		}
		if (width) {
		    base = width;
		    do { *--ptr = '0' + (base % 10); } while (base /= 10);
		}
		if (fill == '0')
		    *--ptr = fill;
		if (left)
		    *--ptr = '-';
		if (plus)
		    *--ptr = plus;
		if (alt)
		    *--ptr = '#';
		*--ptr = '%';

		/* No taint.  Otherwise we are in the strange situation
		 * where printf() taints but print($float) doesn't.
		 * --jhi */
#if defined(HAS_LONG_DOUBLE)
		elen = ((intsize == 'q')
			? my_snprintf(PL_efloatbuf, PL_efloatsize, ptr, nv)
			: my_snprintf(PL_efloatbuf, PL_efloatsize, ptr, (double)nv));
#else
		elen = my_sprintf(PL_efloatbuf, ptr, nv);
#endif
	    }
	float_converted:
	    eptr = PL_efloatbuf;
	    break;

	    /* SPECIAL */

	case 'n':
	    if (vectorize)
		goto unknown;
	    i = SvCUR(sv) - origlen;
	    if (args) {
		switch (intsize) {
		case 'h':	*(va_arg(*args, short*)) = i; break;
		default:	*(va_arg(*args, int*)) = i; break;
		case 'l':	*(va_arg(*args, long*)) = i; break;
		case 'V':	*(va_arg(*args, IV*)) = i; break;
		case 'q':
#ifdef HAS_QUAD
				*(va_arg(*args, Quad_t*)) = i; break;
#else
				goto unknown;
#endif
		}
	    }
	    else
		sv_setuv_mg(argsv, (UV)i);
	    continue;	/* not "break" */

	    /* UNKNOWN */

	default:
      unknown:
	    if (!args
		&& (PL_op->op_type == OP_PRTF || PL_op->op_type == OP_SPRINTF)
		&& ckWARN(WARN_PRINTF))
	    {
		SV * const msg = sv_newmortal();
		Perl_sv_setpvf(aTHX_ msg, "Invalid conversion in %sprintf: ",
			  (PL_op->op_type == OP_PRTF) ? "" : "s");
		if (fmtstart < patend) {
		    const char * const fmtend = q < patend ? q : patend;
		    const char * f;
		    sv_catpvs(msg, "\"%");
		    for (f = fmtstart; f < fmtend; f++) {
			if (isPRINT(*f)) {
			    sv_catpvn(msg, f, 1);
			} else {
			    Perl_sv_catpvf(aTHX_ msg,
					   "\\%03"UVof, (UV)*f & 0xFF);
			}
		    }
		    sv_catpvs(msg, "\"");
		} else {
		    sv_catpvs(msg, "end of string");
		}
		Perl_warner(aTHX_ packWARN(WARN_PRINTF), "%"SVf, SVfARG(msg)); /* yes, this is reentrant */
	    }

	    /* output mangled stuff ... */
	    if (c == '\0')
		--q;
	    eptr = p;
	    elen = q - p;

	    /* ... right here, because formatting flags should not apply */
	    SvGROW(sv, SvCUR(sv) + elen + 1);
	    p = SvEND(sv);
	    Copy(eptr, p, elen, char);
	    p += elen;
	    *p = '\0';
	    SvCUR_set(sv, p - SvPVX_const(sv));
	    svix = osvix;
	    continue;	/* not "break" */
	}

	have = esignlen + zeros + elen;
	if (have < zeros)
	    croak(aTHX_ "%s", PL_memory_wrap);

	need = (have > width ? have : width);
	gap = need - have;

	if (need >= (((STRLEN)~0) - SvCUR(sv) - dotstrlen - 1))
	    croak(aTHX_ "%s", PL_memory_wrap);
	SvGROW(sv, SvCUR(sv) + need + dotstrlen + 1);
	p = SvEND(sv);
	if (esignlen && fill == '0') {
	    int i;
	    for (i = 0; i < (int)esignlen; i++)
		*p++ = esignbuf[i];
	}
	if (gap && !left) {
	    memset(p, fill, gap);
	    p += gap;
	}
	if (esignlen && fill != '0') {
	    int i;
	    for (i = 0; i < (int)esignlen; i++)
		*p++ = esignbuf[i];
	}
	if (zeros) {
	    int i;
	    for (i = zeros; i; i--)
		*p++ = '0';
	}
	if (elen) {
	    Copy(eptr, p, elen, char);
	    p += elen;
	}
	if (gap && left) {
	    memset(p, ' ', gap);
	    p += gap;
	}
	if (vectorize) {
	    if (veclen) {
		Copy(dotstr, p, dotstrlen, char);
		p += dotstrlen;
	    }
	    else
		vectorize = FALSE;		/* done iterating over vecstr */
	}
	*p = '\0';
	SvCUR_set(sv, p - SvPVX_const(sv));
	if (vectorize) {
	    esignlen = 0;
	    goto vector;
	}
    }
}

/* =========================================================================

=head1 Cloning an interpreter

All the macros and functions in this section are for the private use of
the main function, perl_clone().

The foo_dup() functions make an exact copy of an existing foo thingy.
During the course of a cloning, a hash table is used to map old addresses
to new addresses. The table is created and manipulated with the
ptr_table_* functions.

=cut

============================================================================*/

/* create a new pointer-mapping table */

PTR_TBL_t *
Perl_ptr_table_new(pTHX)
{
    PTR_TBL_t *tbl;
    PERL_UNUSED_CONTEXT;

    Newxz(tbl, 1, PTR_TBL_t);
    tbl->tbl_max	= 511;
    tbl->tbl_items	= 0;
    Newxz(tbl->tbl_ary, tbl->tbl_max + 1, PTR_TBL_ENT_t*);
    return tbl;
}

#define PTR_TABLE_HASH(ptr) \
  ((PTR2UV(ptr) >> 3) ^ (PTR2UV(ptr) >> (3 + 7)) ^ (PTR2UV(ptr) >> (3 + 17)))

/* 
   we use the PTE_SVSLOT 'reservation' made above, both here (in the
   following define) and at call to new_body_inline made below in 
   Perl_ptr_table_store()
 */

#define del_pte(p)     del_body_type(p, PTE_SVSLOT)

/* map an existing pointer using a table */

STATIC PTR_TBL_ENT_t *
S_ptr_table_find(PTR_TBL_t *tbl, const void *sv)
{
    PTR_TBL_ENT_t *tblent;
    const UV hash = PTR_TABLE_HASH(sv);

    PERL_ARGS_ASSERT_PTR_TABLE_FIND;

    tblent = tbl->tbl_ary[hash & tbl->tbl_max];
    for (; tblent; tblent = tblent->next) {
	if (tblent->oldval == sv)
	    return tblent;
    }
    return NULL;
}

void *
Perl_ptr_table_fetch(pTHX_ PTR_TBL_t *tbl, const void *sv)
{
    PTR_TBL_ENT_t const *const tblent = ptr_table_find(tbl, sv);

    PERL_ARGS_ASSERT_PTR_TABLE_FETCH;
    PERL_UNUSED_CONTEXT;

    return tblent ? tblent->newval : NULL;
}

/* add a new entry to a pointer-mapping table */

void
Perl_ptr_table_store(pTHX_ PTR_TBL_t *tbl, const void *oldsv, void *newsv)
{
    PTR_TBL_ENT_t *tblent = ptr_table_find(tbl, oldsv);

    PERL_ARGS_ASSERT_PTR_TABLE_STORE;
    PERL_UNUSED_CONTEXT;

    if (tblent) {
	tblent->newval = newsv;
    } else {
	const UV entry = PTR_TABLE_HASH(oldsv) & tbl->tbl_max;

	new_body_inline(tblent, PTE_SVSLOT);

	tblent->oldval = oldsv;
	tblent->newval = newsv;
	tblent->next = tbl->tbl_ary[entry];
	tbl->tbl_ary[entry] = tblent;
	tbl->tbl_items++;
	if (tblent->next && tbl->tbl_items > tbl->tbl_max)
	    ptr_table_split(tbl);
    }
}

/* double the hash bucket size of an existing ptr table */

void
Perl_ptr_table_split(pTHX_ PTR_TBL_t *tbl)
{
    PTR_TBL_ENT_t **ary = tbl->tbl_ary;
    const UV oldsize = tbl->tbl_max + 1;
    UV newsize = oldsize * 2;
    UV i;

    PERL_ARGS_ASSERT_PTR_TABLE_SPLIT;
    PERL_UNUSED_CONTEXT;

    Renew(ary, newsize, PTR_TBL_ENT_t*);
    Zero(&ary[oldsize], newsize-oldsize, PTR_TBL_ENT_t*);
    tbl->tbl_max = --newsize;
    tbl->tbl_ary = ary;
    for (i=0; i < oldsize; i++, ary++) {
	PTR_TBL_ENT_t **curentp, **entp, *ent;
	if (!*ary)
	    continue;
	curentp = ary + oldsize;
	for (entp = ary, ent = *ary; ent; ent = *entp) {
	    if ((newsize & PTR_TABLE_HASH(ent->oldval)) != i) {
		*entp = ent->next;
		ent->next = *curentp;
		*curentp = ent;
		continue;
	    }
	    else
		entp = &ent->next;
	}
    }
}

/* remove all the entries from a ptr table */

void
Perl_ptr_table_clear(pTHX_ PTR_TBL_t *tbl)
{
    if (tbl && tbl->tbl_items) {
	register PTR_TBL_ENT_t * const * const array = tbl->tbl_ary;
	UV riter = tbl->tbl_max;

	do {
	    PTR_TBL_ENT_t *entry = array[riter];

	    while (entry) {
		PTR_TBL_ENT_t * const oentry = entry;
		entry = entry->next;
		del_pte(oentry);
	    }
	} while (riter--);

	tbl->tbl_items = 0;
    }
}

/* clear and free a ptr table */

void
Perl_ptr_table_free(pTHX_ PTR_TBL_t *tbl)
{
    if (!tbl) {
        return;
    }
    ptr_table_clear(tbl);
    Safefree(tbl->tbl_ary);
    Safefree(tbl);
}

/*
=head1 Unicode Support

=for apidoc sv_recode_to_utf8

The encoding is assumed to be an Encode object, on entry the PV
of the sv is assumed to be octets in that encoding, and the sv
will be converted into Unicode (and UTF-8).

If the sv already is UTF-8 (or if it is not POK), or if the encoding
is not a reference, nothing is done to the sv.  If the encoding is not
an C<Encode::XS> Encoding object, bad things will happen.
(See F<lib/encoding.pm> and L<Encode>).

The PV of the sv is returned.

=cut */

char *
Perl_sv_recode_to_utf8(pTHX_ SV *sv, SV *encoding)
{
    dVAR;
    PERL_ARGS_ASSERT_SV_RECODE_TO_UTF8;

    if (SvPOK(sv) && !IN_BYTES && SvROK(encoding)) {
	SV *uni;
	STRLEN len;
	const char *s;
	dSP;
	ENTER_named("call_decode");
	SAVETMPS;
	save_re_context();
	PUSHMARK(sp);
	EXTEND(SP, 3);
	XPUSHs(encoding);
	XPUSHs(sv);
/*
  NI-S 2002/07/09
  Passing sv_yes is wrong - it needs to be or'ed set of constants
  for Encode::XS, while UTf-8 decode (currently) assumes a true value means
  remove converted chars from source.

  Both will default the value - let them.

	XPUSHs(&PL_sv_yes);
*/
	PUTBACK;
	uni = call_method("decode", G_SCALAR);
	SPAGAIN;
	s = SvPV_const(uni, len);
	if (s != SvPVX_const(sv)) {
	    SvGROW(sv, len + 1);
	    Move(s, SvPVX_mutable(sv), len + 1, char);
	    SvCUR_set(sv, len);
	}
	FREETMPS;
	LEAVE_named("call_decode");
	return SvPVX_mutable(sv);
    }
    return SvPOKp(sv) ? SvPVX_mutable(sv) : NULL;
}

/* ---------------------------------------------------------------------
 *
 * support functions for report_uninit()
 */

/* the maxiumum size of array or hash where we will scan looking
 * for the undefined element that triggered the warning */

#define FUV_MAX_SEARCH_SIZE 1000

/* Look for an entry in the hash whose value has the same SV as val;
 * If so, return a mortal copy of the key. */

STATIC SV*
S_find_hash_subscript(pTHX_ const HV *const hv, const SV *const val)
{
    dVAR;
    register HE **array;
    I32 i;

    PERL_ARGS_ASSERT_FIND_HASH_SUBSCRIPT;

    if (!hv || SvMAGICAL(hv) || !HvARRAY(hv) ||
			(HvTOTALKEYS(hv) > FUV_MAX_SEARCH_SIZE))
	return NULL;

    array = HvARRAY(hv);

    for (i=HvMAX(hv); i>0; i--) {
	register HE *entry;
	for (entry = array[i]; entry; entry = HeNEXT(entry)) {
	    if (HeVAL(entry) != val)
		continue;
	    if (    HeVAL(entry) == &PL_sv_undef ||
		    HeVAL(entry) == &PL_sv_placeholder)
		continue;
	    if (!HeKEY(entry))
		return NULL;
	    if (HeKLEN(entry) == HEf_SVKEY)
		return sv_mortalcopy(HeKEY_sv(entry));
	    return sv_2mortal(newSVhek(HeKEY_hek(entry)));
	}
    }
    return NULL;
}

/* Look for an entry in the array whose value has the same SV as val;
 * If so, return the index, otherwise return -1. */

STATIC I32
S_find_array_subscript(pTHX_ const AV *const av, const SV *const val)
{
    dVAR;

    PERL_ARGS_ASSERT_FIND_ARRAY_SUBSCRIPT;

    if (!av || SvMAGICAL(av) || !AvARRAY(av) ||
			(AvFILLp(av) > FUV_MAX_SEARCH_SIZE))
	return -1;

    if (val != &PL_sv_undef) {
	SV ** const svp = AvARRAY(av);
	I32 i;

	for (i=AvFILLp(av); i>=0; i--)
	    if (svp[i] == val)
		return i;
    }
    return -1;
}

/* S_varname(): return the name of a variable, optionally with a subscript.
 * If gv is non-zero, use the name of that global, along with gvtype (one
 * of "$", "@", "%"); otherwise use the name of the lexical at pad offset
 * targ.  Depending on the value of the subscript_type flag, return:
 */

#define FUV_SUBSCRIPT_NONE	1	/* "@foo"          */
#define FUV_SUBSCRIPT_ARRAY	2	/* "$foo[aindex]"  */
#define FUV_SUBSCRIPT_HASH	3	/* "$foo{keyname}" */
#define FUV_SUBSCRIPT_WITHIN	4	/* "within @foo"   */

STATIC SV*
S_varname(pTHX_ const GV *const gv, const char gvtype, PADOFFSET targ,
	const SV *const keyname, I32 aindex, int subscript_type)
{

    SV * const name = sv_newmortal();
    if (gv) {
	char buffer[2];
	buffer[0] = gvtype;
	buffer[1] = 0;

	gv_fullname3(name, gv, buffer);
    }
    else {
	CV * const cv = find_runcv(NULL);
	SV *sv;
	AV *av;

	if (!cv || !CvPADLIST(cv))
	    return NULL;
	av = MUTABLE_AV((*av_fetch(CvPADLIST(cv), 0, FALSE)));
	sv = *av_fetch(av, targ, FALSE);
	sv_setpvn(name, SvPV_nolen_const(sv), SvCUR(sv));
    }

    if (subscript_type == FUV_SUBSCRIPT_HASH) {
	SV * const sv = newSV(0);
	Perl_sv_catpvf(aTHX_ name, "{%s}",
	    pv_display(sv,SvPVX_const(keyname), SvCUR(keyname), 0, 32));
	SvREFCNT_dec(sv);
    }
    else if (subscript_type == FUV_SUBSCRIPT_ARRAY) {
	Perl_sv_catpvf(aTHX_ name, "[%"IVdf"]", (IV)aindex);
    }
    else if (subscript_type == FUV_SUBSCRIPT_WITHIN) {
	/* We know that name has no magic, so can use 0 instead of SV_GMAGIC */
	Perl_sv_insert_flags(aTHX_ name, 0, 0,  STR_WITH_LEN("within "), 0);
    }

    return name;
}


/*
=for apidoc find_uninit_var

Find the name of the undefined variable (if any) that caused the operator o
to issue a "Use of uninitialized value" warning.
If match is true, only return a name if it's value matches uninit_sv.
So roughly speaking, if a unary operator (such as OP_COS) generates a
warning, then following the direct child of the op may yield an
OP_PADSV or OP_GV that gives the name of the undefined variable. On the
other hand, with OP_ADD there are two branches to follow, so we only print
the variable name if we get an exact match.

The name is returned as a mortal SV.

Assumes that PL_op is the op that originally triggered the error, and that
PL_comppad/PL_curpad points to the currently executing pad.

=cut
*/

STATIC SV *
S_find_uninit_var(pTHX_ const OP *const obase, const SV *const uninit_sv,
		  bool match)
{
    dVAR;
    SV *sv;
    const GV *gv;
    const OP *o, *o2, *kid;

    if (!obase || (match && (!uninit_sv || uninit_sv == &PL_sv_undef ||
			    uninit_sv == &PL_sv_placeholder)))
	return NULL;

    switch (obase->op_type) {

    case OP_RV2AV:
    case OP_RV2HV:
      {
	const bool hash = (obase->op_type == OP_RV2HV);
	I32 index = 0;
	SV *keysv = NULL;
	int subscript_type = FUV_SUBSCRIPT_WITHIN;

	    if (cUNOPx(obase)->op_first->op_type == OP_GV) {
	    /* @global, %global */
		gv = cGVOPx_gv(cUNOPx(obase)->op_first);
		if (!gv)
		    break;
		sv = hash ? MUTABLE_SV(GvHV(gv)): MUTABLE_SV(GvAV(gv));
	    }
	    else /* @{expr}, %{expr} */
		return find_uninit_var(cUNOPx(obase)->op_first,
						    uninit_sv, match);

	/* attempt to find a match within the aggregate */
	if (hash) {
	    keysv = find_hash_subscript((const HV*)sv, uninit_sv);
	    if (keysv)
		subscript_type = FUV_SUBSCRIPT_HASH;
	}
	else {
	    index = find_array_subscript((const AV *)sv, uninit_sv);
	    if (index >= 0)
		subscript_type = FUV_SUBSCRIPT_ARRAY;
	}

	if (match && subscript_type == FUV_SUBSCRIPT_WITHIN)
	    break;

	return varname(gv, hash ? '%' : '@', obase->op_targ,
				    keysv, index, subscript_type);
      }

    case OP_PADSV:
	if (match && PAD_SVl(obase->op_targ) != uninit_sv)
	    break;
	return varname(NULL, '$', obase->op_targ,
				    NULL, 0, FUV_SUBSCRIPT_NONE);

    case OP_GVSV:
	gv = cGVOPx_gv(obase);
	if (!gv || (match && GvSV(gv) != uninit_sv))
	    break;
	return varname(gv, '$', 0, NULL, 0, FUV_SUBSCRIPT_NONE);

    case OP_AELEMFAST:
	if (obase->op_flags & OPf_SPECIAL) { /* lexical array */
	    if (match) {
		SV **svp;
		AV *av = MUTABLE_AV(PAD_SV(obase->op_targ));
		if (!av || SvRMAGICAL(av))
		    break;
		svp = av_fetch(av, (I32)obase->op_private, FALSE);
		if (!svp || *svp != uninit_sv)
		    break;
	    }
	    return varname(NULL, '@', obase->op_targ,
		    NULL, (I32)obase->op_private, FUV_SUBSCRIPT_ARRAY);
	}
	else {
	    gv = cGVOPx_gv(obase);
	    if (!gv)
		break;
	    if (match) {
		SV **svp;
		AV *const av = GvAV(gv);
		if (!av || SvRMAGICAL(av))
		    break;
		svp = av_fetch(av, (I32)obase->op_private, FALSE);
		if (!svp || *svp != uninit_sv)
		    break;
	    }
	    return varname(gv, '@', 0,
		    NULL, (I32)obase->op_private, FUV_SUBSCRIPT_ARRAY);
	}
	break;

    case OP_EXISTS:
	o = cUNOPx(obase)->op_first;
	if (!o || o->op_type != OP_NULL ||
		! (o->op_targ == OP_AELEM || o->op_targ == OP_HELEM))
	    break;
	return find_uninit_var(cBINOPo->op_last, uninit_sv, match);

    case OP_AELEM:
    case OP_HELEM:
	if (PL_op == obase)
	    /* $a[uninit_expr] or $h{uninit_expr} */
	    return find_uninit_var(cBINOPx(obase)->op_last, uninit_sv, match);

	gv = NULL;
	o = cBINOPx(obase)->op_first;
	kid = cBINOPx(obase)->op_last;

	/* get the av or hv, and optionally the gv */
	sv = NULL;
	if  (o->op_type == OP_PADSV) {
	    sv = PAD_SV(o->op_targ);
	}
	else if ((o->op_type == OP_RV2AV || o->op_type == OP_RV2HV)
		&& cUNOPo->op_first->op_type == OP_GV)
	{
	    gv = cGVOPx_gv(cUNOPo->op_first);
	    if (!gv)
		break;
	    sv = o->op_type
		== OP_RV2HV ? MUTABLE_SV(GvHV(gv)) : MUTABLE_SV(GvAV(gv));
	}
	if (!sv)
	    break;

	if (kid && kid->op_type == OP_CONST && SvOK(cSVOPx_sv(kid))) {
	    /* index is constant */
	    if (match) {
		if (SvMAGICAL(sv))
		    break;
		if (obase->op_type == OP_HELEM) {
		    HE* he = hv_fetch_ent(MUTABLE_HV(sv), cSVOPx_sv(kid), 0, 0);
		    if (!he || HeVAL(he) != uninit_sv)
			break;
		}
		else {
		    SV * const * const svp = av_fetch(MUTABLE_AV(sv), SvIV(cSVOPx_sv(kid)), FALSE);
		    if (!svp || *svp != uninit_sv)
			break;
		}
	    }
	    if (obase->op_type == OP_HELEM)
		return varname(gv, '%', o->op_targ,
			    cSVOPx_sv(kid), 0, FUV_SUBSCRIPT_HASH);
	    else
		return varname(gv, '@', o->op_targ, NULL,
			    SvIV(cSVOPx_sv(kid)), FUV_SUBSCRIPT_ARRAY);
	}
	else  {
	    /* index is an expression;
	     * attempt to find a match within the aggregate */
	    if (obase->op_type == OP_HELEM) {
		SV * const keysv = find_hash_subscript((const HV*)sv, uninit_sv);
		if (keysv)
		    return varname(gv, '%', o->op_targ,
						keysv, 0, FUV_SUBSCRIPT_HASH);
	    }
	    else {
		const I32 index
		    = find_array_subscript((const AV *)sv, uninit_sv);
		if (index >= 0)
		    return varname(gv, '@', o->op_targ,
					NULL, index, FUV_SUBSCRIPT_ARRAY);
	    }
	    if (match)
		break;
	    return varname(gv, (obase->op_type == OP_HELEM ? '%' : '@'),
			   o->op_targ, NULL, 0, FUV_SUBSCRIPT_WITHIN);
	}
	break;

    case OP_OPEN:
	o = cUNOPx(obase)->op_first;
	if (o->op_type == OP_PUSHMARK)
	    o = o->op_sibling;

	if (!o->op_sibling) {
	    /* one-arg version of open is highly magical */

	    if (o->op_type == OP_GV) { /* open FOO; */
		gv = cGVOPx_gv(o);
		if (match && GvSV(gv) != uninit_sv)
		    break;
		return varname(gv, '$', 0,
			    NULL, 0, FUV_SUBSCRIPT_NONE);
	    }
	    /* other possibilities not handled are:
	     * open $x; or open my $x;	should return '${*$x}'
	     * open expr;		should return '$'.expr ideally
	     */
	     break;
	}
	goto do_op;

    /* ops where $_ may be an implicit arg */
    case OP_SUBST:
    case OP_MATCH:
	if ( !(obase->op_flags & OPf_STACKED)) {
	    if (uninit_sv == ((obase->op_flags & OPf_TARGET_MY)
				 ? PAD_SVl(obase->op_targ)
				 : DEFSV))
	    {
		sv = sv_newmortal();
		sv_setpvs(sv, "$_");
		return sv;
	    }
	}
	goto do_op;

    case OP_PRTF:
    case OP_PRINT:
	match = 1; /* print etc can return undef on defined args */
	/* skip filehandle as it can't produce 'undef' warning  */
	o = cUNOPx(obase)->op_first;
	if (o->op_type == OP_PUSHMARK)
	    o = o->op_sibling->op_sibling;
	goto do_op2;


    case OP_ENTEREVAL: /* could be eval $undef or $x='$undef'; eval $x */
    case OP_RV2SV:
    case OP_CUSTOM: /* XS or custom code could trigger random warnings */

	/* the following ops are capable of returning PL_sv_undef even for
	 * defined arg(s) */

    case OP_BACKTICK:
    case OP_PIPE_OP:
    case OP_FILENO:
    case OP_BINMODE:
    case OP_GETC:
    case OP_SYSREAD:
    case OP_SEND:
    case OP_IOCTL:
    case OP_SOCKET:
    case OP_SOCKPAIR:
    case OP_BIND:
    case OP_CONNECT:
    case OP_LISTEN:
    case OP_ACCEPT:
    case OP_SHUTDOWN:
    case OP_SSOCKOPT:
    case OP_GETPEERNAME:
    case OP_FTRREAD:
    case OP_FTRWRITE:
    case OP_FTREXEC:
    case OP_FTROWNED:
    case OP_FTEREAD:
    case OP_FTEWRITE:
    case OP_FTEEXEC:
    case OP_FTEOWNED:
    case OP_FTIS:
    case OP_FTZERO:
    case OP_FTSIZE:
    case OP_FTFILE:
    case OP_FTDIR:
    case OP_FTLINK:
    case OP_FTPIPE:
    case OP_FTSOCK:
    case OP_FTBLK:
    case OP_FTCHR:
    case OP_FTTTY:
    case OP_FTSUID:
    case OP_FTSGID:
    case OP_FTSVTX:
    case OP_FTTEXT:
    case OP_FTBINARY:
    case OP_FTMTIME:
    case OP_FTATIME:
    case OP_FTCTIME:
    case OP_READLINK:
    case OP_OPEN_DIR:
    case OP_READDIR:
    case OP_TELLDIR:
    case OP_SEEKDIR:
    case OP_REWINDDIR:
    case OP_CLOSEDIR:
    case OP_GMTIME:
    case OP_ALARM:
    case OP_SEMGET:
    case OP_GETLOGIN:
    case OP_UNDEF:
    case OP_SUBSTR:
    case OP_SORT:
    case OP_CALLER:
    case OP_PROTOTYPE:
    case OP_NCMP:
    case OP_UNPACK:
    case OP_SYSOPEN:
    case OP_SYSSEEK:
	match = 1;
	goto do_op;

    case OP_ENTERSUB:
	/* XXX tmp hack: these two may call an XS sub, and currently
	  XS subs don't have a SUB entry on the context stack, so CV and
	  pad determination goes wrong, and BAD things happen. So, just
	  don't try to determine the value under those circumstances.
	  Need a better fix at dome point. DAPM 11/2007 */
	break;


    case OP_POS:
	/* def-ness of rval pos() is independent of the def-ness of its arg */
	if ( !(obase->op_flags & OPf_MOD))
	    break;

    case OP_CHOMP:
	if (SvROK(PL_rs) && uninit_sv == SvRV(PL_rs))
	    return newSVpvs_flags("${$/}", SVs_TEMP);
	/*FALLTHROUGH*/

    default:
    do_op:
	if (!(obase->op_flags & OPf_KIDS))
	    break;
	o = cUNOPx(obase)->op_first;
	
    do_op2:
	if (!o)
	    break;

	/* if all except one arg are constant, or have no side-effects,
	 * or are optimized away, then it's unambiguous */
	o2 = NULL;
	for (kid=o; kid; kid = kid->op_sibling) {
	    if (kid) {
		const OPCODE type = kid->op_type;
		if ( (type == OP_CONST && SvOK(cSVOPx_sv(kid)))
		  || (type == OP_NULL  && ! (kid->op_flags & OPf_KIDS))
		  || (type == OP_PUSHMARK)
		)
		continue;
	    }
	    if (o2) { /* more than one found */
		o2 = NULL;
		break;
	    }
	    o2 = kid;
	}
	if (o2)
	    return find_uninit_var(o2, uninit_sv, match);

	/* scan all args */
	while (o) {
	    sv = find_uninit_var(o, uninit_sv, 1);
	    if (sv)
		return sv;
	    o = o->op_sibling;
	}
	break;
    }
    return NULL;
}


/*
=for apidoc report_uninit

Print appropriate "Use of uninitialized variable" warning

=cut
*/

void
Perl_report_uninit(pTHX_ const SV *uninit_sv)
{
    dVAR;
    if (PL_op) {
	SV* varname = NULL;
	if (uninit_sv) {
	    varname = find_uninit_var(PL_op, uninit_sv,0);
	    if (varname)
		sv_insert(varname, 0, 0, " ", 1);
	}
	Perl_warner(aTHX_ packWARN(WARN_UNINITIALIZED), PL_warn_uninit,
		varname ? SvPV_nolen_const(varname) : "",
		" in ", OP_DESC(PL_op));
    }
    else
	Perl_warner(aTHX_ packWARN(WARN_UNINITIALIZED), PL_warn_uninit,
		    "", "", "");
}

static void
do_reset_tmprefcnt(pTHX_ SV *const sv)
{
    SvTMPREFCNT(sv) = 0;
    if (SvTYPE(sv) == SVt_PVCV)
	CvFLAGS(svTcv(sv)) &= ~CVf_TMPREFCNT;
}

static void
do_sv_tmprefcnt(pTHX_ SV *const sv)
{
    Perl_sv_tmprefcnt_update(aTHX_ sv);
}

void
Perl_sv_tmprefcnt_update(pTHX_ SV *const sv)
{
    dVAR;
    const U32 type = SvTYPE(sv);
    PERL_ARGS_ASSERT_SV_TMPREFCNT_UPDATE;

    if (sv == (SV*)PL_strtab)
	return;

    SvTMPREFCNT_inc(SvLOCATION(sv));

    if (type <= SVt_IV) {
	/* See the comment in sv.h about the collusion between this early
	   return and the overloading of the NULL and IV slots in the size
	   table.  */
	if (SvROK(sv)) {
	    SV * const target = SvRV(sv);
	    if ( ! SvWEAKREF(sv))
	        SvTMPREFCNT_inc(target);
	}
	return;
    }

    if (SvOBJECT(sv)) {
	HvTMPREFCNT_inc(SvSTASH(sv));	/* possibly of changed persuasion */
    }
    if (type >= SVt_PVMG) {
	if (type == SVt_PVMG && SvPAD_OUR(sv)) {
	    GvTMPREFCNT_inc(SvOURGV(sv));
	} else if (SvMAGIC(sv))
	    Perl_mg_tmprefcnt(aTHX_ sv);
    }
    switch (type) {
	/* case SVt_BIND: */
    case SVt_PVIO:
	goto tmpscalar;
    case SVt_REGEXP:
	/* FIXME for plugins */
	preg_tmprefcnt((REGEXP*) sv);
	goto tmpscalar;
    case SVt_PVCV:
	cv_tmprefcnt((CV*)sv);
	goto tmpscalar;
    case SVt_PVHV:
	hv_tmprefcnt((HV*)sv);
	break;
    case SVt_PVAV:
	av_tmprefcnt((AV*)sv);
	break;
    case SVt_PVGV:
	if (isGV_with_GP(sv))
	    gp_tmprefcnt(GvGP(sv));
    case SVt_PVMG:
    case SVt_PVNV:
    case SVt_PVIV:
    case SVt_PV:
      tmpscalar:
	/* Don't bother with SvOOK_off(sv); as we're only going to free it.  */
	if (SvROK(sv)) {
	    SV * const target = SvRV(sv);
	    if ( ! SvWEAKREF(sv))
	        SvTMPREFCNT_inc(target);
	}
	break;
    case SVt_NV:
	break;
    }
}

static void
do_check_tmprefcnt(pTHX_ SV* const sv)
{
    if (SvTMPREFCNT(sv) != SvREFCNT(sv)) {
	PerlIO_printf(Perl_debug_log, "Invalid refcount (%ld) should be %ld\n", 
		      (long)SvREFCNT(sv), (long)SvTMPREFCNT(sv));
	sv_dump(sv);
    }
}

void
Perl_refcnt_check(pTHX)
{
    DEBUG_Rv(PerlIO_printf(Perl_debug_log, "refcount check\n"));
    visit(do_reset_tmprefcnt, 0, 0);
    visit(do_sv_tmprefcnt, 0, 0);
    HvTMPREFCNT_inc(PL_defstash);
    HvTMPREFCNT_inc(PL_curstash);
    SvTMPREFCNT_inc(PL_curstname);
    SvTMPREFCNT_inc(PL_subname);
    GvTMPREFCNT_inc(PL_defgv);
    CvTMPREFCNT_inc(PL_compcv);
    AvTMPREFCNT_inc(PL_comppad);
    AvTMPREFCNT_inc(PL_comppad_name);
    SvTMPREFCNT_inc(PL_diehook);
    SvTMPREFCNT_inc(PL_warnhook);
    SvTMPREFCNT_inc(PL_errorcreatehook); 
    CvTMPREFCNT_inc(PL_main_cv);
    AvTMPREFCNT_inc(PL_unitcheckav);
    SvTMPREFCNT_inc(PL_rs);
    AvTMPREFCNT_inc(PL_fdpid);
    HvTMPREFCNT_inc(PL_modglobal);
    SvTMPREFCNT_inc(PL_errors);
    HvTMPREFCNT_inc(PL_strtab);
    HvTMPREFCNT_inc(PL_stashcache);
    SvTMPREFCNT_inc(PL_patchlevel);
    HvTMPREFCNT_inc(PL_compiling.cop_hints_hash);
    SvTMPREFCNT_inc(PL_dynamicscope);
    GvTMPREFCNT_inc(PL_firstgv);
    GvTMPREFCNT_inc(PL_secondgv);
    SvTMPREFCNT_inc(PL_e_script);
    HvTMPREFCNT_inc(PL_includedhv);
    AvTMPREFCNT_inc(PL_includepathav);
    HvTMPREFCNT_inc(PL_magicsvhv);
    HvTMPREFCNT_inc(PL_hinthv);
    SvTMPREFCNT_inc(PL_errsv);
    HvTMPREFCNT_inc(PL_isarev);
    SvTMPREFCNT_inc(PL_statname);
    HvTMPREFCNT_inc(PL_envhv);
    HvTMPREFCNT_inc(PL_op_sequence);
    AvTMPREFCNT_inc(PL_destroyav);
    AvTMPREFCNT_inc(PL_preambleav);
    AvTMPREFCNT_inc(PL_endav);
    IoTMPREFCNT_inc(PL_stdinio);
    IoTMPREFCNT_inc(PL_stdoutio);
    IoTMPREFCNT_inc(PL_stderrio);
    SvTMPREFCNT_inc(PL_ofs_sv);

    rootop_ll_tmprefcnt();

    if (PL_parser)
	Perl_parser_tmprefcnt(aTHX_ PL_parser);

    Perl_tmps_tmprefcnt(aTHX);
    Perl_scope_tmprefcnt(aTHX);

    {
	PERL_SI *si;
	si = PL_curstackinfo;
	while (si) {
	    PERL_CONTEXT *cx;
	    AvTMPREFCNT_inc(si->si_stack);
	    for (cx = si->si_cxstack + si->si_cxix; cx >= si->si_cxstack; cx--)
		cx_tmprefcnt(cx);
	    si = si->si_next;
	}
	si = PL_curstackinfo;
	si = si->si_prev;
	while (si) {
	    PERL_CONTEXT *cx;
	    AvTMPREFCNT_inc(si->si_stack);
	    for (cx = si->si_cxstack + si->si_cxix; cx >= si->si_cxstack; cx--)
		cx_tmprefcnt(cx);
	    si = si->si_prev;
	}
    }
    visit(do_check_tmprefcnt, 0, 0);
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
