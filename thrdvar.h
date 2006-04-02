/*    thdrvar.h
 *
 *    Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
=head1 Global Variables
*/

/***********************************************/
/* Global only to current thread               */
/***********************************************/

/* Don't forget to re-run embed.pl to propagate changes! */

/* The 'T' prefix is only needed for vars that need appropriate #defines
 * generated when built with or without USE_5005THREADS.  It is also used
 * to generate the appropriate export list for win32.
 *
 * When building without USE_5005THREADS, these variables will be truly global.
 * When building without USE_5005THREADS but with MULTIPLICITY, these variables
 * will be global per-interpreter. */

/* Important ones in the first cache line (if alignment is done right) */

PERLVAR(Tstack_sp,	SV **)		/* top of the stack */
#ifdef OP_IN_REGISTER
PERLVAR(Topsave,	OP *)
#else
PERLVAR(Top,		OP *)		/* currently executing op */
#endif
PERLVAR(Tcurpad,	SV **)		/* active pad (lexicals+tmps) */

PERLVAR(Tstack_base,	SV **)
PERLVAR(Tstack_max,	SV **)

PERLVAR(Tscopestack,	I32 *)		/* scopes we've ENTERed */
PERLVAR(Tscopestack_ix,	I32)
PERLVAR(Tscopestack_max,I32)

PERLVAR(Tsavestack,	ANY *)		/* items that need to be restored
					   when LEAVEing scopes we've ENTERed */
PERLVAR(Tsavestack_ix,	I32)
PERLVAR(Tsavestack_max,	I32)

PERLVAR(Ttmps_stack,	SV **)		/* mortals we've made */
PERLVARI(Ttmps_ix,	I32,	-1)
PERLVARI(Ttmps_floor,	I32,	-1)
PERLVAR(Ttmps_max,	I32)

PERLVAR(Tmarkstack,	I32 *)		/* stack_sp locations we're remembering */
PERLVAR(Tmarkstack_ptr,	I32 *)
PERLVAR(Tmarkstack_max,	I32 *)

PERLVAR(TSv,		SV *)		/* used to hold temporary values */
PERLVAR(TXpv,		XPV *)		/* used to hold temporary values */

/*
=for apidoc Amn|STRLEN|PL_na

A convenience variable which is typically used with C<SvPV> when one
doesn't care about the length of the string.  It is usually more efficient
to either declare a local variable and use that instead or to use the
C<SvPV_nolen> macro.

=cut
*/

PERLVAR(Tna,		STRLEN)		/* for use in SvPV when length is
					   Not Applicable */

/* stat stuff */
PERLVAR(Tstatbuf,	Stat_t)
PERLVAR(Tstatcache,	Stat_t)		/* _ */
PERLVAR(Tstatgv,	GV *)
PERLVARI(Tstatname,	SV *,	NULL)

#ifdef HAS_TIMES
PERLVAR(Ttimesbuf,	struct tms)
#endif

/* Fields used by magic variables such as $@, $/ and so on */
PERLVAR(Ttainted,	bool)		/* using variables controlled by $< */
PERLVAR(Tcurpm,		PMOP *)		/* what to do \ interps in REs from */
PERLVAR(Tnrs,		SV *)		/* was placeholder: unused since 5.8.0 (5.7.2 patch #12027 for bug ID 20010815.012). Used to save rx->saved_copy */

/*
=for apidoc mn|SV*|PL_rs

The input record separator - C<$/> in Perl space.

=for apidoc mn|GV*|PL_last_in_gv

The GV which was last used for a filehandle input operation. (C<< <FH> >>)

=for apidoc mn|SV*|PL_ofs_sv

The output field separator - C<$,> in Perl space.

=cut
*/

PERLVAR(Trs,		SV *)		/* input record separator $/ */
PERLVAR(Tlast_in_gv,	GV *)		/* GV used in last <FH> */
PERLVAR(Tofs_sv,	SV *)		/* output field separator $, */
PERLVAR(Tdefoutgv,	GV *)		/* default FH for output */
PERLVARI(Tchopset,	const char *,	" \n-")	/* $: */
PERLVAR(Tformtarget,	SV *)
PERLVAR(Tbodytarget,	SV *)
PERLVAR(Ttoptarget,	SV *)

/* Stashes */
PERLVAR(Tdefstash,	HV *)		/* main symbol table */
PERLVAR(Tcurstash,	HV *)		/* symbol table for current package */

PERLVAR(Trestartop,	OP *)		/* propagating an error from croak? */
PERLVARI(Tcurcop,	COP * VOL,	&PL_compiling)
PERLVAR(Tin_eval,	VOL int)	/* trap "fatal" errors? */
PERLVAR(Tdelaymagic,	int)		/* ($<,$>) = ... */
PERLVARI(Tdirty,	bool, FALSE)	/* in the middle of tearing things down? */
PERLVAR(Tlocalizing,	int)		/* are we processing a local() list? */

PERLVAR(Tcurstack,	AV *)		/* THE STACK */
PERLVAR(Tcurstackinfo,	PERL_SI *)	/* current stack + context */
PERLVAR(Tmainstack,	AV *)		/* the stack when nothing funny is happening */

PERLVAR(Ttop_env,	JMPENV *)	/* ptr. to current sigjmp() environment */
PERLVAR(Tstart_env,	JMPENV)		/* empty startup sigjmp() environment */
PERLVARI(Terrors,	SV *, NULL)	/* outstanding queued errors */

/* statics "owned" by various functions */
PERLVAR(Tav_fetch_sv,	SV *)		/* unused as of change #19268 */
PERLVAR(Thv_fetch_sv,	SV *)		/* unused as of change #19268 */
PERLVAR(Thv_fetch_ent_mh, HE*)		/* owned by hv_fetch_ent() */

