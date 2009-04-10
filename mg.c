/*    mg.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * "Sam sat on the ground and put his head in his hands.  'I wish I had never
 * come here, and I don't want to see no more magic,' he said, and fell silent."
 */

/*
=head1 Magical Functions

"Magic" is special data attached to SV structures in order to give them
"magical" properties.  When any Perl code tries to read from, or assign to,
an SV marked as magical, it calls the 'get' or 'set' function associated
with that SV's magic. A get is called prior to reading an SV, in order to
give it a chance to update its internal value (get on $. writes the line
number of the last read filehandle into to the SV's IV slot), while
set is called after an SV has been written to, in order to allow it to make
use of its changed value (set on $/ copies the SV's new value to the
PL_rs global variable).

Magic is implemented as a linked list of MAGIC structures attached to the
SV. Each MAGIC struct holds the type of the magic, a pointer to an array
of functions that implement the get(), set(), length() etc functions,
plus space for some flags and pointers. For example, a tied variable has
a MAGIC structure that contains a pointer to the object associated with the
tie.

*/

#include "EXTERN.h"
#define PERL_IN_MG_C
#include "perl.h"

#if defined(HAS_GETGROUPS) || defined(HAS_SETGROUPS)
#  ifdef I_GRP
#    include <grp.h>
#  endif
#endif

#if defined(HAS_SETGROUPS)
#  ifndef NGROUPS
#    define NGROUPS 32
#  endif
#endif

#ifdef __hpux
#  include <sys/pstat.h>
#endif

#if defined(HAS_SIGACTION) && defined(SA_SIGINFO)
Signal_t Perl_csighandler(int sig, siginfo_t *, void *);
#else
Signal_t Perl_csighandler(int sig);
#endif

#ifdef __Lynx__
/* Missing protos on LynxOS */
void setruid(uid_t id);
void seteuid(uid_t id);
void setrgid(uid_t id);
void setegid(uid_t id);
#endif

/*
 * Use the "DESTRUCTOR" scope cleanup to reinstate magic.
 */

struct magic_state {
    SV* mgs_sv;
    U32 mgs_flags;
    I32 mgs_ss_ix;
};
/* MGS is typedef'ed to struct magic_state in perl.h */

STATIC void
S_save_magic(pTHX_ I32 mgs_ix, SV *sv)
{
    dVAR;
    MGS* mgs;

    PERL_ARGS_ASSERT_SAVE_MAGIC;

    assert(SvMAGICAL(sv));
    /* Turning READONLY off for a copy-on-write scalar (including shared
       hash keys) is a bad idea.  */
    if (SvIsCOW(sv))
      sv_force_normal_flags(sv, 0);

    SAVEDESTRUCTOR_X(S_restore_magic, INT2PTR(void*, (IV)mgs_ix));

    mgs = SSPTR(mgs_ix, MGS*);
    mgs->mgs_sv = sv;
    mgs->mgs_flags = SvMAGICAL(sv) | SvREADONLY(sv);
    mgs->mgs_ss_ix = PL_savestack_ix;   /* points after the saved destructor */

    SvMAGICAL_off(sv);
    SvREADONLY_off(sv);
    if (!(SvFLAGS(sv) & (SVf_IOK|SVf_NOK|SVf_POK))) {
	/* No public flags are set, so promote any private flags to public.  */
	SvFLAGS(sv) |= (SvFLAGS(sv) & (SVp_IOK|SVp_NOK|SVp_POK)) >> PRIVSHIFT;
    }
}

/*
=for apidoc mg_magical

Turns on the magical status of an SV.  See C<sv_magic>.

=cut
*/

void
Perl_mg_magical(pTHX_ SV *sv)
{
    const MAGIC* mg;
    PERL_ARGS_ASSERT_MG_MAGICAL;
    PERL_UNUSED_CONTEXT;
    if ((mg = SvMAGIC(sv))) {
	SvRMAGICAL_off(sv);
	do {
	    const MGVTBL* const vtbl = mg->mg_virtual;
	    if (vtbl) {
		if (vtbl->svt_set)
		    SvSMAGICAL_on(sv);
		if (vtbl->svt_clear)
		    SvRMAGICAL_on(sv);
	    }
	} while ((mg = mg->mg_moremagic));
	if (!(SvFLAGS(sv) & SVs_SMG))
	    SvRMAGICAL_on(sv);
    }
}


/* is this container magic (%ENV, $1 etc), or value magic (pos, taint etc)? */

STATIC bool
S_is_container_magic(const MAGIC *mg)
{
    assert(mg);
    switch (mg->mg_type) {
    case PERL_MAGIC_bm:
    case PERL_MAGIC_regex_global:
    case PERL_MAGIC_qr:
    case PERL_MAGIC_vstring:
    case PERL_MAGIC_utf8:
    case PERL_MAGIC_backref:
    case PERL_MAGIC_rhash:
    case PERL_MAGIC_symtab:
	return 0;
    default:
	return 1;
    }
}

/*
=for apidoc mg_set

Do magic after a value is assigned to the SV.  See C<sv_magic>.

=cut
*/

int
Perl_mg_set(pTHX_ SV *sv)
{
    dVAR;
    const I32 mgs_ix = SSNEW(sizeof(MGS));
    MAGIC* mg;
    MAGIC* nextmg;

    PERL_ARGS_ASSERT_MG_SET;

    save_magic(mgs_ix, sv);

    for (mg = SvMAGIC(sv); mg; mg = nextmg) {
        const MGVTBL* vtbl = mg->mg_virtual;
	nextmg = mg->mg_moremagic;	/* it may delete itself */
	if (mg->mg_flags & MGf_GSKIP) {
	    mg->mg_flags &= ~MGf_GSKIP;	/* setting requires another read */
	    (SSPTR(mgs_ix, MGS*))->mgs_flags = 0;
	}
	if (PL_localizing == 2 && !S_is_container_magic(mg))
	    continue;
	if (vtbl && vtbl->svt_set)
	    CALL_FPTR(vtbl->svt_set)(aTHX_ sv, mg);
    }

    restore_magic(INT2PTR(void*, (IV)mgs_ix));
    return 0;
}

/*
=for apidoc mg_clear

Clear something magical that the SV represents.  See C<sv_magic>.

=cut
*/

int
Perl_mg_clear(pTHX_ SV *sv)
{
    const I32 mgs_ix = SSNEW(sizeof(MGS));
    MAGIC* mg;

    PERL_ARGS_ASSERT_MG_CLEAR;

    save_magic(mgs_ix, sv);

    for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
        const MGVTBL* const vtbl = mg->mg_virtual;
	/* omit GSKIP -- never set here */

	if (vtbl && vtbl->svt_clear)
	    CALL_FPTR(vtbl->svt_clear)(aTHX_ sv, mg);
    }

    restore_magic(INT2PTR(void*, (IV)mgs_ix));
    return 0;
}

/*
=for apidoc mg_find

Finds the magic pointer for type matching the SV.  See C<sv_magic>.

=cut
*/

MAGIC*
Perl_mg_find(pTHX_ const SV *sv, int type)
{
    PERL_UNUSED_CONTEXT;
    if (sv) {
        MAGIC *mg;
        for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
            if (mg->mg_type == type)
                return mg;
        }
    }
    return NULL;
}

/*
=for apidoc mg_copy

Copies the magic from one SV to another.  See C<sv_magic>.

=cut
*/

int
Perl_mg_copy(pTHX_ SV *sv, SV *nsv, const char *key, I32 klen)
{
    int count = 0;
    MAGIC* mg;

    PERL_ARGS_ASSERT_MG_COPY;

    for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
        const MGVTBL* const vtbl = mg->mg_virtual;
	if ((mg->mg_flags & MGf_COPY) && vtbl->svt_copy){
	    count += CALL_FPTR(vtbl->svt_copy)(aTHX_ sv, mg, nsv, key, klen);
	}
	else {
	    const char type = mg->mg_type;
	    if (isUPPER(type) && type != PERL_MAGIC_uvar) {
		sv_magic(nsv,
		     mg->mg_obj,
		     toLOWER(type), key, klen);
		count++;
	    }
	}
    }
    return count;
}

/*
=for apidoc mg_localize

Copy some of the magic from an existing SV to new localized version of
that SV. Container magic (eg %ENV, $1, tie) gets copied, value magic
doesn't (eg taint, pos).

=cut
*/

void
Perl_mg_localize(pTHX_ SV *sv, SV *nsv)
{
    dVAR;
    MAGIC *mg;

    PERL_ARGS_ASSERT_MG_LOCALIZE;

    for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
	const MGVTBL* const vtbl = mg->mg_virtual;
	if (!S_is_container_magic(mg))
	    continue;
		
	if ((mg->mg_flags & MGf_LOCAL) && vtbl->svt_local)
	    (void)CALL_FPTR(vtbl->svt_local)(aTHX_ nsv, mg);
	else
	    sv_magicext(nsv, mg->mg_obj, mg->mg_type, vtbl,
			    mg->mg_ptr, mg->mg_len);

	/* container types should remain read-only across localization */
	SvFLAGS(nsv) |= SvREADONLY(sv);
    }

    if (SvTYPE(nsv) >= SVt_PVMG && SvMAGIC(nsv)) {
	SvFLAGS(nsv) |= SvMAGICAL(sv);
	PL_localizing = 1;
	SvSETMAGIC(nsv);
	PL_localizing = 0;
    }	    
}

