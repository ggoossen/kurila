/*    av.h
 *
 *    Copyright (C) 1991, 1992, 1993, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2002, 2005, 2006, 2007, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

#define _XPVAV_ALLOCATED_HEAD						\
    SSize_t	xav_fill;       /* Index of last element present */	\
    SSize_t	xav_max         /* max index for which array has space */

#define _XPVAV_HEAD	\
    union _xnvu xnv_u;	\
    _XPVAV_ALLOCATED_HEAD

struct xpvav {
    _XPVAV_HEAD;
    _XPVMG_HEAD;
};

typedef struct {
    _XPVAV_ALLOCATED_HEAD;
    _XPVMG_HEAD;
} xpvav_allocated;

#undef _XPVAV_ALLOCATED_HEAD
#undef _XPVAV_HEAD

/* SV**	xav_alloc; */
#define xav_alloc xiv_u.xivu_p1
/* SV*	xav_arylen; */

/* SVpav_REAL is set for all AVs whose xav_array contents are refcounted.
 * Some things like "@_" and the scratchpad list do not set this, to
 * indicate that they are cheating (for efficiency) by not refcounting
 * the AV's contents.
 * 
 * SVpav_REIFY is only meaningful on such "fake" AVs (i.e. where SVpav_REAL
 * is not set).  It indicates that the fake AV is capable of becoming
 * real if the array needs to be modified in some way.  Functions that
 * modify fake AVs check both flags to call av_reify() as appropriate.
 *
 * Note that the Perl stack and @DB::args have neither flag set. (Thus,
 * items that go on the stack are never refcounted.)
 *
 * These internal details are subject to change any time.  AV
 * manipulations external to perl should not care about any of this.
 * GSAR 1999-09-10
 */

/*
=head1 Handy Values

=for apidoc AmU||Nullav
Null AV pointer.

=head1 Array Manipulation Functions

=for apidoc Am|int|AvFILL|AV* av
Same as C<av_len()>.  Deprecated, use C<av_len()> instead.

=cut
*/

#define Nullav Null(AV*)

#define AvARRAY(av)	((av)->sv_u.svu_array)
#define AvALLOC(av)	(*((SV***)&((XPVAV*)  SvANY(av))->xav_alloc))
#define AvMAX(av)	((XPVAV*)  SvANY(av))->xav_max
#define AvFILLp(av)	((XPVAV*)  SvANY(av))->xav_fill
#define AvARYLEN(av)	(*Perl_av_arylen_p(aTHX_ (AV*)av))

#define AvREAL(av)	(SvFLAGS(av) & SVpav_REAL)
#define AvREAL_on(av)	(SvFLAGS(av) |= SVpav_REAL)
#define AvREAL_off(av)	(SvFLAGS(av) &= ~SVpav_REAL)
#define AvREAL_only(av)	(AvREIFY_off(av), SvFLAGS(av) |= SVpav_REAL)
#define AvREIFY(av)	(SvFLAGS(av) & SVpav_REIFY)
#define AvREIFY_on(av)	(SvFLAGS(av) |= SVpav_REIFY)
#define AvREIFY_off(av)	(SvFLAGS(av) &= ~SVpav_REIFY)
#define AvREIFY_only(av)	(AvREAL_off(av), SvFLAGS(av) |= SVpav_REIFY)

#define AvREALISH(av)	(SvFLAGS(av) & (SVpav_REAL|SVpav_REIFY))
                                          
#define AvFILL(av)	((SvRMAGICAL((SV *) (av))) \
			  ? mg_size((SV *) av) : AvFILLp(av))

#define NEGATIVE_INDICES_VAR "NEGATIVE_INDICES"

/*
=for apidoc newAV

Creates a new AV.  The reference count is set to 1.

=cut
*/

#define newAV()	((AV *)newSV_type(SVt_PVAV))

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