PERLVAR(Tmodcount,	I32)		/* how much mod()ification in assignment? */

PERLVAR(Tlastgotoprobe,	OP*)		/* from pp_ctl.c */
PERLVARI(Tdumpindent,	I32, 4)		/* # of blanks per dump indentation level */

/* sort stuff */
PERLVAR(Tsortcop,	OP *)		/* user defined sort routine */
PERLVAR(Tsortstash,	HV *)		/* which is in some package or other */
PERLVAR(Tfirstgv,	GV *)		/* $a */
PERLVAR(Tsecondgv,	GV *)		/* $b */

/* float buffer */
PERLVAR(Tefloatbuf,	char*)
PERLVAR(Tefloatsize,	STRLEN)

/* regex stuff */

PERLVAR(Tscreamfirst,	I32 *)
PERLVAR(Tscreamnext,	I32 *)
PERLVARI(Tmaxscream,	I32,	-1)
PERLVAR(Tlastscream,	SV *)

PERLVAR(Tregdummy,	regnode)	/* from regcomp.c */
PERLVAR(Tregprecomp,	char *)		/* uncompiled string. */
PERLVAR(Tregnpar,	I32)		/* () count. */
PERLVAR(Tregsize,	I32)		/* Code size. */
PERLVAR(Tcolorset,	int)		/* from regcomp.c */
PERLVARA(Tcolors,6,	char *)		/* from regcomp.c */
PERLVAR(Treginput,	char *)		/* String-input pointer. */
PERLVAR(Tregbol,	char *)		/* Beginning of input, for ^ check. */
PERLVAR(Tregeol,	char *)		/* End of input, for $ check. */
PERLVAR(Tregstartp,	I32 *)		/* Pointer to startp array. */
PERLVAR(Tregendp,	I32 *)		/* Ditto for endp. */
PERLVAR(Treglastparen,	U32 *)		/* Similarly for lastparen. */
PERLVAR(Treglastcloseparen, U32 *)	/* Similarly for lastcloseparen. */
PERLVAR(Tregtill,	char *)		/* How far we are required to go. */
PERLVAR(Treg_start_tmp,	char **)	/* from regexec.c */
PERLVAR(Treg_start_tmpl,U32)		/* from regexec.c */
PERLVAR(Tregdata,	struct reg_data *)
					/* from regexec.c renamed was data */
PERLVAR(Tbostr,		char *)		/* from regexec.c */
PERLVAR(Treg_flags,	U32)		/* from regexec.c */
PERLVAR(Treg_eval_set,	I32)		/* from regexec.c */
PERLVAR(Tregnarrate,	I32)		/* from regexec.c */
PERLVAR(Tregprogram,	regnode *)	/* from regexec.c */
PERLVARI(Tregindent,	int,	    0)	/* from regexec.c */
PERLVAR(Treg_call_cc,	struct re_cc_state *)	/* from regexec.c */
PERLVAR(Treg_re,	regexp *)	/* from regexec.c */
PERLVAR(Treg_ganch,	char *)		/* position of \G */
PERLVAR(Treg_sv,	SV *)		/* what we match against */
PERLVAR(Treg_magic,	MAGIC *)	/* pos-magic of what we match */
PERLVAR(Treg_oldpos,	I32)		/* old pos of what we match */
PERLVARI(Treg_oldcurpm,	PMOP*, NULL)	/* curpm before match */
PERLVARI(Treg_curpm,	PMOP*, NULL)	/* curpm during match */
PERLVAR(Treg_oldsaved,	char*)		/* old saved substr during match */
PERLVAR(Treg_oldsavedlen, STRLEN)	/* old length of saved substr during match */
PERLVAR(Treg_maxiter,	I32)		/* max wait until caching pos */
PERLVAR(Treg_leftiter,	I32)		/* wait until caching pos */
PERLVARI(Treg_poscache, char *, NULL)	/* cache of pos of WHILEM */
PERLVAR(Treg_poscache_size, STRLEN)	/* size of pos cache of WHILEM */

PERLVARI(Tpeepp,	peep_t, MEMBER_TO_FPTR(Perl_peep))
					/* Pointer to peephole optimizer */
PERLVARI(Tregcompp,	regcomp_t, MEMBER_TO_FPTR(Perl_pregcomp))
					/* Pointer to REx compiler */
PERLVARI(Tregexecp,	regexec_t, MEMBER_TO_FPTR(Perl_regexec_flags))
					/* Pointer to REx executer */
PERLVARI(Tregint_start,	re_intuit_start_t, MEMBER_TO_FPTR(Perl_re_intuit_start))
					/* Pointer to optimized REx executer */
PERLVARI(Tregint_string,re_intuit_string_t, MEMBER_TO_FPTR(Perl_re_intuit_string))
					/* Pointer to optimized REx string */
PERLVARI(Tregfree,	regfree_t, MEMBER_TO_FPTR(Perl_pregfree))
					/* Pointer to REx free()er */

PERLVARI(Treginterp_cnt,int,	    0)	/* Whether "Regexp" was interpolated. */
PERLVARI(Treg_starttry,	char *,	    0)	/* -Dr: where regtry was called. */
PERLVARI(Twatchaddr,	char **,    0)
PERLVAR(Twatchok,	char *)

/* Note that the variables below are all explicitly referenced in the code
 * as thr->whatever and therefore don't need the 'T' prefix. */

PERLVAR(Treg_match_utf8,	bool)		/* was what we matched against utf8 */

/* the currently active slab in a chain of slabs of regmatch states,
 * and the currently active state within that slab */

PERLVARI(Tregmatch_slab,	regmatch_slab *, NULL)
PERLVAR(Tregmatch_state,	regmatch_state *)
