/*    hv.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * "I sit beside the fire and think of all that I have seen."  --Bilbo
 */

/* 
=head1 Hash Manipulation Functions

A HV structure represents a Perl hash. It consists mainly of an array
of pointers, each of which points to a linked list of HE structures. The
array is indexed by the hash function of the key, so each linked list
represents all the hash entries with the same hash value. Each HE contains
a pointer to the actual value, plus a pointer to a HEK structure which
holds the key and hash value.

=cut

*/

#include "EXTERN.h"
#define PERL_IN_HV_C
#define PERL_HASH_INTERNAL_ACCESS
#include "perl.h"

#define HV_MAX_LENGTH_BEFORE_SPLIT 14

static const char S_strtab_error[]
    = "Cannot modify shared string table in hv_%s";

#ifndef PURIFY

STATIC void
S_more_he(pTHX)
{
    dVAR;
    /* We could generate this at compile time via (another) auxiliary C
       program?  */
    const size_t arena_size = Perl_malloc_good_size(PERL_ARENA_SIZE);
    HE* he = (HE*) Perl_get_arena(aTHX_ arena_size, HE_SVSLOT);
    HE * const heend = &he[arena_size / sizeof(HE) - 1];

    PL_body_roots[HE_SVSLOT] = he;
    while (he < heend) {
	HeNEXT(he) = (HE*)(he + 1);
	he++;
    }
    HeNEXT(he) = 0;
}

#endif /* ! PURIFY */

#ifdef PURIFY

#define new_HE() (HE*)safemalloc(sizeof(HE))
#define del_HE(p) safefree((char*)p)

#else

STATIC HE*
S_new_he(pTHX)
{
    dVAR;
    HE* he;
    void ** const root = &PL_body_roots[HE_SVSLOT];

    if (!*root)
	S_more_he(aTHX);
    he = (HE*) *root;
    assert(he);
    *root = HeNEXT(he);
    return he;
}

#define new_HE() new_he()
#define del_HE(p) \
    STMT_START { \
	HeNEXT(p) = (HE*)(PL_body_roots[HE_SVSLOT]);	\
	PL_body_roots[HE_SVSLOT] = p; \
    } STMT_END



#endif

STATIC HEK *
S_save_hek_flags(const char *str, I32 len, U32 hash, int flags)
{
    const int flags_masked = flags & HVhek_MASK;
    char *k;
    register HEK *hek;

    PERL_ARGS_ASSERT_SAVE_HEK_FLAGS;

    Newx(k, HEK_BASESIZE + len + 2, char);
    hek = (HEK*)k;
    Copy(str, HEK_KEY(hek), len, char);
    HEK_KEY(hek)[len] = 0;
    HEK_LEN(hek) = len;
    HEK_HASH(hek) = hash;
    HEK_FLAGS(hek) = (unsigned char)flags_masked | HVhek_UNSHARED;

    if (flags & HVhek_FREEKEY)
	Safefree(str);
    return hek;
}

/* free the pool of temporary HE/HEK pairs returned by hv_fetch_ent
 * for tied hashes */

void
Perl_free_tied_hv_pool(pTHX)
{
    dVAR;
    HE *he = PL_hv_fetch_ent_mh;
    while (he) {
	HE * const ohe = he;
	Safefree(HeKEY_hek(he));
	he = HeNEXT(he);
	del_HE(ohe);
    }
    PL_hv_fetch_ent_mh = NULL;
}

static void
S_hv_notallowed(pTHX_ int flags, const char *key, I32 klen,
		const char *msg)
{
    SV * const sv = sv_newmortal();

    PERL_ARGS_ASSERT_HV_NOTALLOWED;

    if (!(flags & HVhek_FREEKEY)) {
	sv_setpvn(sv, key, klen);
    }
    else {
	/* Need to free saved eventually assign to mortal SV */
	/* XXX is this line an error ???:  SV *sv = sv_newmortal(); */
	sv_usepvn(sv, (char *) key, klen);
    }
    Perl_croak(aTHX_ msg, SVfARG(sv));
}

/* (klen == HEf_SVKEY) is special for MAGICAL hv entries, meaning key slot
 * contains an SV* */

/*
=for apidoc hv_store

Stores an SV in a hash.  The hash key is specified as C<key> and C<klen> is
the length of the key.  The C<hash> parameter is the precomputed hash
value; if it is zero then Perl will compute it.  The return value will be
NULL if the operation failed or if the value did not need to be actually
stored within the hash (as in the case of tied hashes).  Otherwise it can
be dereferenced to get the original C<SV*>.  Note that the caller is
responsible for suitably incrementing the reference count of C<val> before
the call, and decrementing it if the function returned NULL.  Effectively
a successful hv_store takes ownership of one reference to C<val>.  This is
usually what you want; a newly created SV has a reference count of one, so
if all your code does is create SVs then store them in a hash, hv_store
will own the only reference to the new SV, and your code doesn't need to do
anything further to tidy up.  hv_store is not implemented as a call to
hv_store_ent, and does not create a temporary SV for the key, so if your
key data is not already in SV form then use hv_store in preference to
hv_store_ent.

See L<perlguts/"Understanding the Magic of Tied Hashes and Arrays"> for more
information on how to use this function on tied hashes.

=for apidoc hv_store_ent

Stores C<val> in a hash.  The hash key is specified as C<key>.  The C<hash>
parameter is the precomputed hash value; if it is zero then Perl will
compute it.  The return value is the new hash entry so created.  It will be
NULL if the operation failed or if the value did not need to be actually
stored within the hash (as in the case of tied hashes).  Otherwise the
contents of the return value can be accessed using the C<He?> macros
described here.  Note that the caller is responsible for suitably
incrementing the reference count of C<val> before the call, and
decrementing it if the function returned NULL.  Effectively a successful
hv_store_ent takes ownership of one reference to C<val>.  This is
usually what you want; a newly created SV has a reference count of one, so
if all your code does is create SVs then store them in a hash, hv_store
will own the only reference to the new SV, and your code doesn't need to do
anything further to tidy up.  Note that hv_store_ent only reads the C<key>;
unlike C<val> it does not take ownership of it, so maintaining the correct
reference count on C<key> is entirely the caller's responsibility.  hv_store
is not implemented as a call to hv_store_ent, and does not create a temporary
SV for the key, so if your key data is not already in SV form then use
hv_store in preference to hv_store_ent.

See L<perlguts/"Understanding the Magic of Tied Hashes and Arrays"> for more
information on how to use this function on tied hashes.

=for apidoc hv_exists

Returns a boolean indicating whether the specified hash key exists.  The
C<klen> is the length of the key.

=for apidoc hv_fetch

Returns the SV which corresponds to the specified key in the hash.  The
C<klen> is the length of the key.  If C<lval> is set then the fetch will be
part of a store.  Check that the return value is non-null before
dereferencing it to an C<SV*>.

See L<perlguts/"Understanding the Magic of Tied Hashes and Arrays"> for more
information on how to use this function on tied hashes.

=for apidoc hv_exists_ent

Returns a boolean indicating whether the specified hash key exists. C<hash>
can be a valid precomputed hash value, or 0 to ask for it to be
computed.

=cut
*/

/* returns an HE * structure with the all fields set */
/* note that hent_val will be a mortal sv for MAGICAL hashes */
/*
=for apidoc hv_fetch_ent

Returns the hash entry which corresponds to the specified key in the hash.
C<hash> must be a valid precomputed hash number for the given C<key>, or 0
if you want the function to compute it.  IF C<lval> is set then the fetch
will be part of a store.  Make sure the return value is non-null before
accessing it.  The return value when C<tb> is a tied hash is a pointer to a
static location, so be sure to make a copy of the structure if you need to
store it somewhere.

See L<perlguts/"Understanding the Magic of Tied Hashes and Arrays"> for more
information on how to use this function on tied hashes.

=cut
*/

/* Common code for hv_delete()/hv_exists()/hv_fetch()/hv_store()  */
void *
Perl_hv_common_key_len(pTHX_ HV *hv, const char *key, I32 klen_i32,
		       const int action, SV *val, const U32 hash)
{
    STRLEN klen;
    int flags;

    PERL_ARGS_ASSERT_HV_COMMON_KEY_LEN;

    klen = klen_i32;
    flags = 0;

    return hv_common(hv, NULL, key, klen, flags, action, val, hash);
}