/*
=for apidoc mg_free

Free any magic storage used by the SV.  See C<sv_magic>.

=cut
*/

int
Perl_mg_free(pTHX_ SV *sv)
{
    MAGIC* mg;
    MAGIC* moremagic;

    PERL_ARGS_ASSERT_MG_FREE;

    for (mg = SvMAGIC(sv); mg; mg = moremagic) {
        const MGVTBL* const vtbl = mg->mg_virtual;
	moremagic = mg->mg_moremagic;
	if (vtbl && vtbl->svt_free)
	    CALL_FPTR(vtbl->svt_free)(aTHX_ sv, mg);
	if (mg->mg_ptr && mg->mg_type != PERL_MAGIC_regex_global) {
	    if (mg->mg_len > 0 || mg->mg_type == PERL_MAGIC_utf8)
		Safefree(mg->mg_ptr);
	    else if (mg->mg_len == HEf_SVKEY)
		SvREFCNT_dec((SV*)mg->mg_ptr);
	}
	if (mg->mg_flags & MGf_REFCOUNTED)
	    SvREFCNT_dec(mg->mg_obj);
	Safefree(mg);
	SvMAGIC_set(sv, moremagic);
    }
    SvMAGIC_set(sv, NULL);
    return 0;
}

void
Perl_mg_tmprefcnt(pTHX_ SV *sv)
{
    MAGIC* mg;
    MAGIC* moremagic;

    PERL_ARGS_ASSERT_MG_TMPREFCNT;

    for (mg = SvMAGIC(sv); mg; mg = moremagic) {
	moremagic = mg->mg_moremagic;
	if (mg->mg_ptr && mg->mg_type != PERL_MAGIC_regex_global) {
	    if (mg->mg_len == HEf_SVKEY)
		SvTMPREFCNT_inc((SV*)mg->mg_ptr);
	}
	if (mg->mg_flags & MGf_REFCOUNTED)
	    SvTMPREFCNT_inc(mg->mg_obj);
    }
}

#include <signal.h>

U32
Perl_magic_regdata_cnt(pTHX_ SV *sv, MAGIC *mg)
{
    dVAR;
    PERL_UNUSED_ARG(sv);

    PERL_ARGS_ASSERT_MAGIC_REGDATA_CNT;

    if (PL_curpm) {
	register const REGEXP * const rx = PM_GETRE(PL_curpm);
	if (rx) {
	    if (mg->mg_obj) {			/* @+ */
		/* return the number possible */
		return RX_NPARENS(rx);
	    } else {				/* @- */
		I32 paren = RX_LASTPAREN(rx);

		/* return the last filled */
		while ( paren >= 0
			&& (RX_OFFS(rx)[paren].start == -1
			    || RX_OFFS(rx)[paren].end == -1) )
		    paren--;
		return (U32)paren;
	    }
	}
    }

    return (U32)-1;
}

int
Perl_magic_regdatum_get(pTHX_ SV *sv, MAGIC *mg)
{
    dVAR;

    PERL_ARGS_ASSERT_MAGIC_REGDATUM_GET;

    if (PL_curpm) {
	register const REGEXP * const rx = PM_GETRE(PL_curpm);
	if (rx) {
	    register const I32 paren = mg->mg_len;
	    register I32 s;
	    register I32 t;
	    if (paren < 0)
		return 0;
	    if (paren <= (I32)RX_NPARENS(rx) &&
		(s = RX_OFFS(rx)[paren].start) != -1 &&
		(t = RX_OFFS(rx)[paren].end) != -1)
		{
		    register I32 i;
		    if (mg->mg_obj)		/* @+ */
			i = t;
		    else			/* @- */
			i = s;

		    if (i > 0 && IN_CODEPOINTS) {
			const char * const b = RX_SUBBEG(rx);
			if (b)
			    i = utf8_length(b, (b+i));
		    }

		    sv_setiv(sv, i);
		}
	}
    }
    return 0;
}

int
Perl_magic_regdatum_set(pTHX_ SV *sv, MAGIC *mg)
{
    PERL_ARGS_ASSERT_MAGIC_REGDATUM_SET;
    PERL_UNUSED_ARG(sv);
    PERL_UNUSED_ARG(mg);
    Perl_croak(aTHX_ PL_no_modify);
    NORETURN_FUNCTION_END;
}

#define SvRTRIM(sv) STMT_START { \
    if (SvPOK(sv)) { \
        STRLEN len = SvCUR(sv); \
        char * const p = SvPVX_mutable(sv); \
	while (len > 0 && isSPACE(p[len-1])) \
	   --len; \
	SvCUR_set(sv, len); \
	p[len] = '\0'; \
    } \
} STMT_END

void
Perl_emulate_cop_io(pTHX_ const COP *const c, SV *const sv)
{
    PERL_ARGS_ASSERT_EMULATE_COP_IO;

    if (!(CopHINTS_get(c) & (HINT_LEXICAL_IO_IN|HINT_LEXICAL_IO_OUT)))
	sv_setsv(sv, &PL_sv_undef);
    else {
	sv_setpvs(sv, "");
	if ((CopHINTS_get(c) & HINT_LEXICAL_IO_IN)) {
	    SV **const value = hv_fetch(c->cop_hints_hash, "open<", 5, 0);
	    assert(*value);
	    sv_catsv(sv, *value);
	}
	sv_catpvs(sv, "\0");
	if ((CopHINTS_get(c) & HINT_LEXICAL_IO_OUT)) {
	    SV **const value = hv_fetch(c->cop_hints_hash, "open>", 5, 0);
	    assert(*value);
	    sv_catsv(sv, *value);
	}
    }
}