void *
Perl_hv_common(pTHX_ HV *hv, SV *keysv, const char *key, STRLEN klen,
	       int flags, int action, SV *val, register U32 hash)
{
    dVAR;
    XPVHV* xhv;
    HE *entry;
    HE **oentry;
    int masked_flags;
    const int return_svp = action & HV_FETCH_JUST_SV;

    if(!hv)
	return NULL;

    assert(SvTYPE(hv) == SVt_PVHV);

    if (keysv) {
	if (flags & HVhek_FREEKEY)
	    Safefree(key);
	key = SvPV_const(keysv, klen);
	flags = 0;
    }

    if (action & HV_DELETE) {
	return (void *) hv_delete_common(hv, keysv, key, klen,
					 flags,
					 action, hash);
    }

    xhv = (XPVHV*)SvANY(hv);
    if (!HvARRAY(hv)) {
	if ((action & (HV_FETCH_LVALUE | HV_FETCH_ISSTORE))) {
	    char *array;
	    Newxz(array,
		 PERL_HV_ARRAY_ALLOC_BYTES(xhv->xhv_max+1 /* HvMAX(hv)+1 */),
		 char);
	    HvARRAY(hv) = (HE**)array;
	}
	else {
	    /* XXX remove at some point? */
            if (flags & HVhek_FREEKEY)
                Safefree(key);

	    return NULL;
	}
    }

    if (HvREHASH(hv)) {
	PERL_HASH_INTERNAL(hash, key, klen);
	/* We don't have a pointer to the hv, so we have to replicate the
	   flag into every HEK, so that hv_iterkeysv can see it.  */
	/* And yes, you do need this even though you are not "storing" because
	   you can flip the flags below if doing an lval lookup.  (And that
	   was put in to give the semantics Andreas was expecting.)  */
	flags |= HVhek_REHASH;
    } else if (!hash) {
        if (keysv && (SvIsCOW_shared_hash(keysv))) {
            hash = SvSHARED_HASH(keysv);
        } else {
            PERL_HASH(hash, key, klen);
        }
    }

    masked_flags = (flags & HVhek_MASK);

#ifdef DYNAMIC_ENV_FETCH
    if (!HvARRAY(hv)) entry = NULL;
    else
#endif
    {
	entry = (HvARRAY(hv))[hash & (I32) HvMAX(hv)];
    }
    for (; entry; entry = HeNEXT(entry)) {
	if (HeHASH(entry) != hash)		/* strings can't be equal */
	    continue;
	if (HeKLEN(entry) != (I32)klen)
	    continue;
	if (HeKEY(entry) != key && memNE(HeKEY(entry),key,klen))	/* is this it? */
	    continue;

        if (action & (HV_FETCH_LVALUE|HV_FETCH_ISSTORE)) {
	    if (HeKFLAGS(entry) != masked_flags) {
		if (HvSHAREKEYS(hv)) {
		    /* Need to swap the key we have for a key with the flags we
		       need. As keys are shared we can't just write to the
		       flag, so we share the new one, unshare the old one.  */
		    HEK * const new_hek = share_hek_flags(key, klen, hash,
						   masked_flags);
		    unshare_hek (HeKEY_hek(entry));
		    HeKEY_hek(entry) = new_hek;
		}
		else if (hv == PL_strtab) {
		    /* PL_strtab is usually the only hash without HvSHAREKEYS,
		       so putting this test here is cheap  */
		    if (flags & HVhek_FREEKEY)
			Safefree(key);
		    Perl_croak(aTHX_ S_strtab_error,
			       action & HV_FETCH_LVALUE ? "fetch" : "store");
		}
		else
		    HeKFLAGS(entry) = masked_flags;
	    }
	    if (HeVAL(entry) == &PL_sv_placeholder) {
		/* yes, can store into placeholder slot */
		if (action & HV_FETCH_LVALUE) {
		    /* LVAL fetch which actaully needs a store.  */
		    val = newSV(0);
		    HvPLACEHOLDERS(hv)--;
		} else {
		    /* store */
		    if (val != &PL_sv_placeholder)
			HvPLACEHOLDERS(hv)--;
		}
		HeVAL(entry) = val;
	    } else if (action & HV_FETCH_ISSTORE) {
		SvREFCNT_dec(HeVAL(entry));
		HeVAL(entry) = val;
	    }
	} else if (HeVAL(entry) == &PL_sv_placeholder) {
	    /* if we find a placeholder, we pretend we haven't found
	       anything */
	    break;
	}
	if (flags & HVhek_FREEKEY)
	    Safefree(key);
	if (return_svp) {
	    return entry ? (void *) &HeVAL(entry) : NULL;
	}
	return entry;
    }

    if (!entry && HvRESTRICTED(hv) && !(action & HV_FETCH_ISEXISTS)) {
	hv_notallowed(flags, key, klen,
			"Attempt to access disallowed key '%"SVf"' in"
			" a restricted hash");
    }
    if (!(action & (HV_FETCH_LVALUE|HV_FETCH_ISSTORE))) {
	/* Not doing some form of store, so return failure.  */
	if (flags & HVhek_FREEKEY)
	    Safefree(key);
	return NULL;
    }
    if (action & HV_FETCH_LVALUE) {
	val = newSV(0);
    }

    /* Welcome to hv_store...  */

    if (!HvARRAY(hv)) {
	/* Not sure if we can get here.  I think the only case of oentry being
	   NULL is for %ENV with dynamic env fetch.  But that should disappear
	   with magic in the previous code.  */
	char *array;
	Newxz(array,
	     PERL_HV_ARRAY_ALLOC_BYTES(xhv->xhv_max+1 /* HvMAX(hv)+1 */),
	     char);
	HvARRAY(hv) = (HE**)array;
    }

    oentry = &(HvARRAY(hv))[hash & (I32) xhv->xhv_max];

    entry = new_HE();
    /* share_hek_flags will do the free for us.  This might be considered
       bad API design.  */
    if (HvSHAREKEYS(hv))
	HeKEY_hek(entry) = share_hek_flags(key, klen, hash, flags);
    else if (hv == PL_strtab) {
	/* PL_strtab is usually the only hash without HvSHAREKEYS, so putting
	   this test here is cheap  */
	if (flags & HVhek_FREEKEY)
	    Safefree(key);
	Perl_croak(aTHX_ S_strtab_error,
		   action & HV_FETCH_LVALUE ? "fetch" : "store");
    }
    else                                       /* gotta do the real thing */
	HeKEY_hek(entry) = save_hek_flags(key, klen, hash, flags);
    HeVAL(entry) = val;
    HeNEXT(entry) = *oentry;
    *oentry = entry;

    if (val == &PL_sv_placeholder)
	HvPLACEHOLDERS(hv)++;

    {
	const HE *counter = HeNEXT(entry);

	xhv->xhv_keys++; /* HvTOTALKEYS(hv)++ */
	if (!counter) {				/* initial entry? */
	    xhv->xhv_fill++; /* HvFILL(hv)++ */
	} else if (xhv->xhv_keys > (IV)xhv->xhv_max) {
	    hsplit(hv);
	} else if(!HvREHASH(hv)) {
	    U32 n_links = 1;

	    while ((counter = HeNEXT(counter)))
		n_links++;

	    if (n_links > HV_MAX_LENGTH_BEFORE_SPLIT) {
		/* Use only the old HvKEYS(hv) > HvMAX(hv) condition to limit
		   bucket splits on a rehashed hash, as we're not going to
		   split it again, and if someone is lucky (evil) enough to
		   get all the keys in one list they could exhaust our memory
		   as we repeatedly double the number of buckets on every
		   entry. Linear search feels a less worse thing to do.  */
		hsplit(hv);
	    }
	}
    }

    if (return_svp) {
	return entry ? (void *) &HeVAL(entry) : NULL;
    }
    return (void *) entry;
}

/*
=for apidoc hv_scalar

Evaluates the hash in scalar context and returns the result. Handles magic when the hash is tied.

=cut
*/

SV *
Perl_hv_scalar(pTHX_ HV *hv)
{
    SV *sv;

    PERL_ARGS_ASSERT_HV_SCALAR;

    sv = sv_newmortal();
    if (HvFILL((HV*)hv)) 
        Perl_sv_setpvf(aTHX_ sv, "%ld/%ld",
                (long)HvFILL(hv), (long)HvMAX(hv) + 1);
    else
        sv_setiv(sv, 0);
    
    return sv;
}

/*
=for apidoc hv_delete

Deletes a key/value pair in the hash.  The value SV is removed from the
hash and returned to the caller.  The C<klen> is the length of the key.
The C<flags> value will normally be zero; if set to G_DISCARD then NULL
will be returned.

=for apidoc hv_delete_ent

Deletes a key/value pair in the hash.  The value SV is removed from the
hash and returned to the caller.  The C<flags> value will normally be zero;
if set to G_DISCARD then NULL will be returned.  C<hash> can be a valid
precomputed hash value, or 0 to ask for it to be computed.

=cut
*/

STATIC SV *
S_hv_delete_common(pTHX_ HV *hv, SV *keysv, const char *key, STRLEN klen,
		   int k_flags, I32 d_flags, U32 hash)
{
    dVAR;
    register XPVHV* xhv;
    register HE *entry;
    register HE **oentry;
    HE *const *first_entry;
    int masked_flags;

    xhv = (XPVHV*)SvANY(hv);
    if (!HvARRAY(hv))
	return NULL;

    if (HvREHASH(hv)) {
	PERL_HASH_INTERNAL(hash, key, klen);
    } else if (!hash) {
        if (keysv && (SvIsCOW_shared_hash(keysv))) {
            hash = SvSHARED_HASH(keysv);
        } else {
            PERL_HASH(hash, key, klen);
        }
    }

    masked_flags = (k_flags & HVhek_MASK);

    first_entry = oentry = &(HvARRAY(hv))[hash & (I32) HvMAX(hv)];
    entry = *oentry;
    for (; entry; oentry = &HeNEXT(entry), entry = *oentry) {
	SV *sv;
	if (HeHASH(entry) != hash)		/* strings can't be equal */
	    continue;
	if (HeKLEN(entry) != (I32)klen)
	    continue;
	if (HeKEY(entry) != key && memNE(HeKEY(entry),key,klen))	/* is this it? */
	    continue;

	if (hv == PL_strtab) {
	    if (k_flags & HVhek_FREEKEY)
		Safefree(key);
	    Perl_croak(aTHX_ S_strtab_error, "delete");
	}

	/* if placeholder is here, it's already been deleted.... */
	if (HeVAL(entry) == &PL_sv_placeholder) {
	    if (k_flags & HVhek_FREEKEY)
		Safefree(key);
	    return NULL;
	}
	if (SvREADONLY(hv)) {
	    hv_notallowed(k_flags, key, klen,
			    "Attempt to delete key '%"SVf"' from a read-only hash");
	}
	if (HvRESTRICTED(hv) && HeVAL(entry) && SvREADONLY(HeVAL(entry))) {
	    hv_notallowed(k_flags, key, klen,
			    "Attempt to delete readonly key '%"SVf"' from"
			    " a restricted hash");
	}
        if (k_flags & HVhek_FREEKEY)
            Safefree(key);

	if (d_flags & G_DISCARD)
	    sv = NULL;
	else {
	    sv = sv_2mortal(HeVAL(entry));
	    HeVAL(entry) = &PL_sv_placeholder;
	}

	/*
	 * If a restricted hash, rather than really deleting the entry, put
	 * a placeholder there. This marks the key as being "approved", so
	 * we can still access via not-really-existing key without raising
	 * an error.
	 */
	if (HvRESTRICTED(hv)) {
	    SvREFCNT_dec(HeVAL(entry));
	    HeVAL(entry) = &PL_sv_placeholder;
	    /* We'll be saving this slot, so the number of allocated keys
	     * doesn't go down, but the number placeholders goes up */
	    HvPLACEHOLDERS(hv)++;
	} else {
	    *oentry = HeNEXT(entry);
	    if(!*first_entry) {
		xhv->xhv_fill--; /* HvFILL(hv)-- */
	    }
	    if (SvOOK(hv) && entry == HvAUX(hv)->xhv_eiter /* HvEITER(hv) */)
		HvLAZYDEL_on(hv);
	    else
		hv_free_ent(hv, entry);
	    xhv->xhv_keys--; /* HvTOTALKEYS(hv)-- */
	}
	return sv;
    }
    if (HvRESTRICTED(hv)) {
	hv_notallowed(k_flags, key, klen,
			"Attempt to delete disallowed key '%"SVf"' from"
			" a restricted hash");
    }

    if (k_flags & HVhek_FREEKEY)
	Safefree(key);
    return NULL;
}

STATIC void
S_hsplit(pTHX_ HV *hv)
{
    dVAR;
    register XPVHV* const xhv = (XPVHV*)SvANY(hv);
    const I32 oldsize = (I32) xhv->xhv_max+1; /* HvMAX(hv)+1 (sick) */
    register I32 newsize = oldsize * 2;
    register I32 i;
    char *a = (char*) HvARRAY(hv);
    register HE **aep;
    register HE **oentry;
    int longest_chain = 0;
    int was_shared;

    PERL_ARGS_ASSERT_HSPLIT;

    /*PerlIO_printf(PerlIO_stderr(), "hsplit called for %p which had %d\n",
      (void*)hv, (int) oldsize);*/

    if (HvPLACEHOLDERS_get(hv) && !HvRESTRICTED(hv)) {
      /* Can make this clear any placeholders first for non-restricted hashes,
	 even though Storable rebuilds restricted hashes by putting in all the
	 placeholders (first) before turning on the readonly flag, because
	 Storable always pre-splits the hash.  */
      hv_clear_placeholders(hv);
    }
	       
    PL_nomemok = TRUE;
#if defined(STRANGE_MALLOC) || defined(MYMALLOC)
    Renew(a, PERL_HV_ARRAY_ALLOC_BYTES(newsize)
	  + (SvOOK(hv) ? sizeof(struct xpvhv_aux) : 0), char);
    if (!a) {
      PL_nomemok = FALSE;
      return;
    }
    if (SvOOK(hv)) {
	Copy(&a[oldsize * sizeof(HE*)], &a[newsize * sizeof(HE*)], 1, struct xpvhv_aux);
    }
#else
    Newx(a, PERL_HV_ARRAY_ALLOC_BYTES(newsize)
	+ (SvOOK(hv) ? sizeof(struct xpvhv_aux) : 0), char);
    if (!a) {
      PL_nomemok = FALSE;
      return;
    }
    Copy(HvARRAY(hv), a, oldsize * sizeof(HE*), char);
    if (SvOOK(hv)) {
	Copy(HvAUX(hv), &a[newsize * sizeof(HE*)], 1, struct xpvhv_aux);
    }
    if (oldsize >= 64) {
	offer_nice_chunk(HvARRAY(hv),
			 PERL_HV_ARRAY_ALLOC_BYTES(oldsize)
			 + (SvOOK(hv) ? sizeof(struct xpvhv_aux) : 0));
    }
    else
	Safefree(HvARRAY(hv));
#endif

    PL_nomemok = FALSE;
    Zero(&a[oldsize * sizeof(HE*)], (newsize-oldsize) * sizeof(HE*), char);	/* zero 2nd half*/
    xhv->xhv_max = --newsize;	/* HvMAX(hv) = --newsize */
    HvARRAY(hv) = (HE**) a;
    aep = (HE**)a;

    for (i=0; i<oldsize; i++,aep++) {
	int left_length = 0;
	int right_length = 0;
	register HE *entry;
	register HE **bep;

	if (!*aep)				/* non-existent */
	    continue;
	bep = aep+oldsize;
	for (oentry = aep, entry = *aep; entry; entry = *oentry) {
	    if ((HeHASH(entry) & newsize) != (U32)i) {
		*oentry = HeNEXT(entry);
		HeNEXT(entry) = *bep;
		if (!*bep)
		    xhv->xhv_fill++; /* HvFILL(hv)++ */
		*bep = entry;
		right_length++;
		continue;
	    }
	    else {
		oentry = &HeNEXT(entry);
		left_length++;
	    }
	}
	if (!*aep)				/* everything moved */
	    xhv->xhv_fill--; /* HvFILL(hv)-- */
	/* I think we don't actually need to keep track of the longest length,
	   merely flag if anything is too long. But for the moment while
	   developing this code I'll track it.  */
	if (left_length > longest_chain)
	    longest_chain = left_length;
	if (right_length > longest_chain)
	    longest_chain = right_length;
    }


    /* Pick your policy for "hashing isn't working" here:  */
    if (longest_chain <= HV_MAX_LENGTH_BEFORE_SPLIT /* split worked?  */
	|| HvREHASH(hv)) {
	return;
    }

    if (hv == PL_strtab) {
	/* Urg. Someone is doing something nasty to the string table.
	   Can't win.  */
	return;
    }

    /* Awooga. Awooga. Pathological data.  */
    /*PerlIO_printf(PerlIO_stderr(), "%p %d of %d with %d/%d buckets\n", (void*)hv,
      longest_chain, HvTOTALKEYS(hv), HvFILL(hv),  1+HvMAX(hv));*/

    ++newsize;
    Newxz(a, PERL_HV_ARRAY_ALLOC_BYTES(newsize)
	 + (SvOOK(hv) ? sizeof(struct xpvhv_aux) : 0), char);
    if (SvOOK(hv)) {
	Copy(HvAUX(hv), &a[newsize * sizeof(HE*)], 1, struct xpvhv_aux);
    }

    was_shared = HvSHAREKEYS(hv);

    xhv->xhv_fill = 0;
    HvSHAREKEYS_off(hv);
    HvREHASH_on(hv);

    aep = HvARRAY(hv);

    for (i=0; i<newsize; i++,aep++) {
	register HE *entry = *aep;
	while (entry) {
	    /* We're going to trash this HE's next pointer when we chain it
	       into the new hash below, so store where we go next.  */
	    HE * const next = HeNEXT(entry);
	    UV hash;
	    HE **bep;

	    /* Rehash it */
	    PERL_HASH_INTERNAL(hash, HeKEY(entry), HeKLEN(entry));

	    if (was_shared) {
		/* Unshare it.  */
		HEK * const new_hek
		    = save_hek_flags(HeKEY(entry), HeKLEN(entry),
				     hash, HeKFLAGS(entry));
		unshare_hek (HeKEY_hek(entry));
		HeKEY_hek(entry) = new_hek;
	    } else {
		/* Not shared, so simply write the new hash in. */
		HeHASH(entry) = hash;
	    }
	    /*PerlIO_printf(PerlIO_stderr(), "%d ", HeKFLAGS(entry));*/
	    HEK_REHASH_on(HeKEY_hek(entry));
	    /*PerlIO_printf(PerlIO_stderr(), "%d\n", HeKFLAGS(entry));*/

	    /* Copy oentry to the correct new chain.  */
	    bep = ((HE**)a) + (hash & (I32) xhv->xhv_max);
	    if (!*bep)
		    xhv->xhv_fill++; /* HvFILL(hv)++ */
	    HeNEXT(entry) = *bep;
	    *bep = entry;

	    entry = next;
	}
    }
    Safefree (HvARRAY(hv));
    HvARRAY(hv) = (HE **)a;
}