void
Perl_magic_get(pTHX_ const char* name, SV* sv)
{
    dVAR;
    register I32 paren;
    register REGEXP *rx;
    const char * const remaining = name + 1;

    PERL_ARGS_ASSERT_MAGIC_GET;

    {
	SV** oldsv = hv_fetch(PL_magicsvhv, name, strlen(name), 0);
	if (oldsv)
	    sv_setsv(sv, *oldsv);
    }

    switch (*name) {
    case '^':
	switch (*remaining) {
	case 'B':
	    if (strEQ(remaining, "BASETIME")) {
#ifdef BIG_TIME
		sv_setnv(sv, PL_basetime);
#else
		sv_setiv(sv, (IV)PL_basetime);
#endif
		break;
	    }
	    break;

	case 'C':
	    if (strEQ(remaining, "CHILD_ERROR")) { /* $^CHILD_ERROR */
		sv_setiv(sv, (IV)STATUS_CURRENT);
#ifdef COMPLEX_STATUS
		LvTARGOFF(sv) = PL_statusvalue;
		LvTARGLEN(sv) = PL_statusvalue_vms;
#endif
		break;
	    }
	    if (strEQ(remaining, "CHILD_ERROR_NATIVE")) { /* $^CHILD_ERROR_NATIVE */
		sv_setiv(sv, (IV)STATUS_NATIVE);
		break;
	    }
	    if (strEQ(remaining, "COMPILING")) {
		sv_setiv(sv, (IV)PL_minus_c);
		break;
	    }
	    break;
	case 'D':
	    if (strEQ(remaining, "DIE_HOOK")) { /* $^DIE_HOOK */
		sv_setsv(sv, PL_diehook);
		break;
	    }
	    if (strEQ(remaining, "DEBUGGING")) {
		sv_setiv(sv, (IV)(PL_debug & DEBUG_MASK));
		break;
	    }
	    break;
	case 'E':
	    if (strEQ(remaining, "EGID")) { /* $^EGID */
		sv_setiv(sv, (IV)PL_egid);
	      add_groups:
#ifdef HAS_GETGROUPS
		{
		    Groups_t *gary = NULL;
		    I32 i, num_groups = getgroups(0, gary);
		    Newx(gary, num_groups, Groups_t);
		    num_groups = getgroups(num_groups, gary);
		    for (i = 0; i < num_groups; i++)
			Perl_sv_catpvf(aTHX_ sv, " %"IVdf, (IV)gary[i]);
		    Safefree(gary);
		}
		(void)SvIOK_on(sv);	/* what a wonderful hack! */
#endif
		break;
	    }

	    if (strEQ(remaining, "EUID")) {
		/* $^EUID */
		sv_setiv(sv, (IV)PL_euid);
		break;
	    }

	    if (strEQ(remaining, "EVAL_ERROR")) {
		/* $^EVAL_ERROR */
		sv_setsv(sv, PL_errsv);
		return;
	    }

	    if (strEQ(remaining, "EXCEPTIONS_BEING_CAUGHT")) {
		if (PL_parser && PL_parser->lex_state != LEX_NOTPARSING)
		    SvOK_off(sv);
		else if (PL_in_eval)
		    sv_setiv(sv, PL_in_eval & ~(EVAL_INREQUIRE));
		else
		    sv_setiv(sv, 0);
		break;
	    }

	    if (strEQ(remaining, "EXTENDED_OS_ERROR")) {
#if defined(MACOS_TRADITIONAL)
		{
		    char msg[256];

		    sv_setnv(sv,(double)gMacPerl_OSErr);
		    sv_setpv(sv, gMacPerl_OSErr ? GetSysErrText(gMacPerl_OSErr, msg) : "");
		}
#elif defined(VMS)
		{
#	            include <descrip.h>
#	            include <starlet.h>
		    char msg[255];
		    $DESCRIPTOR(msgdsc,msg);
		    sv_setnv(sv,(NV) vaxc$errno);
		    if (sys$getmsg(vaxc$errno,&msgdsc.dsc$w_length,&msgdsc,0,0) & 1)
			sv_setpvn(sv,msgdsc.dsc$a_pointer,msgdsc.dsc$w_length);
		    else
			sv_setpvn(sv,"",0);
		}
#elif defined(OS2)
		if (!(_emx_env & 0x200)) {	/* Under DOS */
		    sv_setnv(sv, (NV)errno);
		    sv_setpv(sv, errno ? Strerror(errno) : "");
		} else {
		    if (errno != errno_isOS2) {
			const int tmp = _syserrno();
			if (tmp)	/* 2nd call to _syserrno() makes it 0 */
			    Perl_rc = tmp;
		    }
		    sv_setnv(sv, (NV)Perl_rc);
		    sv_setpv(sv, os2error(Perl_rc));
		}
#elif defined(WIN32)
		{
		    const DWORD dwErr = GetLastError();
		    sv_setnv(sv, (NV)dwErr);
		    if (dwErr) {
			PerlProc_GetOSError(sv, dwErr);
		    }
		    else
			sv_setpvn(sv, "", 0);
		    SetLastError(dwErr);
		}
#else
		{
		    const int saveerrno = errno;
		    sv_setnv(sv, (NV)errno);
		    sv_setpv(sv, errno ? Strerror(errno) : "");
		    errno = saveerrno;
		}
#endif
		SvRTRIM(sv);
		SvNOK_on(sv);	/* what a wonderful hack! */
		break;
	    }
	    break;

	case 'G':
	    if (strEQ(remaining, "GID")) { /* $^GID */
		sv_setiv(sv, (IV)PL_gid);
		goto add_groups;
	    }
	    break;

	case 'H':
	    if (strEQ(remaining, "HINT_BITS")) {
		sv_setiv(sv, (IV)PL_hints);
		break;
	    }

	    if (strEQ(remaining, "HINTS")) {
		sv_setsv(sv, hvTsv(PL_hinthv));
		return;
	    }
	    break;

	case 'I':
	    if (strEQ(remaining, "INCLUDE_PATH")) {
		sv_setsv(sv, avTsv(PL_includepathav));
		break;
	    }
	    if (strEQ(remaining, "INCLUDED")) {
		sv_setsv(sv, hvTsv(PL_includedhv));
		break;
	    }
	    if (strEQ(remaining, "INPUT_RECORD_SEPARATOR")) {
		break;
	    }
	    break;

	case 'L':
	    if (strEQ(remaining, "LAST_SUBMATCH_RESULT")) {
		if (PL_curpm && (rx = PM_GETRE(PL_curpm))) {
		    if (RX_LASTCLOSEPAREN(rx)) {
			CALLREG_NUMBUF_FETCH(rx,RX_LASTCLOSEPAREN(rx),sv);
			break;
		    }
		}
		sv_setsv(sv,&PL_sv_undef);
		break;
	    }
	    break;

	case 'M': /* $^MATCH */
	    if (strEQ(remaining, "MATCH")) {
		if (PL_curpm && (rx = PM_GETRE(PL_curpm))) {
		    /*
		     * Pre-threads, this was paren = atoi(GvENAME((GV*)mg->mg_obj));
		     * XXX Does the new way break anything?
		     */
		    paren = atoi(name); /* $& is in [0] */
		    CALLREG_NUMBUF_FETCH(rx,paren,sv);
		    break;
		}
		sv_setsv(sv,&PL_sv_undef);
	    }
	    break;

	case 'O':
	    if (strEQ(remaining, "OPEN")) {
		/* $^OPEN */
		Perl_emulate_cop_io(aTHX_ &PL_compiling, sv);
		break;
	    }

	    if (strEQ(remaining, "OS_ERROR")) {
		/* $^OS_ERROR */
#ifdef VMS
		sv_setnv(sv, (NV)((errno == EVMSERR) ? vaxc$errno : errno));
		sv_setpv(sv, errno ? Strerror(errno) : "");
#else
		{
		    const int saveerrno = errno;
		    sv_setnv(sv, (NV)errno);
#ifdef OS2
		    if (errno == errno_isOS2 || errno == errno_isOS2_set)
			sv_setpv(sv, os2error(Perl_rc));
		    else
#endif
			sv_setpv(sv, errno ? Strerror(errno) : "");
		    errno = saveerrno;
		}
#endif
		SvRTRIM(sv);
		SvNOK_on(sv);	/* what a wonderful hack! */
		break;
	    }

	    if (strEQ(remaining, "OS_NAME")) {
		sv_setpv(sv, PL_osname);
		break;
	    }

	    if (strEQ(remaining, "OUTPUT_AUTOFLUSH")) {
		/* $^OUTPUT_AUTOFLUSH */
		if (SvOK(PL_stdoutio))
		    sv_setiv(sv, (IV)(IoFLAGS(PL_stdoutio) & IOf_FLUSH) != 0 );
		break;
	    }

	    if (strEQ(remaining, "OUTPUT_FIELD_SEPARATOR")) {
		/* $^OUTPUT_FIELD_SEPARATOR */
		break;
	    }

	    if (strEQ(remaining, "OUTPUT_RECORD_SEPARATOR")) {
		/* $^OUTPUT_RECORD_SEPARATOR */
		if (PL_ors_sv)
		    sv_copypv(sv, PL_ors_sv);
		break;
	    }
	    break;

	case 'P':
	    if (strEQ(remaining, "PERLDB")) {
		sv_setiv(sv, (IV)PL_perldb);
		break;
	    }
	    if (strEQ(remaining, "PERL_VERSION")) {
		sv_setsv(sv, PL_patchlevel);
		break;
	    }
	    if (strEQ(remaining, "PREMATCH")) { /* $^PREMATCH */
		if (PL_curpm && (rx = PM_GETRE(PL_curpm))) {
		    CALLREG_NUMBUF_FETCH(rx,-2,sv);
		    break;
		}
		sv_setsv(sv,&PL_sv_undef);
		break;
	    } else if (strEQ(remaining, "POSTMATCH")) { /* $^POSTMATCH */
		if (PL_curpm && (rx = PM_GETRE(PL_curpm))) {
		    CALLREG_NUMBUF_FETCH(rx,-1,sv);
		    break;
		}
		sv_setsv(sv,&PL_sv_undef);
		break;
	    }
	    break;

	case 'S':
	    if (strEQ(remaining, "SYSTEM_FD_MAX")) {
		sv_setiv(sv, (IV)PL_maxsysfd);
		break;
	    }
	    if (strEQ(remaining, "STDIN")) {
		sv_setrv(sv, SvREFCNT_inc(ioTsv(PL_stdinio)));
		break;
	    }
	    if (strEQ(remaining, "STDOUT")) {
		sv_setrv(sv, SvREFCNT_inc(ioTsv(PL_stdoutio)));
		break;
	    }
	    if (strEQ(remaining, "STDERR")) {
		sv_setrv(sv, SvREFCNT_inc(ioTsv(PL_stderrio)));
		break;
	    }
	    break;

	case 'U':
	    if (strEQ(remaining, "UID")) {
		/* $^UID */
		sv_setiv(sv, (IV)PL_uid);
		break;
	    }
	    if (strEQ(remaining, "UNICODE")) {
		/* $^UNICODE */
		sv_setuv(sv, (UV) PL_unicode);
		break;
	    }
	    if (strEQ(remaining, "UTF8LOCALE")) {
		/* $^UTF8LOCALE */
		sv_setuv(sv, (UV) PL_utf8locale);
		break;
	    }
	    if (strEQ(remaining, "UTF8CACHE")) {
		/* $^UTF8CACHE */
		sv_setiv(sv, (IV) PL_utf8cache);
		break;
	    }
	    break;
	case 'W':
	    if (strEQ(remaining, "WARNING")) {
		sv_setiv(sv, (IV)((PL_dowarn & G_WARN_ON) ? TRUE : FALSE));
		break;
	    }

	    if (strEQ(remaining, "WARNING_BITS")) { /* $^WARNING_BITS */
		if (PL_compiling.cop_warnings == pWARN_NONE) {
		    sv_setpvn(sv, WARN_NONEstring, WARNsize) ;
		}
		else if (PL_compiling.cop_warnings == pWARN_STD) {
		    sv_setpvn(
			sv, 
			    (PL_dowarn & G_WARN_ON) ? WARN_ALLstring : WARN_NONEstring,
			    WARNsize
			);
		}
		else if (PL_compiling.cop_warnings == pWARN_ALL) {
		    /* Get the bit mask for $warnings::Bits{all}, because
		     * it could have been extended by warnings::register */
		    HV * const bits=get_hv("warnings::Bits", FALSE);
		    if (bits) {
			SV ** const bits_all = hv_fetchs(bits, "all", FALSE);
			if (bits_all)
			    sv_setsv(sv, *bits_all);
		    }
		    else {
			sv_setpvn(sv, WARN_ALLstring, WARNsize) ;
		    }
		}
		else {
		    sv_setpvn(sv, (char *) (PL_compiling.cop_warnings + 1),
			*PL_compiling.cop_warnings);
		}
		SvPOK_only(sv);
	    } else if (strEQ(remaining, "WARN_HOOK")) { /* $^WARN_HOOK */
		sv_setsv(sv, PL_warnhook);
		break;
	    }
	    break;
	}
	break;

    case '1': case '2': case '3': case '4':
    case '5': case '6': case '7': case '8': case '9':
	if (PL_curpm && (rx = PM_GETRE(PL_curpm))) {
	    /*
	     * Pre-threads, this was paren = atoi(GvENAME((GV*)mg->mg_obj));
	     * XXX Does the new way break anything?
	     */
	    paren = atoi(name); /* $& is in [0] */
	    CALLREG_NUMBUF_FETCH(rx,paren,sv);
	    break;
	}
	sv_setsv(sv,&PL_sv_undef);
	break;
    }
    return;
}