void
Perl_hv_ksplit(pTHX_ HV *hv, IV newmax)
{
    dVAR;
    register XPVHV* xhv = (XPVHV*)SvANY(hv);
    const I32 oldsize = (I32) xhv->xhv_max+1; /* HvMAX(hv)+1 (sick) */
    register I32 newsize;
    register I32 i;
    register char *a;
    register HE **aep;
    register HE *entry;
    register HE **oentry;

    PERL_ARGS_ASSERT_HV_KSPLIT;

    newsize = (I32) newmax;			/* possible truncation here */
    if (newsize != newmax || newmax <= oldsize)
	return;
    while ((newsize & (1 + ~newsize)) != newsize) {
	newsize &= ~(newsize & (1 + ~newsize));	/* get proper power of 2 */
    }
    if (newsize < newmax)
	newsize *= 2;
    if (newsize < newmax)
	return;					/* overflow detection */

    a = (char *) HvARRAY(hv);
    if (a) {
	PL_nomemok = TRUE;
#if defined(STRANGE_MALLOC) || defined(MYMALLOC)
	Renew(a, PERL_HV_ARRAY_ALLOC_BYTES(newsize)
	      + (SvOOK(hv) ? sizeof(struct xpvhv_aux) : 0), char);
	if (!a) {
	  PL_nomemok = FALSE;
	  return;
	}
	if (SvOOK(hv)) {
	    Copy(&a[oldsize * sizeof(HE*)], &a[newsize * sizeof(HE*)], 1, struct xpvhv_aux);
	}
#else
	Newx(a, PERL_HV_ARRAY_ALLOC_BYTES(newsize)
	    + (SvOOK(hv) ? sizeof(struct xpvhv_aux) : 0), char);
	if (!a) {
	  PL_nomemok = FALSE;
	  return;
	}
	Copy(HvARRAY(hv), a, oldsize * sizeof(HE*), char);
	if (SvOOK(hv)) {
	    Copy(HvAUX(hv), &a[newsize * sizeof(HE*)], 1, struct xpvhv_aux);
	}
	if (oldsize >= 64) {
	    offer_nice_chunk(HvARRAY(hv),
			     PERL_HV_ARRAY_ALLOC_BYTES(oldsize)
			     + (SvOOK(hv) ? sizeof(struct xpvhv_aux) : 0));
	}
	else
	    Safefree(HvARRAY(hv));
#endif
	PL_nomemok = FALSE;
	Zero(&a[oldsize * sizeof(HE*)], (newsize-oldsize) * sizeof(HE*), char); /* zero 2nd half*/
    }
    else {
	Newxz(a, PERL_HV_ARRAY_ALLOC_BYTES(newsize), char);
    }
    xhv->xhv_max = --newsize; 	/* HvMAX(hv) = --newsize */
    HvARRAY(hv) = (HE **) a;
    if (!xhv->xhv_fill /* !HvFILL(hv) */)	/* skip rest if no entries */
	return;

    aep = (HE**)a;
    for (i=0; i<oldsize; i++,aep++) {
	if (!*aep)				/* non-existent */
	    continue;
	for (oentry = aep, entry = *aep; entry; entry = *oentry) {
	    register I32 j = (HeHASH(entry) & newsize);

	    if (j != i) {
		j -= i;
		*oentry = HeNEXT(entry);
		if (!(HeNEXT(entry) = aep[j]))
		    xhv->xhv_fill++; /* HvFILL(hv)++ */
		aep[j] = entry;
		continue;
	    }
	    else
		oentry = &HeNEXT(entry);
	}
	if (!*aep)				/* everything moved */
	    xhv->xhv_fill--; /* HvFILL(hv)-- */
    }
}

void
Perl_hv_sethv(pTHX_ HV* dstr, HV* sstr)
{
    STRLEN hv_max, hv_fill;
    PERL_ARGS_ASSERT_HV_SETHV;

    hv_undef(dstr);

    if (!sstr || (hv_fill = HvFILL(sstr)) == 0)
	return;
    hv_max = HvMAX(sstr);

    {
	/* It's an ordinary hash, so copy it fast. AMS 20010804 */
	STRLEN i;
	const bool shared = !!HvSHAREKEYS(sstr);
	HE **ents, ** const oents = (HE **)HvARRAY(sstr);
	char *a;
	Newx(a, PERL_HV_ARRAY_ALLOC_BYTES(hv_max+1), char);
	ents = (HE**)a;

	/* In each bucket... */
	for (i = 0; i <= hv_max; i++) {
	    HE *prev = NULL;
	    HE *oent = oents[i];

	    if (!oent) {
		ents[i] = NULL;
		continue;
	    }

	    /* Copy the linked list of entries. */
	    for (; oent; oent = HeNEXT(oent)) {
		const U32 hash   = HeHASH(oent);
		const char * const key = HeKEY(oent);
		const STRLEN len = HeKLEN(oent);
		const int flags  = HeKFLAGS(oent);
		HE * const ent   = new_HE();

		HeVAL(ent)     = newSVsv(HeVAL(oent));
		HeKEY_hek(ent)
                    = shared ? share_hek_flags(key, len, hash, flags)
                             :  save_hek_flags(key, len, hash, flags);
		if (prev)
		    HeNEXT(prev) = ent;
		else
		    ents[i] = ent;
		prev = ent;
		HeNEXT(ent) = NULL;
	    }
	}

	HvMAX(dstr)   = hv_max;
	HvFILL(dstr)  = hv_fill;
	HvTOTALKEYS(dstr)  = HvTOTALKEYS(sstr);
	HvARRAY(dstr) = ents;
    }
}

HV *
Perl_newHVhv(pTHX_ HV *ohv)
{
    HV * const hv = newHV();
    STRLEN hv_max, hv_fill;

    if (!ohv || (hv_fill = HvFILL(ohv)) == 0)
	return hv;
    hv_max = HvMAX(ohv);

    {
	/* It's an ordinary hash, so copy it fast. AMS 20010804 */
	STRLEN i;
	const bool shared = !!HvSHAREKEYS(ohv);
	HE **ents, ** const oents = (HE **)HvARRAY(ohv);
	char *a;
	Newx(a, PERL_HV_ARRAY_ALLOC_BYTES(hv_max+1), char);
	ents = (HE**)a;

	/* In each bucket... */
	for (i = 0; i <= hv_max; i++) {
	    HE *prev = NULL;
	    HE *oent = oents[i];

	    if (!oent) {
		ents[i] = NULL;
		continue;
	    }

	    /* Copy the linked list of entries. */
	    for (; oent; oent = HeNEXT(oent)) {
		const U32 hash   = HeHASH(oent);
		const char * const key = HeKEY(oent);
		const STRLEN len = HeKLEN(oent);
		const int flags  = HeKFLAGS(oent);
		HE * const ent   = new_HE();

		HeVAL(ent)     = newSVsv(HeVAL(oent));
		HeKEY_hek(ent)
                    = shared ? share_hek_flags(key, len, hash, flags)
                             :  save_hek_flags(key, len, hash, flags);
		if (prev)
		    HeNEXT(prev) = ent;
		else
		    ents[i] = ent;
		prev = ent;
		HeNEXT(ent) = NULL;
	    }
	}

	HvMAX(hv)   = hv_max;
	HvFILL(hv)  = hv_fill;
	HvTOTALKEYS(hv)  = HvTOTALKEYS(ohv);
	HvARRAY(hv) = ents;
    }

    return hv;
}