int
Perl_magic_getuvar(pTHX_ SV *sv, MAGIC *mg)
{
    struct ufuncs * const uf = (struct ufuncs *)mg->mg_ptr;

    PERL_ARGS_ASSERT_MAGIC_GETUVAR;

    if (uf && uf->uf_val)
	(*uf->uf_val)(aTHX_ uf->uf_index, sv);
    return 0;
}

/*
 * The signal handling nomenclature has gotten a bit confusing since the advent of
 * safe signals.  S_raise_signal only raises signals by analogy with what the 
 * underlying system's signal mechanism does.  It might be more proper to say that
 * it defers signals that have already been raised and caught.  
 *
 * PL_sig_pending and PL_psig_pend likewise do not track signals that are pending 
 * in the sense of being on the system's signal queue in between raising and delivery.  
 * They are only pending on Perl's deferral list, i.e., they track deferred signals 
 * awaiting delivery after the current Perl opcode completes and say nothing about
 * signals raised but not yet caught in the underlying signal implementation.
 */

#ifndef SIG_PENDING_DIE_COUNT
#  define SIG_PENDING_DIE_COUNT 120
#endif

static void
S_raise_signal(pTHX_ int sig)
{
    dVAR;
    /* Set a flag to say this signal is pending */
    PL_psig_pend[sig]++;
    /* And one to say _a_ signal is pending */
    if (++PL_sig_pending >= SIG_PENDING_DIE_COUNT)
        Perl_croak(aTHX_ "Maximal count of pending signals (%lu) exceeded",
                (unsigned long)SIG_PENDING_DIE_COUNT);
}

Signal_t
#if defined(HAS_SIGACTION) && defined(SA_SIGINFO)
Perl_csighandler(int sig, siginfo_t *sip PERL_UNUSED_DECL, void *uap PERL_UNUSED_DECL)
#else
Perl_csighandler(int sig)
#endif
{
#ifdef PERL_GET_SIG_CONTEXT
    dTHXa(PERL_GET_SIG_CONTEXT);
#else
    dTHX;
#endif
#if defined(HAS_SIGACTION) && defined(SA_SIGINFO)
#endif
#ifdef FAKE_PERSISTENT_SIGNAL_HANDLERS
    (void) rsignal(sig, PL_csighandlerp);
    if (PL_sig_ignoring[sig]) return;
#endif
#ifdef FAKE_DEFAULT_SIGNAL_HANDLERS
    if (PL_sig_defaulting[sig])
#ifdef KILL_BY_SIGPRC
            exit((Perl_sig_to_vmscondition(sig)&STS$M_COND_ID)|STS$K_SEVERE|STS$M_INHIB_MSG);
#else
            exit(1);
#endif
#endif
#if defined(HAS_SIGACTION) && defined(SA_SIGINFO)
#endif
   if (
#ifdef SIGILL
           sig == SIGILL ||
#endif
#ifdef SIGBUS
           sig == SIGBUS ||
#endif
#ifdef SIGSEGV
           sig == SIGSEGV ||
#endif
           (PL_signals & PERL_SIGNALS_UNSAFE_FLAG))
        /* Call the perl level handler now--
         * with risk we may be in malloc() etc. */
#if defined(HAS_SIGACTION) && defined(SA_SIGINFO)
        (*PL_sighandlerp)(sig, NULL, NULL);
#else
        (*PL_sighandlerp)(sig);
#endif
   else
        S_raise_signal(aTHX_ sig);
}

#if defined(FAKE_PERSISTENT_SIGNAL_HANDLERS) || defined(FAKE_DEFAULT_SIGNAL_HANDLERS)
void
Perl_csighandler_init(void)
{
    int sig;
    if (PL_sig_handlers_initted) return;

    for (sig = 1; sig < SIG_SIZE; sig++) {
#ifdef FAKE_DEFAULT_SIGNAL_HANDLERS
        dTHX;
        PL_sig_defaulting[sig] = 1;
        (void) rsignal(sig, PL_csighandlerp);
#endif
#ifdef FAKE_PERSISTENT_SIGNAL_HANDLERS
        PL_sig_ignoring[sig] = 0;
#endif
    }
    PL_sig_handlers_initted = 1;
}
#endif

void
Perl_despatch_signals(pTHX)
{
    dVAR;
    int sig;
    PL_sig_pending = 0;
    for (sig = 1; sig < SIG_SIZE; sig++) {
        if (PL_psig_pend[sig]) {
            PERL_BLOCKSIG_ADD(set, sig);
            PL_psig_pend[sig] = 0;
            PERL_BLOCKSIG_BLOCK(set);
#if defined(HAS_SIGACTION) && defined(SA_SIGINFO)
            (*PL_sighandlerp)(sig, NULL, NULL);
#else
            (*PL_sighandlerp)(sig);
#endif
            PERL_BLOCKSIG_UNBLOCK(set);
        }
    }
}

int
Perl_magic_setisa(pTHX_ SV *sv, MAGIC *mg)
{
    dVAR;
    HV* stash;

    PERL_ARGS_ASSERT_MAGIC_SETISA;
    PERL_UNUSED_ARG(sv);

    /* Bail out if destruction is going on */
    if(PL_dirty) return 0;

    /* Skip _isaelem because _isa will handle it shortly */
    if (PL_delaymagic & DM_ARRAY && mg->mg_type == PERL_MAGIC_isaelem)
        return 0;

    /* XXX Once it's possible, we need to
       detect that our @ISA is aliased in
       other stashes, and act on the stashes
       of all of the aliases */

    /* The first case occurs via setisa,
       the second via setisa_elem, which
       calls this same magic */
    if (SvTYPE(mg->mg_obj) == SVt_PVGV) {
	stash = GvSTASH((GV*)mg->mg_obj);
    }
    else {
	SV* gv = SvRV(mg->mg_obj);
	if ( ! gv )
	    return 0;
	stash = GvSTASH(gv);
    }

    mro_isa_changed_in(stash);

    return 0;
}

int
Perl_magic_clearisa(pTHX_ SV *sv, MAGIC *mg)
{
    dVAR;
    HV* stash;

    PERL_ARGS_ASSERT_MAGIC_CLEARISA;

    /* Bail out if destruction is going on */
    if(PL_dirty) return 0;

    av_clear((AV*)sv);

    /* XXX see comments in magic_setisa */
    stash = GvSTASH(
        SvTYPE(mg->mg_obj) == SVt_PVGV
            ? (GV*)mg->mg_obj
            : (GV*)SvMAGIC(mg->mg_obj)->mg_obj
    );

    mro_isa_changed_in(stash);

    return 0;
}

int
Perl_magic_setdbline(pTHX_ SV *sv, MAGIC *mg)
{
    dVAR;
    GV * const gv = PL_DBline;
    const I32 i = SvTRUE(sv);
    SV ** const svp = av_fetch(GvAV(gv),
                     atoi(MgPV_nolen_const(mg)), FALSE);

    PERL_ARGS_ASSERT_MAGIC_SETDBLINE;

    if (svp && SvIOKp(*svp)) {
        OP * const o = INT2PTR(OP*,SvIVX(*svp));
        if (o) {
            /* set or clear breakpoint in the relevant control op */
            if (i)
                o->op_flags |= OPf_SPECIAL;
            else
                o->op_flags &= ~OPf_SPECIAL;
        }
    }
    return 0;
}

int
Perl_magic_killbackrefs(pTHX_ SV *sv, MAGIC *mg)
{
    PERL_ARGS_ASSERT_MAGIC_KILLBACKREFS;
    return Perl_sv_kill_backrefs(aTHX_ sv, (AV*)mg->mg_obj);
}

int
Perl_magic_setmglob(pTHX_ SV *sv, MAGIC *mg)
{
    PERL_ARGS_ASSERT_MAGIC_SETMGLOB;
    PERL_UNUSED_CONTEXT;
    mg->mg_len = -1;
    SvSCREAM_off(sv);
    return 0;
}

int
Perl_magic_setuvar(pTHX_ SV *sv, MAGIC *mg)
{
    const struct ufuncs * const uf = (struct ufuncs *)mg->mg_ptr;

    PERL_ARGS_ASSERT_MAGIC_SETUVAR;

    if (uf && uf->uf_set)
        (*uf->uf_set)(aTHX_ uf->uf_index, sv);
    return 0;
}