void
Perl_hv_free_ent(pTHX_ HV *hv, register HE *entry)
{
    dVAR;
    SV *val;

    PERL_ARGS_ASSERT_HV_FREE_ENT;

    if (!entry)
	return;
    val = HeVAL(entry);
    if (val && isGV(val) && isGV_with_GP(val) && GvCVu(val) && HvNAME_get(hv))
        mro_method_changed_in(hv);	/* deletion of method from stash */
    SvREFCNT_dec(val);
    if (HeKLEN(entry) == HEf_SVKEY) {
	SvREFCNT_dec(HeKEY_sv(entry));
	Safefree(HeKEY_hek(entry));
    }
    else if (HvSHAREKEYS(hv))
	unshare_hek(HeKEY_hek(entry));
    else
	Safefree(HeKEY_hek(entry));
    del_HE(entry);
}

void
Perl_hv_delayfree_ent(pTHX_ HV *hv, register HE *entry)
{
    dVAR;

    PERL_ARGS_ASSERT_HV_DELAYFREE_ENT;

    if (!entry)
	return;
    /* SvREFCNT_inc to counter the SvREFCNT_dec in hv_free_ent  */
    sv_2mortal(SvREFCNT_inc(HeVAL(entry)));	/* free between statements */
    if (HeKLEN(entry) == HEf_SVKEY) {
	sv_2mortal(SvREFCNT_inc(HeKEY_sv(entry)));
    }
    hv_free_ent(hv, entry);
}

/*
=for apidoc hv_clear

Clears a hash, making it empty.

=cut
*/

void
Perl_hv_clear(pTHX_ HV *hv)
{
    dVAR;
    register XPVHV* xhv;
    if (!hv)
	return;

    DEBUG_A(Perl_hv_assert(aTHX_ hv));

    xhv = (XPVHV*)SvANY(hv);

    if (HvRESTRICTED(hv) && HvARRAY(hv) != NULL) {
	/* restricted hash: convert all keys to placeholders */
	STRLEN i;
	for (i = 0; i <= xhv->xhv_max; i++) {
	    HE *entry = (HvARRAY(hv))[i];
	    for (; entry; entry = HeNEXT(entry)) {
		/* not already placeholder */
		if (HeVAL(entry) != &PL_sv_placeholder) {
		    if (HeVAL(entry) && HvRESTRICTED(HeVAL(entry))) {
			SV* const keysv = hv_iterkeysv(entry);
			Perl_croak(aTHX_
				   "Attempt to delete readonly key '%"SVf"' from a restricted hash",
				   (void*)keysv);
		    }
		    SvREFCNT_dec(HeVAL(entry));
		    HeVAL(entry) = &PL_sv_placeholder;
		    HvPLACEHOLDERS(hv)++;
		}
	    }
	}
	goto reset;
    }

    hfreeentries(hv);
    HvPLACEHOLDERS_set(hv, 0);
    if (HvARRAY(hv))
	Zero(HvARRAY(hv), xhv->xhv_max+1 /* HvMAX(hv)+1 */, HE*);

    if (SvRMAGICAL(hv))
	mg_clear((SV*)hv);

    HvREHASH_off(hv);
    reset:
    if (SvOOK(hv)) {
        if(HvNAME_get(hv))
            mro_isa_changed_in(hv);
	HvEITER_set(hv, NULL);
    }
}

/*
=for apidoc hv_clear_placeholders

Clears any placeholders from a hash.  If a restricted hash has any of its keys
marked as readonly and the key is subsequently deleted, the key is not actually
deleted but is marked by assigning it a value of &PL_sv_placeholder.  This tags
it so it will be ignored by future operations such as iterating over the hash,
but will still allow the hash to have a value reassigned to the key at some
future point.  This function clears any such placeholder keys from the hash.
See Hash::Util::lock_keys() for an example of its use.

=cut
*/

void
Perl_hv_clear_placeholders(pTHX_ HV *hv)
{
    dVAR;
    const U32 items = (U32)HvPLACEHOLDERS_get(hv);

    PERL_ARGS_ASSERT_HV_CLEAR_PLACEHOLDERS;

    if (items)
	clear_placeholders(hv, items);
}

static void
S_clear_placeholders(pTHX_ HV *hv, U32 items)
{
    dVAR;
    I32 i;

    PERL_ARGS_ASSERT_CLEAR_PLACEHOLDERS;

    if (items == 0)
	return;

    i = HvMAX(hv);
    do {
	/* Loop down the linked list heads  */
	bool first = TRUE;
	HE **oentry = &(HvARRAY(hv))[i];
	HE *entry;

	while ((entry = *oentry)) {
	    if (HeVAL(entry) == &PL_sv_placeholder) {
		*oentry = HeNEXT(entry);
		if (first && !*oentry)
		    HvFILL(hv)--; /* This linked list is now empty.  */
		if (entry == HvEITER_get(hv))
		    HvLAZYDEL_on(hv);
		else
		    hv_free_ent(hv, entry);

		if (--items == 0) {
		    /* Finished.  */
		    HvTOTALKEYS(hv) -= (IV)HvPLACEHOLDERS_get(hv);
		    HvPLACEHOLDERS_set(hv, 0);
		    return;
		}
	    } else {
		oentry = &HeNEXT(entry);
		first = FALSE;
	    }
	}
    } while (--i >= 0);
    /* You can't get here, hence assertion should always fail.  */
    assert (items == 0);
    assert (0);
}

STATIC void
S_hfreeentries(pTHX_ HV *hv)
{
    /* This is the array that we're going to restore  */
    HE **const orig_array = HvARRAY(hv);
    HEK *name;
    int attempts = 100;

    PERL_ARGS_ASSERT_HFREEENTRIES;

    if (!orig_array)
	return;

    if (SvOOK(hv)) {
	/* If the hash is actually a symbol table with a name, look after the
	   name.  */
	struct xpvhv_aux *iter = HvAUX(hv);

	name = iter->xhv_name;
	iter->xhv_name = NULL;
    } else {
	name = NULL;
    }

    /* orig_array remains unchanged throughout the loop. If after freeing all
       the entries it turns out that one of the little blighters has triggered
       an action that has caused HvARRAY to be re-allocated, then we set
       array to the new HvARRAY, and try again.  */

    while (1) {
	/* This is the one we're going to try to empty.  First time round
	   it's the original array.  (Hopefully there will only be 1 time
	   round) */
	HE ** const array = HvARRAY(hv);
	I32 i = HvMAX(hv);

	/* Because we have taken xhv_name out, the only allocated pointer
	   in the aux structure that might exist is the backreference array.
	*/

	if (SvOOK(hv)) {
	    HE *entry;
            struct mro_meta *meta;
	    struct xpvhv_aux *iter = HvAUX(hv);
	    /* If there are weak references to this HV, we need to avoid
	       freeing them up here.  In particular we need to keep the AV
	       visible as what we're deleting might well have weak references
	       back to this HV, so the for loop below may well trigger
	       the removal of backreferences from this array.  */

	    if (iter->xhv_backreferences) {
		if (AvFILLp(iter->xhv_backreferences) != -1) {
		    sv_magic((SV*)hv, (SV*)iter->xhv_backreferences,
			     PERL_MAGIC_backref, NULL, 0);
		}
		AVcpNULL(iter->xhv_backreferences);
	    }

	    entry = iter->xhv_eiter; /* HvEITER(hv) */
	    if (entry && HvLAZYDEL(hv)) {	/* was deleted earlier? */
		HvLAZYDEL_off(hv);
		hv_free_ent(hv, entry);
	    }
	    iter->xhv_riter = -1; 	/* HvRITER(hv) = -1 */
	    iter->xhv_eiter = NULL;	/* HvEITER(hv) = NULL */

            if((meta = iter->xhv_mro_meta)) {
                if(meta->mro_linear_c3)  AvREFCNT_dec(meta->mro_linear_c3);
                if(meta->mro_nextmethod) HvREFCNT_dec(meta->mro_nextmethod);
                Safefree(meta);
                iter->xhv_mro_meta = NULL;
            }

	    /* There are now no allocated pointers in the aux structure.  */

	    SvFLAGS(hv) &= ~SVf_OOK; /* Goodbye, aux structure.  */
	    /* What aux structure?  */
	}

	/* make everyone else think the array is empty, so that the destructors
	 * called for freed entries can't recusively mess with us */
	HvARRAY(hv) = NULL;
	HvFILL(hv) = 0;
	((XPVHV*) SvANY(hv))->xhv_keys = 0;


	do {
	    /* Loop down the linked list heads  */
	    HE *entry = array[i];

	    while (entry) {
		register HE * const oentry = entry;
		entry = HeNEXT(entry);
		hv_free_ent(hv, oentry);
	    }
	} while (--i >= 0);

	/* As there are no allocated pointers in the aux structure, it's now
	   safe to free the array we just cleaned up, if it's not the one we're
	   going to put back.  */
	if (array != orig_array) {
	    Safefree(array);
	}

	if (!HvARRAY(hv)) {
	    /* Good. No-one added anything this time round.  */
	    break;
	}

	if (SvOOK(hv)) {
	    /* Someone attempted to iterate or set the hash name while we had
	       the array set to 0.  We'll catch backferences on the next time
	       round the while loop.  */
	    assert(HvARRAY(hv));

	    if (HvAUX(hv)->xhv_name) {
		unshare_hek_or_pvn(HvAUX(hv)->xhv_name, 0, 0, 0);
	    }
	}

	if (--attempts == 0) {
	    Perl_croak(aTHX_ "panic: hfreeentries failed to free hash - something is repeatedly re-creating entries");
	}
    }
	
    HvARRAY(hv) = orig_array;

    /* If the hash was actually a symbol table, put the name back.  */
    if (name) {
	/* We have restored the original array.  If name is non-NULL, then
	   the original array had an aux structure at the end. So this is
	   valid:  */
	SvFLAGS(hv) |= SVf_OOK;
	HvAUX(hv)->xhv_name = name;
    }
}

/*
=for apidoc hv_undef

Undefines the hash.

=cut
*/

void
Perl_hv_undef(pTHX_ HV *hv)
{
    dVAR;
    register XPVHV* xhv;
    const char *name;

    if (!hv)
	return;
    DEBUG_A(Perl_hv_assert(aTHX_ hv));
    xhv = (XPVHV*)SvANY(hv);

    if ((name = HvNAME_get(hv)) && !PL_dirty)
        mro_isa_changed_in(hv);

    hfreeentries(hv);
    if (name) {
        if (PL_stashcache)
	    (void)hv_delete(PL_stashcache, name, HvNAMELEN_get(hv), G_DISCARD);
	hv_name_set(hv, NULL, 0, 0);
    }
    SvFLAGS(hv) &= ~SVf_OOK;
    Safefree(HvARRAY(hv));
    xhv->xhv_max   = 7;	/* HvMAX(hv) = 7 (it's a normal hash) */
    HvARRAY(hv) = 0;
    HvPLACEHOLDERS_set(hv, 0);

    if (SvRMAGICAL(hv))
	mg_clear((SV*)hv);
}

void
Perl_hv_tmprefcnt(pTHX_ HV *hv)
{
    dVAR;
    register XPVHV* xhv;
    PERL_ARGS_ASSERT_HV_TMPREFCNT;

    if (!hv)
	return;

    DEBUG_A(Perl_hv_assert(aTHX_ hv));
    xhv = (XPVHV*)SvANY(hv);

    if (SvOOK(hv)) {
	HE *entry;
	struct mro_meta *meta;
	struct xpvhv_aux *iter = HvAUX(hv);
	/* If there are weak references to this HV, we need to avoid
	   freeing them up here.  In particular we need to keep the AV
	   visible as what we're deleting might well have weak references
	   back to this HV, so the for loop below may well trigger
	   the removal of backreferences from this array.  */

	AvTMPREFCNT_inc(iter->xhv_backreferences);

	entry = iter->xhv_eiter; /* HvEITER(hv) */
	if (entry && HvLAZYDEL(hv)) {	/* was deleted earlier? */
	    SvTMPREFCNT_inc(HeVAL(entry));
	    if (HeKLEN(entry) == HEf_SVKEY) {
		SvTMPREFCNT_inc(HeKEY_sv(entry));
	    }
	}

	if((meta = iter->xhv_mro_meta)) {
	    AvTMPREFCNT_inc(meta->mro_linear_c3);
	    HvTMPREFCNT_inc(meta->mro_nextmethod);
	}
    }

    {
	HE ** const array = HvARRAY(hv);
	I32 i = HvMAX(hv);

	if (array) {
	    do {
		/* Loop down the linked list heads  */
		HE *entry = array[i];

		while (entry) {
		    SvTMPREFCNT_inc(HeVAL(entry));
		    if (HeKLEN(entry) == HEf_SVKEY) {
			SvTMPREFCNT_inc(HeKEY_sv(entry));
		    }

		    entry = HeNEXT(entry);
		}
	    } while (--i >= 0);
	}
    }
}

static struct xpvhv_aux*
S_hv_auxinit(HV *hv) {
    struct xpvhv_aux *iter;
    char *array;

    PERL_ARGS_ASSERT_HV_AUXINIT;

    if (!HvARRAY(hv)) {
	Newxz(array, PERL_HV_ARRAY_ALLOC_BYTES(HvMAX(hv) + 1)
	    + sizeof(struct xpvhv_aux), char);
    } else {
	array = (char *) HvARRAY(hv);
	Renew(array, PERL_HV_ARRAY_ALLOC_BYTES(HvMAX(hv) + 1)
	      + sizeof(struct xpvhv_aux), char);
    }
    HvARRAY(hv) = (HE**) array;
    /* SvOOK_on(hv) attacks the IV flags.  */
    SvFLAGS(hv) |= SVf_OOK;
    iter = HvAUX(hv);

    iter->xhv_riter = -1; 	/* HvRITER(hv) = -1 */
    iter->xhv_eiter = NULL;	/* HvEITER(hv) = NULL */
    iter->xhv_name = 0;
    iter->xhv_backreferences = 0;
    iter->xhv_mro_meta = NULL;
    return iter;
}

/*
=for apidoc hv_iterinit

Prepares a starting point to traverse a hash table.  Returns the number of
keys in the hash (i.e. the same as C<HvKEYS(tb)>).  The return value is
currently only meaningful for hashes without tie magic.

NOTE: Before version 5.004_65, C<hv_iterinit> used to return the number of
hash buckets that happen to be in use.  If you still need that esoteric
value, you can get it through the macro C<HvFILL(tb)>.


=cut
*/

I32
Perl_hv_iterinit(pTHX_ HV *hv)
{
    PERL_ARGS_ASSERT_HV_ITERINIT;

    /* FIXME: Are we not NULL, or do we croak? Place bets now! */

    if (!hv)
	Perl_croak(aTHX_ "Bad hash");

    if (SvOOK(hv)) {
	struct xpvhv_aux * const iter = HvAUX(hv);
	HE * const entry = iter->xhv_eiter; /* HvEITER(hv) */
	if (entry && HvLAZYDEL(hv)) {	/* was deleted earlier? */
	    HvLAZYDEL_off(hv);
	    hv_free_ent(hv, entry);
	}
	iter->xhv_riter = -1; 	/* HvRITER(hv) = -1 */
	iter->xhv_eiter = NULL; /* HvEITER(hv) = NULL */
    } else {
	hv_auxinit(hv);
    }

    /* used to be xhv->xhv_fill before 5.004_65 */
    return HvTOTALKEYS(hv);
}

I32 *
Perl_hv_riter_p(pTHX_ HV *hv) {
    struct xpvhv_aux *iter;

    PERL_ARGS_ASSERT_HV_RITER_P;

    if (!hv)
	Perl_croak(aTHX_ "Bad hash");

    iter = SvOOK(hv) ? HvAUX(hv) : hv_auxinit(hv);
    return &(iter->xhv_riter);
}

HE **
Perl_hv_eiter_p(pTHX_ HV *hv) {
    struct xpvhv_aux *iter;

    PERL_ARGS_ASSERT_HV_EITER_P;

    if (!hv)
	Perl_croak(aTHX_ "Bad hash");

    iter = SvOOK(hv) ? HvAUX(hv) : hv_auxinit(hv);
    return &(iter->xhv_eiter);
}

void
Perl_hv_riter_set(pTHX_ HV *hv, I32 riter) {
    struct xpvhv_aux *iter;

    PERL_ARGS_ASSERT_HV_RITER_SET;

    if (!hv)
	Perl_croak(aTHX_ "Bad hash");

    if (SvOOK(hv)) {
	iter = HvAUX(hv);
    } else {
	if (riter == -1)
	    return;

	iter = hv_auxinit(hv);
    }
    iter->xhv_riter = riter;
}

void
Perl_hv_eiter_set(pTHX_ HV *hv, HE *eiter) {
    struct xpvhv_aux *iter;

    PERL_ARGS_ASSERT_HV_EITER_SET;

    if (!hv)
	Perl_croak(aTHX_ "Bad hash");

    if (SvOOK(hv)) {
	iter = HvAUX(hv);
    } else {
	/* 0 is the default so don't go malloc()ing a new structure just to
	   hold 0.  */
	if (!eiter)
	    return;

	iter = hv_auxinit(hv);
    }
    iter->xhv_eiter = eiter;
}