int
Perl_magic_setregexp(pTHX_ SV *sv, MAGIC *mg)
{
    const char type = mg->mg_type;

    PERL_ARGS_ASSERT_MAGIC_SETREGEXP;

    if (type == PERL_MAGIC_qr) {
    } else {
	assert(type == PERL_MAGIC_bm);
	SvTAIL_off(sv);
	SvVALID_off(sv);
    }
    return sv_unmagic(sv, type);
}

/* Just clear the UTF-8 cache data. */
int
Perl_magic_setutf8(pTHX_ SV *sv, MAGIC *mg)
{
    PERL_ARGS_ASSERT_MAGIC_SETUTF8;
    PERL_UNUSED_CONTEXT;
    PERL_UNUSED_ARG(sv);
    Safefree(mg->mg_ptr);       /* The mg_ptr holds the pos cache. */
    mg->mg_ptr = NULL;
    mg->mg_len = -1;            /* The mg_len holds the len cache. */
    return 0;
}

bool
Perl_is_magicsv(pTHX_ const char* name)
{
    PERL_ARGS_ASSERT_IS_MAGICSV;
    switch(name[0]) {
    case '^': {
	const char* name2 = name + 1;
	switch (*name2) {
	case 'B':
	    if (strEQ(name2, "BASETIME"))
		return 1;
	    break;

	case 'C':
	    if (strEQ(name2, "CHILD_ERROR")) {
		return 1;
	    }
	    if (strEQ(name2, "CHILD_ERROR_NATIVE")) {
		return 1;
	    }
	    if (strEQ(name2, "COMPILING"))
		return 1;
	    break;
	case 'D':        /* $^DIE_HOOK */
	    if (strEQ(name2, "DEBUGGING"))
		return 1;
	    if (strEQ(name2, "DIE_HOOK"))
		return 1;
	    break;
	case 'E':	/* $^ENCODING  $^EGID  $^EUID  $^OS_ERROR  $^EVAL_ERROR */
	    if (strEQ(name2, "ENCODING"))
		return 1;
	    if (strEQ(name2, "EGID"))
		return 1;
	    if (strEQ(name2, "EMERGENCY_MEMORY"))
		return 1;
	    if (strEQ(name2, "EUID"))
		return 1;
	    if (strEQ(name2, "EVAL_ERROR"))
		return 1;
	    if (strEQ(name2, "EXECUTABLE_NAME"))
		return 1;
	    if (strEQ(name2, "EXCEPTIONS_BEING_CAUGHT"))
		return 1;
	    if (strEQ(name2, "EXTENDED_OS_ERROR"))
		return 1;
	    break;

	case 'G':   /* $^GID */
	    if (strEQ(name2, "GID"))
		return 1;
	    break;

	case 'H':
	    if (strEQ(name2, "HINTS")) {
		return 1;
	    }
	    if (strEQ(name2, "HINT_BITS"))
		return 1;
	    break;

	case 'I':
	    if (strEQ(name2, "INCLUDE_PATH"))
		return 1;
	    if (strEQ(name2, "INCLUDED"))
		return 1;
	    /* $^INPUT_RECORD_SEPARATOR */
	    if (strEQ(name2, "INPUT_RECORD_SEPARATOR"))
		return 1;
	    break;

	case 'L':
	    if (strEQ(name2, "LAST_SUBMATCH_RESULT"))
		return 1;
	    break;

	case 'M':        /* $^MATCH */
	    if (strEQ(name2, "MATCH"))
		return 1;
	    break;

	case 'O':	/* $^OPEN */
	    if (strEQ(name2, "OPEN"))
		return 1;
	    if (strEQ(name2, "OS_ERROR"))
		return 1;
	    if (strEQ(name2, "OS_NAME"))
		return 1;
	    if (strEQ(name2, "OUTPUT_AUTOFLUSH")) {
		return 1;
	    }
	    /* $^OUTPUT_RECORD_SEPARATOR */
	    if (strEQ(name2, "OUTPUT_RECORD_SEPARATOR"))
		return 1;
	    /* $^OUTPUT_FIELD_SEPARATOR */
	    if (strEQ(name2, "OUTPUT_FIELD_SEPARATOR"))
		return 1;

	    break;
	case 'P':        /* $^PREMATCH  $^POSTMATCH */
	    if (strEQ(name2, "PERLDB"))
		return 1;
	    if (strEQ(name2, "PERL_VERSION")) {
		return 1;
	    }
	    if (strEQ(name2, "PREMATCH") || strEQ(name2, "POSTMATCH"))
		return 1;
	    if (strEQ(name2, "PROGRAM_NAME"))
		return 1;
	    if (strEQ(name2, "PID"))
		return 1;
	    break;
	case 'R':        /* $^RE_TRIE_MAXBUF */
	    if (strEQ(name2, "RE_TRIE_MAXBUF") || strEQ(name2, "RE_DEBUG_FLAGS"))
		return 1;
	    break;
	case 'S':
	    if (strEQ(name2, "SYSTEM_FD_MAX"))
		return 1;
	    if (strEQ(name2, "STDIN"))
		return 1;
	    if (strEQ(name2, "STDOUT"))
		return 1;
	    if (strEQ(name2, "STDERR"))
		return 1;
	    break;
	case 'U':	/* $^UNICODE, $^UTF8LOCALE, $^UTF8CACHE */
	    if (strEQ(name2, "UID"))
		return 1;
	    if (strEQ(name2, "UNICODE"))
		return 1;
	    if (strEQ(name2, "UTF8LOCALE"))
		return 1;
	    if (strEQ(name2, "UTF8CACHE"))
		return 1;
	    break;
	case 'W':	/* $^WARNING_BITS, $^WARN_HOOK */
	    if (strEQ(name2, "WARN_HOOK"))
		return 1;
	    if (strEQ(name2, "WARNING"))
		return 1;
	    if (strEQ(name2, "WARNING_BITS"))
		return 1;
	    break;
	}
	Perl_croak(aTHX_ "Unknown magic variable '$%s'", name);
	case '1':
	case '2':
	case '3':
	case '4':
	case '5':
	case '6':
	case '7':
	case '8':
	case '9': {
	    /* Ensures that we have an all-digit variable, ${"1foo"} fails
	       this test  */
	    /* This snippet is taken from is_gv_magical */
	    const char *namex = name;
	    while (*++namex) {
		if (!isDIGIT(*namex))
		    return 0;
	    }
	    return 1;
	}
    }
    }
    return 0;
}