void
Perl_hv_name_set(pTHX_ HV *hv, const char *name, U32 len, U32 flags)
{
    dVAR;
    struct xpvhv_aux *iter;
    U32 hash;

    PERL_ARGS_ASSERT_HV_NAME_SET;
    PERL_UNUSED_ARG(flags);

    if (len > I32_MAX)
	Perl_croak(aTHX_ "panic: hv name too long (%"UVuf")", (UV) len);

    if (SvOOK(hv)) {
	iter = HvAUX(hv);
	if (iter->xhv_name) {
	    unshare_hek_or_pvn(iter->xhv_name, 0, 0, 0);
	}
    } else {
	if (name == 0)
	    return;

	iter = hv_auxinit(hv);
    }
    PERL_HASH(hash, name, len);
    iter->xhv_name = name ? share_hek(name, len, hash) : NULL;
}

AV **
Perl_hv_backreferences_p(pTHX_ HV *hv) {
    struct xpvhv_aux * const iter = SvOOK(hv) ? HvAUX(hv) : hv_auxinit(hv);

    PERL_ARGS_ASSERT_HV_BACKREFERENCES_P;
    PERL_UNUSED_CONTEXT;

    return &(iter->xhv_backreferences);
}

void
Perl_hv_kill_backrefs(pTHX_ HV *hv) {
    AV *av;

    PERL_ARGS_ASSERT_HV_KILL_BACKREFS;

    if (!SvOOK(hv))
	return;

    av = HvAUX(hv)->xhv_backreferences;

    if (av) {
	HvAUX(hv)->xhv_backreferences = 0;
	Perl_sv_kill_backrefs(aTHX_ (SV*) hv, av);
    }
}

/*
hv_iternext is implemented as a macro in hv.h

=for apidoc hv_iternext

Returns entries from a hash iterator.  See C<hv_iterinit>.

You may call C<hv_delete> or C<hv_delete_ent> on the hash entry that the
iterator currently points to, without losing your place or invalidating your
iterator.  Note that in this case the current entry is deleted from the hash
with your iterator holding the last reference to it.  Your iterator is flagged
to free the entry on the next call to C<hv_iternext>, so you must not discard
your iterator immediately else the entry will leak - call C<hv_iternext> to
trigger the resource deallocation.

=for apidoc hv_iternext_flags

Returns entries from a hash iterator.  See C<hv_iterinit> and C<hv_iternext>.
The C<flags> value will normally be zero; if HV_ITERNEXT_WANTPLACEHOLDERS is
set the placeholders keys (for restricted hashes) will be returned in addition
to normal keys. By default placeholders are automatically skipped over.
Currently a placeholder is implemented with a value that is
C<&Perl_sv_placeholder>. Note that the implementation of placeholders and
restricted hashes may change, and the implementation currently is
insufficiently abstracted for any change to be tidy.

=cut
*/

HE *
Perl_hv_iternext_flags(pTHX_ HV *hv, I32 flags)
{
    dVAR;
    register XPVHV* xhv;
    register HE *entry;
    HE *oldentry;
    struct xpvhv_aux *iter;

    PERL_ARGS_ASSERT_HV_ITERNEXT_FLAGS;

    if (!hv)
	Perl_croak(aTHX_ "Bad hash");

    xhv = (XPVHV*)SvANY(hv);

    if (!SvOOK(hv)) {
	/* Too many things (well, pp_each at least) merrily assume that you can
	   call iv_iternext without calling hv_iterinit, so we'll have to deal
	   with it.  */
	hv_iterinit(hv);
    }
    iter = HvAUX(hv);

    oldentry = entry = iter->xhv_eiter; /* HvEITER(hv) */

    /* hv_iterint now ensures this.  */
    assert (HvARRAY(hv));

    /* At start of hash, entry is NULL.  */
    if (entry)
    {
	entry = HeNEXT(entry);
        if (!(flags & HV_ITERNEXT_WANTPLACEHOLDERS)) {
            /*
             * Skip past any placeholders -- don't want to include them in
             * any iteration.
             */
            while (entry && HeVAL(entry) == &PL_sv_placeholder) {
                entry = HeNEXT(entry);
            }
	}
    }
    while (!entry) {
	/* OK. Come to the end of the current list.  Grab the next one.  */

	iter->xhv_riter++; /* HvRITER(hv)++ */
	if (iter->xhv_riter > (I32)xhv->xhv_max /* HvRITER(hv) > HvMAX(hv) */) {
	    /* There is no next one.  End of the hash.  */
	    iter->xhv_riter = -1; /* HvRITER(hv) = -1 */
	    break;
	}
	entry = (HvARRAY(hv))[iter->xhv_riter];

        if (!(flags & HV_ITERNEXT_WANTPLACEHOLDERS)) {
            /* If we have an entry, but it's a placeholder, don't count it.
	       Try the next.  */
	    while (entry && HeVAL(entry) == &PL_sv_placeholder)
		entry = HeNEXT(entry);
	}
	/* Will loop again if this linked list starts NULL
	   (for HV_ITERNEXT_WANTPLACEHOLDERS)
	   or if we run through it and find only placeholders.  */
    }

    if (oldentry && HvLAZYDEL(hv)) {		/* was deleted earlier? */
	HvLAZYDEL_off(hv);
	hv_free_ent(hv, oldentry);
    }

    /*if (HvREHASH(hv) && entry && !HeKREHASH(entry))
      PerlIO_printf(PerlIO_stderr(), "Awooga %p %p\n", (void*)hv, (void*)entry);*/

    iter->xhv_eiter = entry; /* HvEITER(hv) = entry */
    return entry;
}

/*
=for apidoc hv_iterkey

Returns the key from the current position of the hash iterator.  See
C<hv_iterinit>.

=cut
*/

char *
Perl_hv_iterkey(pTHX_ register HE *entry, I32 *retlen)
{
    PERL_ARGS_ASSERT_HV_ITERKEY;

    if (HeKLEN(entry) == HEf_SVKEY) {
	STRLEN len;
	char * const p = SvPV(HeKEY_sv(entry), len);
	*retlen = len;
	return p;
    }
    else {
	*retlen = HeKLEN(entry);
	return HeKEY(entry);
    }
}

/* unlike hv_iterval(), this always returns a mortal copy of the key */
/*
=for apidoc hv_iterkeysv

Returns the key as an C<SV*> from the current position of the hash
iterator.  The return value will always be a mortal copy of the key.  Also
see C<hv_iterinit>.

=cut
*/

SV *
Perl_hv_iterkeysv(pTHX_ register HE *entry)
{
    PERL_ARGS_ASSERT_HV_ITERKEYSV;

    return sv_2mortal(newSVhek(HeKEY_hek(entry)));
}

/*
=for apidoc hv_iterval

Returns the value from the current position of the hash iterator.  See
C<hv_iterkey>.

=cut
*/

SV *
Perl_hv_iterval(pTHX_ HV *hv, register HE *entry)
{
    PERL_ARGS_ASSERT_HV_ITERVAL;

    return HeVAL(entry);
}

/*
=for apidoc hv_iternextsv

Performs an C<hv_iternext>, C<hv_iterkey>, and C<hv_iterval> in one
operation.

=cut
*/

SV *
Perl_hv_iternextsv(pTHX_ HV *hv, char **key, I32 *retlen)
{
    HE * const he = hv_iternext_flags(hv, 0);

    PERL_ARGS_ASSERT_HV_ITERNEXTSV;

    if (!he)
	return NULL;
    *key = hv_iterkey(he, retlen);
    return hv_iterval(hv, he);
}

/*

Now a macro in hv.h

=for apidoc hv_magic

Adds magic to a hash.  See C<sv_magic>.

=cut
*/

/* possibly free a shared string if no one has access to it
 * len and hash must both be valid for str.
 */
void
Perl_unsharepvn(pTHX_ const char *str, I32 len, U32 hash)
{
    unshare_hek_or_pvn (NULL, str, len, hash);
}


void
Perl_unshare_hek(pTHX_ HEK *hek)
{
    assert(hek);
    unshare_hek_or_pvn(hek, NULL, 0, 0);
}

/* possibly free a shared string if no one has access to it
   hek if non-NULL takes priority over the other 3, else str, len and hash
   are used.  If so, len and hash must both be valid for str.
 */