void
Perl_magic_set(pTHX_ const char* name, SV *sv)
{
    dVAR;
    register const char *s;
    register I32 paren;
    register const REGEXP * rx;
    const char * const remaining = name + 1;
    I32 i;
    STRLEN len;

    PERL_ARGS_ASSERT_MAGIC_SET;

    sv = sv_mortalcopy(sv);

    switch (*name) {
    case '^':
	switch (*remaining) {
	case 'B':
	    if (strEQ(remaining, "BASETIME")) {
#ifdef BIG_TIME
		PL_basetime = (Time_t)(SvNOK(sv) ? SvNVX(sv) : sv_2nv(sv));
#else
		PL_basetime = (Time_t)SvIV(sv);
#endif
		break;
	    }
	    break;

	case 'C':   /* $^CHILD_ERROR */
	    if (strEQ(remaining, "CHILD_ERROR")) {
#ifdef COMPLEX_STATUS
		if (PL_localizing == 2) {
		    PL_statusvalue = LvTARGOFF(sv);
		    PL_statusvalue_vms = LvTARGLEN(sv);
		}
		else
#endif
#ifdef VMSISH_STATUS
		    if (VMSISH_STATUS)
			STATUS_NATIVE_CHILD_SET((U32)SvIV(sv));
		    else
#endif
			STATUS_UNIX_EXIT_SET(SvIV(sv));
		break;
	    }
	    if (strEQ(remaining, "COMPILING")) {
		PL_minus_c = (bool)SvIV(sv);
		break;
	    }
	    break;

	case 'D':   /* $^DIE_HOOK */
	    if (strEQ(remaining, "DIE_HOOK")) {
		SvREFCNT_dec(PL_diehook);
		PL_diehook = newSVsv(sv);
		break;
	    }
	    if (strEQ(remaining, "DEBUGGING")) {
#ifdef DEBUGGING
		s = SvPV_nolen_const(sv);
		PL_debug = get_debug_opts(&s, 0) | DEBUG_TOP_FLAG;
		DEBUG_x(dump_all());
#else
		PL_debug = (SvIV(sv)) | DEBUG_TOP_FLAG;
#endif
		break;
	    }

	    break;

	case 'E':
	    if (strEQ(remaining, "EVAL_ERROR")) {
		/* $^EVAL_ERROR */
		sv_setsv(PL_errsv, sv);
		break;
	    }

	    if (strEQ(remaining, "EXCEPTIONS_BEING_CAUGHT")) {
		goto magicset_readonly;
	    }

	    if (strEQ(remaining, "EXTENDED_OS_ERROR")) {
#ifdef MACOS_TRADITIONAL
		gMacPerl_OSErr = SvIV(sv);
#else
#  ifdef VMS
		set_vaxc_errno(SvIV(sv));
#  else
#    ifdef WIN32
		SetLastError( SvIV(sv) );
#    else
#      ifdef OS2
		os2_setsyserrno(SvIV(sv));
#      else
		/* will anyone ever use this? */
		SETERRNO(SvIV(sv), 4);
#      endif
#    endif
#  endif
#endif
		break;
	    }
	    if (strEQ(remaining, "EGID")) {  /* $^EGID */
#ifdef HAS_SETGROUPS
		const char *p = SvPV_const(sv, len);
		Groups_t *gary = NULL;

		while (isSPACE(*p))
		    ++p;
		PL_egid = Atol(p);
		for (i = 0; i < NGROUPS; ++i) {
		    while (*p && !isSPACE(*p))
			++p;
		    while (isSPACE(*p))
			++p;
		    if (!*p)
			break;
		    if(!gary)
			Newx(gary, i + 1, Groups_t);
		    else
			Renew(gary, i + 1, Groups_t);
		    gary[i] = Atol(p);
		}
		if (i)
		    (void)setgroups(i, gary);
		Safefree(gary);
#else  /* HAS_SETGROUPS */
		PL_egid = SvIV(sv);
#endif /* HAS_SETGROUPS */
		if (PL_delaymagic) {
		    PL_delaymagic |= DM_EGID;
		    break;                              /* don't do magic till later */
		}
#ifdef HAS_SETEGID
		(void)setegid((Gid_t)PL_egid);
#else
#ifdef HAS_SETREGID
		(void)setregid((Gid_t)-1, (Gid_t)PL_egid);
#else
#ifdef HAS_SETRESGID
		(void)setresgid((Gid_t)-1, (Gid_t)PL_egid, (Gid_t)-1);
#else
		if (PL_egid == PL_gid)                  /* special case $) = $( */
		    (void)PerlProc_setgid(PL_egid);
		else {
		    PL_egid = PerlProc_getegid();
		    Perl_croak(aTHX_ "setegid() not implemented");
		}
#endif
#endif
#endif
		PL_egid = PerlProc_getegid();
		break;
	    }

	    if (strEQ(remaining, "EUID")) {
		/* $^EUID */
		PL_euid = SvIV(sv);
		if (PL_delaymagic) {
		    PL_delaymagic |= DM_EUID;
		    break;                              /* don't do magic till later */
		}
#ifdef HAS_SETEUID
		(void)seteuid((Uid_t)PL_euid);
#else
#ifdef HAS_SETREUID
		(void)setreuid((Uid_t)-1, (Uid_t)PL_euid);
#else
#ifdef HAS_SETRESUID
		(void)setresuid((Uid_t)-1, (Uid_t)PL_euid, (Uid_t)-1);
#else
		if (PL_euid == PL_uid)          /* special case $> = $< */
		    PerlProc_setuid(PL_euid);
		else {
		    PL_euid = PerlProc_geteuid();
		    Perl_croak(aTHX_ "seteuid() not implemented");
		}
#endif
#endif
#endif
		PL_euid = PerlProc_geteuid();
		break;
	    }
	    break;

	case 'G':
	    if (strEQ(remaining, "GID")) { /* $^GID */
		PL_gid = SvIV(sv);
		if (PL_delaymagic) {
		    PL_delaymagic |= DM_RGID;
		    break;                              /* don't do magic till later */
		}
#ifdef HAS_SETRGID
		(void)setrgid((Gid_t)PL_gid);
#else
#ifdef HAS_SETREGID
		(void)setregid((Gid_t)PL_gid, (Gid_t)-1);
#else
#ifdef HAS_SETRESGID
		(void)setresgid((Gid_t)PL_gid, (Gid_t)-1, (Gid_t) 1);
#else
		if (PL_gid == PL_egid)                  /* special case $( = $) */
		    (void)PerlProc_setgid(PL_gid);
		else {
		    PL_gid = PerlProc_getgid();
		    Perl_croak(aTHX_ "setrgid() not implemented");
		}
#endif
#endif
#endif
		PL_gid = PerlProc_getgid();
	    }
	    break;

	case 'H':
	    if (strEQ(remaining, "HINT_BITS")) {
		PL_hints = SvIV(sv);
		break;
	    }
	    if (strEQ(remaining, "HINTS")) {
		if ( ! SvHVOK(sv) ) {
		    Perl_croak(aTHX_ "%s must be a hash not an %s", name, Ddesc(sv));
		}
		PL_hints |= HINT_LOCALIZE_HH;
		HVcpSTEAL(PL_compiling.cop_hints_hash, svThv(newSVsv(sv)));
		hv_sethv(PL_hinthv, svThv(sv));
		return;
	    }
	    break;

	case 'I':
	    if (strEQ(remaining, "INCLUDE_PATH")) {
		if ( ! SvOK(sv) ) {
		    av_clear(PL_includepathav);
		    break;
		}
		if ( ! SvAVOK(sv) ) {
		    Perl_croak(aTHX_ "%s must be an ARRAY not a %s", name, Ddesc(sv));
		}
		sv_setsv(avTsv(PL_includepathav), sv);
		break;
	    }
	    
	    if (strEQ(remaining, "INCLUDED")) {
		if ( ! SvOK(sv) ) {
		    hv_clear(PL_includedhv);
		    break;
		}
		if ( ! SvHVOK(sv) ) {
		    Perl_croak(aTHX_ "%s must be a HASH not a %s", name, Ddesc(sv));
		}
		sv_setsv(hvTsv(PL_includedhv), sv);
		break;
	    }

	    if (strEQ(remaining, "INPUT_RECORD_SEPARATOR")) {
		/* $^INPUT_RECORD_SEPARATOR */
		SVcpSTEAL(PL_rs, newSVsv(sv));
		break;
	    }
	    break;

	case 'M':   /* $^MATCH */
	    if (strEQ(remaining, "MATCH")) {
		paren = RX_BUFF_IDX_FULLMATCH;
		goto setparen;
	    }
	    break;
	case 'O':
	    if (strEQ(remaining, "OPEN")) {
		/* $^OPEN */
		STRLEN len;
		const char *const start = SvPV(sv, len);
		const char *out = (const char*)memchr(start, '\0', len);
		SV *tmp;
		HV* old_cop_hints_hash;


		PL_compiling.cop_hints |= HINT_LEXICAL_IO_IN | HINT_LEXICAL_IO_OUT;
		PL_hints
		    |= HINT_LOCALIZE_HH | HINT_LEXICAL_IO_IN | HINT_LEXICAL_IO_OUT;

		/* Opening for input is more common than opening for output, so
		   ensure that hints for input are sooner on linked list.  */

		old_cop_hints_hash = PL_compiling.cop_hints_hash;
		PL_compiling.cop_hints_hash = newHVhv(PL_compiling.cop_hints_hash);
		HvREFCNT_dec(old_cop_hints_hash);

		tmp = out ? newSVpvn_flags(out + 1, start + len - out - 1, 0) : newSVpvs_flags("", 0);
		(void)hv_store_ent(PL_compiling.cop_hints_hash, 
		    newSVpvs_flags("open>", SVs_TEMP), tmp, 0);

		tmp = newSVpvn_flags(start, out ? (STRLEN)(out - start) : len, 0);
		(void)hv_store_ent(PL_compiling.cop_hints_hash,
		    newSVpvs_flags("open<", SVs_TEMP), tmp, 0);
		break;
	    }

	    if (strEQ(remaining, "OS_ERROR")) {
		/* $^OS_ERROR */
#ifdef VMS
#   define PERL_VMS_BANG vaxc$errno
#else
#   define PERL_VMS_BANG 0
#endif
		SETERRNO(SvIOK(sv) ? SvIVX(sv) : SvOK(sv) ? sv_2iv(sv) : 0,
		    (SvIV(sv) == EVMSERR) ? 4 : PERL_VMS_BANG);
		break;
	    }

	    if (strEQ(remaining, "OS_NAME")) {
		Safefree(PL_osname);
		PL_osname = NULL;
		if (SvOK(sv)) {
		    PL_osname = savesvpv(sv);
		}
		break;
	    }

	    if (strEQ(remaining, "OUTPUT_AUTOFLUSH")) {
		/* $^OUTPUT_AUTOFLUSH */
		IO * const io = PL_stdoutio;
		if(!io)
		    break;
		if ((SvIV(sv)) == 0)
		    IoFLAGS(io) &= ~IOf_FLUSH;
		else {
		    if (!(IoFLAGS(io) & IOf_FLUSH)) {
			PerlIO *ofp = IoOFP(io);
			if (ofp)
			    (void)PerlIO_flush(ofp);
			IoFLAGS(io) |= IOf_FLUSH;
		    }
		}
		break;
	    }

	    if (strEQ(remaining, "OUTPUT_FIELD_SEPARATOR")) {
		/* $^OUTPUT_FIELD_SEPARATOR */
		if (PL_ofs_sv)
		    SvREFCNT_dec(PL_ofs_sv);
		if (SvOK(sv)) {
		    PL_ofs_sv = newSVsv(sv);
		}
		else {
		    PL_ofs_sv = NULL;
		}
		break;
	    }

	    if (strEQ(remaining, "OUTPUT_RECORD_SEPARATOR")) {
		/* $^OUTPUT_RECORD_SEPARATOR */
		if (PL_ors_sv)
		    SvREFCNT_dec(PL_ors_sv);
		if (SvOK(sv)) {
		    PL_ors_sv = newSVsv(sv);
		}
		else {
		    PL_ors_sv = NULL;
		}
		break;
	    }
	    break;

	case 'P':
	    if (strEQ(remaining, "PERLDB")) {
		PL_perldb = SvIV(sv);
		if (PL_perldb && !PL_DBsingle)
		    init_debugger();
		break;
	    }

	    if (strEQ(remaining, "PERL_VERSION")) {
		goto magicset_readonly;
	    }

	    if (strEQ(remaining, "PREMATCH")) { /* $^PREMATCH */
		paren = RX_BUFF_IDX_PREMATCH;
		goto setparen;
	    } 

	    if (strEQ(remaining, "PID")) {
		goto magicset_readonly;
	    }

	    if (strEQ(remaining, "POSTMATCH")) { /* $^POSTMATCH */
		paren = RX_BUFF_IDX_POSTMATCH;
		goto setparen;
	    }
#ifndef MACOS_TRADITIONAL
	    if (strEQ(remaining, "PROGRAM_NAME")) {
		LOCK_DOLLARZERO_MUTEX;
#ifdef HAS_SETPROCTITLE
		/* The BSDs don't show the argv[] in ps(1) output, they
		 * show a string from the process struct and provide
		 * the setproctitle() routine to manipulate that. */
		if (PL_origalen != 1) {
		    s = SvPV_const(sv, len);
#   if __FreeBSD_version > 410001
		    /* The leading "-" removes the "perl: " prefix,
		     * but not the "(perl) suffix from the ps(1)
		     * output, because that's what ps(1) shows if the
		     * argv[] is modified. */
		    setproctitle("-%s", s);
#   else        /* old FreeBSDs, NetBSD, OpenBSD, anyBSD */
		    /* This doesn't really work if you assume that
		     * $0 = 'foobar'; will wipe out 'perl' from the $0
		     * because in ps(1) output the result will be like
		     * sprintf("perl: %s (perl)", s)
		     * I guess this is a security feature:
		     * one (a user process) cannot get rid of the original name.
		     * --jhi */
		    setproctitle("%s", s);
#   endif
		}
#elif defined(__hpux) && defined(PSTAT_SETCMD)
		if (PL_origalen != 1) {
		    union pstun un;
		    s = SvPV_const(sv, len);
		    un.pst_command = (char *)s;
		    pstat(PSTAT_SETCMD, un, len, 0, 0);
		}
#else
		if (PL_origalen > 1) {
		    /* PL_origalen is set in perl_parse(). */
		    s = SvPV_force(sv,len);
		    if (len >= (STRLEN)PL_origalen-1) {
			/* Longer than original, will be truncated. We assume that
			 * PL_origalen bytes are available. */
			Copy(s, PL_origargv[0], PL_origalen-1, char);
		    }
		    else {
			/* Shorter than original, will be padded. */
#ifdef PERL_DARWIN
			/* Special case for Mac OS X: see [perl #38868] */
			const int pad = 0;
#else
			/* Is the space counterintuitive?  Yes.
			 * (You were expecting \0?)
			 * Does it work?  Seems to.  (In Linux 2.4.20 at least.)
			 * --jhi */
			const int pad = ' ';
#endif
			Copy(s, PL_origargv[0], len, char);
			PL_origargv[0][len] = 0;
			memset(PL_origargv[0] + len + 1,
			    pad,  PL_origalen - len - 1);
		    }
		    PL_origargv[0][PL_origalen-1] = 0;
		    for (i = 1; i < PL_origargc; i++)
			PL_origargv[i] = 0;
		}
#endif
		UNLOCK_DOLLARZERO_MUTEX;
		break;
	    }
#endif /* MACOS_TRADITIONAL */
	    break;

	case 'S':
	    if (strEQ(remaining, "SYSTEM_FD_MAX")) {
		PL_maxsysfd = SvIV(sv);
		break;
	    }
	    if (strEQ(remaining, "STDIN")) {
		if (!SvOK(sv)) {
		    IOcpSTEAL(PL_stdinio, newIO());
		    break;
		}
		if (!SvRVOK(sv))
		    Perl_croak(aTHX_ "$^%s must be an IO ref not %s",
			remaining, Ddesc(sv));
		if (! SvIOOK(SvRV(sv)))
		    Perl_croak(aTHX_ "$^%s must be an IO ref not a %s ref",
			remaining, Ddesc(SvRV(sv)));
		IOcpREPLACE(PL_stdinio, svTio(SvRV(sv)));
		break;
	    }
	    if (strEQ(remaining, "STDOUT")) {
		if (!SvOK(sv)) {
		    IOcpSTEAL(PL_stdoutio, newIO());
		    break;
		}
		if (!SvRVOK(sv))
		    Perl_croak(aTHX_ "$^%s must be an IO ref not %s",
			remaining, Ddesc(sv));
		if (! SvIOOK(SvRV(sv)))
		    Perl_croak(aTHX_ "$^%s must be an IO ref not a %s ref",
			remaining, Ddesc(SvRV(sv)));
		IOcpREPLACE(PL_stdoutio, svTio(SvRV(sv)));
		break;
	    }
	    if (strEQ(remaining, "STDERR")) {
		if (!SvOK(sv)) {
		    IOcpSTEAL(PL_stderrio, newIO());
		    break;
		}
		if (!SvRVOK(sv))
		    Perl_croak(aTHX_ "$^%s must be an IO ref not %s",
			remaining, Ddesc(sv));
		if (! SvIOOK(SvRV(sv)))
		    Perl_croak(aTHX_ "$^%s must be an IO ref not a %s ref",
			remaining, Ddesc(SvRV(sv)));
		IOcpREPLACE(PL_stderrio, svTio(SvRV(sv)));
		break;
	    }
	    break;

	case 'U':
	    if (strEQ(remaining, "UID")) {
		/* $^UID */
		PL_uid = SvIV(sv);
		if (PL_delaymagic) {
		    PL_delaymagic |= DM_RUID;
		    break;                              /* don't do magic till later */
		}
#ifdef HAS_SETRUID
		(void)setruid((Uid_t)PL_uid);
#else
#ifdef HAS_SETREUID
		(void)setreuid((Uid_t)PL_uid, (Uid_t)-1);
#else
#ifdef HAS_SETRESUID
		(void)setresuid((Uid_t)PL_uid, (Uid_t)-1, (Uid_t)-1);
#else
		if (PL_uid == PL_euid) {                /* special case $< = $> */
#ifdef PERL_DARWIN
		    /* workaround for Darwin's setuid peculiarity, cf [perl #24122] */
		    if (PL_uid != 0 && PerlProc_getuid() == 0)
			(void)PerlProc_setuid(0);
#endif
		    (void)PerlProc_setuid(PL_uid);
		} else {
		    PL_uid = PerlProc_getuid();
		    Perl_croak(aTHX_ "setruid() not implemented");
		}
#endif
#endif
#endif
		PL_uid = PerlProc_getuid();
		break;
	    }

	    if (strEQ(remaining, "UNICODE")) {
		goto magicset_readonly;
	    }
	    if (strEQ(remaining, "UTF8CACHE")) {
		/* $^UTF8CACHE */
		PL_utf8cache = (signed char) sv_2iv(sv);
		break;
	    }
	    if (strEQ(remaining, "UTF8LOCALE")) {
		goto magicset_readonly;
	    }
	    break;
	case 'W':
	    if (strEQ(remaining, "WARNING_BITS")) { /* $^WARNING_BITS */
		if ( ! (PL_dowarn & G_WARN_ALL_MASK)) {
		    if (!SvPOK(sv) && PL_localizing) {
			sv_setpvn(sv, WARN_NONEstring, WARNsize);
			PL_compiling.cop_warnings = pWARN_NONE;
			break;
		    }
		    {
			STRLEN len, i;
			int accumulate = 0 ;
			int any_fatals = 0 ;
			const char * const ptr = SvPV_const(sv, len) ;
			for (i = 0 ; i < len ; ++i) {
			    accumulate |= ptr[i] ;
			    any_fatals |= (ptr[i] & 0xAA) ;
			}
			if (!accumulate) {
			    if (!specialWARN(PL_compiling.cop_warnings))
				PerlMemShared_free(PL_compiling.cop_warnings);
			    PL_compiling.cop_warnings = pWARN_NONE;
			}
			/* Yuck. I can't see how to abstract this:  */
			else if (isWARN_on(((STRLEN *)SvPV_nolen_const(sv)) - 1,
				WARN_ALL) && !any_fatals) {
			    if (!specialWARN(PL_compiling.cop_warnings))
				PerlMemShared_free(PL_compiling.cop_warnings);
			    PL_compiling.cop_warnings = pWARN_ALL;
			    PL_dowarn |= G_WARN_ONCE ;
			}
			else {
			    STRLEN len;
			    const char *const p = SvPV_const(sv, len);
				
			    PL_compiling.cop_warnings
				= Perl_new_warnings_bitfield(aTHX_ PL_compiling.cop_warnings,
				    p, len);

			    if (isWARN_on(PL_compiling.cop_warnings, WARN_ONCE))
				PL_dowarn |= G_WARN_ONCE ;
			}
			    
		    }
		}
		break;
	    }
	    if (strEQ(remaining, "WARN_HOOK")) { /* $^WARN_HOOK */
		SvREFCNT_dec(PL_warnhook);
		PL_warnhook = newSVsv(sv);
		break;
	    }
	    if (strEQ(remaining, "WARNING")) {
		if ( ! (PL_dowarn & G_WARN_ALL_MASK)) {
		    i = SvIV(sv);
		    PL_dowarn = (PL_dowarn & ~G_WARN_ON)
			| (i ? G_WARN_ON : G_WARN_OFF) ;
		}
		break;
	    }
	    break;
	}
	break;

    case '1': case '2': case '3': case '4':
    case '5': case '6': case '7': case '8': case '9':
      paren = atoi(name);
      setparen:
        if (PL_curpm && (rx = PM_GETRE(PL_curpm))) {
            CALLREG_NUMBUF_STORE((REGEXP * const)rx,paren,sv);
            break;
        } else {
            /* Croak with a READONLY error when a numbered match var is
             * set without a previous pattern match. Unless it's C<local $1>
             */
            if (!PL_localizing) {
                Perl_croak(aTHX_ PL_no_modify);
            }
        }
	break;

    magicset_readonly:
	Perl_croak(aTHX_ "Modification of the read-only magic variable $%s attempted",
	    name);
    }
    {
	SV** storesv = hv_fetch(PL_magicsvhv, name, strlen(name), 1);
	sv_setsv(*storesv, sv);
    }
    return;
}

I32
Perl_whichsig(pTHX_ const char *sig)
{
    register char* const* sigv;

    PERL_ARGS_ASSERT_WHICHSIG;
    PERL_UNUSED_CONTEXT;

    for (sigv = (char* const*)PL_sig_name; *sigv; sigv++)
        if (strEQ(sig,*sigv))
            return PL_sig_num[sigv - (char* const*)PL_sig_name];
#ifdef SIGCLD
    if (strEQ(sig,"CHLD"))
        return SIGCLD;
#endif
#ifdef SIGCHLD
    if (strEQ(sig,"CLD"))
        return SIGCHLD;
#endif
    return -1;
}

Signal_t
#if defined(HAS_SIGACTION) && defined(SA_SIGINFO)
Perl_sighandler(int sig, siginfo_t *sip, void *uap PERL_UNUSED_DECL)
#else
Perl_sighandler(int sig)
#endif
{
#ifdef PERL_GET_SIG_CONTEXT
    dTHXa(PERL_GET_SIG_CONTEXT);
#else
    dTHX;
#endif
    dSP;
    GV *gv = NULL;
    SV *sv = NULL;
    SV * const tSv = PL_Sv;
    CV *cv = NULL;
    OP *myop = PL_op;
    U32 flags = 0;
    XPV * const tXpv = PL_Xpv;

    if (PL_savestack_ix + 15 <= PL_savestack_max)
        flags |= 1;
    if (PL_markstack_ptr < PL_markstack_max - 2)
        flags |= 4;
    if (PL_scopestack_ix < PL_scopestack_max - 3)
        flags |= 16;

    if (!PL_psig_ptr[sig]) {
/* 	PerlIO_printf(Perl_error_log, "Signal SIG%s received, but no signal handler set.\n", */
/* 	    PL_sig_name[sig]); */
/* 	exit(sig); */
	return;
    }

    /* Max number of items pushed there is 3*n or 4. We cannot fix
       infinity, so we fix 4 (in fact 5): */
    if (flags & 1) {
        PL_savestack_ix += 5;           /* Protect save in progress. */
        SAVEDESTRUCTOR_X(S_unwind_handler_stack, (void*)&flags);
    }
    if (flags & 4)
        PL_markstack_ptr++;             /* Protect mark. */
    if (flags & 16)
        PL_scopestack_ix += 1;

    if (!(cv = (CV*)PL_psig_ptr[sig])
        || SvTYPE(cv) != SVt_PVCV) {
	Perl_croak(aTHX "SIG%s handler is not valid", PL_sig_name[sig]);
    }

    if (!cv || !CvROOT(cv)) {
        if (ckWARN(WARN_SIGNAL))
            Perl_warner(aTHX_ packWARN(WARN_SIGNAL), "SIG%s handler \"%s\" not defined.\n",
                PL_sig_name[sig], SvPVX_const(loc_desc(SvLOCATION(gv))));
        goto cleanup;
    }

    if(PL_psig_name[sig]) {
        sv = SvREFCNT_inc_NN(PL_psig_name[sig]);
        flags |= 64;
#if !defined(PERL_IMPLICIT_CONTEXT)
        PL_sig_sv = sv;
#endif
    } else {
        sv = sv_newmortal();
        sv_setpv(sv,PL_sig_name[sig]);
    }

    PUSHSTACKi(PERLSI_SIGNAL);
    PUSHMARK(SP);
    PUSHs(sv);
#if defined(HAS_SIGACTION) && defined(SA_SIGINFO)
    {
         struct sigaction oact;

         if (sigaction(sig, 0, &oact) == 0 && oact.sa_flags & SA_SIGINFO) {
              if (sip) {
                   HV *sih = newHV();
                   SV *rv  = newRV_noinc((SV*)sih);
                   /* The siginfo fields signo, code, errno, pid, uid,
                    * addr, status, and band are defined by POSIX/SUSv3. */
                   (void)hv_stores(sih, "signo", newSViv(sip->si_signo));
                   (void)hv_stores(sih, "code", newSViv(sip->si_code));
#if 0 /* XXX TODO: Configure scan for the existence of these, but even that does not help if the SA_SIGINFO is not implemented according to the spec. */
		   hv_stores(sih, "errno",      newSViv(sip->si_errno));
		   hv_stores(sih, "status",     newSViv(sip->si_status));
		   hv_stores(sih, "uid",        newSViv(sip->si_uid));
		   hv_stores(sih, "pid",        newSViv(sip->si_pid));
		   hv_stores(sih, "addr",       newSVuv(PTR2UV(sip->si_addr)));
		   hv_stores(sih, "band",       newSViv(sip->si_band));
#endif
		   EXTEND(SP, 2);
		   PUSHs((SV*)rv);
		   mPUSHp((char *)sip, sizeof(*sip));
	      }

         }
    }
#endif
    PUTBACK;

    call_sv((SV*)cv, G_DISCARD|G_EVAL);

    POPSTACK;
    if (SvTRUE(ERRSV)) {
#ifndef PERL_MICRO
#ifdef HAS_SIGPROCMASK
        /* Handler "died", for example to get out of a restart-able read().
         * Before we re-do that on its behalf re-enable the signal which was
         * blocked by the system when we entered.
         */
        sigset_t set;
        sigemptyset(&set);
        sigaddset(&set,sig);
        sigprocmask(SIG_UNBLOCK, &set, NULL);
#else
        /* Not clear if this will work */
        (void)rsignal(sig, SIG_IGN);
        (void)rsignal(sig, PL_csighandlerp);
#endif
#endif /* !PERL_MICRO */
        Perl_vdie_common(aTHX_ ERRSV, FALSE);
	die_where(ERRSV);
    }
cleanup:
    if (flags & 1)
	PL_savestack_ix -= 8; /* Unprotect save in progress. */
    if (flags & 4)
	PL_markstack_ptr--;
    if (flags & 16)
	PL_scopestack_ix -= 1;
    if (flags & 64)
	SvREFCNT_dec(sv);
    PL_op = myop;			/* Apparently not needed... */

    PL_Sv = tSv;			/* Restore global temporaries. */
    PL_Xpv = tXpv;
    return;
}