STATIC void
S_unshare_hek_or_pvn(pTHX_ const HEK *hek, const char *str, I32 len, U32 hash)
{
    dVAR;
    register XPVHV* xhv;
    HE *entry;
    register HE **oentry;
    HE **first;
    int k_flags = 0;
    struct shared_he *he = NULL;

    if (hek) {
	/* Find the shared he which is just before us in memory.  */
	he = (struct shared_he *)(((char *)hek)
				  - STRUCT_OFFSET(struct shared_he,
						  shared_he_hek));

	/* Assert that the caller passed us a genuine (or at least consistent)
	   shared hek  */
	assert (he->shared_he_he.hent_hek == hek);

	LOCK_STRTAB_MUTEX;
	if (he->shared_he_he.he_valu.hent_refcount - 1) {
	    --he->shared_he_he.he_valu.hent_refcount;
	    UNLOCK_STRTAB_MUTEX;
	    return;
	}
	UNLOCK_STRTAB_MUTEX;

        hash = HEK_HASH(hek);
    }

    /* what follows was the moral equivalent of:
    if ((Svp = hv_fetch(PL_strtab, tmpsv, FALSE, hash))) {
	if (--*Svp == NULL)
	    hv_delete(PL_strtab, str, len, G_DISCARD, hash);
    } */
    xhv = (XPVHV*)SvANY(PL_strtab);
    /* assert(xhv_array != 0) */
    LOCK_STRTAB_MUTEX;
    first = oentry = &(HvARRAY(PL_strtab))[hash & (I32) HvMAX(PL_strtab)];
    if (he) {
	const HE *const he_he = &(he->shared_he_he);
        for (entry = *oentry; entry; oentry = &HeNEXT(entry), entry = *oentry) {
            if (entry == he_he)
                break;
        }
    } else {
        const int flags_masked = k_flags & HVhek_MASK;
        for (entry = *oentry; entry; oentry = &HeNEXT(entry), entry = *oentry) {
            if (HeHASH(entry) != hash)		/* strings can't be equal */
                continue;
            if (HeKLEN(entry) != len)
                continue;
            if (HeKEY(entry) != str && memNE(HeKEY(entry),str,len))	/* is this it? */
                continue;
            if (HeKFLAGS(entry) != flags_masked)
                continue;
            break;
        }
    }

    if (entry) {
        if (--entry->he_valu.hent_refcount == 0) {
            *oentry = HeNEXT(entry);
            if (!*first) {
		/* There are now no entries in our slot.  */
                xhv->xhv_fill--; /* HvFILL(hv)-- */
	    }
            Safefree(entry);
            xhv->xhv_keys--; /* HvTOTALKEYS(hv)-- */
        }
    }

    UNLOCK_STRTAB_MUTEX;
    if (!entry && ckWARN_d(WARN_INTERNAL))
	Perl_warner(aTHX_ packWARN(WARN_INTERNAL),
                    "Attempt to free non-existent shared string '%s'%s"
                    pTHX__FORMAT,
                    hek ? HEK_KEY(hek) : str,
                    ("") pTHX__VALUE);
    if (k_flags & HVhek_FREEKEY)
	Safefree(str);
}

/* get a (constant) string ptr from the global string table
 * string will get added if it is not already there.
 * len and hash must both be valid for str.
 */
HEK *
Perl_share_hek(pTHX_ const char *str, I32 len, register U32 hash)
{
    int flags = 0;

    PERL_ARGS_ASSERT_SHARE_HEK;

    return share_hek_flags (str, len, hash, flags);
}

STATIC HEK *
S_share_hek_flags(pTHX_ const char *str, I32 len, register U32 hash, int flags)
{
    dVAR;
    register HE *entry;
    const int flags_masked = flags & HVhek_MASK;
    const U32 hindex = hash & (I32) HvMAX(PL_strtab);
    register XPVHV * const xhv = (XPVHV*)SvANY(PL_strtab);

    PERL_ARGS_ASSERT_SHARE_HEK_FLAGS;

    /* what follows is the moral equivalent of:

    if (!(Svp = hv_fetch(PL_strtab, str, len, FALSE)))
	hv_store(PL_strtab, str, len, NULL, hash);

	Can't rehash the shared string table, so not sure if it's worth
	counting the number of entries in the linked list
    */

    /* assert(xhv_array != 0) */
    LOCK_STRTAB_MUTEX;
    entry = (HvARRAY(PL_strtab))[hindex];
    for (;entry; entry = HeNEXT(entry)) {
	if (HeHASH(entry) != hash)		/* strings can't be equal */
	    continue;
	if (HeKLEN(entry) != len)
	    continue;
	if (HeKEY(entry) != str && memNE(HeKEY(entry),str,len))	/* is this it? */
	    continue;
	if (HeKFLAGS(entry) != flags_masked)
	    continue;
	break;
    }

    if (!entry) {
	/* What used to be head of the list.
	   If this is NULL, then we're the first entry for this slot, which
	   means we need to increate fill.  */
	struct shared_he *new_entry;
	HEK *hek;
	char *k;
	HE **const head = &HvARRAY(PL_strtab)[hindex];
	HE *const next = *head;

	/* We don't actually store a HE from the arena and a regular HEK.
	   Instead we allocate one chunk of memory big enough for both,
	   and put the HEK straight after the HE. This way we can find the
	   HEK directly from the HE.
	*/

	Newx(k, STRUCT_OFFSET(struct shared_he,
				shared_he_hek.hek_key[0]) + len + 2, char);
	new_entry = (struct shared_he *)k;
	entry = &(new_entry->shared_he_he);
	hek = &(new_entry->shared_he_hek);

	Copy(str, HEK_KEY(hek), len, char);
	HEK_KEY(hek)[len] = 0;
	HEK_LEN(hek) = len;
	HEK_HASH(hek) = hash;
	HEK_FLAGS(hek) = (unsigned char)flags_masked;

	/* Still "point" to the HEK, so that other code need not know what
	   we're up to.  */
	HeKEY_hek(entry) = hek;
	entry->he_valu.hent_refcount = 0;
	HeNEXT(entry) = next;
	*head = entry;

	xhv->xhv_keys++; /* HvTOTALKEYS(hv)++ */
	if (!next) {			/* initial entry? */
	    xhv->xhv_fill++; /* HvFILL(hv)++ */
	} else if (xhv->xhv_keys > (IV)xhv->xhv_max /* HvKEYS(hv) > HvMAX(hv) */) {
		hsplit(PL_strtab);
	}
    }

    ++entry->he_valu.hent_refcount;
    UNLOCK_STRTAB_MUTEX;

    if (flags & HVhek_FREEKEY)
	Safefree(str);

    return HeKEY_hek(entry);
}

I32 *
Perl_hv_placeholders_p(pTHX_ HV *hv)
{
    dVAR;
    MAGIC *mg = mg_find((SV*)hv, PERL_MAGIC_rhash);

    PERL_ARGS_ASSERT_HV_PLACEHOLDERS_P;

    if (!mg) {
	mg = sv_magicext((SV*)hv, 0, PERL_MAGIC_rhash, 0, 0, 0);

	if (!mg) {
	    Perl_croak(aTHX_ "panic: hv_placeholders_p");
	}
    }
    return &(mg->mg_len);
}


I32
Perl_hv_placeholders_get(pTHX_ HV *hv)
{
    dVAR;
    MAGIC * const mg = mg_find((SV*)hv, PERL_MAGIC_rhash);

    PERL_ARGS_ASSERT_HV_PLACEHOLDERS_GET;

    return mg ? mg->mg_len : 0;
}

void
Perl_hv_placeholders_set(pTHX_ HV *hv, I32 ph)
{
    dVAR;
    MAGIC * const mg = mg_find((SV*)hv, PERL_MAGIC_rhash);

    PERL_ARGS_ASSERT_HV_PLACEHOLDERS_SET;

    if (mg) {
	mg->mg_len = ph;
    } else if (ph) {
	if (!sv_magicext((SV*)hv, 0, PERL_MAGIC_rhash, 0, 0, ph))
	    Perl_croak(aTHX_ "panic: hv_placeholders_set");
    }
    /* else we don't need to add magic to record 0 placeholders.  */
}

/*
=for apidoc hv_assert

Check that a hash is in an internally consistent state.

=cut
*/

#ifdef DEBUGGING

void
Perl_hv_assert(pTHX_ HV *hv)
{
    dVAR;
    HE* entry;
    int placeholders = 0;
    int real = 0;
    int bad = 0;
    const I32 riter = HvRITER_get(hv);
    HE *eiter = HvEITER_get(hv);

    PERL_ARGS_ASSERT_HV_ASSERT;

    (void)hv_iterinit(hv);

    while ((entry = hv_iternext_flags(hv, HV_ITERNEXT_WANTPLACEHOLDERS))) {
	/* sanity check the values */
	if (HeVAL(entry) == &PL_sv_placeholder)
	    placeholders++;
	else
	    real++;
	/* sanity check the keys */
	if (HeSVKEY(entry)) {
	    NOOP;   /* Don't know what to check on SV keys.  */
	} 
    }
    if (bad) {
	sv_dump((SV *)hv);
    }
    HvRITER_set(hv, riter);		/* Restore hash iterator state */
    HvEITER_set(hv, eiter);
}

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