static void
S_restore_magic(pTHX_ const void *p)
{
    dVAR;
    MGS* const mgs = SSPTR(PTR2IV(p), MGS*);
    SV* const sv = mgs->mgs_sv;

    if (!sv)
        return;

    if (SvTYPE(sv) >= SVt_PVMG && SvMAGIC(sv))
    {
#ifdef PERL_OLD_COPY_ON_WRITE
	/* While magic was saved (and off) sv_setsv may well have seen
	   this SV as a prime candidate for COW.  */
	if (SvIsCOW(sv))
	    sv_force_normal_flags(sv, 0);
#endif

	if (mgs->mgs_flags)
	    SvFLAGS(sv) |= mgs->mgs_flags;
	else
	    mg_magical(sv);
    }

    mgs->mgs_sv = NULL;  /* mark the MGS structure as restored */

    /* If we're still on top of the stack, pop us off.  (That condition
     * will be satisfied if restore_magic was called explicitly, but *not*
     * if it's being called via leave_scope.)
     * The reason for doing this is that otherwise, things like sv_2cv()
     * may leave alloc gunk on the savestack, and some code
     * (e.g. sighandler) doesn't expect that...
     */
    if (PL_savestack_ix == mgs->mgs_ss_ix)
    {
	I32 popval = SSPOPINT;
        assert(popval == SAVEt_DESTRUCTOR_X);
        PL_savestack_ix -= 2;
	popval = SSPOPINT;
        assert(popval == SAVEt_ALLOC);
	popval = SSPOPINT;
        PL_savestack_ix -= popval;
    }

}

static void
S_unwind_handler_stack(pTHX_ const void *p)
{
    dVAR;
    const U32 flags = *(const U32*)p;

    PERL_ARGS_ASSERT_UNWIND_HANDLER_STACK;

    if (flags & 1)
	PL_savestack_ix -= 5; /* Unprotect save in progress. */
#if !defined(PERL_IMPLICIT_CONTEXT)
    if (flags & 64)
	SvREFCNT_dec(PL_sig_sv);
#endif
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
