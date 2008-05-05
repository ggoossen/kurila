/*    toke.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 *   "It all comes from here, the stench and the peril."  --Frodo
 */

/*
 * This file is the lexer for Perl.  It's closely linked to the
 * parser, perly.y.
 *
 * The main routine is yylex(), which returns the next token.
 */

#include "EXTERN.h"
#define PERL_IN_TOKE_C
#include "perl.h"

#define new_constant(a,b,c,d,e,f,g)	\
	S_new_constant(aTHX_ a,b,STR_WITH_LEN(c),d,e,f, g)

#define pl_yylval	(PL_parser->yylval)

/* YYINITDEPTH -- initial size of the parser's stacks.  */
#define YYINITDEPTH 200

/* XXX temporary backwards compatibility */
#define PL_lex_brackets		(PL_parser->lex_brackets)
#define PL_lex_brackstack	(PL_parser->lex_brackstack)
#define PL_lex_casemods		(PL_parser->lex_casemods)
#define PL_lex_casestack        (PL_parser->lex_casestack)
#define PL_lex_defer		(PL_parser->lex_defer)
#define PL_lex_dojoin		(PL_parser->lex_dojoin)
#define PL_lex_expect		(PL_parser->lex_expect)
#define PL_lex_flags		(PL_parser->lex_flags)
#define PL_lex_inwhat		(PL_parser->lex_inwhat)
#define PL_lex_op		(PL_parser->lex_op)
#define PL_lex_repl		(PL_parser->lex_repl)
#define PL_lex_starts		(PL_parser->lex_starts)
#define PL_lex_stuff		(PL_parser->lex_stuff)
#define PL_multi_start		(PL_parser->multi_start)
#define PL_multi_open		(PL_parser->multi_open)
#define PL_multi_close		(PL_parser->multi_close)
#define PL_pending_ident        (PL_parser->pending_ident)
#define PL_preambled		(PL_parser->preambled)
#define PL_sublex_info		(PL_parser->sublex_info)
#define PL_linestr		(PL_parser->linestr)
#define PL_expect		(PL_parser->expect)
#define PL_copline		(PL_parser->copline)
#define PL_bufptr		(PL_parser->bufptr)
#define PL_oldbufptr		(PL_parser->oldbufptr)
#define PL_oldoldbufptr		(PL_parser->oldoldbufptr)
#define PL_linestart		(PL_parser->linestart)
#define PL_bufend		(PL_parser->bufend)
#define PL_last_uni		(PL_parser->last_uni)
#define PL_last_lop		(PL_parser->last_lop)
#define PL_last_lop_op		(PL_parser->last_lop_op)
#define PL_lex_state		(PL_parser->lex_state)
#define PL_rsfp			(PL_parser->rsfp)
#define PL_rsfp_filters		(PL_parser->rsfp_filters)
#define PL_in_my		(PL_parser->in_my)
#define PL_tokenbuf		(PL_parser->tokenbuf)
#define PL_multi_end		(PL_parser->multi_end)
#define PL_error_count		(PL_parser->error_count)

#ifdef PERL_MAD
#  define PL_endwhite		(PL_parser->endwhite)
#  define PL_faketokens		(PL_parser->faketokens)
#  define PL_lasttoke		(PL_parser->lasttoke)
#  define PL_nextwhite		(PL_parser->nextwhite)
#  define PL_realtokenstart	(PL_parser->realtokenstart)
#  define PL_skipwhite		(PL_parser->skipwhite)
#  define PL_thisclose		(PL_parser->thisclose)
#  define PL_thismad		(PL_parser->thismad)
#  define PL_thisopen		(PL_parser->thisopen)
#  define PL_thisstuff		(PL_parser->thisstuff)
#  define PL_thistoken		(PL_parser->thistoken)
#  define PL_thiswhite		(PL_parser->thiswhite)
#  define PL_thiswhite		(PL_parser->thiswhite)
#  define PL_nexttoke		(PL_parser->nexttoke)
#  define PL_curforce		(PL_parser->curforce)
#else
#  define PL_nexttoke		(PL_parser->nexttoke)
#  define PL_nexttype		(PL_parser->nexttype)
#  define PL_nextval		(PL_parser->nextval)
#endif

static int
S_pending_ident(pTHX);

static const char ident_too_long[] = "Identifier too long";
static const char commaless_variable_list[] = "comma-less variable list";

#ifndef PERL_NO_UTF16_FILTER
static I32 utf16_textfilter(pTHX_ int idx, SV *sv, int maxlen);
static I32 utf16rev_textfilter(pTHX_ int idx, SV *sv, int maxlen);
#endif

#ifdef PERL_MAD
#  define CURMAD(slot,sv) if (PL_madskills) { curmad(slot,sv); sv = 0; }
#  define NEXTVAL_NEXTTOKE PL_nexttoke[PL_curforce].next_val
#else
#  define CURMAD(slot,sv)
#  define NEXTVAL_NEXTTOKE PL_nextval[PL_nexttoke]
#endif

#define XFAKEBRACK 128
#define XENUMMASK 127

#define UTF (!IN_BYTES)

/* In variables named $^X, these are the legal values for X.
 * 1999-02-27 mjd-perl-patch@plover.com */
#define isCONTROLVAR(x) (isUPPER(x) || strchr("[\\]^_?", (x)))

/* On MacOS, respect nonbreaking spaces */
#ifdef MACOS_TRADITIONAL
#define SPACE_OR_TAB(c) ((c)==' '||(c)=='\312'||(c)=='\t')
#else
#define SPACE_OR_TAB(c) ((c)==' '||(c)=='\t')
#endif

/* LEX_* are values for PL_lex_state, the state of the lexer.
 * They are arranged oddly so that the guard on the switch statement
 * can get by with a single comparison (if the compiler is smart enough).
 */

/* #define LEX_NOTPARSING		11 is done in perl.h. */

#define LEX_INTERPBLOCK          8 /* block inside { ... } */
#define LEX_NORMAL		 7 /* normal code (ie not within "...")     */
#define LEX_INTERPNORMAL	 6 /* code within a string, eg "$foo[$x+1]" */
#define LEX_INTERPCASEMOD	 5 /* expecting a \U, \Q or \E etc          */
#define LEX_INTERPPUSH		 4 /* starting a new sublex parse level     */
#define LEX_INTERPSTART		 3 /* expecting the start of a $var         */

				   /* at end of code, eg "$x" followed by:  */
#define LEX_INTERPEND		 2 /* ... eg not one of [, { or ->          */

#define LEX_INTERPCONCAT	 1 /* expecting anything, eg at start of
				        string or after \E, $foo, etc       */
#define LEX_KNOWNEXT		 0 /* next token known; just return it      */


#ifdef DEBUGGING
static const char* const lex_state_names[] = {
    "KNOWNEXT",
    "INTERPCONCAT",
    "INTERPEND",
    "INTERPSTART",
    "INTERPPUSH",
    "INTERPCASEMOD",
    "INTERPNORMAL",
    "NORMAL",
    "INTERPBLOCK"
};
#endif

#ifdef ff_next
#undef ff_next
#endif

#include "keywords.h"

/* CLINE is a macro that ensures PL_copline has a sane value */

#ifdef CLINE
#undef CLINE
#endif
#define CLINE (PL_copline = (CopLINE(PL_curcop) < PL_copline ? CopLINE(PL_curcop) : PL_copline))

#ifdef PERL_MAD
#  define SKIPSPACE0(s) skipspace0(s)
#  define SKIPSPACE1(s) skipspace1(s)
#  define SKIPSPACE2(s,tsv) skipspace2(s,&tsv)
#  define PEEKSPACE(s) skipspace2(s,0)
#else
#  define SKIPSPACE0(s) skipspace(s)
#  define SKIPSPACE1(s) skipspace(s)
#  define SKIPSPACE2(s,tsv) skipspace(s)
#  define PEEKSPACE(s) skipspace(s)
#endif

/*
 * Convenience functions to return different tokens and prime the
 * lexer for the next token.  They all take an argument.
 *
 * TOKEN        : generic token (used for '(', etc)
 * OPERATOR     : generic operator
 * AOPERATOR    : assignment operator
 * PREBLOCK     : beginning the block after an if, while, foreach, ...
 * PRETERMBLOCK : beginning a non-code-defining {} block (eg, hash ref)
 * PREREF       : *EXPR where EXPR is not a simple identifier
 * TERM         : expression term
 * LOOPX        : loop exiting command (goto, last, dump, etc)
 * FTST         : file test operator
 * FUN0         : zero-argument function
 * FUN1         : not used, except for not, which isn't a UNIOP
 * BOop         : bitwise or or xor
 * BAop         : bitwise and
 * SHop         : shift operator
 * PWop         : power operator
 * PMop         : pattern-matching operator
 * Aop          : addition-level operator
 * Mop          : multiplication-level operator
 * Eop          : equality-testing operator
 * Rop          : relational operator <= != gt
 *
 * Also see LOP and lop() below.
 */

#ifdef DEBUGGING /* Serve -DT. */
#   define REPORT(retval) tokereport((I32)retval, &pl_yylval)
#else
#   define REPORT(retval) (retval)
#endif

#define TOKEN(retval) return ( PL_bufptr = s, REPORT(retval))
#define OPERATOR(retval) return (PL_expect = XTERM, PL_bufptr = s, REPORT(retval))
#define AOPERATOR(retval) return ao((PL_expect = XTERM, PL_bufptr = s, REPORT(retval)))
#define PREBLOCK(retval) return (PL_expect = XBLOCK,PL_bufptr = s, REPORT(retval))
#define PRETERMBLOCK(retval) return (PL_expect = XTERMBLOCK,PL_bufptr = s, REPORT(retval))
#define PREREF(retval) return (PL_expect = XREF,PL_bufptr = s, REPORT(retval))
#define TERM(retval) return (CLINE, PL_expect = XOPERATOR, PL_bufptr = s, REPORT(retval))
#define LOOPX(f) return (pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)LOOPEX))
#define FTST(f)  return (pl_yylval.ival=f, PL_expect=XTERMORDORDOR, PL_bufptr=s, REPORT((int)UNIOP))
#define FUN0(f)  return (pl_yylval.ival=f, PL_expect=XOPERATOR, PL_bufptr=s, REPORT((int)FUNC0))
#define FUN1(f)  return (pl_yylval.ival=f, PL_expect=XOPERATOR, PL_bufptr=s, REPORT((int)FUNC1))
#define BOop(f)  return ao((pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)BITOROP)))
#define BAop(f)  return ao((pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)BITANDOP)))
#define SHop(f)  return ao((pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)SHIFTOP)))
#define PWop(f)  return ao((pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)POWOP)))
#define PMop(f)  return(pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)MATCHOP))
#define Aop(f)   return ao((pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)ADDOP)))
#define Mop(f)   return ao((pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)MULOP)))
#define Eop(f)   return (pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)EQOP))
#define Rop(f)   return (pl_yylval.ival=f, PL_expect=XTERM, PL_bufptr=s, REPORT((int)RELOP))

/* This bit of chicanery makes a unary function followed by
 * a parenthesis into a function with one argument, highest precedence.
 * The UNIDOR macro is for unary functions that can be followed by the //
 * operator (such as C<shift // 0>).
 */
#define UNI2(f,x) { \
	pl_yylval.ival = f; \
	PL_expect = x; \
	PL_bufptr = s; \
	PL_last_uni = PL_oldbufptr; \
	PL_last_lop_op = f; \
	if (*s == '(') \
	    return REPORT( (int)FUNC1 ); \
	s = PEEKSPACE(s); \
	return REPORT( *s=='(' ? (int)FUNC1 : (int)UNIOP ); \
	}
#define UNI(f)    UNI2(f,XTERM)
#define UNIDOR(f) UNI2(f,XTERMORDORDOR)

#define UNIBRACK(f) { \
	pl_yylval.ival = f; \
	PL_bufptr = s; \
	PL_last_uni = PL_oldbufptr; \
	if (*s == '(') \
	    return REPORT( (int)FUNC1 ); \
	s = PEEKSPACE(s); \
	return REPORT( (*s == '(') ? (int)FUNC1 : (int)UNIOP ); \
	}

/* grandfather return to old style */
#define OLDLOP(f) return(pl_yylval.ival=f,PL_expect = XTERM,PL_bufptr = s,(int)LSTOP)

#ifdef DEBUGGING

/* how to interpret the pl_yylval associated with the token */
enum token_type {
    TOKENTYPE_NONE,
    TOKENTYPE_IVAL,
    TOKENTYPE_OPNUM, /* pl_yylval.ival contains an opcode number */
    TOKENTYPE_PVAL,
    TOKENTYPE_OPVAL,
    TOKENTYPE_GVVAL
};

static struct debug_tokens {
    const int token;
    enum token_type type;
    const char *name;
} const debug_tokens[] =
{
    { ADDOP,		TOKENTYPE_OPNUM,	"ADDOP" },
    { ANDAND,		TOKENTYPE_NONE,		"ANDAND" },
    { ANDOP,		TOKENTYPE_NONE,		"ANDOP" },
    { ANONSUB,		TOKENTYPE_IVAL,		"ANONSUB" },
    { ANONARY,		TOKENTYPE_IVAL,		"ANONARY" },
    { ARROW,		TOKENTYPE_NONE,		"ARROW" },
    { ASSIGNOP,		TOKENTYPE_OPNUM,	"ASSIGNOP" },
    { BITANDOP,		TOKENTYPE_OPNUM,	"BITANDOP" },
    { BITOROP,		TOKENTYPE_OPNUM,	"BITOROP" },
    { COLONATTR,	TOKENTYPE_NONE,		"COLONATTR" },
    { CONTINUE,		TOKENTYPE_NONE,		"CONTINUE" },
    { DEFAULT,		TOKENTYPE_NONE,		"DEFAULT" },
    { DO,		TOKENTYPE_NONE,		"DO" },
    { DORDOR,		TOKENTYPE_NONE,		"DORDOR" },
    { DOROP,		TOKENTYPE_OPNUM,	"DOROP" },
    { DOTDOT,		TOKENTYPE_IVAL,		"DOTDOT" },
    { ELSE,		TOKENTYPE_NONE,		"ELSE" },
    { ELSIF,		TOKENTYPE_IVAL,		"ELSIF" },
    { EQOP,		TOKENTYPE_OPNUM,	"EQOP" },
    { FOR,		TOKENTYPE_IVAL,		"FOR" },
    { FUNC,		TOKENTYPE_OPNUM,	"FUNC" },
    { FUNC0,		TOKENTYPE_OPNUM,	"FUNC0" },
    { FUNC0SUB,		TOKENTYPE_OPVAL,	"FUNC0SUB" },
    { FUNC1,		TOKENTYPE_OPNUM,	"FUNC1" },
    { GIVEN,		TOKENTYPE_IVAL,		"GIVEN" },
    { IF,		TOKENTYPE_IVAL,		"IF" },
    { LABEL,		TOKENTYPE_PVAL,		"LABEL" },
    { LOCAL,		TOKENTYPE_IVAL,		"LOCAL" },
    { LOOPEX,		TOKENTYPE_OPNUM,	"LOOPEX" },
    { LSTOP,		TOKENTYPE_OPNUM,	"LSTOP" },
    { LSTOPSUB,		TOKENTYPE_OPVAL,	"LSTOPSUB" },
    { MATCHOP,		TOKENTYPE_OPNUM,	"MATCHOP" },
    { METHOD,		TOKENTYPE_OPVAL,	"METHOD" },
    { MULOP,		TOKENTYPE_OPNUM,	"MULOP" },
    { MY,		TOKENTYPE_IVAL,		"MY" },
    { MYSUB,		TOKENTYPE_NONE,		"MYSUB" },
    { NOAMP,		TOKENTYPE_NONE,		"NOAMP" },
    { NOTOP,		TOKENTYPE_NONE,		"NOTOP" },
    { OROP,		TOKENTYPE_IVAL,		"OROP" },
    { OROR,		TOKENTYPE_NONE,		"OROR" },
    { PACKAGE,		TOKENTYPE_NONE,		"PACKAGE" },
    { PMFUNC,		TOKENTYPE_OPVAL,	"PMFUNC" },
    { POSTDEC,		TOKENTYPE_NONE,		"POSTDEC" },
    { POSTINC,		TOKENTYPE_NONE,		"POSTINC" },
    { POWOP,		TOKENTYPE_OPNUM,	"POWOP" },
    { PREDEC,		TOKENTYPE_NONE,		"PREDEC" },
    { PREINC,		TOKENTYPE_NONE,		"PREINC" },
    { PRIVATEREF,	TOKENTYPE_OPVAL,	"PRIVATEREF" },
    { REFGEN,		TOKENTYPE_NONE,		"REFGEN" },
    { RELOP,		TOKENTYPE_OPNUM,	"RELOP" },
    { SHIFTOP,		TOKENTYPE_OPNUM,	"SHIFTOP" },
    { SUB,		TOKENTYPE_NONE,		"SUB" },
    { THING,		TOKENTYPE_OPVAL,	"THING" },
    { UMINUS,		TOKENTYPE_NONE,		"UMINUS" },
    { UNIOP,		TOKENTYPE_OPNUM,	"UNIOP" },
    { UNIOPSUB,		TOKENTYPE_OPVAL,	"UNIOPSUB" },
    { UNLESS,		TOKENTYPE_IVAL,		"UNLESS" },
    { UNTIL,		TOKENTYPE_IVAL,		"UNTIL" },
    { USE,		TOKENTYPE_IVAL,		"USE" },
    { WHEN,		TOKENTYPE_IVAL,		"WHEN" },
    { WHILE,		TOKENTYPE_IVAL,		"WHILE" },
    { WORD,		TOKENTYPE_OPVAL,	"WORD" },
    { 0,		TOKENTYPE_NONE,		NULL }
};

/* dump the returned token in rv, plus any optional arg in pl_yylval */

STATIC int
S_tokereport(pTHX_ I32 rv, const YYSTYPE* lvalp)
{
    dVAR;

    PERL_ARGS_ASSERT_TOKEREPORT;

    if (DEBUG_T_TEST) {
	const char *name = NULL;
	enum token_type type = TOKENTYPE_NONE;
	const struct debug_tokens *p;
	SV* const report = newSVpvs("<== ");

	for (p = debug_tokens; p->token; p++) {
	    if (p->token == (int)rv) {
		name = p->name;
		type = p->type;
		break;
	    }
	}
	if (name)
	    Perl_sv_catpv(aTHX_ report, name);
	else if ((char)rv > ' ' && (char)rv < '~')
	    Perl_sv_catpvf(aTHX_ report, "'%c'", (char)rv);
	else if (!rv)
	    sv_catpvs(report, "EOF");
	else
	    Perl_sv_catpvf(aTHX_ report, "?? %"IVdf, (IV)rv);
	switch (type) {
	case TOKENTYPE_NONE:
	case TOKENTYPE_GVVAL: /* doesn't appear to be used */
	    break;
	case TOKENTYPE_IVAL:
	    Perl_sv_catpvf(aTHX_ report, "(ival=%"IVdf")", (IV)lvalp->ival);
	    break;
	case TOKENTYPE_OPNUM:
	    Perl_sv_catpvf(aTHX_ report, "(ival=op_%s)",
				    PL_op_name[lvalp->ival]);
	    break;
	case TOKENTYPE_PVAL:
	    Perl_sv_catpvf(aTHX_ report, "(pval=\"%s\")", lvalp->pval);
	    break;
	case TOKENTYPE_OPVAL:
	    if (lvalp->opval) {
		Perl_sv_catpvf(aTHX_ report, "(opval=op_%s)",
				    PL_op_name[lvalp->opval->op_type]);
		if (lvalp->opval->op_type == OP_CONST) {
		    Perl_sv_catpvf(aTHX_ report, " %s",
			SvPEEK(cSVOPx_sv(lvalp->opval)));
		}

	    }
	    else
		sv_catpvs(report, "(opval=null)");
	    break;
	}
        PerlIO_printf(Perl_debug_log, "### %s\n\n", SvPV_nolen_const(report));
    };
    return (int)rv;
}


/* print the buffer with suitable escapes */

STATIC void
S_printbuf(pTHX_ const char *const fmt, const char *const s)
{
    SV* const tmp = newSVpvs("");

    PERL_ARGS_ASSERT_PRINTBUF;

    PerlIO_printf(Perl_debug_log, fmt, pv_display(tmp, s, strlen(s), 0, 60));
    SvREFCNT_dec(tmp);
}

#endif

/*
 * S_ao
 *
 * This subroutine detects &&=, ||=, and //= and turns an ANDAND, OROR or DORDOR
 * into an OP_ANDASSIGN, OP_ORASSIGN, or OP_DORASSIGN
 */

STATIC int
S_ao(pTHX_ int toketype)
{
    dVAR;
    if (*PL_bufptr == '=') {
	PL_bufptr++;
	if (toketype == ANDAND)
	    pl_yylval.ival = OP_ANDASSIGN;
	else if (toketype == OROR)
	    pl_yylval.ival = OP_ORASSIGN;
	else if (toketype == DORDOR)
	    pl_yylval.ival = OP_DORASSIGN;
	toketype = ASSIGNOP;
    }
    return toketype;
}

/*
 * S_no_op
 * When Perl expects an operator and finds something else, no_op
 * prints the warning.  It always prints "<something> found where
 * operator expected.  It prints "Missing semicolon on previous line?"
 * if the surprise occurs at the start of the line.  "do you need to
 * predeclare ..." is printed out for code like "sub bar; foo bar $x"
 * where the compiler doesn't know if foo is a method call or a function.
 * It prints "Missing operator before end of line" if there's nothing
 * after the missing operator, or "... before <...>" if there is something
 * after the missing operator.
 */

STATIC void
S_no_op(pTHX_ const char *const what, char *s)
{
    dVAR;
    char * const oldbp = PL_bufptr;
    const bool is_first = (PL_oldbufptr == PL_linestart);

    PERL_ARGS_ASSERT_NO_OP;

    if (!s)
	s = oldbp;
    else
	PL_bufptr = s;
    yywarn(Perl_form(aTHX_ "%s found where operator expected", what));
    if (ckWARN_d(WARN_SYNTAX)) {
	if (is_first)
	    Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
		    "\t(Missing semicolon on previous line?)\n");
	else if (PL_oldoldbufptr && isIDFIRST_lazy_if(PL_oldoldbufptr,UTF)) {
	    const char *t;
	    for (t = PL_oldoldbufptr; (isALNUM_lazy_if(t,UTF) || *t == ':'); t++)
		NOOP;
	    if (t < PL_bufptr && isSPACE(*t))
		Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
			"\t(Do you need to predeclare %.*s?)\n",
		    (int)(t - PL_oldoldbufptr), PL_oldoldbufptr);
	}
	else {
	    assert(s >= oldbp);
	    Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
		    "\t(Missing operator before %.*s?)\n", (int)(s - oldbp), oldbp);
	}
    }
    PL_bufptr = oldbp;
}

/*
 * S_missingterminator
 * Complain about missing quote/regexp/heredoc terminator.
 * If it's called with NULL then it cauterizes the line buffer.
 * If we're in a delimited string and the delimiter is a control
 * character, it's reformatted into a two-char sequence like ^C.
 * This is fatal.
 */

STATIC void
S_missingterminator(pTHX_ char *s)
{
    dVAR;
    char tmpbuf[3];
    char q;
    if (s) {
	char * const nl = strrchr(s,'\n');
	if (nl)
	    *nl = '\0';
    }
    else if (
#ifdef EBCDIC
	iscntrl(PL_multi_close)
#else
	PL_multi_close < 32 || PL_multi_close == 127
#endif
	) {
	*tmpbuf = '^';
	tmpbuf[1] = (char)toCTRL(PL_multi_close);
	tmpbuf[2] = '\0';
	s = tmpbuf;
    }
    else {
	*tmpbuf = (char)PL_multi_close;
	tmpbuf[1] = '\0';
	s = tmpbuf;
    }
    q = strchr(s,'"') ? '\'' : '"';
    Perl_croak(aTHX_ "Can't find string terminator %c%s%c anywhere before EOF",q,s,q);
}

#define FEATURE_IS_ENABLED(name)				        \
	((0 != (PL_hints & HINT_LOCALIZE_HH))				\
	    && S_feature_is_enabled(aTHX_ STR_WITH_LEN(name)))
/* The longest string we pass in.  */
#define MAX_FEATURE_LEN (sizeof("switch")-1)

/*
 * S_feature_is_enabled
 * Check whether the named feature is enabled.
 */
STATIC bool
S_feature_is_enabled(pTHX_ const char *const name, STRLEN namelen)
{
    dVAR;
    HV * const hinthv = GvHV(PL_hintgv);
    char he_name[8 + MAX_FEATURE_LEN] = "feature_";

    PERL_ARGS_ASSERT_FEATURE_IS_ENABLED;

    assert(namelen <= MAX_FEATURE_LEN);
    memcpy(&he_name[8], name, namelen);

    return (hinthv && hv_exists(hinthv, he_name, 8 + namelen));
}

/*
 * Perl_deprecate
 */

void
Perl_deprecate(pTHX_ const char *const s)
{
    PERL_ARGS_ASSERT_DEPRECATE;

    if (ckWARN(WARN_DEPRECATED))
	Perl_warner(aTHX_ packWARN(WARN_DEPRECATED), "Use of %s is deprecated", s);
}

void
Perl_deprecate_old(pTHX_ const char *const s)
{
    /* This function should NOT be called for any new deprecated warnings */
    /* Use Perl_deprecate instead                                         */
    /*                                                                    */
    /* It is here to maintain backward compatibility with the pre-5.8     */
    /* warnings category hierarchy. The "deprecated" category used to     */
    /* live under the "syntax" category. It is now a top-level category   */
    /* in its own right.                                                  */

    PERL_ARGS_ASSERT_DEPRECATE_OLD;

    if (ckWARN2(WARN_DEPRECATED, WARN_SYNTAX))
	Perl_warner(aTHX_ packWARN2(WARN_DEPRECATED, WARN_SYNTAX),
			"Use of %s is deprecated", s);
}

/*
 * experimental text filters for win32 carriage-returns, utf16-to-utf8 and
 * utf16-to-utf8-reversed.
 */

#ifdef PERL_CR_FILTER
static void
strip_return(SV *sv)
{
    register const char *s = SvPVX_const(sv);
    register const char * const e = s + SvCUR(sv);

    PERL_ARGS_ASSERT_STRIP_RETURN;

    /* outer loop optimized to do nothing if there are no CR-LFs */
    while (s < e) {
	if (*s++ == '\r' && *s == '\n') {
	    /* hit a CR-LF, need to copy the rest */
	    register char *d = s - 1;
	    *d++ = *s++;
	    while (s < e) {
		if (*s == '\r' && s[1] == '\n')
		    s++;
		*d++ = *s++;
	    }
	    SvCUR(sv) -= s - d;
	    return;
	}
    }
}

STATIC I32
S_cr_textfilter(pTHX_ int idx, SV *sv, int maxlen)
{
    const I32 count = FILTER_READ(idx+1, sv, maxlen);
    if (count > 0 && !maxlen)
	strip_return(sv);
    return count;
}
#endif



/*
 * Perl_lex_start
 *
 * Create a parser object and initialise its parser and lexer fields
 *
 * rsfp       is the opened file handle to read from (if any),
 *
 * line       holds any initial content already read from the file (or in
 *            the case of no file, such as an eval, the whole contents);
 *
 * new_filter indicates that this is a new file and it shouldn't inherit
 *            the filters from the current parser (ie require).
 */

void
Perl_lex_start(pTHX_ SV *line, PerlIO *rsfp, bool new_filter)
{
    dVAR;
    const char *s = NULL;
    STRLEN len;
    yy_parser *parser, *oparser;

    /* create and initialise a parser */

    Newxz(parser, 1, yy_parser);
    parser->old_parser = oparser = PL_parser;
    PL_parser = parser;

    Newx(parser->stack, YYINITDEPTH, yy_stack_frame);
    parser->ps = parser->stack;
    parser->stack_size = YYINITDEPTH;

    parser->stack->state = 0;
    parser->yyerrstatus = 0;
    parser->yychar = YYEMPTY;		/* Cause a token to be read.  */

    /* on scope exit, free this parser and restore any outer one */
    SAVEPARSER(parser);
    parser->saved_curcop = PL_curcop;

    /* initialise lexer state */

#ifdef PERL_MAD
    parser->curforce = -1;
#else
    parser->nexttoke = 0;
#endif
    parser->error_count = oparser ? oparser->error_count : 0;
    parser->copline = NOLINE;
    parser->lex_state = LEX_NORMAL;
    parser->expect = XSTATE;
    parser->rsfp = rsfp;
    parser->rsfp_filters = (new_filter || !oparser) ? newAV()
		: (AV*)SvREFCNT_inc(oparser->rsfp_filters);

    Newx(parser->lex_brackstack, 120, char);
    Newx(parser->lex_casestack, 12, char);
    *parser->lex_casestack = '\0';

    if (line) {
	s = SvPV_const(line, len);
    } else {
	len = 0;
    }

    if (!len) {
	parser->linestr = newSVpvs("\n;");
    } else if (SvREADONLY(line) || s[len-1] != ';') {
	parser->linestr = newSVsv(line);
	if (s[len-1] != ';')
	    sv_catpvs(parser->linestr, "\n;");
    } else {
	SvTEMP_off(line);
	SvREFCNT_inc_simple_void_NN(line);
	parser->linestr = line;
    }
    parser->oldoldbufptr =
	parser->oldbufptr =
	parser->bufptr =
	parser->linestart = SvPVX(parser->linestr);
    parser->bufend = parser->bufptr + SvCUR(parser->linestr);
    parser->last_lop = parser->last_uni = NULL;
}


/* delete a parser object */

void
Perl_parser_free(pTHX_  const yy_parser *parser)
{
    PERL_ARGS_ASSERT_PARSER_FREE;

    PL_curcop = parser->saved_curcop;
    SvREFCNT_dec(parser->linestr);

    if (parser->rsfp == PerlIO_stdin())
	PerlIO_clearerr(parser->rsfp);
    else if (parser->rsfp && parser->old_parser
			  && parser->rsfp != parser->old_parser->rsfp)
	PerlIO_close(parser->rsfp);
    SvREFCNT_dec(parser->rsfp_filters);

    Safefree(parser->stack);
    Safefree(parser->lex_brackstack);
    Safefree(parser->lex_casestack);
    PL_parser = parser->old_parser;
    Safefree(parser);
}


/*
 * Perl_lex_end
 * Finalizer for lexing operations.  Must be called when the parser is
 * done with the lexer.
 */

void
Perl_lex_end(pTHX)
{
    dVAR;
    PL_doextract = FALSE;
}

/*
 * S_incline
 * This subroutine has nothing to do with tilting, whether at windmills
 * or pinball tables.  Its name is short for "increment line".  It
 * increments the current line number in CopLINE(PL_curcop) and checks
 * to see whether the line starts with a comment of the form
 *    # line 500 "foo.pm"
 * If so, it sets the current line number and file to the values in the comment.
 */

STATIC void
S_incline(pTHX_ const char *s)
{
    dVAR;
    const char *t;
    const char *n;
    const char *e;

    PERL_ARGS_ASSERT_INCLINE;

    CopLINE_inc(PL_curcop);
    if (*s++ != '#')
	return;
    while (SPACE_OR_TAB(*s))
	s++;
    if (strnEQ(s, "line", 4))
	s += 4;
    else
	return;
    if (SPACE_OR_TAB(*s))
	s++;
    else
	return;
    while (SPACE_OR_TAB(*s))
	s++;
    if (!isDIGIT(*s))
	return;

    n = s;
    while (isDIGIT(*s))
	s++;
    while (SPACE_OR_TAB(*s))
	s++;
    if (*s == '"' && (t = strchr(s+1, '"'))) {
	s++;
	e = t + 1;
    }
    else {
	t = s;
	while (!isSPACE(*t))
	    t++;
	e = t;
    }
    while (SPACE_OR_TAB(*e) || *e == '\r' || *e == '\f')
	e++;
    if (*e != '\n' && *e != '\0')
	return;		/* false alarm */

    if (t - s > 0) {
	const STRLEN len = t - s;
#ifndef USE_ITHREADS
	SV *const temp_sv = CopFILESV(PL_curcop);
	const char *cf;
	STRLEN tmplen;

	if (temp_sv) {
	    cf = SvPVX(temp_sv);
	    tmplen = SvCUR(temp_sv);
	} else {
	    cf = NULL;
	    tmplen = 0;
	}

	if (tmplen > 7 && strnEQ(cf, "(eval ", 6)) {
	    /* must copy *{"::_<(eval N)[oldfilename:L]"}
	     * to *{"::_<newfilename"} */
	    /* However, the long form of evals is only turned on by the
	       debugger - usually they're "(eval %lu)" */
	    char smallbuf[128];
	    char *tmpbuf;
	    GV **gvp;
	    STRLEN tmplen2 = len;
	    if (tmplen + 2 <= sizeof smallbuf)
		tmpbuf = smallbuf;
	    else
		Newx(tmpbuf, tmplen + 2, char);
	    tmpbuf[0] = '_';
	    tmpbuf[1] = '<';
	    memcpy(tmpbuf + 2, cf, tmplen);
	    tmplen += 2;
	    gvp = (GV**)hv_fetch(PL_defstash, tmpbuf, tmplen, FALSE);
	    if (gvp) {
		char *tmpbuf2;
		GV *gv2;

		if (tmplen2 + 2 <= sizeof smallbuf)
		    tmpbuf2 = smallbuf;
		else
		    Newx(tmpbuf2, tmplen2 + 2, char);

		if (tmpbuf2 != smallbuf || tmpbuf != smallbuf) {
		    /* Either they malloc'd it, or we malloc'd it,
		       so no prefix is present in ours.  */
		    tmpbuf2[0] = '_';
		    tmpbuf2[1] = '<';
		}

		memcpy(tmpbuf2 + 2, s, tmplen2);
		tmplen2 += 2;

		gv2 = *(GV**)hv_fetch(PL_defstash, tmpbuf2, tmplen2, TRUE);
		if (!isGV(gv2)) {
		    gv_init(gv2, PL_defstash, tmpbuf2, tmplen2, FALSE);
		    /* adjust ${"::_<newfilename"} to store the new file name */
		    GvSV(gv2) = newSVpvn(tmpbuf2 + 2, tmplen2 - 2);
		    GvHV(gv2) = (HV*)SvREFCNT_inc(GvHV(*gvp));
		    GvAV(gv2) = (AV*)SvREFCNT_inc(GvAV(*gvp));
		}

		if (tmpbuf2 != smallbuf) Safefree(tmpbuf2);
	    }
	    if (tmpbuf != smallbuf) Safefree(tmpbuf);
	}
#endif
	CopFILE_free(PL_curcop);
	CopFILE_setn(PL_curcop, s, len);
    }
    CopLINE_set(PL_curcop, atoi(n)-1);
}

#ifdef PERL_MAD
/* skip space before PL_thistoken */

STATIC char *
S_skipspace0(pTHX_ register char *s)
{
    PERL_ARGS_ASSERT_SKIPSPACE0;

    s = skipspace(s);
    if (!PL_madskills)
	return s;
    if (PL_skipwhite) {
	if (!PL_thiswhite)
	    PL_thiswhite = newSVpvs("");
	sv_catsv(PL_thiswhite, PL_skipwhite);
	sv_free(PL_skipwhite);
	PL_skipwhite = 0;
    }
    PL_realtokenstart = s - SvPVX(PL_linestr);
    return s;
}

/* skip space after PL_thistoken */

STATIC char *
S_skipspace1(pTHX_ register char *s)
{
    const char *start = s;
    I32 startoff = start - SvPVX(PL_linestr);

    PERL_ARGS_ASSERT_SKIPSPACE1;

    s = skipspace(s);
    if (!PL_madskills)
	return s;
    start = SvPVX(PL_linestr) + startoff;
    if (!PL_thistoken && PL_realtokenstart >= 0) {
	const char * const tstart = SvPVX(PL_linestr) + PL_realtokenstart;
	PL_thistoken = newSVpvn(tstart, start - tstart);
    }
    PL_realtokenstart = -1;
    if (PL_skipwhite) {
	if (!PL_nextwhite)
	    PL_nextwhite = newSVpvs("");
	sv_catsv(PL_nextwhite, PL_skipwhite);
	sv_free(PL_skipwhite);
	PL_skipwhite = 0;
    }
    return s;
}

STATIC char *
S_skipspace2(pTHX_ register char *s, SV **svp)
{
    char *start;
    const I32 bufptroff = PL_bufptr - SvPVX(PL_linestr);
    const I32 startoff = s - SvPVX(PL_linestr);

    PERL_ARGS_ASSERT_SKIPSPACE2;

    s = skipspace(s);
    PL_bufptr = SvPVX(PL_linestr) + bufptroff;
    if (!PL_madskills || !svp)
	return s;
    start = SvPVX(PL_linestr) + startoff;
    if (!PL_thistoken && PL_realtokenstart >= 0) {
	char * const tstart = SvPVX(PL_linestr) + PL_realtokenstart;
	PL_thistoken = newSVpvn(tstart, start - tstart);
	PL_realtokenstart = -1;
    }
    if (PL_skipwhite) {
	if (!*svp)
	    *svp = newSVpvs("");
	sv_setsv(*svp, PL_skipwhite);
	sv_free(PL_skipwhite);
	PL_skipwhite = 0;
    }
    
    return s;
}
#endif

STATIC void
S_update_debugger_info(pTHX_ SV *orig_sv, const char *const buf, STRLEN len)
{
    AV *av = CopFILEAVx(PL_curcop);
    if (av) {
	SV * const sv = newSV_type(SVt_PVMG);
	if (orig_sv)
	    sv_setsv(sv, orig_sv);
	else
	    sv_setpvn(sv, buf, len);
	(void)SvIOK_on(sv);
	SvIV_set(sv, 0);
	av_store(av, (I32)CopLINE(PL_curcop), sv);
    }
}

/*
 * S_skipspace
 * Called to gobble the appropriate amount and type of whitespace.
 * Skips comments as well.
 */

STATIC char *
S_skipspace(pTHX_ register char *s)
{
    dVAR;
#ifdef PERL_MAD
    int curoff;
    int startoff = s - SvPVX(PL_linestr);

    PERL_ARGS_ASSERT_SKIPSPACE;

    if (PL_skipwhite) {
	sv_free(PL_skipwhite);
	PL_skipwhite = 0;
    }
#endif
    PERL_ARGS_ASSERT_SKIPSPACE;

    for (;;) {
	STRLEN prevlen;
	SSize_t oldprevlen, oldoldprevlen;
	SSize_t oldloplen = 0, oldunilen = 0;
	while (s < PL_bufend && isSPACE(*s)) {
	    if (*s++ == '\n' && PL_in_eval && !PL_rsfp)
		incline(s);
	}

	/* comment */
	if (s < PL_bufend && *s == '#') {
	    while (s < PL_bufend && *s != '\n')
		s++;
	    if (s < PL_bufend) {
		s++;
		if (PL_in_eval && !PL_rsfp) {
		    incline(s);
		    continue;
		}
	    }
	}

	/* only continue to recharge the buffer if we're at the end
	 * of the buffer, we're not reading from a source filter, and
	 * we're in normal lexing mode
	 */
	if (s < PL_bufend || !PL_rsfp || PL_sublex_info.sub_inwhat)
#ifdef PERL_MAD
	    goto done;
#else
	    return s;
#endif

	/* try to recharge the buffer */
#ifdef PERL_MAD
	curoff = s - SvPVX(PL_linestr);
#endif

	if ((s = filter_gets(PL_linestr, PL_rsfp,
			     (prevlen = SvCUR(PL_linestr)))) == NULL)
	{
#ifdef PERL_MAD
	    if (PL_madskills && curoff != startoff) {
		if (!PL_skipwhite)
		    PL_skipwhite = newSVpvs("");
		sv_catpvn(PL_skipwhite, SvPVX(PL_linestr) + startoff,
					curoff - startoff);
	    }

	    /* mustn't throw out old stuff yet if madpropping */
	    SvCUR(PL_linestr) = curoff;
	    s = SvPVX(PL_linestr) + curoff;
	    *s = 0;
	    if (curoff && s[-1] == '\n')
		s[-1] = ' ';
#endif

	    /* end of file.  Add on the -p or -n magic */
	    /* XXX these shouldn't really be added here, can't set PL_faketokens */
	    if (PL_minus_p) {
#ifdef PERL_MAD
		sv_catpvs(PL_linestr,
			 ";}continue{print or die qq(-p destination: $!\\n);}");
#else
		sv_setpvs(PL_linestr,
			 ";}continue{print or die qq(-p destination: $!\\n);}");
#endif
		PL_minus_n = PL_minus_p = 0;
	    }
	    else if (PL_minus_n) {
#ifdef PERL_MAD
		sv_catpvn(PL_linestr, ";}", 2);
#else
		sv_setpvn(PL_linestr, ";}", 2);
#endif
		PL_minus_n = 0;
	    }
	    else
#ifdef PERL_MAD
		sv_catpvn(PL_linestr,";", 1);
#else
		sv_setpvn(PL_linestr,";", 1);
#endif

	    /* reset variables for next time we lex */
	    PL_oldoldbufptr = PL_oldbufptr = PL_bufptr = s = PL_linestart
		= SvPVX(PL_linestr)
#ifdef PERL_MAD
		+ curoff
#endif
		;
	    PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
	    PL_last_lop = PL_last_uni = NULL;

	    /* Close the filehandle.  Could be from
	     * STDIN, or a regular file.  If we were reading code from
	     * STDIN (because the commandline held no -e or filename)
	     * then we don't close it, we reset it so the code can
	     * read from STDIN too.
	     */

	    if ((PerlIO*)PL_rsfp == PerlIO_stdin())
		PerlIO_clearerr(PL_rsfp);
	    else
		(void)PerlIO_close(PL_rsfp);
	    PL_rsfp = NULL;
	    return s;
	}

	/* not at end of file, so we only read another line */
	/* make corresponding updates to old pointers, for yyerror() */
	oldprevlen = PL_oldbufptr - PL_bufend;
	oldoldprevlen = PL_oldoldbufptr - PL_bufend;
	if (PL_last_uni)
	    oldunilen = PL_last_uni - PL_bufend;
	if (PL_last_lop)
	    oldloplen = PL_last_lop - PL_bufend;
	PL_linestart = PL_bufptr = s + prevlen;
	PL_bufend = s + SvCUR(PL_linestr);
	s = PL_bufptr;
	PL_oldbufptr = s + oldprevlen;
	PL_oldoldbufptr = s + oldoldprevlen;
	if (PL_last_uni)
	    PL_last_uni = s + oldunilen;
	if (PL_last_lop)
	    PL_last_lop = s + oldloplen;
	incline(s);

	/* debugger active and we're not compiling the debugger code,
	 * so store the line into the debugger's array of lines
	 */
	if (PERLDB_LINE && PL_curstash != PL_debstash)
	    update_debugger_info(NULL, PL_bufptr, PL_bufend - PL_bufptr);
    }

#ifdef PERL_MAD
  done:
    if (PL_madskills) {
	if (!PL_skipwhite)
	    PL_skipwhite = newSVpvs("");
	curoff = s - SvPVX(PL_linestr);
	if (curoff - startoff)
	    sv_catpvn(PL_skipwhite, SvPVX(PL_linestr) + startoff,
				curoff - startoff);
    }
    return s;
#endif
}

/*
 * S_check_uni
 * Check the unary operators to ensure there's no ambiguity in how they're
 * used.  An ambiguous piece of code would be:
 *     rand + 5
 * This doesn't mean rand() + 5.  Because rand() is a unary operator,
 * the +5 is its argument.
 */

STATIC void
S_check_uni(pTHX)
{
    dVAR;
    const char *s;
    const char *t;

    if (PL_oldoldbufptr != PL_last_uni)
	return;
    while (isSPACE(*PL_last_uni))
	PL_last_uni++;
    s = PL_last_uni;
    while (isALNUM_lazy_if(s,UTF) || *s == '-')
	s++;
    if ((t = strchr(s, '(')) && t < PL_bufptr)
	return;

    if (ckWARN_d(WARN_AMBIGUOUS)){
        Perl_warner(aTHX_ packWARN(WARN_AMBIGUOUS),
		   "Warning: Use of \"%.*s\" without parentheses is ambiguous",
		   (int)(s - PL_last_uni), PL_last_uni);
    }
}

/*
 * LOP : macro to build a list operator.  Its behaviour has been replaced
 * with a subroutine, S_lop() for which LOP is just another name.
 */

#define LOP(f,x) return lop(f,x,s)

/*
 * S_lop
 * Build a list operator (or something that might be one).  The rules:
 *  - if we have a next token, then it's a list operator [why?]
 *  - if the next thing is an opening paren, then it's a function
 *  - else it's a list operator
 */

STATIC I32
S_lop(pTHX_ I32 f, int x, char *s)
{
    dVAR;

    PERL_ARGS_ASSERT_LOP;

    pl_yylval.ival = f;
    CLINE;
    PL_expect = x;
    PL_bufptr = s;
    PL_last_lop = PL_oldbufptr;
    PL_last_lop_op = (OPCODE)f;
#ifdef PERL_MAD
    if (PL_lasttoke)
 	return REPORT(LSTOP);
#else
    if (PL_nexttoke)
	return REPORT(LSTOP);
#endif
    if (*s == '(')
	return REPORT(FUNC);
    s = PEEKSPACE(s);
    if (*s == '(')
	return REPORT(FUNC);
    else
	return REPORT(LSTOP);
}

#ifdef PERL_MAD
 /*
 * S_start_force
 * Sets up for an eventual force_next().  start_force(0) basically does
 * an unshift, while start_force(-1) does a push.  yylex removes items
 * on the "pop" end.
 */

STATIC void
S_start_force(pTHX_ int where)
{
    int i;

    if (where < 0)	/* so people can duplicate start_force(PL_curforce) */
	where = PL_lasttoke;
    assert(PL_curforce < 0 || PL_curforce == where);
    if (PL_curforce != where) {
	for (i = PL_lasttoke; i > where; --i) {
	    PL_nexttoke[i] = PL_nexttoke[i-1];
	}
	PL_lasttoke++;
    }
    if (PL_curforce < 0)	/* in case of duplicate start_force() */
	Zero(&PL_nexttoke[where], 1, NEXTMADTOKE);
    PL_curforce = where;
    if (PL_nextwhite) {
	if (PL_madskills)
	    curmad('^', newSVpvs(""));
	CURMAD('_', PL_nextwhite);
    }
}

STATIC void
S_curmad(pTHX_ char slot, SV *sv)
{
    MADPROP **where;

    if (!sv)
	return;
    if (PL_curforce < 0)
	where = &PL_thismad;
    else
	where = &PL_nexttoke[PL_curforce].next_mad;

    if (PL_faketokens)
	sv_setpvn(sv, "", 0);

    /* keep a slot open for the head of the list? */
    if (slot != '_' && *where && (*where)->mad_key == '^') {
	(*where)->mad_key = slot;
	sv_free((SV*)((*where)->mad_val));
	(*where)->mad_val = (void*)sv;
    }
    else
	addmad(newMADsv(slot, sv), where, 0);
}
#else
#  define start_force(where)    NOOP
#  define curmad(slot, sv)      NOOP
#endif

/*
 * S_force_next
 * When the lexer realizes it knows the next token (for instance,
 * it is reordering tokens for the parser) then it can call S_force_next
 * to know what token to return the next time the lexer is called.  Caller
 * will need to set PL_nextval[] (or PL_nexttoke[].next_val with PERL_MAD),
 * and possibly PL_expect to ensure the lexer handles the token correctly.
 */

STATIC void
S_force_next(pTHX_ I32 type)
{
    dVAR;
#ifdef DEBUGGING
    if (DEBUG_T_TEST) {
        PerlIO_printf(Perl_debug_log, "### forced token:\n");
	tokereport(type, &NEXTVAL_NEXTTOKE);
    }
#endif
#ifdef PERL_MAD
    if (PL_curforce < 0)
	start_force(PL_lasttoke);
    PL_nexttoke[PL_curforce].next_type = type;
    if (PL_lex_state != LEX_KNOWNEXT)
 	PL_lex_defer = PL_lex_state;
    PL_lex_state = LEX_KNOWNEXT;
    PL_lex_expect = PL_expect;
    PL_curforce = -1;
#else
    PL_nexttype[PL_nexttoke] = type;
    PL_nexttoke++;
    if (PL_lex_state != LEX_KNOWNEXT) {
	PL_lex_defer = PL_lex_state;
	PL_lex_expect = PL_expect;
	PL_lex_state = LEX_KNOWNEXT;
    }
#endif
}

/*
 * S_force_word
 * When the lexer knows the next thing is a word (for instance, it has
 * just seen -> and it knows that the next char is a word char, then
 * it calls S_force_word to stick the next word into the PL_nexttoke/val
 * lookahead.
 *
 * Arguments:
 *   char *start : buffer position (must be within PL_linestr)
 *   int token   : PL_next* will be this type of bare word (e.g., METHOD,WORD)
 *   int check_keyword : if true, Perl checks to make sure the word isn't
 *       a keyword (do this if the word is a label, e.g. goto FOO)
 *   int allow_pack : if true, : characters will also be allowed (require,
 *       use, etc. do this)
 *   int allow_initial_tick : used by the "sub" lexer only.
 */

STATIC char *
S_force_word(pTHX_ register char *start, int token, int check_keyword, int allow_pack, int allow_initial_tick)
{
    dVAR;
    register char *s;
    STRLEN len;

    PERL_ARGS_ASSERT_FORCE_WORD;

    start = SKIPSPACE1(start);
    s = start;
    if (isIDFIRST_lazy_if(s,UTF) ||
	(allow_pack && *s == ':') ||
	(allow_initial_tick && *s == '\'') )
    {
	s = scan_word(s, PL_tokenbuf, sizeof PL_tokenbuf, allow_pack, &len);
	if (check_keyword && keyword(PL_tokenbuf, len, 0))
	    return start;
	start_force(PL_curforce);
	if (PL_madskills)
	    curmad('X', newSVpvn(start,s-start));
	if (token == METHOD) {
	    s = SKIPSPACE1(s);
	    if (*s == '(')
		PL_expect = XTERM;
	    else {
		PL_expect = XOPERATOR;
	    }
	}
	if (PL_madskills)
	    curmad('g', newSVpvs( "forced" ));
	NEXTVAL_NEXTTOKE.opval
	    = (OP*)newSVOP(OP_CONST,0,
			   newSVpvn(PL_tokenbuf, len));
	NEXTVAL_NEXTTOKE.opval->op_private |= OPpCONST_BARE;
	force_next(token);
    }
    return s;
}

/*
 * S_force_ident
 * Called when the lexer wants $foo *foo &foo etc, but the program
 * text only contains the "foo" portion.  The first argument is a pointer
 * to the "foo", and the second argument is the type symbol to prefix.
 * Forces the next token to be a "WORD".
 * Creates the symbol if it didn't already exist (via gv_fetchpv()).
 */

STATIC void
S_force_ident(pTHX_ register const char *s, int kind)
{
    dVAR;

    PERL_ARGS_ASSERT_FORCE_IDENT;

    if (*s) {
	const STRLEN len = strlen(s);
	OP* const o = (OP*)newSVOP(OP_CONST, 0, newSVpvn(s, len));
	start_force(PL_curforce);
	NEXTVAL_NEXTTOKE.opval = o;
	force_next(WORD);
	if (kind) {
	    o->op_private = OPpCONST_ENTERED;
	    /* XXX see note in pp_entereval() for why we forgo typo
	       warnings if the symbol must be introduced in an eval.
	       GSAR 96-10-12 */
	    gv_fetchpvn_flags(s, len,
			      PL_in_eval ? (GV_ADDMULTI | GV_ADDINEVAL)
			      : GV_ADD,
			      kind == '$' ? SVt_PV :
			      kind == '@' ? SVt_PVAV :
			      kind == '%' ? SVt_PVHV :
			      SVt_PVGV
			      );
	}
    }
}

/*
 * S_force_version
 * Forces the next token to be a version number.
 * Emits a NULL token if there there isn't a version.
 */

STATIC char *
S_force_version(pTHX_ char *s)
{
    dVAR;
    OP *version = NULL;
    const char *d;
#ifdef PERL_MAD
    I32 startoff = s - SvPVX(PL_linestr);
#endif

    PERL_ARGS_ASSERT_FORCE_VERSION;

    s = SKIPSPACE1(s);

    d = s;
    if (*d == 'v' && isDIGIT(d[1])) {
	SV *sv;

	sv = newSV(5); /* preallocate storage space */
	s = scan_vstring(s, PL_bufend, sv);
	version = newSVOP(OP_CONST, 0, sv);
    }

    /* NOTE: The parser sees the package name and the VERSION swapped */
    start_force(PL_curforce);
    NEXTVAL_NEXTTOKE.opval = version;
#ifdef PERL_MAD
    if (PL_madskills && !version) {
	sv_free(PL_nextwhite);	/* let next token collect whitespace */
	PL_nextwhite = 0;
	s = SvPVX(PL_linestr) + startoff;
    } else {
	curmad('X', newSVpvn(d,s-d));
    }
#endif
    force_next(THING);

    return s;
}

/*
 * S_tokeq
 * Tokenize a quoted string passed in as an SV.  It finds the next
 * chunk, up to end of string or a backslash.  It may make a new
 * SV containing that chunk (if HINT_NEW_STRING is on).  It also
 * turns \\ into \.
 */

STATIC SV *
S_tokeq(pTHX_ SV *sv)
{

    PERL_ARGS_ASSERT_TOKEQ;

    if ( PL_hints & HINT_NEW_STRING )
       return new_constant(NULL, 0, "q", sv, sv, "q", 1);
    return sv;
}

/*
 * Now come three functions related to double-quote context,
 * S_sublex_start, S_sublex_push, and S_sublex_done.  They're used when
 * converting things like "\u\Lgnat" into ucfirst(lc("gnat")).  They
 * interact with PL_lex_state, and create fake ( ... ) argument lists
 * to handle functions and concatenation.
 * They assume that whoever calls them will be setting up a fake
 * join call, because each subthing puts a ',' after it.  This lets
 *   "lower \luPpEr"
 * become
 *  join($, , 'lower ', lcfirst( 'uPpEr', ) ,)
 *
 * (I'm not sure whether the spurious commas at the end of lcfirst's
 * arguments and join's arguments are created or not).
 */

/*
 * S_sublex_start
 * Assumes that pl_yylval.ival is the op we're creating (e.g. OP_LCFIRST).
 *
 * Pattern matching will set PL_lex_op to the pattern-matching op to
 * make (we return THING if pl_yylval.ival is OP_NULL, PMFUNC otherwise).
 *
 * OP_CONST is easy--just make the new op and return.
 *
 * Everything else becomes a FUNC.
 *
 * Sets PL_lex_state to LEX_INTERPPUSH unless (ival was OP_NULL or we
 * had an OP_CONST).  This just sets us up for a
 * call to S_sublex_push().
 */

STATIC I32
S_sublex_start(pTHX_ I32 op_type, OP* op)
{
    dVAR;
    pl_yylval.ival = op_type;

    if (op_type == OP_NULL) {
	pl_yylval.opval = op;
	PL_lex_op = NULL;
	return THING;
    }
    if (op_type == OP_CONST) {
	SV *sv = tokeq(PL_lex_stuff.str_sv);
	pl_yylval.opval = (OP*)newSVOP(op_type, 0, sv);
	PL_lex_stuff.str_sv = NULL;
	PL_lex_stuff.flags = 0;
	return THING;
    }
    else if (op_type == OP_BACKTICK && PL_lex_op) {
	/* readpipe() vas overriden */
	cSVOPx(cLISTOPx(cUNOPx(PL_lex_op)->op_first)->op_first->op_sibling)->op_sv = tokeq(PL_lex_stuff.str_sv);
	pl_yylval.opval = PL_lex_op;
	PL_lex_op = NULL;
	PL_lex_stuff.str_sv = NULL;
	PL_lex_stuff.flags = 0;
	return THING;
    }

    PL_sublex_info.super_state = PL_lex_state;
    PL_sublex_info.sub_inwhat = (U16)op_type;
    PL_sublex_info.sub_op = PL_lex_op;
    PL_lex_state = LEX_INTERPPUSH;

    PL_expect = XTERM;
    if (op) {
	pl_yylval.opval = PL_lex_op;
	PL_lex_op = NULL;
	return PMFUNC;
    }
    else
	return FUNC;
}

/*
 * S_sublex_push
 * Create a new scope to save the lexing state.  The scope will be
 * ended in S_sublex_done.  Returns a '(', starting the function arguments
 * to the uc, lc, etc. found before.
 * Sets PL_lex_state to LEX_INTERPCONCAT.
 */

STATIC I32
S_sublex_push(pTHX)
{
    dVAR;
    ENTER;

    PL_lex_state = PL_sublex_info.super_state;
    SAVEBOOL(PL_lex_dojoin);
    SAVEI32(PL_lex_brackets);
    SAVEI32(PL_lex_casemods);
    SAVEI32(PL_lex_starts);
    SAVEI8(PL_lex_state);
    SAVEI16(PL_lex_flags);
    SAVEI16(PL_lex_inwhat);
    SAVECOPLINE(PL_curcop);
    SAVEPPTR(PL_bufptr);
    SAVEPPTR(PL_bufend);
    SAVEPPTR(PL_oldbufptr);
    SAVEPPTR(PL_oldoldbufptr);
    SAVEPPTR(PL_last_lop);
    SAVEPPTR(PL_last_uni);
    SAVEPPTR(PL_linestart);
    SAVESPTR(PL_linestr);
    SAVEGENERICPV(PL_lex_brackstack);
    SAVEGENERICPV(PL_lex_casestack);

    PL_linestr = PL_lex_stuff.str_sv;
    PL_lex_stuff.str_sv = NULL;

    PL_bufend = PL_bufptr = PL_oldbufptr = PL_oldoldbufptr = PL_linestart
	= SvPVX(PL_linestr);
    PL_bufend += SvCUR(PL_linestr);
    PL_last_lop = PL_last_uni = NULL;
    SAVEFREESV(PL_linestr);

    PL_lex_dojoin = FALSE;
    PL_lex_brackets = 0;
    Newx(PL_lex_brackstack, 120, char);
    Newx(PL_lex_casestack, 12, char);
    PL_lex_casemods = 0;
    *PL_lex_casestack = '\0';
    PL_lex_starts = 0;
    PL_lex_state = LEX_INTERPCONCAT;
    CopLINE_set(PL_curcop, (line_t)PL_multi_start);

    PL_lex_inwhat = PL_sublex_info.sub_inwhat;
    PL_lex_flags = PL_lex_stuff.flags;
    if (PL_lex_inwhat == OP_MATCH || PL_lex_inwhat == OP_QR || PL_lex_inwhat == OP_SUBST) {
	PL_lex_flags |= LEXf_INPAT;
	if (((PMOP*)PL_sublex_info.sub_op)->op_pmflags & PMf_EXTENDED)
	    PL_lex_flags |= LEXf_EXT_PAT;
    }

    return '(';
}

/*
 * S_sublex_done
 * Restores lexer state after a S_sublex_push.
 */

STATIC I32
S_sublex_done(pTHX)
{
    dVAR;
    if (!PL_lex_starts++) {
	SV * const sv = newSVpvs("");
	PL_expect = XOPERATOR;
	pl_yylval.opval = (OP*)newSVOP(OP_CONST, 0, sv);
	return THING;
    }

    if (PL_lex_casemods) {		/* oops, we've got some unbalanced parens */
	PL_lex_state = LEX_INTERPCASEMOD;
	return yylex();
    }

    /* Is there a right-hand side to take care of? (s//RHS/ or tr//RHS/) */
    if (PL_lex_repl.str_sv && (PL_lex_inwhat == OP_SUBST || PL_lex_inwhat == OP_TRANS)) {
	PL_linestr = PL_lex_repl.str_sv;
	PL_lex_stuff.flags = PL_lex_repl.flags;
	PL_lex_repl.flags = 0;
	PL_lex_flags = 0;
	PL_bufend = PL_bufptr = PL_oldbufptr = PL_oldoldbufptr = PL_linestart = SvPVX(PL_linestr);
	PL_bufend += SvCUR(PL_linestr);
	PL_last_lop = PL_last_uni = NULL;
	SAVEFREESV(PL_linestr);
	PL_lex_dojoin = FALSE;
	PL_lex_brackets = 0;
	PL_lex_casemods = 0;
	*PL_lex_casestack = '\0';
	PL_lex_starts = 0;
	PL_lex_state = LEX_INTERPCONCAT;
	PL_lex_repl.str_sv = NULL;
	return ',';
    }
    else {
#ifdef PERL_MAD
	if (PL_madskills) {
	    if (PL_thiswhite) {
		if (!PL_endwhite)
		    PL_endwhite = newSVpvs("");
		sv_catsv(PL_endwhite, PL_thiswhite);
		PL_thiswhite = 0;
	    }
	    if (PL_thistoken)
		sv_setpvn(PL_thistoken,"",0);
	    else
		PL_realtokenstart = -1;
	}
#endif
	LEAVE;
	PL_bufend = SvPVX(PL_linestr);
	PL_bufend += SvCUR(PL_linestr);
	PL_expect = XOPERATOR;
	PL_sublex_info.sub_inwhat = 0;
	return ')';
    }
}

/*
  parse_escape

  's' points to the first escape character, i.e. the chracter _after_ the '\'
  'd' is a pointer to a pointer holding the value.
  the function returns the pointer after the escape sequence.

  'd' at most (s-send) chacters are written to 'd'
  'l' is updated the the number of bytes written to 'd'
  's' and '*d' might be the same.

*/
const char *
Perl_parse_escape(pTHX_ const char *s, char *d, STRLEN *l, const char *send)
{
    U32 uv;

    switch (*s) {

    default:
    {
	if ((isALPHA(*s) || isDIGIT(*s)) && ckWARN(WARN_MISC))
	    Perl_warner(aTHX_ packWARN(WARN_MISC),
			"Unrecognized escape \\%c passed through",
			*s);
	/* default action is to copy the quoted character */
	/* ignoring invalid UTF sequences */
	*d++ = *s++;
	*l = 1;
	while (UTF8_IS_CONTINUED(*s) && s < send) {
	    *d++ = *s++;
	    *l += 1;
	}
	return s;
    }

    /* \132 indicates an octal constant */
    case '0': case '1': case '2': case '3':
    case '4': case '5': case '6': case '7':
    {
	I32 flags = 0;
	STRLEN len = 3;
	uv = grok_oct(s, &len, &flags, NULL);
	s += len;
	*d = (char) uv;
	*l = 1;
	return s;
    }

    /* \x24 indicates a hex constant */
    case 'x':
	++s;
	if (*s == '[') {
	    /* \x[XX] insert byte XX */
	    char *const orgd = d;
	    char *const e = strchr(s, ']');
	    s++;
	    if (!e) {
		Perl_croak(aTHX_ "Missing right square bracket on \\x[]");
	    }
	    while ( s + 2 <= e ) {
		STRLEN len = 2;
		I32 flags = PERL_SCAN_DISALLOW_PREFIX;
		uv = grok_hex(s, &len, &flags, NULL);
		s += 2;
		*d++ = (char)uv;
	    }
	    if (s + 1 == e) {
		if (ckWARN(WARN_DIGIT))
		    Perl_warner(aTHX_ packWARN(WARN_DIGIT),
				"single hexadecimal digit '%c' ignored", *s);
		s++;
	    }
	    s += 1;
	    *l = d - orgd;
	    return s;
	}
	if (*s == '{') {
	    /* \x{XX} insert codepoint XX */
	    char* const e = strchr(s, '}');
	    I32 flags = PERL_SCAN_ALLOW_UNDERSCORES |
		PERL_SCAN_DISALLOW_PREFIX;
	    STRLEN len;

	    ++s;
	    if (!e) {
		Perl_croak(aTHX_ "Missing right brace on \\x{}");
	    }
	    len = e - s;
	    uv = grok_hex(s, &len, &flags, NULL);
	    s = e + 1;
	}
	else {
	    /* \xXX insert byte or codepoint depending on IN_CODEPOINTS */
	    STRLEN len = 2;
	    I32 flags = PERL_SCAN_DISALLOW_PREFIX;
	    uv = grok_hex(s, &len, &flags, NULL);
	    s += len;
	    if ( ! UNI_IS_INVARIANT(uv) )
		Perl_warner(aTHX_ packWARN(WARN_UTF8),
			    "\\xXX are assumed bytes");
	    *d = (char)uv;
	    *l = 1;
	    return s;
	}

      NUM_ESCAPE_INSERT:
	/* Insert oct or hex escaped character.
	 * There will always enough room in sv since such
	 * escapes will be longer than any UTF-8 sequence
	 * they can end up as. */
	
	/* We need to map to chars to ASCII before doing the tests
	   to cover EBCDIC
		*/
	if (!UNI_IS_INVARIANT(uv)) {
	    char *orgd = d;
	    d = uvchr_to_utf8(d, uv);
	    *l = d-orgd;
	}
	else {
	    *d = (char) uv;
	    *l = 1;
	}
	return s;
	
	/* \N{LATIN SMALL LETTER A} is a named character */
    case 'N':
	++s;
	if (*s == '{') {
	    const char* e = strchr(s, '}');
	    SV *res;
	    STRLEN len;
	    const char *str;
	    
	    if (!e || (e >= send)) {
		Perl_croak(aTHX_ "Missing right brace on \\N{}");
	    }
	    if (e > s + 2 && s[1] == 'U' && s[2] == '+') {
		/* \N{U+...} */
		I32 flags = PERL_SCAN_ALLOW_UNDERSCORES |
		    PERL_SCAN_DISALLOW_PREFIX;
		s += 3;
		len = e - s;
		uv = grok_hex(s, &len, &flags, NULL);
		if ( e > s && len != (STRLEN)(e - s) ) {
		    uv = 0xFFFD;
		}
		s = e + 1;
		goto NUM_ESCAPE_INSERT;
	    }
	    res = newSVpvn(s + 1, e - s - 1);
	    res = new_constant( NULL, 0, "charnames",
				res, NULL, s - 2, e - s + 3 );
	    str = SvPV_const(res,len);
	    if (len > (STRLEN)(e - s + 4)) { /* I _guess_ 4 is \N{} --jhi */
		Perl_croak(aTHX_ "panic: \\N{...} replacement too long");
	    }
	    Copy(str, d, len, char);
	    *l = len;
	    SvREFCNT_dec(res);
	    s = e + 1;
	}
	else
	    Perl_croak(aTHX_ "Missing braces on \\N{}");
	return s;

	/* \c is a control character */
    case 'c':
	s++;
	if (s < send) {
	    char c = *s++;
	    *d++ = NATIVE_TO_UNI(toCTRL(c));
	    *l = 1;
	}
	else {
	    Perl_croak(aTHX_ "Missing control char name in \\c");
	}
	return s;

	/* printf-style backslashes, formfeeds, newlines, etc */
    case 'b':
	*d++ = '\b';
	break;
    case 'n':
	*d++ = '\n';
	break;
    case 'r':
	*d++ = '\r';
	break;
    case 'f':
	*d++ = '\f';
	break;
    case 't':
	*d++ = '\t';
	break;
    case 'e':
	*d++ = ASCII_TO_UNI('\033');
	break;
    case 'a':
	*d++ = ASCII_TO_UNI('\007');
	break;
    } /* end switch */

    *l = 1;
    return s+1;
}

/*
  scan_const

  Extracts a pattern, double-quoted string, or transliteration.  This
  is terrifying code.

  It looks at PL_lex_inwhat and PL_lex_flags to find out whether it's
  processing a pattern (PL_lex_flags in_pat is true), a transliteration
  (PL_lex_inwhat == OP_TRANS is true), or a double-quoted string.

  Returns a pointer to the character scanned up to. If this is
  advanced from the start pointer supplied (i.e. if anything was
  successfully parsed), will leave an OP for the substring scanned
  in pl_yylval. Caller must intuit reason for not parsing further
  by looking at the next characters herself.

  In patterns:
    backslashes:
      double-quoted style: \r and \n
      regexp special ones: \D \s
      constants: \x31
      backrefs: \1
      case and quoting: \U \Q \E
    stops on @ and $, but not for $ as tail anchor

  In transliterations:
    characters are VERY literal, except for - not at the start or end
    of the string, which indicates a range. If the range is in bytes,
    scan_const expands the range to the full set of intermediate
    characters. If the range is in utf8, the hyphen is replaced with
    a certain range mark which will be handled by pmtrans() in op.c.

  In double-quoted strings:
    backslashes:
      double-quoted style: \r and \n
      constants: \x31
      deprecated backrefs: \1 (in substitution replacements)
      case and quoting: \U \Q \E
    stops on @ and $

  scan_const does *not* construct ops to handle interpolated strings.
  It stops processing as soon as it finds an embedded $ or @ variable
  and leaves it to the caller to work out what's going on.

  embedded arrays (whether in pattern or not) could be:
      @foo, @::foo, @'foo, @{foo}, @$foo, @+, @-.

  $ in double-quoted strings must be the symbol of an embedded scalar.

  $ in pattern could be $foo or could be tail anchor.  Assumption:
  it's a tail anchor if $ is the last thing in the string, or if it's
  followed by one of "()| \r\n\t"

  \1 (backreferences) are turned into $1

  The structure of the code is
      while (there's a character to process) {
	  handle transliteration ranges
	  skip regexp comments /(?#comment)/ and codes /(?{code})/
	  skip #-initiated comments in //x patterns
	  check for embedded arrays
	  check for embedded scalars
	  if (backslash) {
	      leave intact backslashes from leaveit (below)
	      deprecate \1 in substitution replacements
	      handle string-changing backslashes \l \U \Q \E, etc.
	      switch (what was escaped) {
		  handle \- in a transliteration (becomes a literal -)
		  handle \132 (octal characters)
		  handle \x15 and \x{1234} (hex characters)
		  handle \N{name} (named characters)
		  handle \cV (control characters)
		  handle printf-style backslashes (\f, \r, \n, etc)
	      } (end switch)
	  } (end if backslash)
    } (end while character to read)
		
*/


STATIC char *
S_scan_const(pTHX_ char *start)
{
    dVAR;
    register char *send = PL_bufend;		/* end of the constant */
    SV *sv = newSV(send - start);		/* sv for the constant */
    register char *s = start;			/* start of the constant */
    register char *d = SvPVX(sv);		/* destination for copies */
    bool dorange = FALSE;			/* are we in a translit range? */
    bool didrange = FALSE;		        /* did we just finish a range? */
    I32  has_utf8 = FALSE;			/* Output constant is UTF8 */
    bool in_codepoints = (IN_CODEPOINTS != 0);  /* PL_curtoken can be changed ?! */
    bool in_pat = ((PL_lex_flags & LEXf_INPAT) != 0);

    PERL_ARGS_ASSERT_SCAN_CONST;

    while (s < send || dorange) {
        /* get transliterations out of the way (they're most literal) */
	if (PL_lex_inwhat == OP_TRANS) {
	    /* expand a range A-Z to the full set of characters.  AIE! */
	    if (dorange) {
		I32 i;				/* current expanded character */
		I32 min;			/* first character in range */
		I32 max;			/* last character in range */


		if ( in_codepoints ) {
		    char * const c = (char*)utf8_hop(d, -1);
		    char *e = d++;
		    while (e-- > c)
			*(e + 1) = *e;
		    *c = (char)UTF_TO_NATIVE(0xff);
		    /* mark the range as done, and continue */
		    dorange = FALSE;
		    didrange = TRUE;
		    continue;
		}

		i = d - SvPVX_const(sv);		/* remember current offset */
		SvGROW(sv, SvLEN(sv) + 256);	/* never more than 256 chars in a range */
		d = SvPVX(sv) + i;		/* refresh d after realloc */

		d -= 2;		/* eat the first char and the - */
		min = (U8)*d;	/* first char in range */
		max = (U8)d[1];	/* last char in range  */

                if (min > max) {
		    Perl_croak(aTHX_
			       "Invalid range \"%c-%c\" in transliteration operator",
			       (char)min, (char)max);
                }

		for (i = min; i <= max; i++)
		    *d++ = (char)i;
 
		/* mark the range as done, and continue */
		dorange = FALSE;
		didrange = TRUE;
		continue;
	    }

	    /* range begins (ignore - as first or last char) */
	    else if (*s == '-' && s+1 < send  && s != start) {
		if (didrange) {
		    Perl_croak(aTHX_ "Ambiguous range in transliteration operator");
		}
		if (in_codepoints) {
		    *d++ = (char)UTF_TO_NATIVE(0xff);	/* use illegal utf8 byte--see pmtrans */
		    s++;
		    continue;
		}
		dorange = TRUE;
		s++;
	    }
	    else {
		didrange = FALSE;
	    }
	}

	/* if we get here, we're not doing a transliteration */

	/* skip for regexp comments /(?#comment)/ and code /(?{code})/,
	   except for the last char, which will be done separately. */
	else if (*s == '(' && in_pat && s[1] == '?') {
	    if (s[2] == '#') {
		while (s+1 < send && *s != ')')
		    *d++ = NATIVE_TO_UNI(*s++);
	    }
	    else if (s[2] == '{' /* This should match regcomp.c */
		    || (s[2] == '?' && s[3] == '{'))
	    {
		I32 count = 1;
		char *regparse = s + (s[2] == '{' ? 3 : 4);
		char c;

		while (count && (c = *regparse)) {
		    if (c == '\\' && regparse[1])
			regparse++;
		    else if (c == '{')
			count++;
		    else if (c == '}')
			count--;
		    regparse++;
		}
		if (*regparse != ')')
		    regparse--;		/* Leave one char for continuation. */
		while (s < regparse)
		    *d++ = NATIVE_TO_UNI(*s++);
	    }
	}

	/* likewise skip #-initiated comments in //x patterns */
	else if (*s == '#' && in_pat && (PL_lex_flags & LEXf_EXT_PAT)) {
	    while (s+1 < send && *s != '\n')
		*d++ = NATIVE_TO_UNI(*s++);
	}

	/* check for embedded arrays
	   (@foo, @::foo, @'foo, @{foo}, @$foo, @+, @-)
	   */
	else if (*s == '@' && s[1]) {
	    if (isALNUM_lazy_if(s+1,UTF))
		break;
	    if (strchr(":'{$", s[1]))
		break;
	    if (!in_pat && (s[1] == '+' || s[1] == '-'))
		break; /* in regexp, neither @+ nor @- are interpolated */
	}
	else if (*s == '%' && s[1]) {
	    if (isALNUM_lazy_if(s+1,UTF))
		break;
	    if (strchr(":'{$", s[1]))
		break;
	    if (!in_pat && (s[1] == '+' || s[1] == '-'))
		break; /* in regexp, neither %+ nor %- are interpolated */
	}

	/* check for embedded scalars.  only stop if we're sure it's a
	   variable.
        */
	else if (*s == '$') {
	    if (!in_pat)	/* not a regexp, so $ must be var */
		break;
	    if (s + 1 < send && !strchr("()| \r\n\t", s[1]))
		break;		/* in regexp, $ might be tail anchor */
	}

	/* embedded code */
	if ( (*s == '{' || *s == '}') && ! in_pat) {
	    break;
	}

	/* End of else if chain - OP_TRANS rejoin rest */

	/* backslashes */
	if (*s == '\\' && s+1 < send) {
	    s++;

	    /* deprecate \1 in strings and substitution replacements */
	    if (PL_lex_inwhat == OP_SUBST && !in_pat &&
		isDIGIT(*s) && *s != '0' && !isDIGIT(s[1]))
	    {
		if (ckWARN(WARN_SYNTAX))
		    Perl_warner(aTHX_ packWARN(WARN_SYNTAX), "\\%c better written as $%c", *s, *s);
		*--s = '$';
		break;
	    }

	    /* string-change backslash escapes */
/* 	    if (PL_lex_inwhat != OP_TRANS && *s && strchr("LUlu", *s)) { */
/* 		Perl_warner(packWARN(WARN_SYNTAX), "case modifiers have een removed"); */
/* 	    } */
	    if (PL_lex_inwhat != OP_TRANS && *s && strchr("lLuUEQ", *s)) {
		--s;
		break;
	    }
	    /* skip any other backslash escapes in a pattern */
	    else if (in_pat) {
		*d++ = NATIVE_TO_UNI('\\');
		goto default_action;
	    }

	    /* quoted - in transliterations */
	    if ((*s == '-') && (PL_lex_inwhat == OP_TRANS)) {
		*d++ = *s++;
		continue;
	    }

	    /* if we get here, it's either a quoted -, or a digit */
	    {
		STRLEN len;
		s = (char*)parse_escape(s, d, &len, send);
		d += len;
		continue;
	    }

	} /* end if (backslash) */

    default_action:
	if (!NATIVE_IS_INVARIANT((*s)) && ! IN_BYTES) {
	    STRLEN len;
	    utf8n_to_uvchr(s, send - s, &len, 0); /* validate UTF-8 */
	    has_utf8 = TRUE;
	    while (len--)
		*d++ = *s++;
	}
	else {
	    *d++ = NATIVE_TO_UNI(*s++);
	}
    } /* while loop to process each character */

    /* terminate the string and set up the sv */
    *d = '\0';
    SvCUR_set(sv, d - SvPVX_const(sv));
    if (SvCUR(sv) >= SvLEN(sv))
	Perl_croak(aTHX_ "panic: constant overflowed allocated space");

    SvPOK_on(sv);

    /* shrink the sv if we allocated more than we used */
    if (SvCUR(sv) + 5 < SvLEN(sv)) {
	SvPV_shrink_to_cur(sv);
    }

    /* return the substring (via pl_yylval) only if we parsed anything */
    if (s > PL_bufptr) {
	if ( PL_hints & ( in_pat ? HINT_NEW_RE : HINT_NEW_STRING ) ) {
	    const char *const key = in_pat ? "qr" : "q";
	    const STRLEN keylen = in_pat ? 2 : 1;
	    const char *type;
	    STRLEN typelen;

	    if (PL_lex_inwhat == OP_TRANS) {
		type = "tr";
		typelen = 2;
	    } else if (PL_lex_inwhat == OP_SUBST && !in_pat) {
		type = "s";
		typelen = 1;
	    } else  {
		type = "qq";
		typelen = 2;
	    }

	    sv = S_new_constant(aTHX_ start, s - start, key, keylen, sv, NULL,
				type, typelen);
	}
	pl_yylval.opval = (OP*)newSVOP(OP_CONST, 0, sv);
    } else
	SvREFCNT_dec(sv);

    return s;
}

/* S_intuit_more
 * Returns TRUE if there's more to the expression (e.g., a subscript),
 * FALSE otherwise.
 *
 * { and [ and ->[ and ->{ and ->@ return TRUE
 */

STATIC int
S_intuit_more(pTHX_ register char *s)
{
    dVAR;

    PERL_ARGS_ASSERT_INTUIT_MORE;

    if (PL_lex_brackets)
	return TRUE;
    if (*s == '-' && s[1] == '>' && (s[2] == '[' || s[2] == '{' || s[2] == '@'))
	return TRUE;
    if (*s != '{' && *s != '[')
	return FALSE;

    return TRUE;
}

/* Encoded script support. filter_add() effectively inserts a
 * 'pre-processing' function into the current source input stream.
 * Note that the filter function only applies to the current source file
 * (e.g., it will not affect files 'require'd or 'use'd by this one).
 *
 * The datasv parameter (which may be NULL) can be used to pass
 * private data to this instance of the filter. The filter function
 * can recover the SV using the FILTER_DATA macro and use it to
 * store private buffers and state information.
 *
 * The supplied datasv parameter is upgraded to a PVIO type
 * and the IoDIRP/IoANY field is used to store the function pointer,
 * and IOf_FAKE_DIRP is enabled on datasv to mark this as such.
 * Note that IoTOP_NAME, IoFMT_NAME, IoBOTTOM_NAME, if set for
 * private use must be set using malloc'd pointers.
 */

SV *
Perl_filter_add(pTHX_ filter_t funcp, SV *datasv)
{
    dVAR;
    if (!funcp)
	return NULL;

    if (!PL_parser)
	return NULL;

    if (!PL_rsfp_filters)
	PL_rsfp_filters = newAV();
    if (!datasv)
	datasv = newSV(0);
    SvUPGRADE(datasv, SVt_PVIO);
    IoANY(datasv) = FPTR2DPTR(void *, funcp); /* stash funcp into spare field */
    IoFLAGS(datasv) |= IOf_FAKE_DIRP;
    DEBUG_P(PerlIO_printf(Perl_debug_log, "filter_add func %p (%s)\n",
			  FPTR2DPTR(void *, IoANY(datasv)),
			  SvPV_nolen(datasv)));
    av_unshift(PL_rsfp_filters, 1);
    av_store(PL_rsfp_filters, 0, datasv) ;
    return(datasv);
}


/* Delete most recently added instance of this filter function.	*/
void
Perl_filter_del(pTHX_ filter_t funcp)
{
    dVAR;
    SV *datasv;

    PERL_ARGS_ASSERT_FILTER_DEL;

#ifdef DEBUGGING
    DEBUG_P(PerlIO_printf(Perl_debug_log, "filter_del func %p",
			  FPTR2DPTR(void*, funcp)));
#endif
    if (!PL_parser || !PL_rsfp_filters || AvFILLp(PL_rsfp_filters)<0)
	return;
    /* if filter is on top of stack (usual case) just pop it off */
    datasv = FILTER_DATA(AvFILLp(PL_rsfp_filters));
    if (IoANY(datasv) == FPTR2DPTR(void *, funcp)) {
	IoFLAGS(datasv) &= ~IOf_FAKE_DIRP;
	IoANY(datasv) = (void *)NULL;
	sv_free(av_pop(PL_rsfp_filters));

        return;
    }
    /* we need to search for the correct entry and clear it	*/
    Perl_croak(aTHX_ "filter_del can only delete in reverse order (currently)");
}


/* Invoke the idxth filter function for the current rsfp.	 */
/* maxlen 0 = read one text line */
I32
Perl_filter_read(pTHX_ int idx, SV *buf_sv, int maxlen)
{
    dVAR;
    filter_t funcp;
    SV *datasv = NULL;
    /* This API is bad. It should have been using unsigned int for maxlen.
       Not sure if we want to change the API, but if not we should sanity
       check the value here.  */
    const unsigned int correct_length
	= maxlen < 0 ?
#ifdef PERL_MICRO
	0x7FFFFFFF
#else
	INT_MAX
#endif
	: maxlen;

    PERL_ARGS_ASSERT_FILTER_READ;

    if (!PL_parser || !PL_rsfp_filters)
	return -1;
    if (idx > AvFILLp(PL_rsfp_filters)) {       /* Any more filters?	*/
	/* Provide a default input filter to make life easy.	*/
	/* Note that we append to the line. This is handy.	*/
	DEBUG_P(PerlIO_printf(Perl_debug_log,
			      "filter_read %d: from rsfp\n", idx));
	if (correct_length) {
 	    /* Want a block */
	    int len ;
	    const int old_len = SvCUR(buf_sv);

	    /* ensure buf_sv is large enough */
	    SvGROW(buf_sv, (STRLEN)(old_len + correct_length)) ;
	    if ((len = PerlIO_read(PL_rsfp, SvPVX(buf_sv) + old_len,
				   correct_length)) <= 0) {
		if (PerlIO_error(PL_rsfp))
	            return -1;		/* error */
	        else
		    return 0 ;		/* end of file */
	    }
	    SvCUR_set(buf_sv, old_len + len) ;
	} else {
	    /* Want a line */
            if (sv_gets(buf_sv, PL_rsfp, SvCUR(buf_sv)) == NULL) {
		if (PerlIO_error(PL_rsfp))
	            return -1;		/* error */
	        else
		    return 0 ;		/* end of file */
	    }
	}
	return SvCUR(buf_sv);
    }
    /* Skip this filter slot if filter has been deleted	*/
    if ( (datasv = FILTER_DATA(idx)) == &PL_sv_undef) {
	DEBUG_P(PerlIO_printf(Perl_debug_log,
			      "filter_read %d: skipped (filter deleted)\n",
			      idx));
	return FILTER_READ(idx+1, buf_sv, correct_length); /* recurse */
    }
    /* Get function pointer hidden within datasv	*/
    funcp = DPTR2FPTR(filter_t, IoANY(datasv));
    DEBUG_P(PerlIO_printf(Perl_debug_log,
			  "filter_read %d: via function %p (%s)\n",
			  idx, (void*)datasv, SvPV_nolen_const(datasv)));
    /* Call function. The function is expected to 	*/
    /* call "FILTER_READ(idx+1, buf_sv)" first.		*/
    /* Return: <0:error, =0:eof, >0:not eof 		*/
    return (*funcp)(aTHX_ idx, buf_sv, correct_length);
}

STATIC char *
S_filter_gets(pTHX_ register SV *sv, register PerlIO *fp, STRLEN append)
{
    dVAR;

    PERL_ARGS_ASSERT_FILTER_GETS;

#ifdef PERL_CR_FILTER
    if (!PL_rsfp_filters) {
	filter_add(S_cr_textfilter,NULL);
    }
#endif
    if (PL_rsfp_filters) {
	if (!append)
            SvCUR_set(sv, 0);	/* start with empty line	*/
        if (FILTER_READ(0, sv, 0) > 0)
            return ( SvPVX(sv) ) ;
        else
	    return NULL ;
    }
    else
        return (sv_gets(sv, fp, append));
}

/*
 * S_readpipe_override
 * Check whether readpipe() is overriden, and generates the appropriate
 * optree, provided sublex_start() is called afterwards.
 */
STATIC void
S_readpipe_override(pTHX)
{
    GV **gvp;
    GV *gv_readpipe = gv_fetchpvs("readpipe", GV_NOTQUAL, SVt_PVCV);
    pl_yylval.ival = OP_BACKTICK;
    if ((gv_readpipe
		&& GvCVu(gv_readpipe) && GvIMPORTED_CV(gv_readpipe))
	    ||
	    ((gvp = (GV**)hv_fetchs(PL_globalstash, "readpipe", FALSE))
	     && (gv_readpipe = *gvp) && isGV_with_GP(gv_readpipe)
	     && GvCVu(gv_readpipe) && GvIMPORTED_CV(gv_readpipe)))
    {
	PL_lex_op = (OP*)newUNOP(OP_ENTERSUB, OPf_STACKED,
	    append_elem(OP_LIST,
		newSVOP(OP_CONST, 0, &PL_sv_undef), /* value will be read later */
		newCVREF(0, newGVOP(OP_GV, 0, gv_readpipe))));
    }
}

#ifdef PERL_MAD 
 /*
 * Perl_madlex
 * The intent of this yylex wrapper is to minimize the changes to the
 * tokener when we aren't interested in collecting madprops.  It remains
 * to be seen how successful this strategy will be...
 */

int
Perl_madlex(pTHX)
{
    int optype;
    char *s = PL_bufptr;

    /* make sure PL_thiswhite is initialized */
    PL_thiswhite = 0;
    PL_thismad = 0;

    /* just do what yylex would do on pending identifier; leave PL_thiswhite alone */
    if (PL_pending_ident)
        return S_pending_ident(aTHX);

    /* previous token ate up our whitespace? */
    if (!PL_lasttoke && PL_nextwhite) {
	PL_thiswhite = PL_nextwhite;
	PL_nextwhite = 0;
    }

    /* isolate the token, and figure out where it is without whitespace */
    PL_realtokenstart = -1;
    PL_thistoken = 0;
    optype = yylex();
    s = PL_bufptr;
    assert(PL_curforce < 0);

    if (!PL_thismad || PL_thismad->mad_key == '^') {	/* not forced already? */
	if (!PL_thistoken) {
	    if (PL_realtokenstart < 0 || !CopLINE(PL_curcop))
		PL_thistoken = newSVpvs("");
	    else {
		char * const tstart = SvPVX(PL_linestr) + PL_realtokenstart;
		PL_thistoken = newSVpvn(tstart, s - tstart);
	    }
	}
	if (PL_thismad)	/* install head */
	    CURMAD('X', PL_thistoken);
    }

    /* last whitespace of a sublex? */
    if (optype == ')' && PL_endwhite) {
	CURMAD('X', PL_endwhite);
    }

    if (!PL_thismad) {

	/* if no whitespace and we're at EOF, bail.  Otherwise fake EOF below. */
	if (!PL_thiswhite && !PL_endwhite && !optype) {
	    sv_free(PL_thistoken);
	    PL_thistoken = 0;
	    return 0;
	}

	/* put off final whitespace till peg */
	if (optype == ';' && !PL_rsfp) {
	    PL_nextwhite = PL_thiswhite;
	    PL_thiswhite = 0;
	}
	else if (PL_thisopen) {
	    curmad('<', newSVpv("quote", 0));
	    CURMAD('q', PL_thisopen);
	    if (PL_thistoken)
		sv_free(PL_thistoken);
	    PL_thistoken = 0;
	}
	else {
	    /* Store actual token text as madprop X */
	    CURMAD('X', PL_thistoken);
	}

	if (PL_thiswhite) {
	    /* add preceding whitespace as madprop _ */
	    CURMAD('_', PL_thiswhite);
	}

	if (PL_thisstuff) {
	    /* add quoted material as madprop = */
	    CURMAD('=', PL_thisstuff);
	}

	if (PL_thisclose) {
	    /* add terminating quote as madprop Q */
	    CURMAD('Q', PL_thisclose);
	}
    }

    /* special processing based on optype */

    switch (optype) {

    /* opval doesn't need a TOKEN since it can already store mp */
    case WORD:
    case METHOD:
    case THING:
    case PMFUNC:
    case PRIVATEREF:
    case FUNC0SUB:
    case UNIOPSUB:
    case LSTOPSUB:
	if (pl_yylval.opval)
	    append_madprops(PL_thismad, pl_yylval.opval, 0);
	PL_thismad = 0;
	return optype;

    /* fake EOF */
    case 0:
	optype = PEG;
	if (PL_endwhite) {
	    addmad(newMADsv('G', PL_endwhite), &PL_thismad, 0);
	    PL_endwhite = 0;
	}
	break;

    case ']':
    case '}':
	if (PL_faketokens)
	    break;
	/* remember any fake bracket that lexer is about to discard */ 
	if (PL_lex_brackets == 1 &&
	    ((expectation)PL_lex_brackstack[0] & XFAKEBRACK))
	{
	    s = PL_bufptr;
	    while (s < PL_bufend && (*s == ' ' || *s == '\t'))
		s++;
	    if (*s == '}') {
		PL_thiswhite = newSVpvn(PL_bufptr, ++s - PL_bufptr);
		addmad(newMADsv('#', PL_thiswhite), &PL_thismad, 0);
		PL_thiswhite = 0;
		PL_bufptr = s - 1;
		break;	/* don't bother looking for trailing comment */
	    }
	    else
		s = PL_bufptr;
	}
	if (optype == ']')
	    break;
	/* FALLTHROUGH */

    /* attach a trailing comment to its statement instead of next token */
    case ';':
	if (PL_faketokens)
	    break;
	if (PL_bufptr > PL_oldbufptr && PL_bufptr[-1] == optype) {
	    s = PL_bufptr;
	    while (s < PL_bufend && (*s == ' ' || *s == '\t'))
		s++;
	    if (*s == '\n' || *s == '#') {
		while (s < PL_bufend && *s != '\n')
		    s++;
		if (s < PL_bufend)
		    s++;
		PL_thiswhite = newSVpvn(PL_bufptr, s - PL_bufptr);
		addmad(newMADsv('#', PL_thiswhite), &PL_thismad, 0);
		PL_thiswhite = 0;
		PL_bufptr = s;
	    }
	}
	break;

    /* pval */
    case LABEL:
	break;

    /* ival */
    default:
	break;

    }

    /* Create new token struct.  Note: opvals return early above. */
    pl_yylval.tkval = newMADTOKEN(optype, pl_yylval, PL_thismad);
    PL_thismad = 0;
    return optype;
}
#endif

STATIC char *
S_tokenize_use(pTHX_ int is_use, char *s) {
    dVAR;

    PERL_ARGS_ASSERT_TOKENIZE_USE;

    if (PL_expect != XSTATE)
	yyerror(Perl_form(aTHX_ "\"%s\" not allowed in expression",
		    is_use ? "use" : "no"));
    s = SKIPSPACE1(s);
    if (isDIGIT(*s) || (*s == 'v' && isDIGIT(s[1])))
	Perl_croak(aTHX_ "use VERSION is not valid in Perl Kurila (this is probably Perl 5 code)");
    s = force_word(s,WORD,FALSE,TRUE,FALSE);
    s = force_version(s);
    pl_yylval.ival = is_use;
    return s;
}
#ifdef DEBUGGING
    static const char* const exp_name[] =
	{ "OPERATOR", "TERM", "REF", "STATE", "BLOCK", "ATTRBLOCK",
	  "ATTRTERM", "TERMBLOCK", "TERMORDORDOR"
	};
#endif

/*
  yylex

  Works out what to call the token just pulled out of the input
  stream.  The yacc parser takes care of taking the ops we return and
  stitching them into a tree.

  Returns:
    PRIVATEREF

  Structure:
      if read an identifier
          if we're in a my declaration
	      croak if they tried to say my($foo::bar)
	      build the ops for a my() declaration
	  if it's an access to a my() variable
	      are we in a sort block?
	          croak if my($a); $a <=> $b
	      build ops for access to a my() variable
	  if in a dq string, and they've said @foo and we can't find @foo
	      croak
	  build ops for a bareword
      if we already built the token before, use it.
*/


#ifdef __SC__
#pragma segment Perl_yylex
#endif
int
Perl_yylex(pTHX)
{
    dVAR;
    register char *s = PL_bufptr;
    register char *d;
    STRLEN len;
    bool bof = FALSE;

    /* orig_keyword, gvp, and gv are initialized here because
     * jump to the label just_a_word_zero can bypass their
     * initialization later. */
    I32 orig_keyword = 0;
    GV *gv = NULL;
    GV **gvp = NULL;

    DEBUG_T( {
	SV* tmp = newSVpvs("");
	PerlIO_printf(Perl_debug_log, "### %"IVdf":LEX_%s/X%s %s\n",
	    (IV)CopLINE(PL_curcop),
	    lex_state_names[PL_lex_state],
	    exp_name[PL_expect],
	    pv_display(tmp, s, strlen(s), 0, 60));
	SvREFCNT_dec(tmp);
    } );
    /* check if there's an identifier for us to look at */
    if (PL_pending_ident)
        return REPORT(S_pending_ident(aTHX));

    /* no identifier pending identification */

    switch (PL_lex_state) {
#ifdef COMMENTARY
    case LEX_NORMAL:		/* Some compilers will produce faster */
    case LEX_INTERPNORMAL:	/* code if we comment these out. */
	break;
#endif

    /* when we've already built the next token, just pull it out of the queue */
    case LEX_KNOWNEXT:
#ifdef PERL_MAD
	PL_lasttoke--;
	pl_yylval = PL_nexttoke[PL_lasttoke].next_val;
	if (PL_madskills) {
	    PL_thismad = PL_nexttoke[PL_lasttoke].next_mad;
	    PL_nexttoke[PL_lasttoke].next_mad = 0;
	    if (PL_thismad && PL_thismad->mad_key == '_') {
		PL_thiswhite = (SV*)PL_thismad->mad_val;
		PL_thismad->mad_val = 0;
		mad_free(PL_thismad);
		PL_thismad = 0;
	    }
	}
	if (!PL_lasttoke) {
	    PL_lex_state = PL_lex_defer;
  	    PL_expect = PL_lex_expect;
  	    PL_lex_defer = LEX_NORMAL;
	    if (!PL_nexttoke[PL_lasttoke].next_type)
		return yylex();
  	}
#else
	PL_nexttoke--;
	pl_yylval = PL_nextval[PL_nexttoke];
	if (!PL_nexttoke) {
	    PL_lex_state = PL_lex_defer;
	    PL_expect = PL_lex_expect;
	    PL_lex_defer = LEX_NORMAL;
	}
#endif
#ifdef PERL_MAD
	/* FIXME - can these be merged?  */
	return(PL_nexttoke[PL_lasttoke].next_type);
#else
	return REPORT(PL_nexttype[PL_nexttoke]);
#endif

    /* interpolated case modifiers like \L \U, including \Q and \E.
       when we get here, PL_bufptr is at the \
    */
    case LEX_INTERPCASEMOD:
#ifdef DEBUGGING
	if (PL_bufptr != PL_bufend && *PL_bufptr != '\\')
	    Perl_croak(aTHX_ "panic: INTERPCASEMOD");
#endif
	/* handle \E or end of string */
       	if (PL_bufptr == PL_bufend || PL_bufptr[1] == 'E') {
	    /* if at a \E */
	    if (PL_lex_casemods) {
		const char oldmod = PL_lex_casestack[--PL_lex_casemods];
		PL_lex_casestack[PL_lex_casemods] = '\0';

		if (PL_bufptr != PL_bufend
		    && (oldmod == 'L' || oldmod == 'U' || oldmod == 'Q')) {
		    PL_bufptr += 2;
		    PL_lex_state = LEX_INTERPCONCAT;
#ifdef PERL_MAD
		    if (PL_madskills)
			PL_thistoken = newSVpvs("\\E");
#endif
		}
		return REPORT(')');
	    }
	    if (PL_bufptr != PL_bufend) {
		PL_bufptr += 2;
#ifdef PERL_MAD
		if (!PL_thiswhite)
		    PL_thiswhite = newSVpvs("");
		sv_catpvn(PL_thiswhite, PL_bufptr, 2);
#endif
	    }
	    PL_lex_state = LEX_INTERPCONCAT;
	    return yylex();
	}
	else {
	    DEBUG_T({ PerlIO_printf(Perl_debug_log,
              "### Saw case modifier\n"); });
	    s = PL_bufptr + 1;
	    if (s[1] == '\\' && s[2] == 'E') {
#ifdef PERL_MAD
		if (!PL_thiswhite)
		    PL_thiswhite = newSVpvs("");
		sv_catpvn(PL_thiswhite, PL_bufptr, 4);
#endif
	        PL_bufptr = s + 3;
		PL_lex_state = LEX_INTERPCONCAT;
		return yylex();
	    }
	    else {
		I32 tmp;
		if (!PL_madskills) /* when just compiling don't need correct */
		    if (strnEQ(s, "L\\u", 3) || strnEQ(s, "U\\l", 3))
			tmp = *s, *s = s[2], s[2] = (char)tmp;	/* misordered... */
		if ((*s == 'L' || *s == 'U') &&
		    (strchr(PL_lex_casestack, 'L') || strchr(PL_lex_casestack, 'U'))) {
		    PL_lex_casestack[--PL_lex_casemods] = '\0';
		    return REPORT(')');
		}
		if (PL_lex_casemods > 10)
		    Renew(PL_lex_casestack, PL_lex_casemods + 2, char);
		PL_lex_casestack[PL_lex_casemods++] = *s;
		PL_lex_casestack[PL_lex_casemods] = '\0';
		PL_lex_state = LEX_INTERPCONCAT;
		start_force(PL_curforce);
		NEXTVAL_NEXTTOKE.ival = 0;
		force_next('(');
		start_force(PL_curforce);
		if (*s == 'l')
		    NEXTVAL_NEXTTOKE.ival = OP_LCFIRST;
		else if (*s == 'u')
		    NEXTVAL_NEXTTOKE.ival = OP_UCFIRST;
		else if (*s == 'L')
		    NEXTVAL_NEXTTOKE.ival = OP_LC;
		else if (*s == 'U')
		    NEXTVAL_NEXTTOKE.ival = OP_UC;
		else if (*s == 'Q')
		    NEXTVAL_NEXTTOKE.ival = OP_QUOTEMETA;
		else
		    Perl_croak(aTHX_ "panic: yylex");
		if (PL_madskills) {
		    SV* const tmpsv = newSVpvs("\\ ");
		    /* replace the space with the character we want to escape
		     */
		    SvPVX(tmpsv)[1] = *s;
		    curmad('_', tmpsv);
		}
		PL_bufptr = s + 1;
	    }
	    force_next(FUNC);
	    if (PL_lex_starts) {
		s = PL_bufptr;
		PL_lex_starts = 0;
#ifdef PERL_MAD
		if (PL_madskills) {
		    if (PL_thistoken)
			sv_free(PL_thistoken);
		    PL_thistoken = newSVpvs("");
		}
#endif
		/* commas only at base level: /$a\Ub$c/ => ($a,uc(b.$c)) */
		if (PL_lex_casemods == 1 && PL_lex_flags & LEXf_INPAT)
		    OPERATOR(',');
		else
		    Aop(OP_CONCAT);
	    }
	    else
		return yylex();
	}

    case LEX_INTERPPUSH:
        return REPORT(sublex_push());

    case LEX_INTERPSTART:
	if (PL_bufptr == PL_bufend)
	    return REPORT(sublex_done());
	DEBUG_T({ PerlIO_printf(Perl_debug_log,
              "### Interpolated variable\n"); });
	if (*PL_bufptr == '{') {
	    PL_lex_state = LEX_INTERPBLOCK;
	    PL_expect = XREF;

	    start_force(PL_curforce);
	    NEXTVAL_NEXTTOKE.ival = 0;
	    force_next(DO);

	    if (PL_lex_starts++)
		Aop(OP_CONCAT);

	    return yylex();
	}

	PL_expect = XTERM;
	PL_lex_dojoin = (*PL_bufptr == '@');
	PL_lex_state = LEX_INTERPNORMAL;
	if (PL_lex_dojoin) {
	    start_force(PL_curforce);
	    NEXTVAL_NEXTTOKE.ival = 0;
	    force_next(',');
	    start_force(PL_curforce);
	    force_ident("\"", '$');
	    start_force(PL_curforce);
	    NEXTVAL_NEXTTOKE.ival = 0;
	    force_next('$');
	    start_force(PL_curforce);
	    NEXTVAL_NEXTTOKE.ival = 0;
	    force_next('(');
	    start_force(PL_curforce);
	    NEXTVAL_NEXTTOKE.ival = OP_JOIN;	/* emulate join($", ...) */
	    force_next(FUNC);
	}
	if (PL_lex_starts++) {
	    s = PL_bufptr;
#ifdef PERL_MAD
	    if (PL_madskills) {
		if (PL_thistoken)
		    sv_free(PL_thistoken);
		PL_thistoken = newSVpvs("");
	    }
#endif
	    /* commas only at base level: /$a\Ub$c/ => ($a,uc(b.$c)) */
	    if (!PL_lex_casemods && (PL_lex_flags & LEXf_INPAT))
		OPERATOR(',');
	    else
		Aop(OP_CONCAT);
	}
	return yylex();

    case LEX_INTERPEND:
	if (PL_lex_dojoin) {
	    PL_lex_dojoin = FALSE;
	    PL_lex_state = LEX_INTERPCONCAT;
#ifdef PERL_MAD
	    if (PL_madskills) {
		if (PL_thistoken)
		    sv_free(PL_thistoken);
		PL_thistoken = newSVpvs("");
	    }
#endif
	    return REPORT(')');
	}
	/* FALLTHROUGH */
    case LEX_INTERPCONCAT:
#ifdef DEBUGGING
	if (PL_lex_brackets)
	    Perl_croak(aTHX_ "panic: INTERPCONCAT");
#endif
	if (PL_bufptr == PL_bufend)
	    return REPORT(sublex_done());

	assert( ! (PL_lex_flags & LEXf_SINGLEQ) );

	s = scan_const(PL_bufptr);
	if (*s == '\\')
	    PL_lex_state = LEX_INTERPCASEMOD;
	else
	    PL_lex_state = LEX_INTERPSTART;

	if (s != PL_bufptr) {
	    start_force(PL_curforce);
	    if (PL_madskills) {
		curmad('X', newSVpvn(PL_bufptr,s-PL_bufptr));
	    }
	    NEXTVAL_NEXTTOKE = pl_yylval;
	    PL_expect = XTERM;
	    force_next(THING);
	    if (PL_lex_starts++) {
#ifdef PERL_MAD
		if (PL_madskills) {
		    if (PL_thistoken)
			sv_free(PL_thistoken);
		    PL_thistoken = newSVpvs("");
		}
#endif
		/* commas only at base level: /$a\Ub$c/ => ($a,uc(b.$c)) */
		if (!PL_lex_casemods &&  PL_lex_flags & LEXf_INPAT)
		    OPERATOR(',');
		else
		    Aop(OP_CONCAT);
	    }
	    else {
		PL_bufptr = s;
		return yylex();
	    }
	}

	return yylex();
    }

    s = PL_bufptr;
    PL_oldoldbufptr = PL_oldbufptr;
    PL_oldbufptr = s;

  retry:
#ifdef PERL_MAD
    if (PL_thistoken) {
	sv_free(PL_thistoken);
	PL_thistoken = 0;
    }
    PL_realtokenstart = s - SvPVX(PL_linestr);	/* assume but undo on ws */
#endif
    switch (*s) {
    default:
	if (isIDFIRST_lazy_if(s,UTF))
	    goto keylookup;
	len = UTF ? Perl_utf8_length(aTHX_ PL_linestart, s) : (STRLEN) (s - PL_linestart);
	Perl_croak(aTHX_ "Unrecognized character \\x%02X in column %d", *s & 255, (int) len + 1);
    case 4:
    case 26:
	goto fake_eof;			/* emulate EOF on ^D or ^Z */
    case 0:
#ifdef PERL_MAD
	if (PL_madskills)
	    PL_faketokens = 0;
#endif
	if (!PL_rsfp) {
	    PL_last_uni = 0;
	    PL_last_lop = 0;
	    if (PL_lex_brackets) {
		yyerror((const char *)
			("Missing right curly or square bracket"));
	    }
            DEBUG_T( { PerlIO_printf(Perl_debug_log,
                        "### Tokener got EOF\n");
            } );
	    TOKEN(0);
	}
	if (s++ < PL_bufend)
	    goto retry;			/* ignore stray nulls */
	PL_last_uni = 0;
	PL_last_lop = 0;
	if (!PL_in_eval && !PL_preambled) {
	    PL_preambled = TRUE;
#ifdef PERL_MAD
	    if (PL_madskills)
		PL_faketokens = 1;
#endif
	    if (PL_perldb) {
		/* Generate a string of Perl code to load the debugger.
		 * If PERL5DB is set, it will return the contents of that,
		 * otherwise a compile-time require of perl5db.pl.  */

		const char * const pdb = PerlEnv_getenv("PERL5DB");

		if (pdb) {
		    sv_setpv(PL_linestr, pdb);
		    sv_catpvs(PL_linestr,";");
		} else {
		    SETERRNO(0,SS_NORMAL);
		    sv_setpvs(PL_linestr, "BEGIN { require 'perl5db.pl' };");
		}
	    } else
		sv_setpvs(PL_linestr,"");
	    if (PL_preambleav) {
		SV **svp = AvARRAY(PL_preambleav);
		SV **const end = svp + AvFILLp(PL_preambleav);
		while(svp <= end) {
		    sv_catsv(PL_linestr, *svp);
		    ++svp;
		    sv_catpvs(PL_linestr, ";");
		}
		sv_free((SV*)PL_preambleav);
		PL_preambleav = NULL;
	    }
	    if (PL_minus_n || PL_minus_p) {
		sv_catpvs(PL_linestr, "LINE: while (~< *ARGV) {");
		if (PL_minus_l)
		    sv_catpvs(PL_linestr,"chomp;");
		if (PL_minus_a) {
		    if (PL_minus_F) {
			if ((*PL_splitstr == '/' || *PL_splitstr == '\''
			     || *PL_splitstr == '"')
			      && strchr(PL_splitstr + 1, *PL_splitstr))
			    Perl_sv_catpvf(aTHX_ PL_linestr, "our @F=split(%s);", PL_splitstr);
			else {
			    /* "q\0${splitstr}\0" is legal perl. Yes, even NUL
			       bytes can be used as quoting characters.  :-) */
			    const char *splits = PL_splitstr;
			    sv_catpvs(PL_linestr, "our @F=split(q\0");
			    do {
				/* Need to \ \s  */
				if (*splits == '\\')
				    sv_catpvn(PL_linestr, splits, 1);
				sv_catpvn(PL_linestr, splits, 1);
			    } while (*splits++);
			    /* This loop will embed the trailing NUL of
			       PL_linestr as the last thing it does before
			       terminating.  */
			    sv_catpvs(PL_linestr, ");");
			}
		    }
		    else
		        sv_catpvs(PL_linestr,"our @F=split(' ');");
		}
	    }
	    if (PL_minus_E)
		sv_catpvs(PL_linestr,
			  "use feature ':5." STRINGIFY(PERL_VERSION) "';");
	    sv_catpvs(PL_linestr, "\n");
	    PL_oldoldbufptr = PL_oldbufptr = s = PL_linestart = SvPVX(PL_linestr);
	    PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
	    PL_last_lop = PL_last_uni = NULL;
	    if (PERLDB_LINE && PL_curstash != PL_debstash)
		update_debugger_info(PL_linestr, NULL, 0);
	    goto retry;
	}
	do {
	    bof = PL_rsfp ? TRUE : FALSE;
	    if ((s = filter_gets(PL_linestr, PL_rsfp, 0)) == NULL) {
	      fake_eof:
#ifdef PERL_MAD
		PL_realtokenstart = -1;
#endif
		if (PL_rsfp) {
		    if ((PerlIO *)PL_rsfp == PerlIO_stdin())
			PerlIO_clearerr(PL_rsfp);
		    else
			(void)PerlIO_close(PL_rsfp);
		    PL_rsfp = NULL;
		    PL_doextract = FALSE;
		}
		if (!PL_in_eval && (PL_minus_n || PL_minus_p)) {
#ifdef PERL_MAD
		    if (PL_madskills)
			PL_faketokens = 1;
#endif
		    if (PL_minus_p)
			sv_setpvs(PL_linestr, ";}continue{print;}");
		    else
			sv_setpvs(PL_linestr, ";}");
		    PL_oldoldbufptr = PL_oldbufptr = s = PL_linestart = SvPVX(PL_linestr);
		    PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
		    PL_last_lop = PL_last_uni = NULL;
		    PL_minus_n = PL_minus_p = 0;
		    goto retry;
		}
		PL_oldoldbufptr = PL_oldbufptr = s = PL_linestart = SvPVX(PL_linestr);
		PL_last_lop = PL_last_uni = NULL;
		sv_setpvn(PL_linestr,"",0);
		TOKEN(';');	/* not infinite loop because rsfp is NULL now */
	    }
	    /* If it looks like the start of a BOM or raw UTF-16,
	     * check if it in fact is. */
	    else if (bof &&
		     (*s == 0 ||
		      *(U8*)s == 0xEF ||
		      *(U8*)s >= 0xFE ||
		      s[1] == 0)) {
#ifdef PERLIO_IS_STDIO
#  ifdef __GNU_LIBRARY__
#    if __GNU_LIBRARY__ == 1 /* Linux glibc5 */
#      define FTELL_FOR_PIPE_IS_BROKEN
#    endif
#  else
#    ifdef __GLIBC__
#      if __GLIBC__ == 1 /* maybe some glibc5 release had it like this? */
#        define FTELL_FOR_PIPE_IS_BROKEN
#      endif
#    endif
#  endif
#endif
		bof = PerlIO_tell(PL_rsfp) == (Off_t)SvCUR(PL_linestr);
		if (bof) {
		    PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
		    s = swallow_bom(s);
		}
	    }
	    if (PL_doextract) {
		/* Incest with pod. */
#ifdef PERL_MAD
		if (PL_madskills)
		    sv_catsv(PL_thiswhite, PL_linestr);
#endif
		if (*s == '=' && strnEQ(s, "=cut", 4) && !isALPHA(s[4])) {
		    sv_setpvn(PL_linestr, "", 0);
		    PL_oldoldbufptr = PL_oldbufptr = s = PL_linestart = SvPVX(PL_linestr);
		    PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
		    PL_last_lop = PL_last_uni = NULL;
		    PL_doextract = FALSE;
		}
	    }
	    incline(s);
	} while (PL_doextract);
	PL_oldoldbufptr = PL_oldbufptr = PL_bufptr = PL_linestart = s;
	if (PERLDB_LINE && PL_curstash != PL_debstash)
	    update_debugger_info(PL_linestr, NULL, 0);
	PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
	PL_last_lop = PL_last_uni = NULL;
	if (CopLINE(PL_curcop) == 1) {
	    while (s < PL_bufend && isSPACE(*s))
		s++;
	    if (*s == ':' && s[1] != ':') /* for csh execing sh scripts */
		s++;
#ifdef PERL_MAD
	    if (PL_madskills)
		PL_thiswhite = newSVpvn(PL_linestart, s - PL_linestart);
#endif
	    d = NULL;
	    if (!PL_in_eval) {
		if (*s == '#' && *(s+1) == '!')
		    d = s + 2;
#ifdef ALTERNATE_SHEBANG
		else {
		    static char const as[] = ALTERNATE_SHEBANG;
		    if (*s == as[0] && strnEQ(s, as, sizeof(as) - 1))
			d = s + (sizeof(as) - 1);
		}
#endif /* ALTERNATE_SHEBANG */
	    }
	    if (d) {
		char *ipath;
		char *ipathend;

		while (isSPACE(*d))
		    d++;
		ipath = d;
		while (*d && !isSPACE(*d))
		    d++;
		ipathend = d;

#ifdef ARG_ZERO_IS_SCRIPT
		if (ipathend > ipath) {
		    /*
		     * HP-UX (at least) sets argv[0] to the script name,
		     * which makes $^X incorrect.  And Digital UNIX and Linux,
		     * at least, set argv[0] to the basename of the Perl
		     * interpreter. So, having found "#!", we'll set it right.
		     */
		    SV * const x = GvSV(gv_fetchpvs("^X", GV_ADD|GV_NOTQUAL,
						    SVt_PV)); /* $^X */
		    assert(SvPOK(x) || SvGMAGICAL(x));
		    if (sv_eq(x, CopFILESV(PL_curcop))) {
			sv_setpvn(x, ipath, ipathend - ipath);
			SvSETMAGIC(x);
		    }
		    else {
			STRLEN blen;
			STRLEN llen;
			const char *bstart = SvPV_const(CopFILESV(PL_curcop),blen);
			const char * const lstart = SvPV_const(x,llen);
			if (llen < blen) {
			    bstart += blen - llen;
			    if (strnEQ(bstart, lstart, llen) &&	bstart[-1] == '/') {
				sv_setpvn(x, ipath, ipathend - ipath);
				SvSETMAGIC(x);
			    }
			}
		    }
		    TAINT_NOT;	/* $^X is always tainted, but that's OK */
		}
#endif /* ARG_ZERO_IS_SCRIPT */

		/*
		 * Look for options.
		 */
		d = instr(s,"perl -");
		if (!d) {
		    d = instr(s,"perl");
#if defined(DOSISH)
		    /* avoid getting into infinite loops when shebang
		     * line contains "Perl" rather than "perl" */
		    if (!d) {
			for (d = ipathend-4; d >= ipath; --d) {
			    if ((*d == 'p' || *d == 'P')
				&& !ibcmp(d, "perl", 4))
			    {
				break;
			    }
			}
			if (d < ipath)
			    d = NULL;
		    }
#endif
		}
#ifdef ALTERNATE_SHEBANG
		/*
		 * If the ALTERNATE_SHEBANG on this system starts with a
		 * character that can be part of a Perl expression, then if
		 * we see it but not "perl", we're probably looking at the
		 * start of Perl code, not a request to hand off to some
		 * other interpreter.  Similarly, if "perl" is there, but
		 * not in the first 'word' of the line, we assume the line
		 * contains the start of the Perl program.
		 */
		if (d && *s != '#') {
		    const char *c = ipath;
		    while (*c && !strchr("; \t\r\n\f\v#", *c))
			c++;
		    if (c < d)
			d = NULL;	/* "perl" not in first word; ignore */
		    else
			*s = '#';	/* Don't try to parse shebang line */
		}
#endif /* ALTERNATE_SHEBANG */
#ifndef MACOS_TRADITIONAL
		if (!d &&
		    *s == '#' &&
		    ipathend > ipath &&
		    !PL_minus_c &&
		    !instr(s,"indir") &&
		    instr(PL_origargv[0],"perl"))
		{
		    dVAR;
		    char **newargv;

		    *ipathend = '\0';
		    s = ipathend + 1;
		    while (s < PL_bufend && isSPACE(*s))
			s++;
		    if (s < PL_bufend) {
			Newxz(newargv,PL_origargc+3,char*);
			newargv[1] = s;
			while (s < PL_bufend && !isSPACE(*s))
			    s++;
			*s = '\0';
			Copy(PL_origargv+1, newargv+2, PL_origargc+1, char*);
		    }
		    else
			newargv = PL_origargv;
		    newargv[0] = ipath;
		    PERL_FPU_PRE_EXEC
		    PerlProc_execv(ipath, EXEC_ARGV_CAST(newargv));
		    PERL_FPU_POST_EXEC
		    Perl_croak(aTHX_ "Can't exec %s", ipath);
		}
#endif
		if (d) {
		    while (*d && !isSPACE(*d))
			d++;
		    while (SPACE_OR_TAB(*d))
			d++;

		    if (*d++ == '-') {
			const bool switches_done = PL_doswitches;
			const U32 oldpdb = PL_perldb;
			const bool oldn = PL_minus_n;
			const bool oldp = PL_minus_p;
			const char *d1 = d;

			do {
			    if (*d1 == 'M' || *d1 == 'm' || *d1 == 'C') {
				const char * const m = d1;
				while (*d1 && !isSPACE(*d1))
				    d1++;
				Perl_croak(aTHX_ "Too late for \"-%.*s\" option",
				      (int)(d1 - m), m);
			    }
			    d1 = moreswitches(d1);
			} while (d1);
			if (PL_doswitches && !switches_done) {
			    int argc = PL_origargc;
			    char **argv = PL_origargv;
			    do {
				argc--,argv++;
			    } while (argc && argv[0][0] == '-' && argv[0][1]);
			    init_argv_symbols(argc,argv);
			}
			if ((PERLDB_LINE && !oldpdb) ||
			    ((PL_minus_n || PL_minus_p) && !(oldn || oldp)))
			      /* if we have already added "LINE: while (<>) {",
			         we must not do it again */
			{
			    sv_setpvn(PL_linestr, "", 0);
			    PL_oldoldbufptr = PL_oldbufptr = s = PL_linestart = SvPVX(PL_linestr);
			    PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
			    PL_last_lop = PL_last_uni = NULL;
			    PL_preambled = FALSE;
			    if (PERLDB_LINE)
				(void)gv_fetchfile(PL_origfilename);
			    goto retry;
			}
		    }
		}
	    }
	}
	goto retry;
    case '\r':
#ifdef PERL_STRICT_CR
	Perl_warn(aTHX_ "Illegal character \\%03o (carriage return)", '\r');
	Perl_croak(aTHX_
      "\t(Maybe you didn't strip carriage returns after a network transfer?)\n");
#endif
    case ' ': case '\t': case '\f': case 013:
#ifdef MACOS_TRADITIONAL
    case '\312':
#endif
#ifdef PERL_MAD
	PL_realtokenstart = -1;
	if (!PL_thiswhite)
	    PL_thiswhite = newSVpvs("");
	sv_catpvn(PL_thiswhite, s, 1);
#endif
	s++;
	goto retry;
    case '#':
    case '\n':
#ifdef PERL_MAD
	PL_realtokenstart = -1;
	if (PL_madskills)
	    PL_faketokens = 0;
#endif
	if (PL_lex_state != LEX_NORMAL || (PL_in_eval && !PL_rsfp)) {
	    if (*s == '#' && s == PL_linestart && PL_in_eval && !PL_rsfp) {
		/* handle eval qq[#line 1 "foo"\n ...] */
		CopLINE_dec(PL_curcop);
		incline(s);
	    }
	    if (PL_madskills && !PL_in_eval) {
		s = SKIPSPACE0(s);
		if (!PL_in_eval || PL_rsfp)
		    incline(s);
	    }
	    else {
		d = s;
		while (d < PL_bufend && *d != '\n')
		    d++;
		if (d < PL_bufend)
		    d++;
		else if (d > PL_bufend) /* Found by Ilya: feed random input to Perl. */
		  Perl_croak(aTHX_ "panic: input overflow");
#ifdef PERL_MAD
		if (PL_madskills)
		    PL_thiswhite = newSVpvn(s, d - s);
#endif
		s = d;
		incline(s);
	    }
	}
	else {
#ifdef PERL_MAD
	    if (PL_madskills && CopLINE(PL_curcop) >= 1) {
		if (CopLINE(PL_curcop) == 1 && s[0] == '#' && s[1] == '!') {
		    PL_faketokens = 0;
		    s = SKIPSPACE0(s);
		    TOKEN(PEG);	/* make sure any #! line is accessible */
		}
		s = SKIPSPACE0(s);
	    }
	    else {
/*		if (PL_madskills && PL_lex_formbrack) { */
		    d = s;
		    while (d < PL_bufend && *d != '\n')
			d++;
		    if (d < PL_bufend)
			d++;
		    else if (d > PL_bufend) /* Found by Ilya: feed random input to Perl. */
		      Perl_croak(aTHX_ "panic: input overflow");
		    if (PL_madskills && CopLINE(PL_curcop) >= 1) {
			if (!PL_thiswhite)
			    PL_thiswhite = newSVpvs("");
			if (CopLINE(PL_curcop) == 1) {
			    sv_setpvn(PL_thiswhite, "", 0);
			    PL_faketokens = 0;
			}
			sv_catpvn(PL_thiswhite, s, d - s);
		    }
		    s = d;
/*		}
		*s = '\0';
		PL_bufend = s; */
	    }
#else
	    *s = '\0';
	    PL_bufend = s;
#endif
	}
	goto retry;
    case '-':
	if (s[1] && isALPHA(s[1]) && !isALNUM(s[2])) {
	    I32 ftst = 0;
	    char tmp;

	    s++;
	    PL_bufptr = s;
	    tmp = *s++;

	    while (s < PL_bufend && SPACE_OR_TAB(*s))
		s++;

	    if (strnEQ(s,"=>",2)) {
		s = force_word(PL_bufptr,WORD,FALSE,FALSE,FALSE);
		DEBUG_T( { printbuf("### Saw unary minus before =>, forcing word %s\n", s); } );
		OPERATOR('-');		/* unary minus */
	    }
	    PL_last_uni = PL_oldbufptr;
	    switch (tmp) {
	    case 'r': ftst = OP_FTEREAD;	break;
	    case 'w': ftst = OP_FTEWRITE;	break;
	    case 'x': ftst = OP_FTEEXEC;	break;
	    case 'o': ftst = OP_FTEOWNED;	break;
	    case 'R': ftst = OP_FTRREAD;	break;
	    case 'W': ftst = OP_FTRWRITE;	break;
	    case 'X': ftst = OP_FTREXEC;	break;
	    case 'O': ftst = OP_FTROWNED;	break;
	    case 'e': ftst = OP_FTIS;		break;
	    case 'z': ftst = OP_FTZERO;		break;
	    case 's': ftst = OP_FTSIZE;		break;
	    case 'f': ftst = OP_FTFILE;		break;
	    case 'd': ftst = OP_FTDIR;		break;
	    case 'l': ftst = OP_FTLINK;		break;
	    case 'p': ftst = OP_FTPIPE;		break;
	    case 'S': ftst = OP_FTSOCK;		break;
	    case 'u': ftst = OP_FTSUID;		break;
	    case 'g': ftst = OP_FTSGID;		break;
	    case 'k': ftst = OP_FTSVTX;		break;
	    case 'b': ftst = OP_FTBLK;		break;
	    case 'c': ftst = OP_FTCHR;		break;
	    case 't': ftst = OP_FTTTY;		break;
	    case 'T': ftst = OP_FTTEXT;		break;
	    case 'B': ftst = OP_FTBINARY;	break;
	    case 'M': case 'A': case 'C':
		gv_fetchpvs("\024", GV_ADD|GV_NOTQUAL, SVt_PV);
		switch (tmp) {
		case 'M': ftst = OP_FTMTIME;	break;
		case 'A': ftst = OP_FTATIME;	break;
		case 'C': ftst = OP_FTCTIME;	break;
		default:			break;
		}
		break;
	    default:
		break;
	    }
	    if (ftst) {
		PL_last_lop_op = (OPCODE)ftst;
		DEBUG_T( { PerlIO_printf(Perl_debug_log,
                        "### Saw file test %c\n", (int)tmp);
		} );
		FTST(ftst);
	    }
	    else {
		/* Assume it was a minus followed by a one-letter named
		 * subroutine call (or a -bareword), then. */
		DEBUG_T( { PerlIO_printf(Perl_debug_log,
			"### '-%c' looked like a file test but was not\n",
			(int) tmp);
		} );
		s = --PL_bufptr;
	    }
	}
	{
	    const char tmp = *s++;
	    if (*s == tmp) {
		s++;
		if (PL_expect == XOPERATOR)
		    TERM(POSTDEC);
		else
		    OPERATOR(PREDEC);
	    }
	    else if (*s == '>') {
		s++;
		if (*s == '?') {
		    s++;
		    OPERATOR(ARROW);
		}
		else if (*s == '@') {
		    s++;
		    pl_yylval.ival=0;
		    if (PL_lex_state == LEX_INTERPNORMAL && PL_lex_brackets == 0 ) {
			/* ->@ closes the interpoltion and creates a join */
			PL_lex_state = LEX_INTERPEND;
			pl_yylval.ival = OP_JOIN;
		    }
		    TERM(DEREFARY);
		}
		else if (*s == '$') {
		    s++;
		    if (PL_lex_state == LEX_INTERPNORMAL && PL_lex_brackets == 0 ) {
			/* ->$ closes the interpoltion and creates a join */
			PL_lex_state = LEX_INTERPEND;
		    }
		    OPERATOR(DEREFSCL);
		}
		else if (*s == '%') {
		    s++;
		    if (PL_lex_state == LEX_INTERPNORMAL && PL_lex_brackets == 0 ) {
			/* ->$ closes the interpoltion and creates a join */
			PL_lex_state = LEX_INTERPEND;
		    }
		    OPERATOR(DEREFHSH);
		} 
		else if (*s == '*') {
		    s++;
		    if (PL_lex_state == LEX_INTERPNORMAL && PL_lex_brackets == 0 ) {
			/* ->$ closes the interpoltion and creates a join */
			PL_lex_state = LEX_INTERPEND;
		    }
		    OPERATOR(DEREFSTAR);
		} 
		else if (*s == '&') {
		    s++;
		    if (PL_lex_state == LEX_INTERPNORMAL && PL_lex_brackets == 0 ) {
			/* ->$ closes the interpoltion and creates a join */
			PL_lex_state = LEX_INTERPEND;
		    }
		    OPERATOR(DEREFAMP);
		} 
		s = SKIPSPACE1(s);
		if (isIDFIRST_lazy_if(s,UTF)) {
		    s = force_word(s,METHOD,FALSE,TRUE,FALSE);
		    TOKEN(ARROW);
		}
		else
		    TERM(ARROW);
	    }
	    if (PL_expect == XOPERATOR)
		Aop(OP_SUBTRACT);
	    else {
		if (isSPACE(*s) || !isSPACE(*PL_bufptr))
		    check_uni();
		OPERATOR('-');		/* unary minus */
	    }
	}

    case '+':
	{
	    s++;
	    if (*s == '<') {
		s++;
		if (*s == '=') {
		    s++;
		    Rop(OP_LE);
		}
		Rop(OP_LT);
	    }
	    if (*s == '>') {
		s++;
		if (*s == '=') {
		    s++;
		    Rop(OP_GE);
		}
		Rop(OP_GT);
	    }

	    if (*s == '+') {
		s++;
		if (PL_expect == XOPERATOR)
		    TERM(POSTINC);
		else
		    OPERATOR(PREINC);
	    }
	    if (PL_expect == XOPERATOR)
		Aop(OP_ADD);
	    else {
		if (isSPACE(*s) || !isSPACE(*PL_bufptr))
		    check_uni();
		OPERATOR('+');
	    }
	}

    case '*':
	if (PL_expect != XOPERATOR) {
	    s = scan_ident(s, PL_bufend, PL_tokenbuf, sizeof PL_tokenbuf, TRUE);
	    PL_expect = XOPERATOR;
	    force_ident(PL_tokenbuf, '*');
	    if (!*PL_tokenbuf)
		PREREF('*');
	    TERM('*');
	}
	s++;
	if (*s == '*') {
	    s++;
	    PWop(OP_POW);
	}
	Mop(OP_MULTIPLY);

    case '%':
	if (PL_expect == XOPERATOR) {
	    ++s;
	    Mop(OP_MODULO);
	}

	if (s[1] == '(') {
	    /* anonymous hash constructor */
	    s += 2;
	    OPERATOR(ANONHSH);
	}

	PL_tokenbuf[0] = '%';
	s = scan_ident(s, PL_bufend, PL_tokenbuf + 1,
		sizeof PL_tokenbuf - 1, FALSE);
	if (!PL_tokenbuf[1]) {
	    PREREF('%');
	}
	PL_pending_ident = '%';
	TERM('%');

    case '^':
	s++;
	if ( ! strchr("^&|~", *s ) )
	    Perl_croak(aTHX_ "Expected ^,&,| or ~ after a ^, but found '%c'", *s);
	s++;
	if (*s != '^')
	    Perl_croak(aTHX_ "Expected a '^' after ^%c'", *(s-1));
	s++;
	switch (*(s-2)) {
	case '^': BOop(OP_BIT_XOR);
	case '&': BAop(OP_BIT_AND);
	case '|': BOop(OP_BIT_OR);
	case '~': OPERATOR('~');
	}
    case '~':
	if (s[1] == '~'
	    && (PL_expect == XOPERATOR || PL_expect == XTERMORDORDOR))
	{
	    s += 2;
	    Eop(OP_SMARTMATCH);
	}


	if (s[1] == '<') {
	    s += 2;
	    UNI(OP_READLINE);
	}
	Perl_croak(aTHX_ "Unknown operator '~' found");
    case '[':
	s++;
	if (PL_expect == XOPERATOR && *s == '[') {
	    s++;
	    PL_lex_brackstack[PL_lex_brackets++] = XSTATE;
	    PL_lex_brackstack[PL_lex_brackets++] = XSTATE;
	    PL_expect = XSTATE;
	    TOKEN(ASLICE);
	    /* NOT REACHED */
	}
	if (PL_expect != XOPERATOR) {
	    yyerror("'[...]' should be '\\@(...)'");
	}
	PL_lex_brackets++;
	OPERATOR('[');
    case ',':
	s++;
	OPERATOR(',');
    case ':':
	if (s[1] == ':') {
	    len = 0;
	    goto just_a_word_zero_gv;
	}
	s++;
	switch (PL_expect) {
	    OP *attrs;
#ifdef PERL_MAD
	    I32 stuffstart;
#endif
	case XOPERATOR:
	    if (!PL_in_my || PL_lex_state != LEX_NORMAL)
		break;
	    PL_bufptr = s;	/* update in case we back off */
	    goto grabattrs;
	case XATTRBLOCK:
	    PL_expect = XBLOCK;
	    goto grabattrs;
	case XATTRTERM:
	    PL_expect = XTERMBLOCK;
	 grabattrs:
#ifdef PERL_MAD
	    stuffstart = s - SvPVX(PL_linestr) - 1;
#endif
	    s = PEEKSPACE(s);
	    attrs = NULL;
	    while (isIDFIRST_lazy_if(s,UTF)) {
		I32 tmp;
		SV *sv;
		d = scan_word(s, PL_tokenbuf, sizeof PL_tokenbuf, FALSE, &len);
		if (isLOWER(*s) && (tmp = keyword(PL_tokenbuf, len, 0))) {
		    if (tmp < 0) tmp = -tmp;
		    switch (tmp) {
		    case KEY_or:
		    case KEY_and:
		    case KEY_for:
		    case KEY_unless:
		    case KEY_if:
		    case KEY_while:
		    case KEY_until:
			goto got_attrs;
		    default:
			break;
		    }
		}
		sv = newSVpvn(s, len);
		if (*d == '(') {
		    PL_lex_stuff.flags = LEXf_ATTRS;
		    d = scan_str(d,TRUE,TRUE,&PL_lex_stuff);
		    if (!d) {
			/* MUST advance bufptr here to avoid bogus
			   "at end of line" context messages from yyerror().
			 */
			PL_bufptr = s + len;
			yyerror("Unterminated attribute parameter in attribute list");
			if (attrs)
			    op_free(attrs);
			sv_free(sv);
			return REPORT(0);	/* EOF indicator */
		    }
		}
		if (PL_lex_stuff.str_sv) {
		    sv_catsv(sv, PL_lex_stuff.str_sv);
		    attrs = append_elem(OP_LIST, attrs,
					newSVOP(OP_CONST, 0, sv));
		    SvREFCNT_dec(PL_lex_stuff.str_sv);
		    PL_lex_stuff.str_sv = NULL;
		}
		else {
		    if (len == 6 && strnEQ(SvPVX(sv), "unique", len)) {
			sv_free(sv);
			if (PL_in_my == KEY_our) {
#ifdef USE_ITHREADS
			    GvUNIQUE_on(cGVOPx_gv(pl_yylval.opval));
#else
			    /* skip to avoid loading attributes.pm */
#endif
			    deprecate(":unique");
			}
			else
			    Perl_croak(aTHX_ "The 'unique' attribute may only be applied to 'our' variables");
		    }

		    /* NOTE: any CV attrs applied here need to be part of
		       the CVf_BUILTIN_ATTRS define in cv.h! */
		    else if (!PL_in_my && len == 6 && strnEQ(SvPVX(sv), "locked", len)) {
			sv_free(sv);
			CvLOCKED_on(PL_compcv);
		    }
		    else if (!PL_in_my && len == 6 && strnEQ(SvPVX(sv), "method", len)) {
			sv_free(sv);
			CvMETHOD_on(PL_compcv);
		    }
		    /* After we've set the flags, it could be argued that
		       we don't need to do the attributes.pm-based setting
		       process, and shouldn't bother appending recognized
		       flags.  To experiment with that, uncomment the
		       following "else".  (Note that's already been
		       uncommented.  That keeps the above-applied built-in
		       attributes from being intercepted (and possibly
		       rejected) by a package's attribute routines, but is
		       justified by the performance win for the common case
		       of applying only built-in attributes.) */
		    else
		        attrs = append_elem(OP_LIST, attrs,
					    newSVOP(OP_CONST, 0,
					      	    sv));
		}
		s = PEEKSPACE(d);
		if (*s == ':' && s[1] != ':')
		    s = PEEKSPACE(s+1);
		else if (s == d)
		    break;	/* require real whitespace or :'s */
		/* XXX losing whitespace on sequential attributes here */
	    }
	    {
		const char tmp
		    = (PL_expect == XOPERATOR ? '=' : '{'); /*'}(' for vi */
		if (*s != ';' && *s != '}' && *s != tmp
		    && (tmp != '=' || *s != ')')) {
		    const char q = ((*s == '\'') ? '"' : '\'');
		    /* If here for an expression, and parsed no attrs, back
		       off. */
		    if (tmp == '=' && !attrs) {
			s = PL_bufptr;
			break;
		    }
		    /* MUST advance bufptr here to avoid bogus "at end of line"
		       context messages from yyerror().
		    */
		    PL_bufptr = s;
		    yyerror( (const char *)
			     (*s
			      ? Perl_form(aTHX_ "Invalid separator character "
					  "%c%c%c in attribute list", q, *s, q)
			      : "Unterminated attribute list" ) );
		    if (attrs)
			op_free(attrs);
		    OPERATOR(':');
		}
	    }
	got_attrs:
	    if (attrs) {
		start_force(PL_curforce);
		NEXTVAL_NEXTTOKE.opval = attrs;
		CURMAD('_', PL_nextwhite);
		force_next(THING);
	    }
#ifdef PERL_MAD
	    if (PL_madskills) {
		PL_thistoken = newSVpvn(SvPVX(PL_linestr) + stuffstart,
				     (s - SvPVX(PL_linestr)) - stuffstart);
	    }
#endif
	    TOKEN(COLONATTR);
	}
	OPERATOR(':');
    case '(':
	s++;
	if (PL_last_lop == PL_oldoldbufptr || PL_last_uni == PL_oldoldbufptr)
	    PL_oldbufptr = PL_oldoldbufptr;		/* allow print(STDOUT 123) */
	else
	    PL_expect = XTERM;
	s = SKIPSPACE1(s);
	TOKEN('(');
    case ';':
	CLINE;
	{
	    const char tmp = *s++;
	    OPERATOR(tmp);
	}
    case ')':
	{
	    const char tmp = *s++;
	    s = SKIPSPACE1(s);
	    if (*s == '{' && PL_expect != XOPERATOR)
		PREBLOCK(tmp);
	    TERM(tmp);
	}
    case ']':
	s++;
	if (PL_lex_brackets <= 0)
	    yyerror("Unmatched right square bracket");
	else
	    --PL_lex_brackets;
	if (PL_lex_state == LEX_INTERPNORMAL) {
	    if ( ! intuit_more(s))
		PL_lex_state = LEX_INTERPEND;
	}
	TERM(']');
    case '{':
	s++;
	if (PL_lex_brackets > 100) {
	    Renew(PL_lex_brackstack, PL_lex_brackets + 10, char);
	}
	switch (PL_expect) {
	case XTERM:
	    if (PL_oldoldbufptr == PL_last_lop)
		PL_lex_brackstack[PL_lex_brackets++] = XTERM;
	    else
		PL_lex_brackstack[PL_lex_brackets++] = XOPERATOR;
	    yyerror("'{' should be '\%(' expected");
	case XOPERATOR:
	    if (*s == '[') {
		s++;
		PL_lex_brackstack[PL_lex_brackets++] = XSTATE;
		PL_lex_brackstack[PL_lex_brackets++] = XSTATE;
		PL_expect = XSTATE;
		TOKEN(HSLICE);
		/* NOT REACHED */
	    }
	    while (s < PL_bufend && SPACE_OR_TAB(*s))
		s++;
	    d = s;
	    PL_tokenbuf[0] = '\0';
	    if (d < PL_bufend && *d == '-') {
		PL_tokenbuf[0] = '-';
		d++;
		while (d < PL_bufend && SPACE_OR_TAB(*d))
		    d++;
	    }
	    if (d < PL_bufend && isIDFIRST_lazy_if(d,UTF)) {
		d = scan_word(d, PL_tokenbuf + 1, sizeof PL_tokenbuf - 1,
			      FALSE, &len);
		while (d < PL_bufend && SPACE_OR_TAB(*d))
		    d++;
		if (*d == '}') {
		    const char minus = (PL_tokenbuf[0] == '-');
		    s = force_word(s + minus, WORD, FALSE, TRUE, FALSE);
		    if (minus)
			force_next('-');
		}
	    }
	    /* FALL THROUGH */
	case XATTRBLOCK:
	case XBLOCK:
	    PL_lex_brackstack[PL_lex_brackets++] = XSTATE;
	    PL_expect = XSTATE;
	    break;
	case XATTRTERM:
	case XTERMBLOCK:
	    PL_lex_brackstack[PL_lex_brackets++] = XOPERATOR;
	    PL_expect = XSTATE;
	    break;
	default:
	    yyerror("panic: Unknown PL_expect");
	    break;
	case XSTATE:
	case XREF:
	    if (PL_oldoldbufptr == PL_last_lop)
		PL_lex_brackstack[PL_lex_brackets++] = XTERM;
	    else
		PL_lex_brackstack[PL_lex_brackets++] = XOPERATOR;
	    s = SKIPSPACE1(s);
	    if (PL_expect == XREF)
		PL_expect = XTERM;
	    else {
		PL_lex_brackstack[PL_lex_brackets-1] = XSTATE;
		PL_expect = XSTATE;
	    }
	    break;
	}
	pl_yylval.ival = CopLINE(PL_curcop);
	if (isSPACE(*s) || *s == '#')
	    PL_copline = NOLINE;   /* invalidate current command line number */
	TOKEN('{');
    case '}':
	s++;
	if (PL_lex_brackets <= 0)
	    Perl_croak(aTHX_ "Unmatched right curly bracket");
	else
	    PL_expect = (expectation)PL_lex_brackstack[--PL_lex_brackets];
	if (PL_lex_state == LEX_INTERPBLOCK) {
	    if (PL_lex_brackets == 0) 
		PL_lex_state = LEX_INTERPEND;
	    if (PL_lex_brackets == 0) {
		if (PL_expect & XFAKEBRACK) {
		    PL_expect &= XENUMMASK;
		    PL_lex_state = LEX_INTERPEND;
		    PL_bufptr = s;
		    return yylex();	/* ignore fake brackets */
		}
	    }
	}
	if (PL_lex_state == LEX_INTERPNORMAL) {
	    if ( ! intuit_more(s))
		PL_lex_state = LEX_INTERPEND;
	    if (PL_lex_brackets == 0) {
		if (PL_expect & XFAKEBRACK) {
		    PL_expect &= XENUMMASK;
		    PL_lex_state = LEX_INTERPEND;
		    PL_bufptr = s;
		    return yylex();	/* ignore fake brackets */
		}
	    }
	}
	if (PL_expect & XFAKEBRACK) {
	    PL_expect &= XENUMMASK;
	    PL_bufptr = s;
	    return yylex();		/* ignore fake brackets */
	}
	start_force(PL_curforce);
	if (PL_madskills) {
	    curmad('X', newSVpvn(s-1,1));
	    CURMAD('_', PL_thiswhite);
	}
	force_next('}');
#ifdef PERL_MAD
	if (!PL_thistoken)
	    PL_thistoken = newSVpvs("");
#endif
	TOKEN(';');
    case '&':
	s++;
	if (*s++ == '&')
	    AOPERATOR(ANDAND);
	s--;
	if (PL_expect == XOPERATOR) {
	    no_op("'&'", s);
	}

	s = scan_ident(s - 1, PL_bufend, PL_tokenbuf, sizeof PL_tokenbuf, TRUE);
	if (*PL_tokenbuf) {
	    PL_expect = XOPERATOR;
	    force_ident(PL_tokenbuf, '&');
	}
	else
	    PREREF('&');
	pl_yylval.ival = (OPpENTERSUB_AMPER<<8);
	TERM('&');

    case '|':
	s++;
	if (*s++ == '|')
	    AOPERATOR(OROR);
	s--;
	Perl_croak(aTHX_ "Unknown operator '|' found. Did you mean '||' or '^|^'?");
    case '=':
	s++;
	{
	    const char tmp = *s++;
	    if (tmp == '=')
		Eop(OP_EQ);
	    if (tmp == '>')
		OPERATOR(',');
	    if (tmp == '~')
		PMop(OP_MATCH);
	    if (tmp && isSPACE(*s) && ckWARN(WARN_SYNTAX)
		&& strchr("+-*/%.^&|<",tmp))
		Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
			    "Reversed %c= operator",(int)tmp);
	    s--;
	    if (PL_expect == XSTATE && isALPHA(tmp) &&
		(s == PL_linestart+1 || s[-2] == '\n') )
		{
		    if (PL_in_eval && !PL_rsfp) {
			d = PL_bufend;
			while (s < d) {
			    if (*s++ == '\n') {
				incline(s);
				if (strnEQ(s,"=cut",4)) {
				    s = strchr(s,'\n');
				    if (s)
					s++;
				    else
					s = d;
				    incline(s);
				    goto retry;
				}
			    }
			}
			goto retry;
		    }
#ifdef PERL_MAD
		    if (PL_madskills) {
			if (!PL_thiswhite)
			    PL_thiswhite = newSVpvs("");
			sv_catpvn(PL_thiswhite, PL_linestart,
				  PL_bufend - PL_linestart);
		    }
#endif
		    s = PL_bufend;
		    PL_doextract = TRUE;
		    goto retry;
		}
	}
	pl_yylval.ival = 0;
	OPERATOR(ASSIGNOP);
    case '!':
	s++;
	{
	    const char tmp = *s++;
	    if (tmp == '=') {
		/* was this !=~ where !~ was meant?
		 * warn on m:!=~\s+([/?]|[msy]\W|tr\W): */

		if (*s == '~' && ckWARN(WARN_SYNTAX)) {
		    const char *t = s+1;

		    while (t < PL_bufend && isSPACE(*t))
			++t;

		    if (((*t == 'm' || *t == 's' || *t == 'y')
			 && !isALNUM(t[1])) ||
			(*t == 't' && t[1] == 'r' && !isALNUM(t[2])))
			Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				    "!=~ should be !~");
		}
		Eop(OP_NE);
	    }
	    if (tmp == '~')
		PMop(OP_NOT);
	}
	s--;
	OPERATOR('!');
    case '<':
	if (PL_expect != XOPERATOR) {
	    if (s[1] != '<' && !strchr(s,'>'))
		check_uni();
	    if (s[1] == '<') {
		I32 op_type;
		s = scan_heredoc(s);

		op_type = pl_yylval.ival;
		if (op_type == OP_CONST) {
		    /* like sublex_start, but without PL_lex_stuff going through tokeq */
		    /* do not go through tokeq because it unescpaes slashes */
		    SV *sv = PL_lex_stuff.str_sv;
		    if ( PL_hints & HINT_NEW_STRING )
			sv = new_constant(NULL, 0, "q", sv, sv, "q", 1);

		    pl_yylval.opval = (OP*)newSVOP(op_type, 0, sv);
		    PL_lex_stuff.str_sv = NULL;
		    TERM(THING);
		}
		TERM(sublex_start(op_type, NULL));
	    }
	    Perl_croak(aTHX_ "No operator expected, but found '<', '<=' or '<=>' operator");
	}
	s++;
	{
	    char tmp = *s++;
	    if (tmp == '<')
		SHop(OP_LEFT_SHIFT);

	    if ((tmp == '+') && (*s == '>')) {
		s++;
		Eop(OP_NCMP);
	    }
	    Perl_croak(aTHX_ "'<' is reserved for hashes");
	}
    case '>':
	s++;
	if (*s++ == '>')
	    SHop(OP_RIGHT_SHIFT);
	
	Perl_croak(aTHX_ "'>' is reserved for hashes");

    case '$':
	CLINE;

	if (s[1] == '#' && (isIDFIRST_lazy_if(s+2,UTF) || strchr("{$:+-", s[2]))) {
	    Perl_croak(aTHX_ "$# is not allowed");
	}

	PL_tokenbuf[0] = '$';
	s = scan_ident(s, PL_bufend, PL_tokenbuf + 1,
		       sizeof PL_tokenbuf - 1, FALSE);
	if (PL_expect == XOPERATOR)
	    no_op("Scalar", s);
	if (!PL_tokenbuf[1]) {
	    if (s == PL_bufend)
		yyerror("Final $ should be \\$ or $name");
	    PREREF('$');
	}

	d = s;
	{
	    const char tmp = *s;
	    if (PL_lex_state == LEX_NORMAL)
		s = SKIPSPACE1(s);

	    if ((PL_expect != XREF || PL_oldoldbufptr == PL_last_lop)
		&& intuit_more(s)) {
		if (*s == '[') {
		    Perl_croak(aTHX_ "array element should be @%s[...] instead of $%s[...]",
			       &PL_tokenbuf[1], &PL_tokenbuf[1]);
		}
		else if (*s == '{') {
		    Perl_croak(aTHX_ "hash element should be %%%s{...} instead of $%s{...}",
			       &PL_tokenbuf[1], &PL_tokenbuf[1]);
		}
	    }

	    PL_expect = XOPERATOR;
	    if (PL_lex_state == LEX_NORMAL && isSPACE((char)tmp)) {
		const bool islop = (PL_last_lop == PL_oldoldbufptr);
		if (!islop || PL_last_lop_op == OP_GREPSTART)
		    PL_expect = XOPERATOR;
		else if (strchr("$@\"'`q", *s))
		    PL_expect = XTERM;		/* e.g. print $fh "foo" */
		else if (strchr("&*<%", *s) && isIDFIRST_lazy_if(s+1,UTF))
		    PL_expect = XTERM;		/* e.g. print $fh &sub */
		else if (isIDFIRST_lazy_if(s,UTF)) {
		    char tmpbuf[sizeof PL_tokenbuf];
		    int t2;
		    scan_word(s, tmpbuf, sizeof tmpbuf, TRUE, &len);
		    if ((t2 = keyword(tmpbuf, len, 0))) {
			/* binary operators exclude handle interpretations */
			switch (t2) {
			case -KEY_x:
			case -KEY_eq:
			case -KEY_ne:
			case -KEY_cmp:
			    break;
			default:
			    PL_expect = XTERM;	/* e.g. print $fh length() */
			    break;
			}
		    }
		    else {
			PL_expect = XTERM;	/* e.g. print $fh subr() */
		    }
		}
		else if (isDIGIT(*s))
		    PL_expect = XTERM;		/* e.g. print $fh 3 */
		else if (*s == '.' && isDIGIT(s[1]))
		    PL_expect = XTERM;		/* e.g. print $fh .3 */
		else if ((*s == '-' || *s == '+')
			 && !isSPACE(s[1]) && s[1] != '=')
		    PL_expect = XTERM;		/* e.g. print $fh -1 */
		else if (*s == '<' && s[1] == '<' && !isSPACE(s[2])
			 && s[2] != '=')
		    PL_expect = XTERM;		/* print $fh <<"EOF" */
	    }
	}
	PL_pending_ident = '$';
	TOKEN('$');

    case '@':
	if (PL_expect == XOPERATOR)
	    no_op("Array", s);

	if (s[1] == '(') {
	    /* array constructor */
	    s += 2;
	    OPERATOR(ANONARY);
	}

	PL_tokenbuf[0] = '@';
	s = scan_ident(s, PL_bufend, PL_tokenbuf + 1, sizeof PL_tokenbuf - 1, FALSE);
	if (!PL_tokenbuf[1]) {
	    PREREF('@');
	}
	if (PL_lex_state == LEX_NORMAL)
	    s = SKIPSPACE1(s);
	if ((PL_expect != XREF || PL_oldoldbufptr == PL_last_lop) && intuit_more(s)) {
	    if (*s == '{') {
		Perl_croak(aTHX_ "hash slice should be %%%s{[...]} instead of @%s{...}",
			   PL_tokenbuf+1, PL_tokenbuf+1);
		PL_tokenbuf[0] = '%';
	    }

	    /* Warn about @...[...] where they meant @...[[...]]. */
	    if (*s == '[') {
		if (ckWARN(WARN_SYNTAX)) {
		    char *t = s+1;

		    while (isSPACE(*t) || isALNUM_lazy_if(t,UTF) || *t == '$')
			t++;
		    if (*t++ == ',') {
			PL_bufptr = PEEKSPACE(PL_bufptr); /* XXX can realloc */
			while (t < PL_bufend && *t != ']')
			    t++;
			Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				    "Multidimensional syntax %.*s not supported",
				    (int)((t - PL_bufptr) + 1), PL_bufptr);
		    }
		}
	    }
	}
	PL_pending_ident = '@';
	TERM('@');

     case '/':			/* may be division, defined-or */
	if (PL_expect == XTERMORDORDOR && s[1] == '/') {
	    s += 2;
	    AOPERATOR(DORDOR);
	}
	if(PL_expect == XOPERATOR) {
	    char tmp = *s++;
	    tmp = *s++;
	    if(tmp == '/') {
		/* A // operator. */
		AOPERATOR(DORDOR);
	    }
	    else {
		s--;
		Mop(OP_DIVIDE);
	    }
	 }
	 yyerror("/pat/ should be m/pat/"); /*  */

    case '?':			/* conditional */
	 s++;
	 OPERATOR('?');

    case '.':
	if (PL_expect == XOPERATOR || !isDIGIT(s[1])) {
	    char tmp = *s++;
	    if (*s == tmp) {
		s++;
		if (*s == tmp) {
		    s++;
		    pl_yylval.ival = OPf_SPECIAL;
		}
		else
		    pl_yylval.ival = 0;
		OPERATOR(DOTDOT);
	    }
	    if (PL_expect != XOPERATOR)
		check_uni();
	    Aop(OP_CONCAT);
	}
	/* FALL THROUGH */
    case '0': case '1': case '2': case '3': case '4':
    case '5': case '6': case '7': case '8': case '9':
	s = scan_num(s, &pl_yylval);
	DEBUG_T( { printbuf("### Saw number in %s\n", s); } );
	if (PL_expect == XOPERATOR)
	    no_op("Number",s);
	TERM(THING);

    case '\'':
	PL_lex_stuff.flags = LEXf_SINGLEQ;
	s = scan_str(s,FALSE,FALSE, &PL_lex_stuff);
	if (PL_expect == XOPERATOR) {
	    no_op("String",s);
	}
	
	if (!s)
	    missingterminator(NULL);
	DEBUG_T( { printbuf("### Saw string before %s\n", s); } );
	TERM(sublex_start(OP_CONST, NULL));

    case '"':
	PL_lex_stuff.flags = LEXf_DOUBLEQ;
	s = scan_str(s,TRUE,FALSE, &PL_lex_stuff);
	DEBUG_T( { printbuf("### Saw string before %s\n", s); } );
	if (PL_expect == XOPERATOR) {
	    no_op("String",s);
	}
	if (!s)
	    missingterminator(NULL);
	pl_yylval.ival = OP_CONST;
	/* FIXME. I think that this can be const if char *d is replaced by
	   more localised variables.  */
	for (d = SvPV(PL_lex_stuff.str_sv, len); len; len--, d++) {
	    if (*d == '{' || *d == '$' || *d == '@' || *d == '%' || *d == '\\' || !UTF8_IS_INVARIANT(*d)) {
		pl_yylval.ival = OP_STRINGIFY;
		break;
	    }
	}
	TERM(sublex_start(pl_yylval.ival, NULL));

    case '`':
	PL_lex_stuff.flags = LEXf_BACKTICK;
	s = scan_str(s,TRUE,FALSE, &PL_lex_stuff);
	DEBUG_T( { printbuf("### Saw backtick string before %s\n", s); } );
	if (PL_expect == XOPERATOR)
	    no_op("Backticks",s);
	if (!s)
	    missingterminator(NULL);
	readpipe_override();
	TERM(sublex_start(pl_yylval.ival, PL_lex_op));

    case '\\':
	s++;
	if (PL_lex_inwhat && isDIGIT(*s) && ckWARN(WARN_SYNTAX))
	    Perl_warner(aTHX_ packWARN(WARN_SYNTAX),"Can't use \\%c to mean $%c in expression",
			*s, *s);
	if (PL_expect == XOPERATOR) {
	    if (*s == '=' && s[1] == '=') {
		s += 2;
		Eop(OP_REF_EQ);
	    }
	    if (*s == '!' && s[1] == '=') {
		s += 2;
		Eop(OP_REF_NE);
	    }
	    no_op("Backslash",s);
	}
	OPERATOR(REFGEN);

    case 'v':
	if (isDIGIT(s[1]) && PL_expect != XOPERATOR) {
	    char *start = s + 2;
	    while (isDIGIT(*start) || *start == '_')
		start++;
	    if (*start == '.' && isDIGIT(start[1])) {
		SV* sv = newSV(5); /* preallocate storage space */
		s = scan_vstring(s, PL_bufend, sv);
		pl_yylval.opval = newSVOP(OP_CONST, 0, sv);
		TERM(THING);
	    }
	    /* avoid v123abc() or $h{v1}, allow C<print v10;> */
	    else if (!isALPHA(*start) && (PL_expect == XTERM
			|| PL_expect == XREF || PL_expect == XSTATE
			|| PL_expect == XTERMORDORDOR)) {
		GV *const gv = gv_fetchpvn_flags(s, start - s, 0, SVt_PVCV);
		if (!gv) {
		    SV* sv = newSV(5); /* preallocate storage space */
		    s = scan_vstring(s, PL_bufend, sv);
		    pl_yylval.opval = newSVOP(OP_CONST, 0, sv);
		    TERM(THING);
		}
	    }
	}
	goto keylookup;
    case 'x':
	if (isDIGIT(s[1]) && PL_expect == XOPERATOR) {
	    s++;
	    Mop(OP_REPEAT);
	}
	goto keylookup;

    case '_':
    case 'a': case 'A':
    case 'b': case 'B':
    case 'c': case 'C':
    case 'd': case 'D':
    case 'e': case 'E':
    case 'f': case 'F':
    case 'g': case 'G':
    case 'h': case 'H':
    case 'i': case 'I':
    case 'j': case 'J':
    case 'k': case 'K':
    case 'l': case 'L':
    case 'm': case 'M':
    case 'n': case 'N':
    case 'o': case 'O':
    case 'p': case 'P':
    case 'q': case 'Q':
    case 'r': case 'R':
    case 's': case 'S':
    case 't': case 'T':
    case 'u': case 'U':
	      case 'V':
    case 'w': case 'W':
	      case 'X':
    case 'y': case 'Y':
    case 'z': case 'Z':

      keylookup: {
	I32 tmp;

	orig_keyword = 0;
	gv = NULL;
	gvp = NULL;

	PL_bufptr = s;
	s = scan_word(s, PL_tokenbuf, sizeof PL_tokenbuf, FALSE, &len);

	/* Some keywords can be followed by any delimiter, including ':' */
	tmp = ((len == 1 && strchr("msyq", PL_tokenbuf[0])) ||
	       (len == 2 && ((PL_tokenbuf[0] == 't' && PL_tokenbuf[1] == 'r') ||
			     (PL_tokenbuf[0] == 'q' &&
			      strchr("qwxr", PL_tokenbuf[1])))));

	/* x::* is just a word, unless x is "CORE" */
	if (!tmp && *s == ':' && s[1] == ':' && strNE(PL_tokenbuf, "CORE"))
	    goto just_a_word;

	d = s;
	while (d < PL_bufend && isSPACE(*d))
		d++;	/* no comments skipped here, or s### is misparsed */

	/* Is this a label? */
	if (!tmp && PL_expect == XSTATE
	      && d < PL_bufend && *d == ':' && *(d + 1) != ':') {
	    s = d + 1;
	    pl_yylval.pval = CopLABEL_alloc(PL_tokenbuf);
	    CLINE;
	    TOKEN(LABEL);
	}

	/* Check for keywords */
	tmp = keyword(PL_tokenbuf, len, 0);

	/* Is this a word before a => operator? */
	if (*d == '=' && d[1] == '>') {
	    CLINE;
	    pl_yylval.opval
		= (OP*)newSVOP(OP_CONST, 0,
			       newSVpvn(PL_tokenbuf, len));
	    pl_yylval.opval->op_private = OPpCONST_BARE;
	    TERM(WORD);
	}

	if (tmp < 0) {			/* second-class keyword? */
	    GV *ogv = NULL;	/* override (winner) */
	    GV *hgv = NULL;	/* hidden (loser) */
	    if (PL_expect != XOPERATOR && (*s != ':' || s[1] != ':')) {
		CV *cv;
		if ((gv = gv_fetchpvn_flags(PL_tokenbuf, len, 0, SVt_PVCV)) &&
		    (cv = GvCVu(gv)))
		{
		    if (GvIMPORTED_CV(gv))
			ogv = gv;
		    else if (! CvMETHOD(cv))
			hgv = gv;
		}
		if (!ogv &&
		    (gvp = (GV**)hv_fetch(PL_globalstash,PL_tokenbuf,len,FALSE)) &&
		    (gv = *gvp) && isGV_with_GP(gv) &&
		    GvCVu(gv) && GvIMPORTED_CV(gv))
		{
		    ogv = gv;
		}
	    }
	    if (ogv) {
		orig_keyword = tmp;
		tmp = 0;		/* overridden by import or by GLOBAL */
	    }
	    else if (gv && !gvp
		     && -tmp==KEY_lock	/* XXX generalizable kludge */
		     && GvCVu(gv))
	    {
		tmp = 0;		/* any sub overrides "weak" keyword */
	    }
	    else {			/* no override */
		tmp = -tmp;
		if (tmp == KEY_dump && ckWARN(WARN_MISC)) {
		    Perl_warner(aTHX_ packWARN(WARN_MISC),
			    "dump() better written as CORE::dump()");
		}
		gv = NULL;
		gvp = 0;
		if (hgv && tmp != KEY_x && tmp != KEY_CORE
			&& ckWARN(WARN_AMBIGUOUS))	/* never ambiguous */
		    Perl_warner(aTHX_ packWARN(WARN_AMBIGUOUS),
		    	"Ambiguous call resolved as CORE::%s(), %s",
			 GvENAME(hgv), "qualify as such or use &");
	    }
	}

      reserved_word:
	switch (tmp) {

	default:			/* not a keyword */
	    /* Trade off - by using this evil construction we can pull the
	       variable gv into the block labelled keylookup. If not, then
	       we have to give it function scope so that the goto from the
	       earlier ':' case doesn't bypass the initialisation.  */
	    if (0) {
	    just_a_word_zero_gv:
		gv = NULL;
		gvp = NULL;
		orig_keyword = 0;
	    }
	  just_a_word: {
		SV *sv;
		int pkgname = 0;
		const char lastchar = (PL_bufptr == PL_oldoldbufptr ? 0 : PL_bufptr[-1]);
		CV *cv;
		SV **compsubtable;

#ifdef PERL_MAD
		SV *nextPL_nextwhite = 0;
#endif


		/* Get the rest if it looks like a package qualifier */

		if (*s == ':' && s[1] == ':') {
		    STRLEN morelen;
		    s = scan_word(s, PL_tokenbuf + len, sizeof PL_tokenbuf - len,
				  TRUE, &morelen);
		    if (!morelen)
			Perl_croak(aTHX_ "Bad name after %s::", PL_tokenbuf);
		    len += morelen;
		    pkgname = 1;
		}

		if (PL_expect == XOPERATOR) {
		    if (PL_bufptr == PL_linestart) {
			CopLINE_dec(PL_curcop);
			Perl_warner(aTHX_ packWARN(WARN_SEMICOLON), PL_warn_nosemi);
			CopLINE_inc(PL_curcop);
		    }
		    else
			no_op("Bareword",s);
		}

		/* Is this a compile time function? */
		compsubtable = hv_fetch(PL_compiling.cop_hints_hash, "compsub", 7, FALSE);
		if (compsubtable && SvROK(*compsubtable) && SvTYPE(SvRV(*compsubtable)) == SVt_PVHV) {
		    SV **compsub = hv_fetch((HV *)SvRV(*compsubtable), PL_tokenbuf, len, FALSE);
		    if (compsub) {
			pl_yylval.opval = (OP*)newSVOP(OP_CONST, 0, SvREFCNT_inc_NN(SvRV(*compsub)));
			pl_yylval.opval->op_private = OPpCONST_BARE;
			PL_expect = XTERM;
			s = skipspace(s);
			PL_bufptr = s;
			PL_last_uni = PL_oldbufptr;
			PL_last_lop_op = OP_COMPSUB;
			return REPORT( (int)COMPSUB );
		    }
		}
 

		/* Look for a subroutine with this name in current package,
		   unless name is "Foo::" which isn't allowed. */

		if (len > 2 &&
		    PL_tokenbuf[len - 2] == ':' && PL_tokenbuf[len - 1] == ':')
		{
		    /* And if "Foo::", then that's what it certainly is. */
		    Perl_croak(aTHX_ "Bareword \"%s\" refering to a package are not allowed", PL_tokenbuf);
		}

		if (!gv) {
		    /* Mustn't actually add anything to a symbol table.
		       But also don't want to "initialise" any placeholder
		       constants that might already be there into full
		       blown PVGVs with attached PVCV.  */
		    gv = gv_fetchpvn_flags(PL_tokenbuf, len,
					   GV_NOADD_NOINIT, SVt_PVCV);
		}

		/* if we saw a global override before, get the right name */

		if (gvp) {
		    sv = newSVpvs("CORE::GLOBAL::");
		    sv_catpv(sv,PL_tokenbuf);
		}
		else {
		    sv = newSVpv(PL_tokenbuf,len);
		}
#ifdef PERL_MAD
		if (PL_madskills && !PL_thistoken) {
		    char *start = SvPVX(PL_linestr) + PL_realtokenstart;
		    PL_thistoken = newSVpvn(start,s - start);
		    PL_realtokenstart = s - SvPVX(PL_linestr);
		}
#endif

		/* Presume this is going to be a bareword of some sort. */

		CLINE;
		pl_yylval.opval = (OP*)newSVOP(OP_CONST, 0, sv);
		pl_yylval.opval->op_private = OPpCONST_BARE;

		/* Do the explicit type check so that we don't need to force
		   the initialisation of the symbol table to have a real GV.
		   Beware - gv may not really be a PVGV, cv may not really be
		   a PVCV, (because of the space optimisations that gv_init
		   understands) But they're true if for this symbol there is
		   respectively a typeglob and a subroutine.
		*/
		cv = gv ? ((SvTYPE(gv) == SVt_PVGV)
		    /* Real typeglob, so get the real subroutine: */
			   ? GvCVu(gv)
		    /* A proxy for a subroutine in this package? */
			   : SvOK(gv) ? (CV *) gv : NULL)
		    : NULL;

		/* See if it's the indirect object for a list operator. */

		if (PL_oldoldbufptr &&
		    PL_oldoldbufptr < PL_bufptr &&
		    (PL_oldoldbufptr == PL_last_lop
		     || PL_oldoldbufptr == PL_last_uni) &&
		    /* NO SKIPSPACE BEFORE HERE! */
		    (PL_expect == XREF ||
		     ((PL_opargs[PL_last_lop_op] >> OASHIFT)& 7) == OA_FILEREF))
		{
		    bool immediate_paren = *s == '(';

		    /* (Now we can afford to cross potential line boundary.) */
		    s = SKIPSPACE2(s,nextPL_nextwhite);
#ifdef PERL_MAD
		    PL_nextwhite = nextPL_nextwhite;	/* assume no & deception */
#endif

		    /* If not a declared subroutine, it's an indirect object. */
		    /* (But it's an indir obj regardless for sort.) */
		    /* Also, if "_" follows a filetest operator, it's a bareword */

		    if (
			( !immediate_paren && (PL_last_lop_op == OP_SORT ||
                         ((!gv || !cv) &&
                        (PL_last_lop_op != OP_MAPSTART &&
			 PL_last_lop_op != OP_GREPSTART))))
		       || (PL_tokenbuf[0] == '_' && PL_tokenbuf[1] == '\0'
			    && ((PL_opargs[PL_last_lop_op] & OA_CLASS_MASK) == OA_FILESTATOP))
		       )
		    {
			PL_expect = (PL_last_lop == PL_oldoldbufptr) ? XTERM : XOPERATOR;
			goto bareword;
		    }
		}

		PL_expect = XOPERATOR;
#ifdef PERL_MAD
		if (isSPACE(*s))
		    s = SKIPSPACE2(s,nextPL_nextwhite);
		PL_nextwhite = nextPL_nextwhite;
#else
		s = skipspace(s);
#endif

		/* Is this a word before a => operator? */
		if (*s == '=' && s[1] == '>' && !pkgname) {
		    CLINE;
		    sv_setpv(((SVOP*)pl_yylval.opval)->op_sv, PL_tokenbuf);
		    TERM(WORD);
		}

		/* If followed by a paren, it's certainly a subroutine. */
		if (*s == '(') {
		    CLINE;
		    if (cv) {
			d = s + 1;
			while (SPACE_OR_TAB(*d))
			    d++;
			if (*d == ')' && (sv = gv_const_sv(gv))) {
#ifdef PERL_MAD
			    if (PL_madskills) {
				curmad('X', PL_thistoken);
				curmad('_', PL_thiswhite);
				curmad('h', newSVpvn(s, d-s+1));
			    }
#endif
			    s = d + 1;
			    goto its_constant;
			}
		    }
#ifdef PERL_MAD
		    if (PL_madskills) {
			PL_nextwhite = PL_thiswhite;
			PL_thiswhite = 0;
		    }
		    start_force(PL_curforce);
#endif
		    NEXTVAL_NEXTTOKE.opval = pl_yylval.opval;
		    PL_expect = XOPERATOR;
#ifdef PERL_MAD
		    if (PL_madskills) {
			PL_nextwhite = nextPL_nextwhite;
			curmad('X', PL_thistoken);
			PL_thistoken = newSVpvs("");
		    }
#endif
		    force_next(WORD);
		    pl_yylval.ival = 0;
		    TOKEN('&');
		}

		/* Not a method, so call it a subroutine (if defined) */

		if (cv) {
		    if (lastchar == '-' && ckWARN_d(WARN_AMBIGUOUS))
			Perl_warner(aTHX_ packWARN(WARN_AMBIGUOUS),
				"Ambiguous use of -%s resolved as -&%s()",
				PL_tokenbuf, PL_tokenbuf);
		    /* Check for a constant sub */
		    if ((sv = gv_const_sv(gv))) {
		  its_constant:
			SvREFCNT_dec(((SVOP*)pl_yylval.opval)->op_sv);
			((SVOP*)pl_yylval.opval)->op_sv = SvREFCNT_inc_simple(sv);
			pl_yylval.opval->op_private = 0;
			TOKEN(WORD);
		    }

		    /* Resolve to GV now. */
		    if (SvTYPE(gv) != SVt_PVGV) {
			gv = gv_fetchpv(PL_tokenbuf, 0, SVt_PVCV);
			assert (SvTYPE(gv) == SVt_PVGV);
			/* cv must have been some sort of placeholder, so
			   now needs replacing with a real code reference.  */
			cv = GvCV(gv);
		    }

		    op_free(pl_yylval.opval);
		    pl_yylval.opval = newCVREF(0, newGVOP(OP_GV, 0, gv));
		    pl_yylval.opval->op_private |= OPpENTERSUB_NOPAREN;
		    PL_last_lop = PL_oldbufptr;
		    PL_last_lop_op = OP_ENTERSUB;
		    /* Is there a prototype? */
		    if (SvPOK(cv)) {
			STRLEN protolen;
			const char *proto = SvPV_const((SV*)cv, protolen);
			if (!protolen)
			    TERM(FUNC0SUB);
			if ((*proto == '$' || *proto == '_') && proto[1] == '\0')
			    OPERATOR(UNIOPSUB);
			while (*proto == ';')
			    proto++;
			if (*proto == '&' && *s == '{') {
			    if (PL_curstash)
				sv_setpvs(PL_subname, "__ANON__");
			    else
				sv_setpvs(PL_subname, "__ANON__::__ANON__");
			    PREBLOCK(LSTOPSUB);
			}
		    }
#ifdef PERL_MAD
		    if (PL_madskills) {
			PL_nextwhite = PL_thiswhite;
			PL_thiswhite = 0;
		    }
		    start_force(PL_curforce);
#endif
		    NEXTVAL_NEXTTOKE.opval = pl_yylval.opval;
		    PL_expect = XTERM;
#ifdef PERL_MAD
		    if (PL_madskills) {
			PL_nextwhite = nextPL_nextwhite;
			curmad('X', PL_thistoken);
			PL_thistoken = newSVpvs("");
		    }
#endif
		    force_next(WORD);
		    TOKEN(NOAMP);
		}

		/* Call it a bare word */

		if (PL_hints & HINT_STRICT_SUBS)
		    pl_yylval.opval->op_private |= OPpCONST_STRICT;
		else {
		bareword:
		    if (lastchar != '-') {
			if (ckWARN(WARN_RESERVED)) {
			    d = PL_tokenbuf;
			    while (isLOWER(*d))
				d++;
			    if (!*d && !gv_stashpv(PL_tokenbuf, 0))
				Perl_warner(aTHX_ packWARN(WARN_RESERVED), PL_warn_reserved,
				       PL_tokenbuf);
			}
		    }
		}

		if ((lastchar == '*' || lastchar == '%' || lastchar == '&')
		    && ckWARN_d(WARN_AMBIGUOUS)) {
		    Perl_warner(aTHX_ packWARN(WARN_AMBIGUOUS),
		  	"Operator or semicolon missing before %c%s",
			lastchar, PL_tokenbuf);
		    Perl_warner(aTHX_ packWARN(WARN_AMBIGUOUS),
			"Ambiguous use of %c resolved as operator %c",
			lastchar, lastchar);
		}
		TOKEN(WORD);
	    }

	case KEY___FILE__:
	    pl_yylval.opval = (OP*)newSVOP(OP_CONST, 0,
					newSVpv(CopFILE(PL_curcop),0));
	    TERM(THING);

	case KEY___LINE__:
            pl_yylval.opval = (OP*)newSVOP(OP_CONST, 0,
                                    Perl_newSVpvf(aTHX_ "%"IVdf, (IV)CopLINE(PL_curcop)));
	    TERM(THING);

	case KEY___PACKAGE__:
	    pl_yylval.opval = (OP*)newSVOP(OP_CONST, 0,
					(PL_curstash
					 ? newSVhek(HvNAME_HEK(PL_curstash))
					 : &PL_sv_undef));
	    TERM(THING);

	case KEY___DATA__:
	case KEY___END__: {
	    GV *gv;
	    if (PL_rsfp && (!PL_in_eval || PL_tokenbuf[2] == 'D')) {
		const char *pname = "main";
		if (PL_tokenbuf[2] == 'D')
		    pname = HvNAME_get(PL_curstash ? PL_curstash : PL_defstash);
		gv = gv_fetchpv(Perl_form(aTHX_ "%s::DATA", pname), GV_ADD,
				SVt_PVIO);
		GvMULTI_on(gv);
		if (!GvIO(gv))
		    GvIOp(gv) = newIO();
		IoIFP(GvIOp(gv)) = PL_rsfp;
#if defined(HAS_FCNTL) && defined(F_SETFD)
		{
		    const int fd = PerlIO_fileno(PL_rsfp);
		    fcntl(fd,F_SETFD,fd >= 3);
		}
#endif
		/* Mark this internal pseudo-handle as clean */
		IoFLAGS(GvIOp(gv)) |= IOf_UNTAINT;
		if ((PerlIO*)PL_rsfp == PerlIO_stdin())
		    IoTYPE(GvIOp(gv)) = IoTYPE_STD;
		else
		    IoTYPE(GvIOp(gv)) = IoTYPE_RDONLY;
#if defined(WIN32) && !defined(PERL_TEXTMODE_SCRIPTS)
		/* if the script was opened in binmode, we need to revert
		 * it to text mode for compatibility; but only iff it has CRs
		 * XXX this is a questionable hack at best. */
		if (PL_bufend-PL_bufptr > 2
		    && PL_bufend[-1] == '\n' && PL_bufend[-2] == '\r')
		{
		    Off_t loc = 0;
		    if (IoTYPE(GvIOp(gv)) == IoTYPE_RDONLY) {
			loc = PerlIO_tell(PL_rsfp);
			(void)PerlIO_seek(PL_rsfp, 0L, 0);
		    }
#ifdef NETWARE
			if (PerlLIO_setmode(PL_rsfp, O_TEXT) != -1) {
#else
		    if (PerlLIO_setmode(PerlIO_fileno(PL_rsfp), O_TEXT) != -1) {
#endif	/* NETWARE */
#ifdef PERLIO_IS_STDIO /* really? */
#  if defined(__BORLANDC__)
			/* XXX see note in do_binmode() */
			((FILE*)PL_rsfp)->flags &= ~_F_BIN;
#  endif
#endif
			if (loc > 0)
			    PerlIO_seek(PL_rsfp, loc, 0);
		    }
		}
#endif
#ifdef PERLIO_LAYERS
		if (!IN_BYTES) {
		    if (UTF)
			PerlIO_apply_layers(aTHX_ PL_rsfp, NULL, ":utf8");
		}
#endif
#ifdef PERL_MAD
		if (PL_madskills) {
		    if (PL_realtokenstart >= 0) {
			char *tstart = SvPVX(PL_linestr) + PL_realtokenstart;
			if (!PL_endwhite)
			    PL_endwhite = newSVpvs("");
			sv_catsv(PL_endwhite, PL_thiswhite);
			PL_thiswhite = 0;
			sv_catpvn(PL_endwhite, tstart, PL_bufend - tstart);
			PL_realtokenstart = -1;
		    }
		    while ((s = filter_gets(PL_endwhite, PL_rsfp,
				 SvCUR(PL_endwhite))) != NULL) ;
		}
#endif
		PL_rsfp = NULL;
	    }
	    goto fake_eof;
	}

	case KEY_DESTROY:
	case KEY_BEGIN:
	case KEY_UNITCHECK:
	case KEY_CHECK:
	case KEY_INIT:
	case KEY_END:
	    if (PL_expect == XSTATE) {
		s = PL_bufptr;
		goto really_sub;
	    }
	    goto just_a_word;

	case KEY_CORE:
	    if (*s == ':' && s[1] == ':') {
		s += 2;
		d = s;
		s = scan_word(s, PL_tokenbuf, sizeof PL_tokenbuf, FALSE, &len);
		if (!(tmp = keyword(PL_tokenbuf, len, 0)))
		    Perl_croak(aTHX_ "CORE::%s is not a keyword", PL_tokenbuf);
		if (tmp < 0)
		    tmp = -tmp;
		else if (tmp == KEY_require || tmp == KEY_do)
		    /* that's a way to remember we saw "CORE::" */
		    orig_keyword = tmp;
		goto reserved_word;
	    }
	    goto just_a_word;

	case KEY_abs:
	    UNI(OP_ABS);

	case KEY_alarm:
	    UNI(OP_ALARM);

	case KEY_accept:
	    LOP(OP_ACCEPT,XTERM);

	case KEY_and:
	    OPERATOR(ANDOP);

	case KEY_atan2:
	    LOP(OP_ATAN2,XTERM);

	case KEY_bind:
	    LOP(OP_BIND,XTERM);

	case KEY_binmode:
	    LOP(OP_BINMODE,XTERM);

	case KEY_bless:
	    LOP(OP_BLESS,XTERM);

	case KEY_break:
	    FUN0(OP_BREAK);

	case KEY_chop:
	    UNI(OP_CHOP);

	case KEY_continue:
	    /* When 'use switch' is in effect, continue has a dual
	       life as a control operator. */
	    {
		if (!FEATURE_IS_ENABLED("switch"))
		    PREBLOCK(CONTINUE);
		else {
		    /* We have to disambiguate the two senses of
		      "continue". If the next token is a '{' then
		      treat it as the start of a continue block;
		      otherwise treat it as a control operator.
		     */
		    s = skipspace(s);
		    if (*s == '{')
	    PREBLOCK(CONTINUE);
		    else
			FUN0(OP_CONTINUE);
		}
	    }

	case KEY_chdir:
	    /* may use HOME */
	    (void)gv_fetchpvs("ENV", GV_ADD|GV_NOTQUAL, SVt_PVHV);
	    UNI(OP_CHDIR);

	case KEY_close:
	    UNI(OP_CLOSE);

	case KEY_closedir:
	    UNI(OP_CLOSEDIR);

	case KEY_cmp:
	    Eop(OP_SCMP);

	case KEY_caller:
	    UNI(OP_CALLER);

	case KEY_crypt:
#ifdef FCRYPT
	    if (!PL_cryptseen) {
		PL_cryptseen = TRUE;
		init_des();
	    }
#endif
	    LOP(OP_CRYPT,XTERM);

	case KEY_chmod:
	    LOP(OP_CHMOD,XTERM);

	case KEY_chown:
	    LOP(OP_CHOWN,XTERM);

	case KEY_connect:
	    LOP(OP_CONNECT,XTERM);

	case KEY_chr:
	    UNI(OP_CHR);

	case KEY_cos:
	    UNI(OP_COS);

	case KEY_chroot:
	    UNI(OP_CHROOT);

	case KEY_default:
	    PREBLOCK(DEFAULT);

	case KEY_do:
	    s = SKIPSPACE1(s);
	    if (*s == '{')
		PRETERMBLOCK(DO);
	    if (*s != '\'')
		s = force_word(s,WORD,TRUE,TRUE,FALSE);
	    if (orig_keyword == KEY_do) {
		orig_keyword = 0;
		pl_yylval.ival = 1;
	    }
	    else
		pl_yylval.ival = 0;
	    OPERATOR(DO);

	case KEY_die:
	    PL_hints |= HINT_BLOCK_SCOPE;
	    LOP(OP_DIE,XTERM);

	case KEY_defined:
	    UNI(OP_DEFINED);

	case KEY_delete:
	    UNI(OP_DELETE);

	case KEY_dump:
	    s = force_word(s,WORD,TRUE,FALSE,FALSE);
	    LOOPX(OP_DUMP);

	case KEY_else:
	    PREBLOCK(ELSE);

	case KEY_elsif:
	    pl_yylval.ival = CopLINE(PL_curcop);
	    OPERATOR(ELSIF);

	case KEY_eq:
	    Eop(OP_SEQ);

	case KEY_exists:
	    UNI(OP_EXISTS);
	
	case KEY_exit:
	    UNI(OP_EXIT);

	case KEY_eval:
	    s = SKIPSPACE1(s);
	    PL_expect = (*s == '{') ? XTERMBLOCK : XTERM;
	    UNIBRACK(OP_ENTEREVAL);

	case KEY_eof:
	    UNI(OP_EOF);

	case KEY_exp:
	    UNI(OP_EXP);

	case KEY_each:
	    UNI(OP_EACH);

	case KEY_exec:
	    LOP(OP_EXEC,XREF);

	case KEY_endhostent:
	    FUN0(OP_EHOSTENT);

	case KEY_endnetent:
	    FUN0(OP_ENETENT);

	case KEY_endservent:
	    FUN0(OP_ESERVENT);

	case KEY_endprotoent:
	    FUN0(OP_EPROTOENT);

	case KEY_endpwent:
	    FUN0(OP_EPWENT);

	case KEY_endgrent:
	    FUN0(OP_EGRENT);

	case KEY_for:
	case KEY_foreach:
	    pl_yylval.ival = CopLINE(PL_curcop);
	    s = SKIPSPACE1(s);
	    if (PL_expect == XSTATE && isIDFIRST_lazy_if(s,UTF)) {
		char *p = s;
#ifdef PERL_MAD
		int soff = s - SvPVX(PL_linestr); /* for skipspace realloc */
#endif

		if ((PL_bufend - p) >= 3 &&
		    strnEQ(p, "my", 2) && isSPACE(*(p + 2)))
		    p += 2;
		else if ((PL_bufend - p) >= 4 &&
		    strnEQ(p, "our", 3) && isSPACE(*(p + 3)))
		    p += 3;
		p = PEEKSPACE(p);
		if (isIDFIRST_lazy_if(p,UTF)) {
		    p = scan_ident(p, PL_bufend,
			PL_tokenbuf, sizeof PL_tokenbuf, TRUE);
		    p = PEEKSPACE(p);
		}
		if (*p != '$')
		    Perl_croak(aTHX_ "Missing $ on loop variable");
#ifdef PERL_MAD
		s = SvPVX(PL_linestr) + soff;
#endif
	    }
	    OPERATOR(FOR);

	case KEY_fork:
	    FUN0(OP_FORK);

	case KEY_fcntl:
	    LOP(OP_FCNTL,XTERM);

	case KEY_fileno:
	    UNI(OP_FILENO);

	case KEY_flock:
	    LOP(OP_FLOCK,XTERM);

	case KEY_grep:
	    LOP(OP_GREPSTART, XREF);

	case KEY_goto:
	    s = force_word(s,WORD,TRUE,FALSE,FALSE);
	    LOOPX(OP_GOTO);

	case KEY_gmtime:
	    UNI(OP_GMTIME);

	case KEY_getc:
	    UNIDOR(OP_GETC);

	case KEY_getppid:
	    FUN0(OP_GETPPID);

	case KEY_getpgrp:
	    UNI(OP_GETPGRP);

	case KEY_getpriority:
	    LOP(OP_GETPRIORITY,XTERM);

	case KEY_getprotobyname:
	    UNI(OP_GPBYNAME);

	case KEY_getprotobynumber:
	    LOP(OP_GPBYNUMBER,XTERM);

	case KEY_getprotoent:
	    FUN0(OP_GPROTOENT);

	case KEY_getpwent:
	    FUN0(OP_GPWENT);

	case KEY_getpwnam:
	    UNI(OP_GPWNAM);

	case KEY_getpwuid:
	    UNI(OP_GPWUID);

	case KEY_getpeername:
	    UNI(OP_GETPEERNAME);

	case KEY_gethostbyname:
	    UNI(OP_GHBYNAME);

	case KEY_gethostbyaddr:
	    LOP(OP_GHBYADDR,XTERM);

	case KEY_gethostent:
	    FUN0(OP_GHOSTENT);

	case KEY_getnetbyname:
	    UNI(OP_GNBYNAME);

	case KEY_getnetbyaddr:
	    LOP(OP_GNBYADDR,XTERM);

	case KEY_getnetent:
	    FUN0(OP_GNETENT);

	case KEY_getservbyname:
	    LOP(OP_GSBYNAME,XTERM);

	case KEY_getservbyport:
	    LOP(OP_GSBYPORT,XTERM);

	case KEY_getservent:
	    FUN0(OP_GSERVENT);

	case KEY_getsockname:
	    UNI(OP_GETSOCKNAME);

	case KEY_getsockopt:
	    LOP(OP_GSOCKOPT,XTERM);

	case KEY_getgrent:
	    FUN0(OP_GGRENT);

	case KEY_getgrnam:
	    UNI(OP_GGRNAM);

	case KEY_getgrgid:
	    UNI(OP_GGRGID);

	case KEY_getlogin:
	    FUN0(OP_GETLOGIN);

	case KEY_given:
	    pl_yylval.ival = CopLINE(PL_curcop);
	    OPERATOR(GIVEN);

	case KEY_glob:
	    LOP(OP_GLOB,XTERM);

	case KEY_hex:
	    UNI(OP_HEX);

	case KEY_if:
	    pl_yylval.ival = CopLINE(PL_curcop);
	    OPERATOR(IF);

	case KEY_index:
	    LOP(OP_INDEX,XTERM);

	case KEY_int:
	    UNI(OP_INT);

	case KEY_ioctl:
	    LOP(OP_IOCTL,XTERM);

	case KEY_join:
	    LOP(OP_JOIN,XTERM);

	case KEY_keys:
	    UNI(OP_KEYS);

	case KEY_kill:
	    LOP(OP_KILL,XTERM);

	case KEY_last:
	    s = force_word(s,WORD,TRUE,FALSE,FALSE);
	    LOOPX(OP_LAST);
	
	case KEY_lc:
	    UNI(OP_LC);

	case KEY_lcfirst:
	    UNI(OP_LCFIRST);

	case KEY_local:
	    pl_yylval.ival = 0;
	    OPERATOR(LOCAL);

	case KEY_length:
	    UNI(OP_LENGTH);

	case KEY_localtime:
	    UNI(OP_LOCALTIME);

	case KEY_log:
	    UNI(OP_LOG);

	case KEY_link:
	    LOP(OP_LINK,XTERM);

	case KEY_listen:
	    LOP(OP_LISTEN,XTERM);

	case KEY_lock:
	    UNI(OP_LOCK);

	case KEY_lstat:
	    UNI(OP_LSTAT);

	case KEY_m:
	    s = scan_pat(s,OP_MATCH);
	    TERM(sublex_start(pl_yylval.ival, PL_lex_op));

	case KEY_map:
	    LOP(OP_MAPSTART, XREF);

	case KEY_mkdir:
	    LOP(OP_MKDIR,XTERM);

	case KEY_msgctl:
	    LOP(OP_MSGCTL,XTERM);

	case KEY_msgget:
	    LOP(OP_MSGGET,XTERM);

	case KEY_msgrcv:
	    LOP(OP_MSGRCV,XTERM);

	case KEY_msgsnd:
	    LOP(OP_MSGSND,XTERM);

	case KEY_our:
	case KEY_my:
	case KEY_state:
	    PL_in_my = (U16)tmp;
	    s = SKIPSPACE1(s);
	    if (isIDFIRST_lazy_if(s,UTF)) {
		s = scan_word(s, PL_tokenbuf, sizeof PL_tokenbuf, TRUE, &len);
		if (len == 3 && strnEQ(PL_tokenbuf, "sub", 3))
		    goto really_sub;
		Perl_croak(aTHX_ "Expected variable after declarator");
	    }
	    pl_yylval.ival = 1;
	    OPERATOR(MY);

	case KEY_next:
	    s = force_word(s,WORD,TRUE,FALSE,FALSE);
	    LOOPX(OP_NEXT);

	case KEY_ne:
	    Eop(OP_SNE);

	case KEY_no:
	    s = tokenize_use(0, s);
	    OPERATOR(USE);

	case KEY_not:
	    if (*s == '(' || (s = SKIPSPACE1(s), *s == '('))
		FUN1(OP_NOT);
	    else
		OPERATOR(NOTOP);

	case KEY_open:
	    s = SKIPSPACE1(s);
	    if (isIDFIRST_lazy_if(s,UTF)) {
		const char *t;
		for (d = s; isALNUM_lazy_if(d,UTF);)
		    d++;
		for (t=d; isSPACE(*t);)
		    t++;
		if ( *t && strchr("|&*+-=!?:.", *t) && ckWARN_d(WARN_PRECEDENCE)
		    /* [perl #16184] */
		    && !(t[0] == '=' && t[1] == '>')
		) {
		    int parms_len = (int)(d-s);
		    Perl_warner(aTHX_ packWARN(WARN_PRECEDENCE),
			   "Precedence problem: open %.*s should be open(%.*s)",
			    parms_len, s, parms_len, s);
		}
	    }
	    LOP(OP_OPEN,XTERM);

	case KEY_or:
	    pl_yylval.ival = OP_OR;
	    OPERATOR(OROP);

	case KEY_ord:
	    UNI(OP_ORD);

	case KEY_oct:
	    UNI(OP_OCT);

	case KEY_opendir:
	    LOP(OP_OPEN_DIR,XTERM);

	case KEY_print:
	    checkcomma(s,PL_tokenbuf,"filehandle");
	    LOP(OP_PRINT,XREF);

	case KEY_printf:
	    checkcomma(s,PL_tokenbuf,"filehandle");
	    LOP(OP_PRTF,XREF);

	case KEY_prototype:
	    UNI(OP_PROTOTYPE);

	case KEY_push:
	    LOP(OP_PUSH,XTERM);

	case KEY_pop:
	    UNIDOR(OP_POP);

	case KEY_pos:
	    UNIDOR(OP_POS);
	
	case KEY_pack:
	    LOP(OP_PACK,XTERM);

	case KEY_package:
	    s = force_word(s,WORD,FALSE,TRUE,FALSE);
	    OPERATOR(PACKAGE);

	case KEY_pipe:
	    LOP(OP_PIPE_OP,XTERM);

	case KEY_q:
	    PL_lex_stuff.flags = LEXf_SINGLEQ;
	    s = scan_str(s,FALSE,FALSE, &PL_lex_stuff);
	    if (!s)
		missingterminator(NULL);
	    pl_yylval.ival = OP_CONST;
	    TERM(sublex_start(pl_yylval.ival, NULL));

	case KEY_quotemeta:
	    UNI(OP_QUOTEMETA);

	case KEY_qw:
	    PL_lex_stuff.flags = LEXf_QW;
	    s = scan_str(s,FALSE,FALSE, &PL_lex_stuff);
	    if (!s)
		missingterminator(NULL);
	    PL_expect = XOPERATOR;
	    force_next(')');
	    if (SvCUR(PL_lex_stuff.str_sv)) {
		OP *words = NULL;
		int warned = 0;
		d = SvPV_force(PL_lex_stuff.str_sv, len);
		while (len) {
		    for (; isSPACE(*d) && len; --len, ++d)
			/**/;
		    if (len) {
			SV *sv;
			const char *b = d;
			if (!warned && ckWARN(WARN_QW)) {
			    for (; !isSPACE(*d) && len; --len, ++d) {
				if (*d == ',') {
				    Perl_warner(aTHX_ packWARN(WARN_QW),
					"Possible attempt to separate words with commas");
				    ++warned;
				}
				else if (*d == '#') {
				    Perl_warner(aTHX_ packWARN(WARN_QW),
					"Possible attempt to put comments in qw() list");
				    ++warned;
				}
			    }
			}
			else {
			    for (; !isSPACE(*d) && len; --len, ++d)
				/**/;
			}
			sv = newSVpvn(b, d-b);
			words = append_elem(OP_LIST, words,
					    newSVOP(OP_CONST, 0, tokeq(sv)));
		    }
		}
		if (words) {
		    start_force(PL_curforce);
		    NEXTVAL_NEXTTOKE.opval = words;
		    force_next(THING);
		}
	    }
	    if (PL_lex_stuff.str_sv) {
		SvREFCNT_dec(PL_lex_stuff.str_sv);
		PL_lex_stuff.str_sv = NULL;
	    }
	    PL_expect = XTERM;
	    TOKEN('(');

	case KEY_qq:
	    PL_lex_stuff.flags = LEXf_DOUBLEQ;
	    s = scan_str(s,TRUE,FALSE, &PL_lex_stuff);
	    if (!s)
		missingterminator(NULL);
	    pl_yylval.ival = OP_STRINGIFY;
	    TERM(sublex_start(pl_yylval.ival, NULL));

	case KEY_qr:
	    s = scan_pat(s,OP_QR);
	    TERM(sublex_start(pl_yylval.ival, PL_lex_op));

	case KEY_qx:
	    PL_lex_stuff.flags = LEXf_BACKTICK;
	    s = scan_str(s,TRUE,FALSE, &PL_lex_stuff);
	    if (!s)
		missingterminator(NULL);
	    readpipe_override();
	    TERM(sublex_start(pl_yylval.ival, NULL));

	case KEY_return:
	    OLDLOP(OP_RETURN);

	case KEY_require:
	    s = SKIPSPACE1(s);
	    if (isDIGIT(*s) || ((*s == 'v') && isDIGIT(s[1]))) {
		yyerror(Perl_form(aTHX_ "require VERSION is not valid in Perl Kurila (this is probably Perl 5 code)"));
	    }
	    *PL_tokenbuf = '\0';
	    s = force_word(s,WORD,TRUE,TRUE,FALSE);
	    if (isIDFIRST_lazy_if(PL_tokenbuf,UTF))
		gv_stashpvn(PL_tokenbuf, strlen(PL_tokenbuf), GV_ADD);
	    else if (*s == '<')
		yyerror("<> should be quotes");
	    if (orig_keyword == KEY_require) {
		orig_keyword = 0;
		pl_yylval.ival = 1;
	    }
	    else 
		pl_yylval.ival = 0;
	    PL_expect = XTERM;
	    PL_bufptr = s;
	    PL_last_uni = PL_oldbufptr;
	    PL_last_lop_op = OP_REQUIRE;
	    s = skipspace(s);
	    return REPORT( (int)REQUIRE );

	case KEY_redo:
	    s = force_word(s,WORD,TRUE,FALSE,FALSE);
	    LOOPX(OP_REDO);

	case KEY_rename:
	    LOP(OP_RENAME,XTERM);

	case KEY_rand:
	    UNI(OP_RAND);

	case KEY_rmdir:
	    UNI(OP_RMDIR);

	case KEY_rindex:
	    LOP(OP_RINDEX,XTERM);

	case KEY_read:
	    LOP(OP_READ,XTERM);

	case KEY_readdir:
	    UNI(OP_READDIR);

	case KEY_readline:
	    UNIDOR(OP_READLINE);

	case KEY_readpipe:
	    UNIDOR(OP_BACKTICK);

	case KEY_rewinddir:
	    UNI(OP_REWINDDIR);

	case KEY_recv:
	    LOP(OP_RECV,XTERM);

	case KEY_reverse:
	    LOP(OP_REVERSE,XTERM);

	case KEY_readlink:
	    UNIDOR(OP_READLINK);

	case KEY_ref:
	    UNI(OP_REF);

	case KEY_s:
	    s = scan_subst(s);
	    if (pl_yylval.opval)
		TERM(sublex_start(pl_yylval.ival, PL_lex_op));
	    else
		TOKEN(1);	/* force error */

	case KEY_chomp:
	    UNI(OP_CHOMP);
	
	case KEY_scalar:
	    UNI(OP_SCALAR);

	case KEY_select:
	    LOP(OP_SELECT,XTERM);

	case KEY_seek:
	    LOP(OP_SEEK,XTERM);

	case KEY_semctl:
	    LOP(OP_SEMCTL,XTERM);

	case KEY_semget:
	    LOP(OP_SEMGET,XTERM);

	case KEY_semop:
	    LOP(OP_SEMOP,XTERM);

	case KEY_send:
	    LOP(OP_SEND,XTERM);

	case KEY_setpgrp:
	    LOP(OP_SETPGRP,XTERM);

	case KEY_setpriority:
	    LOP(OP_SETPRIORITY,XTERM);

	case KEY_sethostent:
	    UNI(OP_SHOSTENT);

	case KEY_setnetent:
	    UNI(OP_SNETENT);

	case KEY_setservent:
	    UNI(OP_SSERVENT);

	case KEY_setprotoent:
	    UNI(OP_SPROTOENT);

	case KEY_setpwent:
	    FUN0(OP_SPWENT);

	case KEY_setgrent:
	    FUN0(OP_SGRENT);

	case KEY_seekdir:
	    LOP(OP_SEEKDIR,XTERM);

	case KEY_setsockopt:
	    LOP(OP_SSOCKOPT,XTERM);

	case KEY_shift:
	    UNIDOR(OP_SHIFT);

	case KEY_shmctl:
	    LOP(OP_SHMCTL,XTERM);

	case KEY_shmget:
	    LOP(OP_SHMGET,XTERM);

	case KEY_shmread:
	    LOP(OP_SHMREAD,XTERM);

	case KEY_shmwrite:
	    LOP(OP_SHMWRITE,XTERM);

	case KEY_shutdown:
	    LOP(OP_SHUTDOWN,XTERM);

	case KEY_sin:
	    UNI(OP_SIN);

	case KEY_sleep:
	    UNI(OP_SLEEP);

	case KEY_socket:
	    LOP(OP_SOCKET,XTERM);

	case KEY_socketpair:
	    LOP(OP_SOCKPAIR,XTERM);

	case KEY_sort:
	    checkcomma(s,PL_tokenbuf,"subroutine name");
	    s = SKIPSPACE1(s);
	    if (*s == ';' || *s == ')')		/* probably a close */
		Perl_croak(aTHX_ "sort is now a reserved word");
	    PL_expect = XTERM;
	    s = force_word(s,WORD,TRUE,TRUE,FALSE);
	    LOP(OP_SORT,XREF);

	case KEY_split:
	    LOP(OP_SPLIT,XTERM);

	case KEY_sprintf:
	    LOP(OP_SPRINTF,XTERM);

	case KEY_splice:
	    LOP(OP_SPLICE,XTERM);

	case KEY_sqrt:
	    UNI(OP_SQRT);

	case KEY_srand:
	    UNI(OP_SRAND);

	case KEY_stat:
	    UNI(OP_STAT);

	case KEY_study:
	    UNI(OP_STUDY);

	case KEY_substr:
	    LOP(OP_SUBSTR,XTERM);

	case KEY_sub:
	  really_sub:
	    {
		char tmpbuf[sizeof PL_tokenbuf];
		SSize_t tboffset = 0;
		expectation attrful;
		bool have_name, have_proto;
		const int key = tmp;

#ifdef PERL_MAD
		SV *tmpwhite = 0;

		char *tstart = SvPVX(PL_linestr) + PL_realtokenstart;
		SV *subtoken = newSVpvn(tstart, s - tstart);
		PL_thistoken = 0;

		d = s;
		s = SKIPSPACE2(s,tmpwhite);
#else
		s = skipspace(s);
#endif

		if (isIDFIRST_lazy_if(s,UTF) ||
		    (*s == ':' && s[1] == ':'))
		{
#ifdef PERL_MAD
		    SV *nametoke = NULL;
#endif

		    PL_expect = XBLOCK;
		    attrful = XATTRBLOCK;
		    /* remember buffer pos'n for later force_word */
		    tboffset = s - PL_oldbufptr;
		    d = scan_word(s, tmpbuf, sizeof tmpbuf, TRUE, &len);
#ifdef PERL_MAD
		    if (PL_madskills)
			nametoke = newSVpvn(s, d - s);
#endif
		    if (memchr(tmpbuf, ':', len))
			sv_setpvn(PL_subname, tmpbuf, len);
		    else {
			sv_setsv(PL_subname,PL_curstname);
			sv_catpvs(PL_subname,"::");
			sv_catpvn(PL_subname,tmpbuf,len);
		    }
		    have_name = TRUE;

#ifdef PERL_MAD

		    start_force(0);
		    CURMAD('X', nametoke);
		    CURMAD('_', tmpwhite);
		    (void) force_word(PL_oldbufptr + tboffset, WORD,
				      FALSE, TRUE, TRUE);

		    s = SKIPSPACE2(d,tmpwhite);
#else
		    s = skipspace(d);
#endif
		}
		else {
		    if (key == KEY_my)
			Perl_croak(aTHX_ "Missing name in \"my sub\"");
		    PL_expect = XTERMBLOCK;
		    attrful = XATTRTERM;
		    sv_setpvn(PL_subname,"?",1);
		    have_name = FALSE;
		}

		/* Look for a prototype */
		if (*s == '(') {
		    char *p;
		    bool bad_proto = FALSE;
		    const bool warnsyntax = ckWARN(WARN_SYNTAX);

		    PL_lex_stuff.flags = LEXf_PROTOTYPE;
		    s = scan_str(s,TRUE,FALSE, &PL_lex_stuff);
		    if (!s)
			Perl_croak(aTHX_ "Prototype not terminated");
		    /* strip spaces and check for bad characters */
		    d = SvPVX(PL_lex_stuff.str_sv);
		    tmp = 0;
		    for (p = d; *p; ++p) {
			if (!isSPACE(*p)) {
			    d[tmp++] = *p;
			    if (warnsyntax && !strchr("$@%*;[]&\\_", *p))
				bad_proto = TRUE;
			}
		    }
		    d[tmp] = '\0';
		    if (bad_proto)
			Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				    "Illegal character in prototype for %"SVf" : %s",
				    SVfARG(PL_subname), d);
		    SvCUR_set(PL_lex_stuff.str_sv, tmp);
		    have_proto = TRUE;

#ifdef PERL_MAD
		    start_force(0);
		    CURMAD('q', PL_thisopen);
		    CURMAD('_', tmpwhite);
		    CURMAD('=', PL_thisstuff);
		    CURMAD('Q', PL_thisclose);
		    NEXTVAL_NEXTTOKE.opval =
			(OP*)newSVOP(OP_CONST, 0, PL_lex_stuff.str_sv);
		    PL_lex_stuff.str_sv = NULL;
		    force_next(THING);

		    s = SKIPSPACE2(s,tmpwhite);
#else
		    s = skipspace(s);
#endif
		}
		else
		    have_proto = FALSE;

		if (*s == ':' && s[1] != ':')
		    PL_expect = attrful;
		else if (*s != '{' && key == KEY_sub) {
		    if (!have_name)
			Perl_croak(aTHX_ "Illegal declaration of anonymous subroutine");
		    else if (*s != ';')
			Perl_croak(aTHX_ "Illegal declaration of subroutine %"SVf, SVfARG(PL_subname));
		}

#ifdef PERL_MAD
		start_force(0);
		if (tmpwhite) {
		    if (PL_madskills)
			curmad('^', newSVpvs(""));
		    CURMAD('_', tmpwhite);
		}
		force_next(0);

		PL_thistoken = subtoken;
#else
		if (have_proto) {
		    NEXTVAL_NEXTTOKE.opval =
			(OP*)newSVOP(OP_CONST, 0, PL_lex_stuff.str_sv);
		    PL_lex_stuff.str_sv = NULL;
		    force_next(THING);
		}
#endif
		if (!have_name) {
		    if (PL_curstash)
			sv_setpvs(PL_subname, "__ANON__");
		    else
			sv_setpvs(PL_subname, "__ANON__::__ANON__");
		    TOKEN(ANONSUB);
		}
#ifndef PERL_MAD
		(void) force_word(PL_oldbufptr + tboffset, WORD,
				  FALSE, TRUE, TRUE);
#endif
		if (key == KEY_my)
		    TOKEN(MYSUB);
		TOKEN(SUB);
	    }

	case KEY_system:
	    LOP(OP_SYSTEM,XREF);

	case KEY_symlink:
	    LOP(OP_SYMLINK,XTERM);

	case KEY_syscall:
	    LOP(OP_SYSCALL,XTERM);

	case KEY_sysopen:
	    LOP(OP_SYSOPEN,XTERM);

	case KEY_sysseek:
	    LOP(OP_SYSSEEK,XTERM);

	case KEY_sysread:
	    LOP(OP_SYSREAD,XTERM);

	case KEY_syswrite:
	    LOP(OP_SYSWRITE,XTERM);

	case KEY_tr:
	    s = scan_trans(s);
	    TERM(sublex_start(pl_yylval.ival, PL_lex_op));

	case KEY_tell:
	    UNI(OP_TELL);

	case KEY_telldir:
	    UNI(OP_TELLDIR);

	case KEY_tie:
	    LOP(OP_TIE,XTERM);

	case KEY_tied:
	    UNI(OP_TIED);

	case KEY_time:
	    FUN0(OP_TIME);

	case KEY_times:
	    FUN0(OP_TMS);

	case KEY_truncate:
	    LOP(OP_TRUNCATE,XTERM);

	case KEY_uc:
	    UNI(OP_UC);

	case KEY_ucfirst:
	    UNI(OP_UCFIRST);

	case KEY_untie:
	    UNI(OP_UNTIE);

	case KEY_until:
	    pl_yylval.ival = CopLINE(PL_curcop);
	    OPERATOR(UNTIL);

	case KEY_unless:
	    pl_yylval.ival = CopLINE(PL_curcop);
	    OPERATOR(UNLESS);

	case KEY_unlink:
	    LOP(OP_UNLINK,XTERM);

	case KEY_undef:
	    UNIDOR(OP_UNDEF);

	case KEY_unpack:
	    LOP(OP_UNPACK,XTERM);

	case KEY_utime:
	    LOP(OP_UTIME,XTERM);

	case KEY_umask:
	    UNIDOR(OP_UMASK);

	case KEY_unshift:
	    LOP(OP_UNSHIFT,XTERM);

	case KEY_use:
	    s = tokenize_use(1, s);
	    OPERATOR(USE);

	case KEY_values:
	    UNI(OP_VALUES);

	case KEY_vec:
	    LOP(OP_VEC,XTERM);

	case KEY_when:
	    pl_yylval.ival = CopLINE(PL_curcop);
	    OPERATOR(WHEN);

	case KEY_while:
	    pl_yylval.ival = CopLINE(PL_curcop);
	    OPERATOR(WHILE);

	case KEY_warn:
	    PL_hints |= HINT_BLOCK_SCOPE;
	    LOP(OP_WARN,XTERM);

	case KEY_wait:
	    FUN0(OP_WAIT);

	case KEY_waitpid:
	    LOP(OP_WAITPID,XTERM);

	case KEY_wantarray:
	    FUN0(OP_WANTARRAY);

	case KEY_write:
	    Perl_croak(aTHX_ "write keyword is removed");

	case KEY_x:
	    if (PL_expect == XOPERATOR)
		Mop(OP_REPEAT);
	    check_uni();
	    goto just_a_word;

	case KEY_xor:
	    pl_yylval.ival = OP_XOR;
	    OPERATOR(OROP);

	case KEY_y:
	    s = scan_trans(s);
	    TERM(sublex_start(pl_yylval.ival, PL_lex_op));
	}
    }}
}
#ifdef __SC__
#pragma segment Main
#endif

static int
S_pending_ident(pTHX)
{
    dVAR;
    register char *d;
    PADOFFSET tmp = 0;
    /* pit holds the identifier we read and pending_ident is reset */
    char pit = PL_pending_ident;
    const STRLEN tokenbuf_len = strlen(PL_tokenbuf);
    /* All routes through this function want to know if there is a colon.  */
    const char *const has_colon = (const char*) memchr (PL_tokenbuf, ':', tokenbuf_len);
    PL_pending_ident = 0;

    /* PL_realtokenstart = realtokenend = PL_bufptr - SvPVX(PL_linestr); */
    DEBUG_T({ PerlIO_printf(Perl_debug_log,
          "### Pending identifier '%s'\n", PL_tokenbuf); });

    /* if we're in a my(), we can't allow dynamics here.
       if it's a legal name, the OP is a PADANY.
    */
    if (PL_in_my) {
        if (PL_in_my == KEY_our) {	/* "our" is merely analogous to "my" */
            if (has_colon)
                yyerror(Perl_form(aTHX_ "No package name allowed for "
                                  "variable %s in \"our\"",
                                  PL_tokenbuf));
            tmp = allocmy(PL_tokenbuf);
        }
        else {
            if (has_colon)
                yyerror(Perl_form(aTHX_ PL_no_myglob,
			    PL_in_my == KEY_my ? "my" : "state", PL_tokenbuf));

            pl_yylval.opval = newOP(OP_PADANY, 0);
            pl_yylval.opval->op_targ = allocmy(PL_tokenbuf);
            return PRIVATEREF;
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
	if (!PL_in_my)
	    tmp = pad_findmy(PL_tokenbuf);
        if (tmp != NOT_IN_PAD) {
            /* might be an "our" variable" */
            if (PAD_COMPNAME_FLAGS_isOUR(tmp)) {
                /* build ops for a bareword */
		HV *  const stash = PAD_COMPNAME_OURSTASH(tmp);
		HEK * const stashname = HvNAME_HEK(stash);
		SV *  const sym = newSVhek(stashname);
                sv_catpvs(sym, "::");
                sv_catpvn(sym, PL_tokenbuf+1, tokenbuf_len - 1);
                pl_yylval.opval = (OP*)newSVOP(OP_CONST, 0, sym);
                pl_yylval.opval->op_private = OPpCONST_ENTERED;
                gv_fetchsv(sym,
                    (PL_in_eval
                        ? (GV_ADDMULTI | GV_ADDINEVAL)
                        : GV_ADDMULTI
                    ),
                    ((PL_tokenbuf[0] == '$') ? SVt_PV
                     : (PL_tokenbuf[0] == '@') ? SVt_PVAV
                     : SVt_PVHV));
                return WORD;
            }

            /* if it's a sort block and they're naming $a or $b */
            if (PL_last_lop_op == OP_SORT &&
                PL_tokenbuf[0] == '$' &&
                (PL_tokenbuf[1] == 'a' || PL_tokenbuf[1] == 'b')
                && !PL_tokenbuf[2])
            {
                for (d = PL_in_eval ? PL_oldoldbufptr : PL_linestart;
                     d < PL_bufend && *d != '\n';
                     d++)
                {
                    if (strnEQ(d,"<=>",3) || strnEQ(d,"cmp",3)) {
                        Perl_croak(aTHX_ "Can't use \"my %s\" in sort comparison",
                              PL_tokenbuf);
                    }
                }
            }

            pl_yylval.opval = newOP(OP_PADANY, 0);
            pl_yylval.opval->op_targ = tmp;
            return PRIVATEREF;
        }
    }

    /*
       Whine if they've said @foo in a doublequoted string,
       and @foo isn't a variable we can find in the symbol
       table.
    */
    if (pit == '@' && PL_lex_state != LEX_NORMAL && !PL_lex_brackets) {
        GV *const gv = gv_fetchpvn_flags(PL_tokenbuf + 1, tokenbuf_len - 1, 0,
					 SVt_PVAV);
        if ((!gv || ((PL_tokenbuf[0] == '@') ? !GvAV(gv) : !GvHV(gv)))
		&& ckWARN(WARN_AMBIGUOUS)
		/* DO NOT warn for @- and @+ */
		&& !( PL_tokenbuf[2] == '\0' &&
		    ( PL_tokenbuf[1] == '-' || PL_tokenbuf[1] == '+' ))
	   )
        {
            /* Downgraded from fatal to warning 20000522 mjd */
            Perl_warner(aTHX_ packWARN(WARN_AMBIGUOUS),
                        "Possible unintended interpolation of %s in string",
                         PL_tokenbuf);
        }
    }

    /* build ops for a bareword */
    pl_yylval.opval = (OP*)newSVOP(OP_CONST, 0, newSVpvn(PL_tokenbuf + 1,
						      tokenbuf_len - 1));
    pl_yylval.opval->op_private = OPpCONST_ENTERED;
    gv_fetchpvn_flags(
	    PL_tokenbuf + 1, tokenbuf_len - 1,
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
	    (*PL_tokenbuf == '%'
	     && *(d = PL_tokenbuf + tokenbuf_len - 1) == ':'
	     && d[-1] == ':'
	     ? 0
	     : PL_in_eval ? (GV_ADDMULTI | GV_ADDINEVAL) : GV_ADD),
	    ((PL_tokenbuf[0] == '$') ? SVt_PV
	     : (PL_tokenbuf[0] == '@') ? SVt_PVAV
	     : SVt_PVHV));
    return WORD;
}

/*
 *  The following code was generated by perl_keyword.pl.
 */

I32
Perl_keyword (pTHX_ const char *name, I32 len, bool all_keywords)
{
    dVAR;

    PERL_ARGS_ASSERT_KEYWORD;

  switch (len)
  {
    case 1: /* 5 tokens of length 1 */
      switch (name[0])
      {
        case 'm':
          {                                       /* m          */
            return KEY_m;
          }

        case 'q':
          {                                       /* q          */
            return KEY_q;
          }

        case 's':
          {                                       /* s          */
            return KEY_s;
          }

        case 'x':
          {                                       /* x          */
            return -KEY_x;
          }

        case 'y':
          {                                       /* y          */
            return KEY_y;
          }

        default:
          goto unknown;
      }

    case 2: /* 18 tokens of length 2 */
      switch (name[0])
      {
        case 'd':
          if (name[1] == 'o')
          {                                       /* do         */
            return KEY_do;
          }

          goto unknown;

        case 'e':
          if (name[1] == 'q')
          {                                       /* eq         */
            return -KEY_eq;
          }

          goto unknown;

        case 'g':
	    goto unknown;

        case 'i':
          if (name[1] == 'f')
          {                                       /* if         */
            return KEY_if;
          }

          goto unknown;

        case 'l':
          switch (name[1])
          {
            case 'c':
              {                                   /* lc         */
                return -KEY_lc;
              }

            default:
              goto unknown;
          }

        case 'm':
          if (name[1] == 'y')
          {                                       /* my         */
            return KEY_my;
          }

          goto unknown;

        case 'n':
          switch (name[1])
          {
            case 'e':
              {                                   /* ne         */
                return -KEY_ne;
              }

            case 'o':
              {                                   /* no         */
                return KEY_no;
              }

            default:
              goto unknown;
          }

        case 'o':
          if (name[1] == 'r')
          {                                       /* or         */
            return -KEY_or;
          }

          goto unknown;

        case 'q':
          switch (name[1])
          {
            case 'q':
              {                                   /* qq         */
                return KEY_qq;
              }

            case 'r':
              {                                   /* qr         */
                return KEY_qr;
              }

            case 'w':
              {                                   /* qw         */
                return KEY_qw;
              }

            case 'x':
              {                                   /* qx         */
                return KEY_qx;
              }

            default:
              goto unknown;
          }

        case 't':
          if (name[1] == 'r')
          {                                       /* tr         */
            return KEY_tr;
          }

          goto unknown;

        case 'u':
          if (name[1] == 'c')
          {                                       /* uc         */
            return -KEY_uc;
          }

          goto unknown;

        default:
          goto unknown;
      }

    case 3: /* 29 tokens of length 3 */
      switch (name[0])
      {
        case 'E':
          if (name[1] == 'N' &&
              name[2] == 'D')
          {                                       /* END        */
            return KEY_END;
          }

          goto unknown;

        case 'a':
          switch (name[1])
          {
            case 'b':
              if (name[2] == 's')
              {                                   /* abs        */
                return -KEY_abs;
              }

              goto unknown;

            case 'n':
              if (name[2] == 'd')
              {                                   /* and        */
                return -KEY_and;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'c':
          switch (name[1])
          {
            case 'h':
              if (name[2] == 'r')
              {                                   /* chr        */
                return -KEY_chr;
              }

              goto unknown;

            case 'm':
              if (name[2] == 'p')
              {                                   /* cmp        */
                return -KEY_cmp;
              }

              goto unknown;

            case 'o':
              if (name[2] == 's')
              {                                   /* cos        */
                return -KEY_cos;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'd':
          if (name[1] == 'i' &&
              name[2] == 'e')
          {                                       /* die        */
            return -KEY_die;
          }

          goto unknown;

        case 'e':
          switch (name[1])
          {
            case 'o':
              if (name[2] == 'f')
              {                                   /* eof        */
                return -KEY_eof;
              }

              goto unknown;

            case 'x':
              if (name[2] == 'p')
              {                                   /* exp        */
                return -KEY_exp;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'f':
          if (name[1] == 'o' &&
              name[2] == 'r')
          {                                       /* for        */
            return KEY_for;
          }

          goto unknown;

        case 'h':
          if (name[1] == 'e' &&
              name[2] == 'x')
          {                                       /* hex        */
            return -KEY_hex;
          }

          goto unknown;

        case 'i':
          if (name[1] == 'n' &&
              name[2] == 't')
          {                                       /* int        */
            return -KEY_int;
          }

          goto unknown;

        case 'l':
          if (name[1] == 'o' &&
              name[2] == 'g')
          {                                       /* log        */
            return -KEY_log;
          }

          goto unknown;

        case 'm':
          if (name[1] == 'a' &&
              name[2] == 'p')
          {                                       /* map        */
            return KEY_map;
          }

          goto unknown;

        case 'n':
          if (name[1] == 'o' &&
              name[2] == 't')
          {                                       /* not        */
            return -KEY_not;
          }

          goto unknown;

        case 'o':
          switch (name[1])
          {
            case 'c':
              if (name[2] == 't')
              {                                   /* oct        */
                return -KEY_oct;
              }

              goto unknown;

            case 'r':
              if (name[2] == 'd')
              {                                   /* ord        */
                return -KEY_ord;
              }

              goto unknown;

            case 'u':
              if (name[2] == 'r')
              {                                   /* our        */
                return KEY_our;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'p':
          if (name[1] == 'o')
          {
            switch (name[2])
            {
              case 'p':
                {                                 /* pop        */
                  return -KEY_pop;
                }

              case 's':
                {                                 /* pos        */
                  return KEY_pos;
                }

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 'r':
          if (name[1] == 'e' &&
              name[2] == 'f')
          {                                       /* ref        */
            return -KEY_ref;
          }

          goto unknown;

        case 's':
          switch (name[1])
          {
            case 'i':
              if (name[2] == 'n')
              {                                   /* sin        */
                return -KEY_sin;
              }

              goto unknown;

            case 'u':
              if (name[2] == 'b')
              {                                   /* sub        */
                return KEY_sub;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 't':
          if (name[1] == 'i' &&
              name[2] == 'e')
          {                                       /* tie        */
            return KEY_tie;
          }

          goto unknown;

        case 'u':
          if (name[1] == 's' &&
              name[2] == 'e')
          {                                       /* use        */
            return KEY_use;
          }

          goto unknown;

        case 'v':
          if (name[1] == 'e' &&
              name[2] == 'c')
          {                                       /* vec        */
            return -KEY_vec;
          }

          goto unknown;

        case 'x':
          if (name[1] == 'o' &&
              name[2] == 'r')
          {                                       /* xor        */
            return -KEY_xor;
          }

          goto unknown;

        default:
          goto unknown;
      }

    case 4: /* 41 tokens of length 4 */
      switch (name[0])
      {
        case 'C':
          if (name[1] == 'O' &&
              name[2] == 'R' &&
              name[3] == 'E')
          {                                       /* CORE       */
            return -KEY_CORE;
          }

          goto unknown;

        case 'I':
          if (name[1] == 'N' &&
              name[2] == 'I' &&
              name[3] == 'T')
          {                                       /* INIT       */
            return KEY_INIT;
          }

          goto unknown;

        case 'b':
          if (name[1] == 'i' &&
              name[2] == 'n' &&
              name[3] == 'd')
          {                                       /* bind       */
            return -KEY_bind;
          }

          goto unknown;

        case 'c':
          if (name[1] == 'h' &&
              name[2] == 'o' &&
              name[3] == 'p')
          {                                       /* chop       */
            return -KEY_chop;
          }

          goto unknown;

        case 'd':
          if (name[1] == 'u' &&
              name[2] == 'm' &&
              name[3] == 'p')
          {                                       /* dump       */
            return -KEY_dump;
          }

          goto unknown;

        case 'e':
          switch (name[1])
          {
            case 'a':
              if (name[2] == 'c' &&
                  name[3] == 'h')
              {                                   /* each       */
                return -KEY_each;
              }

              goto unknown;

            case 'l':
              if (name[2] == 's' &&
                  name[3] == 'e')
              {                                   /* else       */
                return KEY_else;
              }

              goto unknown;

            case 'v':
              if (name[2] == 'a' &&
                  name[3] == 'l')
              {                                   /* eval       */
                return KEY_eval;
              }

              goto unknown;

            case 'x':
              switch (name[2])
              {
                case 'e':
                  if (name[3] == 'c')
                  {                               /* exec       */
                    return -KEY_exec;
                  }

                  goto unknown;

                case 'i':
                  if (name[3] == 't')
                  {                               /* exit       */
                    return -KEY_exit;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            default:
              goto unknown;
          }

        case 'f':
          if (name[1] == 'o' &&
              name[2] == 'r' &&
              name[3] == 'k')
          {                                       /* fork       */
            return -KEY_fork;
          }

          goto unknown;

        case 'g':
          switch (name[1])
          {
            case 'e':
              if (name[2] == 't' &&
                  name[3] == 'c')
              {                                   /* getc       */
                return -KEY_getc;
              }

              goto unknown;

            case 'l':
              if (name[2] == 'o' &&
                  name[3] == 'b')
              {                                   /* glob       */
                return KEY_glob;
              }

              goto unknown;

            case 'o':
              if (name[2] == 't' &&
                  name[3] == 'o')
              {                                   /* goto       */
                return KEY_goto;
              }

              goto unknown;

            case 'r':
              if (name[2] == 'e' &&
                  name[3] == 'p')
              {                                   /* grep       */
                return KEY_grep;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'j':
          if (name[1] == 'o' &&
              name[2] == 'i' &&
              name[3] == 'n')
          {                                       /* join       */
            return -KEY_join;
          }

          goto unknown;

        case 'k':
          switch (name[1])
          {
            case 'e':
              if (name[2] == 'y' &&
                  name[3] == 's')
              {                                   /* keys       */
                return -KEY_keys;
              }

              goto unknown;

            case 'i':
              if (name[2] == 'l' &&
                  name[3] == 'l')
              {                                   /* kill       */
                return -KEY_kill;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'l':
          switch (name[1])
          {
            case 'a':
              if (name[2] == 's' &&
                  name[3] == 't')
              {                                   /* last       */
                return KEY_last;
              }

              goto unknown;

            case 'i':
              if (name[2] == 'n' &&
                  name[3] == 'k')
              {                                   /* link       */
                return -KEY_link;
              }

              goto unknown;

            case 'o':
              if (name[2] == 'c' &&
                  name[3] == 'k')
              {                                   /* lock       */
                return -KEY_lock;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'n':
          if (name[1] == 'e' &&
              name[2] == 'x' &&
              name[3] == 't')
          {                                       /* next       */
            return KEY_next;
          }

          goto unknown;

        case 'o':
          if (name[1] == 'p' &&
              name[2] == 'e' &&
              name[3] == 'n')
          {                                       /* open       */
            return -KEY_open;
          }

          goto unknown;

        case 'p':
          switch (name[1])
          {
            case 'a':
              if (name[2] == 'c' &&
                  name[3] == 'k')
              {                                   /* pack       */
                return -KEY_pack;
              }

              goto unknown;

            case 'i':
              if (name[2] == 'p' &&
                  name[3] == 'e')
              {                                   /* pipe       */
                return -KEY_pipe;
              }

              goto unknown;

            case 'u':
              if (name[2] == 's' &&
                  name[3] == 'h')
              {                                   /* push       */
                return -KEY_push;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'r':
          switch (name[1])
          {
            case 'a':
              if (name[2] == 'n' &&
                  name[3] == 'd')
              {                                   /* rand       */
                return -KEY_rand;
              }

              goto unknown;

            case 'e':
              switch (name[2])
              {
                case 'a':
                  if (name[3] == 'd')
                  {                               /* read       */
                    return -KEY_read;
                  }

                  goto unknown;

                case 'c':
                  if (name[3] == 'v')
                  {                               /* recv       */
                    return -KEY_recv;
                  }

                  goto unknown;

                case 'd':
                  if (name[3] == 'o')
                  {                               /* redo       */
                    return KEY_redo;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            default:
              goto unknown;
          }

        case 's':
          switch (name[1])
          {
            case 'e':
              switch (name[2])
              {
                case 'e':
                  if (name[3] == 'k')
                  {                               /* seek       */
                    return -KEY_seek;
                  }

                  goto unknown;

                case 'n':
                  if (name[3] == 'd')
                  {                               /* send       */
                    return -KEY_send;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            case 'o':
              if (name[2] == 'r' &&
                  name[3] == 't')
              {                                   /* sort       */
                return KEY_sort;
              }

              goto unknown;

            case 'q':
              if (name[2] == 'r' &&
                  name[3] == 't')
              {                                   /* sqrt       */
                return -KEY_sqrt;
              }

              goto unknown;

            case 't':
              if (name[2] == 'a' &&
                  name[3] == 't')
              {                                   /* stat       */
                return -KEY_stat;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 't':
          switch (name[1])
          {
            case 'e':
              if (name[2] == 'l' &&
                  name[3] == 'l')
              {                                   /* tell       */
                return -KEY_tell;
              }

              goto unknown;

            case 'i':
              switch (name[2])
              {
                case 'e':
                  if (name[3] == 'd')
                  {                               /* tied       */
                    return KEY_tied;
                  }

                  goto unknown;

                case 'm':
                  if (name[3] == 'e')
                  {                               /* time       */
                    return -KEY_time;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            default:
              goto unknown;
          }

        case 'w':
          switch (name[1])
          {
            case 'a':
              switch (name[2])
              {
                case 'i':
                  if (name[3] == 't')
                  {                               /* wait       */
                    return -KEY_wait;
                  }

                  goto unknown;

                case 'r':
                  if (name[3] == 'n')
                  {                               /* warn       */
                    return -KEY_warn;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            case 'h':
              if (name[2] == 'e' &&
                  name[3] == 'n')
              {                                   /* when       */
                return (all_keywords || FEATURE_IS_ENABLED("switch") ? KEY_when : 0);
              }

              goto unknown;

            default:
              goto unknown;
          }

        default:
          goto unknown;
      }

    case 5: /* 39 tokens of length 5 */
      switch (name[0])
      {
        case 'B':
          if (name[1] == 'E' &&
              name[2] == 'G' &&
              name[3] == 'I' &&
              name[4] == 'N')
          {                                       /* BEGIN      */
            return KEY_BEGIN;
          }

          goto unknown;

        case 'C':
          if (name[1] == 'H' &&
              name[2] == 'E' &&
              name[3] == 'C' &&
              name[4] == 'K')
          {                                       /* CHECK      */
            return KEY_CHECK;
          }

          goto unknown;

        case 'a':
          switch (name[1])
          {
            case 'l':
              if (name[2] == 'a' &&
                  name[3] == 'r' &&
                  name[4] == 'm')
              {                                   /* alarm      */
                return -KEY_alarm;
              }

              goto unknown;

            case 't':
              if (name[2] == 'a' &&
                  name[3] == 'n' &&
                  name[4] == '2')
              {                                   /* atan2      */
                return -KEY_atan2;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'b':
          switch (name[1])
          {
            case 'l':
              if (name[2] == 'e' &&
                  name[3] == 's' &&
                  name[4] == 's')
              {                                   /* bless      */
                return -KEY_bless;
              }

              goto unknown;

            case 'r':
              if (name[2] == 'e' &&
                  name[3] == 'a' &&
                  name[4] == 'k')
              {                                   /* break      */
                return (all_keywords || FEATURE_IS_ENABLED("switch") ? -KEY_break : 0);
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'c':
          switch (name[1])
          {
            case 'h':
              switch (name[2])
              {
                case 'd':
                  if (name[3] == 'i' &&
                      name[4] == 'r')
                  {                               /* chdir      */
                    return -KEY_chdir;
                  }

                  goto unknown;

                case 'm':
                  if (name[3] == 'o' &&
                      name[4] == 'd')
                  {                               /* chmod      */
                    return -KEY_chmod;
                  }

                  goto unknown;

                case 'o':
                  switch (name[3])
                  {
                    case 'm':
                      if (name[4] == 'p')
                      {                           /* chomp      */
                        return -KEY_chomp;
                      }

                      goto unknown;

                    case 'w':
                      if (name[4] == 'n')
                      {                           /* chown      */
                        return -KEY_chown;
                      }

                      goto unknown;

                    default:
                      goto unknown;
                  }

                default:
                  goto unknown;
              }

            case 'l':
              if (name[2] == 'o' &&
                  name[3] == 's' &&
                  name[4] == 'e')
              {                                   /* close      */
                return -KEY_close;
              }

              goto unknown;

            case 'r':
              if (name[2] == 'y' &&
                  name[3] == 'p' &&
                  name[4] == 't')
              {                                   /* crypt      */
                return -KEY_crypt;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'e':
          if (name[1] == 'l' &&
              name[2] == 's' &&
              name[3] == 'i' &&
              name[4] == 'f')
          {                                       /* elsif      */
            return KEY_elsif;
          }

          goto unknown;

        case 'f':
          switch (name[1])
          {
            case 'c':
              if (name[2] == 'n' &&
                  name[3] == 't' &&
                  name[4] == 'l')
              {                                   /* fcntl      */
                return -KEY_fcntl;
              }

              goto unknown;

            case 'l':
              if (name[2] == 'o' &&
                  name[3] == 'c' &&
                  name[4] == 'k')
              {                                   /* flock      */
                return -KEY_flock;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'g':
          if (name[1] == 'i' &&
              name[2] == 'v' &&
              name[3] == 'e' &&
              name[4] == 'n')
          {                                       /* given      */
            return (all_keywords || FEATURE_IS_ENABLED("switch") ? KEY_given : 0);
          }

          goto unknown;

        case 'i':
          switch (name[1])
          {
            case 'n':
              if (name[2] == 'd' &&
                  name[3] == 'e' &&
                  name[4] == 'x')
              {                                   /* index      */
                return -KEY_index;
              }

              goto unknown;

            case 'o':
              if (name[2] == 'c' &&
                  name[3] == 't' &&
                  name[4] == 'l')
              {                                   /* ioctl      */
                return -KEY_ioctl;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'l':
          switch (name[1])
          {
            case 'o':
              if (name[2] == 'c' &&
                  name[3] == 'a' &&
                  name[4] == 'l')
              {                                   /* local      */
                return KEY_local;
              }

              goto unknown;

            case 's':
              if (name[2] == 't' &&
                  name[3] == 'a' &&
                  name[4] == 't')
              {                                   /* lstat      */
                return -KEY_lstat;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'm':
          if (name[1] == 'k' &&
              name[2] == 'd' &&
              name[3] == 'i' &&
              name[4] == 'r')
          {                                       /* mkdir      */
            return -KEY_mkdir;
          }

          goto unknown;

        case 'p':
          if (name[1] == 'r' &&
              name[2] == 'i' &&
              name[3] == 'n' &&
              name[4] == 't')
          {                                       /* print      */
            return KEY_print;
          }

          goto unknown;

        case 'r':
          switch (name[1])
          {
            case 'm':
              if (name[2] == 'd' &&
                  name[3] == 'i' &&
                  name[4] == 'r')
              {                                   /* rmdir      */
                return -KEY_rmdir;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 's':
          switch (name[1])
          {
            case 'e':
              if (name[2] == 'm' &&
                  name[3] == 'o' &&
                  name[4] == 'p')
              {                                   /* semop      */
                return -KEY_semop;
              }

              goto unknown;

            case 'h':
              if (name[2] == 'i' &&
                  name[3] == 'f' &&
                  name[4] == 't')
              {                                   /* shift      */
                return -KEY_shift;
              }

              goto unknown;

            case 'l':
              if (name[2] == 'e' &&
                  name[3] == 'e' &&
                  name[4] == 'p')
              {                                   /* sleep      */
                return -KEY_sleep;
              }

              goto unknown;

            case 'p':
              if (name[2] == 'l' &&
                  name[3] == 'i' &&
                  name[4] == 't')
              {                                   /* split      */
                return KEY_split;
              }

              goto unknown;

            case 'r':
              if (name[2] == 'a' &&
                  name[3] == 'n' &&
                  name[4] == 'd')
              {                                   /* srand      */
                return -KEY_srand;
              }

              goto unknown;

            case 't':
              switch (name[2])
              {
                case 'a':
                  if (name[3] == 't' &&
                      name[4] == 'e')
                  {                               /* state      */
                    return (all_keywords || FEATURE_IS_ENABLED("state") ? KEY_state : 0);
                  }

                  goto unknown;

                case 'u':
                  if (name[3] == 'd' &&
                      name[4] == 'y')
                  {                               /* study      */
                    return KEY_study;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            default:
              goto unknown;
          }

        case 't':
          if (name[1] == 'i' &&
              name[2] == 'm' &&
              name[3] == 'e' &&
              name[4] == 's')
          {                                       /* times      */
            return -KEY_times;
          }

          goto unknown;

        case 'u':
          switch (name[1])
          {
            case 'm':
              if (name[2] == 'a' &&
                  name[3] == 's' &&
                  name[4] == 'k')
              {                                   /* umask      */
                return -KEY_umask;
              }

              goto unknown;

            case 'n':
              switch (name[2])
              {
                case 'd':
                  if (name[3] == 'e' &&
                      name[4] == 'f')
                  {                               /* undef      */
                    return KEY_undef;
                  }

                  goto unknown;

                case 't':
                  if (name[3] == 'i')
                  {
                    switch (name[4])
                    {
                      case 'e':
                        {                         /* untie      */
                          return KEY_untie;
                        }

                      case 'l':
                        {                         /* until      */
                          return KEY_until;
                        }

                      default:
                        goto unknown;
                    }
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            case 't':
              if (name[2] == 'i' &&
                  name[3] == 'm' &&
                  name[4] == 'e')
              {                                   /* utime      */
                return -KEY_utime;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'w':
          switch (name[1])
          {
            case 'h':
              if (name[2] == 'i' &&
                  name[3] == 'l' &&
                  name[4] == 'e')
              {                                   /* while      */
                return KEY_while;
              }

              goto unknown;

            case 'r':
              if (name[2] == 'i' &&
                  name[3] == 't' &&
                  name[4] == 'e')
              {                                   /* write      */
                return -KEY_write;
              }

              goto unknown;

            default:
              goto unknown;
          }

        default:
          goto unknown;
      }

    case 6: /* 33 tokens of length 6 */
      switch (name[0])
      {
        case 'a':
          if (name[1] == 'c' &&
              name[2] == 'c' &&
              name[3] == 'e' &&
              name[4] == 'p' &&
              name[5] == 't')
          {                                       /* accept     */
            return -KEY_accept;
          }

          goto unknown;

        case 'c':
          switch (name[1])
          {
            case 'a':
              if (name[2] == 'l' &&
                  name[3] == 'l' &&
                  name[4] == 'e' &&
                  name[5] == 'r')
              {                                   /* caller     */
                return -KEY_caller;
              }

              goto unknown;

            case 'h':
              if (name[2] == 'r' &&
                  name[3] == 'o' &&
                  name[4] == 'o' &&
                  name[5] == 't')
              {                                   /* chroot     */
                return -KEY_chroot;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'd':
          if (name[1] == 'e' &&
              name[2] == 'l' &&
              name[3] == 'e' &&
              name[4] == 't' &&
              name[5] == 'e')
          {                                       /* delete     */
            return KEY_delete;
          }

          goto unknown;

        case 'e':
          switch (name[1])
          {
            case 'l':
              if (name[2] == 's' &&
                  name[3] == 'e' &&
                  name[4] == 'i' &&
                  name[5] == 'f')
              {                                   /* elseif     */
                if(ckWARN_d(WARN_SYNTAX))
                  Perl_warner(aTHX_ packWARN(WARN_SYNTAX), "elseif should be elsif");
              }

              goto unknown;

            case 'x':
              if (name[2] == 'i' &&
                  name[3] == 's' &&
                  name[4] == 't' &&
                  name[5] == 's')
              {                                   /* exists     */
                return KEY_exists;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'f':
          switch (name[1])
          {
            case 'i':
              if (name[2] == 'l' &&
                  name[3] == 'e' &&
                  name[4] == 'n' &&
                  name[5] == 'o')
              {                                   /* fileno     */
                return -KEY_fileno;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'g':
          if (name[1] == 'm' &&
              name[2] == 't' &&
              name[3] == 'i' &&
              name[4] == 'm' &&
              name[5] == 'e')
          {                                       /* gmtime     */
            return -KEY_gmtime;
          }

          goto unknown;

        case 'l':
          switch (name[1])
          {
            case 'e':
              if (name[2] == 'n' &&
                  name[3] == 'g' &&
                  name[4] == 't' &&
                  name[5] == 'h')
              {                                   /* length     */
                return -KEY_length;
              }

              goto unknown;

            case 'i':
              if (name[2] == 's' &&
                  name[3] == 't' &&
                  name[4] == 'e' &&
                  name[5] == 'n')
              {                                   /* listen     */
                return -KEY_listen;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'm':
          if (name[1] == 's' &&
              name[2] == 'g')
          {
            switch (name[3])
            {
              case 'c':
                if (name[4] == 't' &&
                    name[5] == 'l')
                {                                 /* msgctl     */
                  return -KEY_msgctl;
                }

                goto unknown;

              case 'g':
                if (name[4] == 'e' &&
                    name[5] == 't')
                {                                 /* msgget     */
                  return -KEY_msgget;
                }

                goto unknown;

              case 'r':
                if (name[4] == 'c' &&
                    name[5] == 'v')
                {                                 /* msgrcv     */
                  return -KEY_msgrcv;
                }

                goto unknown;

              case 's':
                if (name[4] == 'n' &&
                    name[5] == 'd')
                {                                 /* msgsnd     */
                  return -KEY_msgsnd;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 'p':
          if (name[1] == 'r' &&
              name[2] == 'i' &&
              name[3] == 'n' &&
              name[4] == 't' &&
              name[5] == 'f')
          {                                       /* printf     */
            return KEY_printf;
          }

          goto unknown;

        case 'r':
          switch (name[1])
          {
            case 'e':
              switch (name[2])
              {
                case 'n':
                  if (name[3] == 'a' &&
                      name[4] == 'm' &&
                      name[5] == 'e')
                  {                               /* rename     */
                    return -KEY_rename;
                  }

                  goto unknown;

                case 't':
                  if (name[3] == 'u' &&
                      name[4] == 'r' &&
                      name[5] == 'n')
                  {                               /* return     */
                    return KEY_return;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            case 'i':
              if (name[2] == 'n' &&
                  name[3] == 'd' &&
                  name[4] == 'e' &&
                  name[5] == 'x')
              {                                   /* rindex     */
                return -KEY_rindex;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 's':
          switch (name[1])
          {
            case 'c':
              if (name[2] == 'a' &&
                  name[3] == 'l' &&
                  name[4] == 'a' &&
                  name[5] == 'r')
              {                                   /* scalar     */
                return KEY_scalar;
              }

              goto unknown;

            case 'e':
              switch (name[2])
              {
                case 'l':
                  if (name[3] == 'e' &&
                      name[4] == 'c' &&
                      name[5] == 't')
                  {                               /* select     */
                    return -KEY_select;
                  }

                  goto unknown;

                case 'm':
                  switch (name[3])
                  {
                    case 'c':
                      if (name[4] == 't' &&
                          name[5] == 'l')
                      {                           /* semctl     */
                        return -KEY_semctl;
                      }

                      goto unknown;

                    case 'g':
                      if (name[4] == 'e' &&
                          name[5] == 't')
                      {                           /* semget     */
                        return -KEY_semget;
                      }

                      goto unknown;

                    default:
                      goto unknown;
                  }

                default:
                  goto unknown;
              }

            case 'h':
              if (name[2] == 'm')
              {
                switch (name[3])
                {
                  case 'c':
                    if (name[4] == 't' &&
                        name[5] == 'l')
                    {                             /* shmctl     */
                      return -KEY_shmctl;
                    }

                    goto unknown;

                  case 'g':
                    if (name[4] == 'e' &&
                        name[5] == 't')
                    {                             /* shmget     */
                      return -KEY_shmget;
                    }

                    goto unknown;

                  default:
                    goto unknown;
                }
              }

              goto unknown;

            case 'o':
              if (name[2] == 'c' &&
                  name[3] == 'k' &&
                  name[4] == 'e' &&
                  name[5] == 't')
              {                                   /* socket     */
                return -KEY_socket;
              }

              goto unknown;

            case 'p':
              if (name[2] == 'l' &&
                  name[3] == 'i' &&
                  name[4] == 'c' &&
                  name[5] == 'e')
              {                                   /* splice     */
                return -KEY_splice;
              }

              goto unknown;

            case 'u':
              if (name[2] == 'b' &&
                  name[3] == 's' &&
                  name[4] == 't' &&
                  name[5] == 'r')
              {                                   /* substr     */
                return -KEY_substr;
              }

              goto unknown;

            case 'y':
              if (name[2] == 's' &&
                  name[3] == 't' &&
                  name[4] == 'e' &&
                  name[5] == 'm')
              {                                   /* system     */
                return -KEY_system;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'u':
          if (name[1] == 'n')
          {
            switch (name[2])
            {
              case 'l':
                switch (name[3])
                {
                  case 'e':
                    if (name[4] == 's' &&
                        name[5] == 's')
                    {                             /* unless     */
                      return KEY_unless;
                    }

                    goto unknown;

                  case 'i':
                    if (name[4] == 'n' &&
                        name[5] == 'k')
                    {                             /* unlink     */
                      return -KEY_unlink;
                    }

                    goto unknown;

                  default:
                    goto unknown;
                }

              case 'p':
                if (name[3] == 'a' &&
                    name[4] == 'c' &&
                    name[5] == 'k')
                {                                 /* unpack     */
                  return -KEY_unpack;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 'v':
          if (name[1] == 'a' &&
              name[2] == 'l' &&
              name[3] == 'u' &&
              name[4] == 'e' &&
              name[5] == 's')
          {                                       /* values     */
            return -KEY_values;
          }

          goto unknown;

        default:
          goto unknown;
      }

    case 7: /* 29 tokens of length 7 */
      switch (name[0])
      {
        case 'D':
          if (name[1] == 'E' &&
              name[2] == 'S' &&
              name[3] == 'T' &&
              name[4] == 'R' &&
              name[5] == 'O' &&
              name[6] == 'Y')
          {                                       /* DESTROY    */
            return KEY_DESTROY;
          }

          goto unknown;

        case '_':
          if (name[1] == '_' &&
              name[2] == 'E' &&
              name[3] == 'N' &&
              name[4] == 'D' &&
              name[5] == '_' &&
              name[6] == '_')
          {                                       /* __END__    */
            return KEY___END__;
          }

          goto unknown;

        case 'b':
          if (name[1] == 'i' &&
              name[2] == 'n' &&
              name[3] == 'm' &&
              name[4] == 'o' &&
              name[5] == 'd' &&
              name[6] == 'e')
          {                                       /* binmode    */
            return -KEY_binmode;
          }

          goto unknown;

        case 'c':
          if (name[1] == 'o' &&
              name[2] == 'n' &&
              name[3] == 'n' &&
              name[4] == 'e' &&
              name[5] == 'c' &&
              name[6] == 't')
          {                                       /* connect    */
            return -KEY_connect;
          }

          goto unknown;

        case 'd':
          switch (name[1])
          {
            case 'e':
              if (name[2] == 'f')
              {
                switch (name[3])
                {
                  case 'a':
                    if (name[4] == 'u' &&
                        name[5] == 'l' &&
                        name[6] == 't')
                    {                             /* default    */
                      return (all_keywords || FEATURE_IS_ENABLED("switch") ? KEY_default : 0);
                    }

                    goto unknown;

                  case 'i':
                    if (name[4] == 'n' &&
                        name[5] == 'e' &&
                        name[6] == 'd')
                    {                             /* defined    */
                      return KEY_defined;
                    }

                    goto unknown;

                  default:
                    goto unknown;
                }
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'f':
          if (name[1] == 'o' &&
              name[2] == 'r' &&
              name[3] == 'e' &&
              name[4] == 'a' &&
              name[5] == 'c' &&
              name[6] == 'h')
          {                                       /* foreach    */
            return KEY_foreach;
          }

          goto unknown;

        case 'g':
          if (name[1] == 'e' &&
              name[2] == 't' &&
              name[3] == 'p')
          {
            switch (name[4])
            {
              case 'g':
                if (name[5] == 'r' &&
                    name[6] == 'p')
                {                                 /* getpgrp    */
                  return -KEY_getpgrp;
                }

                goto unknown;

              case 'p':
                if (name[5] == 'i' &&
                    name[6] == 'd')
                {                                 /* getppid    */
                  return -KEY_getppid;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 'l':
          if (name[1] == 'c' &&
              name[2] == 'f' &&
              name[3] == 'i' &&
              name[4] == 'r' &&
              name[5] == 's' &&
              name[6] == 't')
          {                                       /* lcfirst    */
            return -KEY_lcfirst;
          }

          goto unknown;

        case 'o':
          if (name[1] == 'p' &&
              name[2] == 'e' &&
              name[3] == 'n' &&
              name[4] == 'd' &&
              name[5] == 'i' &&
              name[6] == 'r')
          {                                       /* opendir    */
            return -KEY_opendir;
          }

          goto unknown;

        case 'p':
          if (name[1] == 'a' &&
              name[2] == 'c' &&
              name[3] == 'k' &&
              name[4] == 'a' &&
              name[5] == 'g' &&
              name[6] == 'e')
          {                                       /* package    */
            return KEY_package;
          }

          goto unknown;

        case 'r':
          if (name[1] == 'e')
          {
            switch (name[2])
            {
              case 'a':
                if (name[3] == 'd' &&
                    name[4] == 'd' &&
                    name[5] == 'i' &&
                    name[6] == 'r')
                {                                 /* readdir    */
                  return -KEY_readdir;
                }

                goto unknown;

              case 'q':
                if (name[3] == 'u' &&
                    name[4] == 'i' &&
                    name[5] == 'r' &&
                    name[6] == 'e')
                {                                 /* require    */
                  return KEY_require;
                }

                goto unknown;

              case 'v':
                if (name[3] == 'e' &&
                    name[4] == 'r' &&
                    name[5] == 's' &&
                    name[6] == 'e')
                {                                 /* reverse    */
                  return -KEY_reverse;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 's':
          switch (name[1])
          {
            case 'e':
              switch (name[2])
              {
                case 'e':
                  if (name[3] == 'k' &&
                      name[4] == 'd' &&
                      name[5] == 'i' &&
                      name[6] == 'r')
                  {                               /* seekdir    */
                    return -KEY_seekdir;
                  }

                  goto unknown;

                case 't':
                  if (name[3] == 'p' &&
                      name[4] == 'g' &&
                      name[5] == 'r' &&
                      name[6] == 'p')
                  {                               /* setpgrp    */
                    return -KEY_setpgrp;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            case 'h':
              if (name[2] == 'm' &&
                  name[3] == 'r' &&
                  name[4] == 'e' &&
                  name[5] == 'a' &&
                  name[6] == 'd')
              {                                   /* shmread    */
                return -KEY_shmread;
              }

              goto unknown;

            case 'p':
              if (name[2] == 'r' &&
                  name[3] == 'i' &&
                  name[4] == 'n' &&
                  name[5] == 't' &&
                  name[6] == 'f')
              {                                   /* sprintf    */
                return -KEY_sprintf;
              }

              goto unknown;

            case 'y':
              switch (name[2])
              {
                case 'm':
                  if (name[3] == 'l' &&
                      name[4] == 'i' &&
                      name[5] == 'n' &&
                      name[6] == 'k')
                  {                               /* symlink    */
                    return -KEY_symlink;
                  }

                  goto unknown;

                case 's':
                  switch (name[3])
                  {
                    case 'c':
                      if (name[4] == 'a' &&
                          name[5] == 'l' &&
                          name[6] == 'l')
                      {                           /* syscall    */
                        return -KEY_syscall;
                      }

                      goto unknown;

                    case 'o':
                      if (name[4] == 'p' &&
                          name[5] == 'e' &&
                          name[6] == 'n')
                      {                           /* sysopen    */
                        return -KEY_sysopen;
                      }

                      goto unknown;

                    case 'r':
                      if (name[4] == 'e' &&
                          name[5] == 'a' &&
                          name[6] == 'd')
                      {                           /* sysread    */
                        return -KEY_sysread;
                      }

                      goto unknown;

                    case 's':
                      if (name[4] == 'e' &&
                          name[5] == 'e' &&
                          name[6] == 'k')
                      {                           /* sysseek    */
                        return -KEY_sysseek;
                      }

                      goto unknown;

                    default:
                      goto unknown;
                  }

                default:
                  goto unknown;
              }

            default:
              goto unknown;
          }

        case 't':
          if (name[1] == 'e' &&
              name[2] == 'l' &&
              name[3] == 'l' &&
              name[4] == 'd' &&
              name[5] == 'i' &&
              name[6] == 'r')
          {                                       /* telldir    */
            return -KEY_telldir;
          }

          goto unknown;

        case 'u':
          switch (name[1])
          {
            case 'c':
              if (name[2] == 'f' &&
                  name[3] == 'i' &&
                  name[4] == 'r' &&
                  name[5] == 's' &&
                  name[6] == 't')
              {                                   /* ucfirst    */
                return -KEY_ucfirst;
              }

              goto unknown;

            case 'n':
              if (name[2] == 's' &&
                  name[3] == 'h' &&
                  name[4] == 'i' &&
                  name[5] == 'f' &&
                  name[6] == 't')
              {                                   /* unshift    */
                return -KEY_unshift;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'w':
          if (name[1] == 'a' &&
              name[2] == 'i' &&
              name[3] == 't' &&
              name[4] == 'p' &&
              name[5] == 'i' &&
              name[6] == 'd')
          {                                       /* waitpid    */
            return -KEY_waitpid;
          }

          goto unknown;

        default:
          goto unknown;
      }

    case 8: /* 26 tokens of length 8 */
      switch (name[0])
      {
        case '_':
          if (name[1] == '_')
          {
            switch (name[2])
            {
              case 'D':
                if (name[3] == 'A' &&
                    name[4] == 'T' &&
                    name[5] == 'A' &&
                    name[6] == '_' &&
                    name[7] == '_')
                {                                 /* __DATA__   */
                  return KEY___DATA__;
                }

                goto unknown;

              case 'F':
                if (name[3] == 'I' &&
                    name[4] == 'L' &&
                    name[5] == 'E' &&
                    name[6] == '_' &&
                    name[7] == '_')
                {                                 /* __FILE__   */
                  return -KEY___FILE__;
                }

                goto unknown;

              case 'L':
                if (name[3] == 'I' &&
                    name[4] == 'N' &&
                    name[5] == 'E' &&
                    name[6] == '_' &&
                    name[7] == '_')
                {                                 /* __LINE__   */
                  return -KEY___LINE__;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 'c':
          switch (name[1])
          {
            case 'l':
              if (name[2] == 'o' &&
                  name[3] == 's' &&
                  name[4] == 'e' &&
                  name[5] == 'd' &&
                  name[6] == 'i' &&
                  name[7] == 'r')
              {                                   /* closedir   */
                return -KEY_closedir;
              }

              goto unknown;

            case 'o':
              if (name[2] == 'n' &&
                  name[3] == 't' &&
                  name[4] == 'i' &&
                  name[5] == 'n' &&
                  name[6] == 'u' &&
                  name[7] == 'e')
              {                                   /* continue   */
                return -KEY_continue;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 'e':
          if (name[1] == 'n' &&
              name[2] == 'd')
          {
            switch (name[3])
            {
              case 'g':
                if (name[4] == 'r' &&
                    name[5] == 'e' &&
                    name[6] == 'n' &&
                    name[7] == 't')
                {                                 /* endgrent   */
                  return -KEY_endgrent;
                }

                goto unknown;

              case 'p':
                if (name[4] == 'w' &&
                    name[5] == 'e' &&
                    name[6] == 'n' &&
                    name[7] == 't')
                {                                 /* endpwent   */
                  return -KEY_endpwent;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 'g':
          if (name[1] == 'e' &&
              name[2] == 't')
          {
            switch (name[3])
            {
              case 'g':
                if (name[4] == 'r')
                {
                  switch (name[5])
                  {
                    case 'e':
                      if (name[6] == 'n' &&
                          name[7] == 't')
                      {                           /* getgrent   */
                        return -KEY_getgrent;
                      }

                      goto unknown;

                    case 'g':
                      if (name[6] == 'i' &&
                          name[7] == 'd')
                      {                           /* getgrgid   */
                        return -KEY_getgrgid;
                      }

                      goto unknown;

                    case 'n':
                      if (name[6] == 'a' &&
                          name[7] == 'm')
                      {                           /* getgrnam   */
                        return -KEY_getgrnam;
                      }

                      goto unknown;

                    default:
                      goto unknown;
                  }
                }

                goto unknown;

              case 'l':
                if (name[4] == 'o' &&
                    name[5] == 'g' &&
                    name[6] == 'i' &&
                    name[7] == 'n')
                {                                 /* getlogin   */
                  return -KEY_getlogin;
                }

                goto unknown;

              case 'p':
                if (name[4] == 'w')
                {
                  switch (name[5])
                  {
                    case 'e':
                      if (name[6] == 'n' &&
                          name[7] == 't')
                      {                           /* getpwent   */
                        return -KEY_getpwent;
                      }

                      goto unknown;

                    case 'n':
                      if (name[6] == 'a' &&
                          name[7] == 'm')
                      {                           /* getpwnam   */
                        return -KEY_getpwnam;
                      }

                      goto unknown;

                    case 'u':
                      if (name[6] == 'i' &&
                          name[7] == 'd')
                      {                           /* getpwuid   */
                        return -KEY_getpwuid;
                      }

                      goto unknown;

                    default:
                      goto unknown;
                  }
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 'r':
          if (name[1] == 'e' &&
              name[2] == 'a' &&
              name[3] == 'd')
          {
            switch (name[4])
            {
              case 'l':
                if (name[5] == 'i' &&
                    name[6] == 'n')
                {
                  switch (name[7])
                  {
                    case 'e':
                      {                           /* readline   */
                        return -KEY_readline;
                      }

                    case 'k':
                      {                           /* readlink   */
                        return -KEY_readlink;
                      }

                    default:
                      goto unknown;
                  }
                }

                goto unknown;

              case 'p':
                if (name[5] == 'i' &&
                    name[6] == 'p' &&
                    name[7] == 'e')
                {                                 /* readpipe   */
                  return -KEY_readpipe;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 's':
          switch (name[1])
          {
            case 'e':
              if (name[2] == 't')
              {
                switch (name[3])
                {
                  case 'g':
                    if (name[4] == 'r' &&
                        name[5] == 'e' &&
                        name[6] == 'n' &&
                        name[7] == 't')
                    {                             /* setgrent   */
                      return -KEY_setgrent;
                    }

                    goto unknown;

                  case 'p':
                    if (name[4] == 'w' &&
                        name[5] == 'e' &&
                        name[6] == 'n' &&
                        name[7] == 't')
                    {                             /* setpwent   */
                      return -KEY_setpwent;
                    }

                    goto unknown;

                  default:
                    goto unknown;
                }
              }

              goto unknown;

            case 'h':
              switch (name[2])
              {
                case 'm':
                  if (name[3] == 'w' &&
                      name[4] == 'r' &&
                      name[5] == 'i' &&
                      name[6] == 't' &&
                      name[7] == 'e')
                  {                               /* shmwrite   */
                    return -KEY_shmwrite;
                  }

                  goto unknown;

                case 'u':
                  if (name[3] == 't' &&
                      name[4] == 'd' &&
                      name[5] == 'o' &&
                      name[6] == 'w' &&
                      name[7] == 'n')
                  {                               /* shutdown   */
                    return -KEY_shutdown;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }

            case 'y':
              if (name[2] == 's' &&
                  name[3] == 'w' &&
                  name[4] == 'r' &&
                  name[5] == 'i' &&
                  name[6] == 't' &&
                  name[7] == 'e')
              {                                   /* syswrite   */
                return -KEY_syswrite;
              }

              goto unknown;

            default:
              goto unknown;
          }

        case 't':
          if (name[1] == 'r' &&
              name[2] == 'u' &&
              name[3] == 'n' &&
              name[4] == 'c' &&
              name[5] == 'a' &&
              name[6] == 't' &&
              name[7] == 'e')
          {                                       /* truncate   */
            return -KEY_truncate;
          }

          goto unknown;

        default:
          goto unknown;
      }

    case 9: /* 9 tokens of length 9 */
      switch (name[0])
      {
        case 'U':
          if (name[1] == 'N' &&
              name[2] == 'I' &&
              name[3] == 'T' &&
              name[4] == 'C' &&
              name[5] == 'H' &&
              name[6] == 'E' &&
              name[7] == 'C' &&
              name[8] == 'K')
          {                                       /* UNITCHECK  */
            return KEY_UNITCHECK;
          }

          goto unknown;

        case 'e':
          if (name[1] == 'n' &&
              name[2] == 'd' &&
              name[3] == 'n' &&
              name[4] == 'e' &&
              name[5] == 't' &&
              name[6] == 'e' &&
              name[7] == 'n' &&
              name[8] == 't')
          {                                       /* endnetent  */
            return -KEY_endnetent;
          }

          goto unknown;

        case 'g':
          if (name[1] == 'e' &&
              name[2] == 't' &&
              name[3] == 'n' &&
              name[4] == 'e' &&
              name[5] == 't' &&
              name[6] == 'e' &&
              name[7] == 'n' &&
              name[8] == 't')
          {                                       /* getnetent  */
            return -KEY_getnetent;
          }

          goto unknown;

        case 'l':
          if (name[1] == 'o' &&
              name[2] == 'c' &&
              name[3] == 'a' &&
              name[4] == 'l' &&
              name[5] == 't' &&
              name[6] == 'i' &&
              name[7] == 'm' &&
              name[8] == 'e')
          {                                       /* localtime  */
            return -KEY_localtime;
          }

          goto unknown;

        case 'p':
          if (name[1] == 'r' &&
              name[2] == 'o' &&
              name[3] == 't' &&
              name[4] == 'o' &&
              name[5] == 't' &&
              name[6] == 'y' &&
              name[7] == 'p' &&
              name[8] == 'e')
          {                                       /* prototype  */
            return KEY_prototype;
          }

          goto unknown;

        case 'q':
          if (name[1] == 'u' &&
              name[2] == 'o' &&
              name[3] == 't' &&
              name[4] == 'e' &&
              name[5] == 'm' &&
              name[6] == 'e' &&
              name[7] == 't' &&
              name[8] == 'a')
          {                                       /* quotemeta  */
            return -KEY_quotemeta;
          }

          goto unknown;

        case 'r':
          if (name[1] == 'e' &&
              name[2] == 'w' &&
              name[3] == 'i' &&
              name[4] == 'n' &&
              name[5] == 'd' &&
              name[6] == 'd' &&
              name[7] == 'i' &&
              name[8] == 'r')
          {                                       /* rewinddir  */
            return -KEY_rewinddir;
          }

          goto unknown;

        case 's':
          if (name[1] == 'e' &&
              name[2] == 't' &&
              name[3] == 'n' &&
              name[4] == 'e' &&
              name[5] == 't' &&
              name[6] == 'e' &&
              name[7] == 'n' &&
              name[8] == 't')
          {                                       /* setnetent  */
            return -KEY_setnetent;
          }

          goto unknown;

        case 'w':
          if (name[1] == 'a' &&
              name[2] == 'n' &&
              name[3] == 't' &&
              name[4] == 'a' &&
              name[5] == 'r' &&
              name[6] == 'r' &&
              name[7] == 'a' &&
              name[8] == 'y')
          {                                       /* wantarray  */
            return -KEY_wantarray;
          }

          goto unknown;

        default:
          goto unknown;
      }

    case 10: /* 9 tokens of length 10 */
      switch (name[0])
      {
        case 'e':
          if (name[1] == 'n' &&
              name[2] == 'd')
          {
            switch (name[3])
            {
              case 'h':
                if (name[4] == 'o' &&
                    name[5] == 's' &&
                    name[6] == 't' &&
                    name[7] == 'e' &&
                    name[8] == 'n' &&
                    name[9] == 't')
                {                                 /* endhostent */
                  return -KEY_endhostent;
                }

                goto unknown;

              case 's':
                if (name[4] == 'e' &&
                    name[5] == 'r' &&
                    name[6] == 'v' &&
                    name[7] == 'e' &&
                    name[8] == 'n' &&
                    name[9] == 't')
                {                                 /* endservent */
                  return -KEY_endservent;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 'g':
          if (name[1] == 'e' &&
              name[2] == 't')
          {
            switch (name[3])
            {
              case 'h':
                if (name[4] == 'o' &&
                    name[5] == 's' &&
                    name[6] == 't' &&
                    name[7] == 'e' &&
                    name[8] == 'n' &&
                    name[9] == 't')
                {                                 /* gethostent */
                  return -KEY_gethostent;
                }

                goto unknown;

              case 's':
                switch (name[4])
                {
                  case 'e':
                    if (name[5] == 'r' &&
                        name[6] == 'v' &&
                        name[7] == 'e' &&
                        name[8] == 'n' &&
                        name[9] == 't')
                    {                             /* getservent */
                      return -KEY_getservent;
                    }

                    goto unknown;

                  case 'o':
                    if (name[5] == 'c' &&
                        name[6] == 'k' &&
                        name[7] == 'o' &&
                        name[8] == 'p' &&
                        name[9] == 't')
                    {                             /* getsockopt */
                      return -KEY_getsockopt;
                    }

                    goto unknown;

                  default:
                    goto unknown;
                }

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 's':
          switch (name[1])
          {
            case 'e':
              if (name[2] == 't')
              {
                switch (name[3])
                {
                  case 'h':
                    if (name[4] == 'o' &&
                        name[5] == 's' &&
                        name[6] == 't' &&
                        name[7] == 'e' &&
                        name[8] == 'n' &&
                        name[9] == 't')
                    {                             /* sethostent */
                      return -KEY_sethostent;
                    }

                    goto unknown;

                  case 's':
                    switch (name[4])
                    {
                      case 'e':
                        if (name[5] == 'r' &&
                            name[6] == 'v' &&
                            name[7] == 'e' &&
                            name[8] == 'n' &&
                            name[9] == 't')
                        {                         /* setservent */
                          return -KEY_setservent;
                        }

                        goto unknown;

                      case 'o':
                        if (name[5] == 'c' &&
                            name[6] == 'k' &&
                            name[7] == 'o' &&
                            name[8] == 'p' &&
                            name[9] == 't')
                        {                         /* setsockopt */
                          return -KEY_setsockopt;
                        }

                        goto unknown;

                      default:
                        goto unknown;
                    }

                  default:
                    goto unknown;
                }
              }

              goto unknown;

            case 'o':
              if (name[2] == 'c' &&
                  name[3] == 'k' &&
                  name[4] == 'e' &&
                  name[5] == 't' &&
                  name[6] == 'p' &&
                  name[7] == 'a' &&
                  name[8] == 'i' &&
                  name[9] == 'r')
              {                                   /* socketpair */
                return -KEY_socketpair;
              }

              goto unknown;

            default:
              goto unknown;
          }

        default:
          goto unknown;
      }

    case 11: /* 8 tokens of length 11 */
      switch (name[0])
      {
        case '_':
          if (name[1] == '_' &&
              name[2] == 'P' &&
              name[3] == 'A' &&
              name[4] == 'C' &&
              name[5] == 'K' &&
              name[6] == 'A' &&
              name[7] == 'G' &&
              name[8] == 'E' &&
              name[9] == '_' &&
              name[10] == '_')
          {                                       /* __PACKAGE__ */
            return -KEY___PACKAGE__;
          }

          goto unknown;

        case 'e':
          if (name[1] == 'n' &&
              name[2] == 'd' &&
              name[3] == 'p' &&
              name[4] == 'r' &&
              name[5] == 'o' &&
              name[6] == 't' &&
              name[7] == 'o' &&
              name[8] == 'e' &&
              name[9] == 'n' &&
              name[10] == 't')
          {                                       /* endprotoent */
            return -KEY_endprotoent;
          }

          goto unknown;

        case 'g':
          if (name[1] == 'e' &&
              name[2] == 't')
          {
            switch (name[3])
            {
              case 'p':
                switch (name[4])
                {
                  case 'e':
                    if (name[5] == 'e' &&
                        name[6] == 'r' &&
                        name[7] == 'n' &&
                        name[8] == 'a' &&
                        name[9] == 'm' &&
                        name[10] == 'e')
                    {                             /* getpeername */
                      return -KEY_getpeername;
                    }

                    goto unknown;

                  case 'r':
                    switch (name[5])
                    {
                      case 'i':
                        if (name[6] == 'o' &&
                            name[7] == 'r' &&
                            name[8] == 'i' &&
                            name[9] == 't' &&
                            name[10] == 'y')
                        {                         /* getpriority */
                          return -KEY_getpriority;
                        }

                        goto unknown;

                      case 'o':
                        if (name[6] == 't' &&
                            name[7] == 'o' &&
                            name[8] == 'e' &&
                            name[9] == 'n' &&
                            name[10] == 't')
                        {                         /* getprotoent */
                          return -KEY_getprotoent;
                        }

                        goto unknown;

                      default:
                        goto unknown;
                    }

                  default:
                    goto unknown;
                }

              case 's':
                if (name[4] == 'o' &&
                    name[5] == 'c' &&
                    name[6] == 'k' &&
                    name[7] == 'n' &&
                    name[8] == 'a' &&
                    name[9] == 'm' &&
                    name[10] == 'e')
                {                                 /* getsockname */
                  return -KEY_getsockname;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        case 's':
          if (name[1] == 'e' &&
              name[2] == 't' &&
              name[3] == 'p' &&
              name[4] == 'r')
          {
            switch (name[5])
            {
              case 'i':
                if (name[6] == 'o' &&
                    name[7] == 'r' &&
                    name[8] == 'i' &&
                    name[9] == 't' &&
                    name[10] == 'y')
                {                                 /* setpriority */
                  return -KEY_setpriority;
                }

                goto unknown;

              case 'o':
                if (name[6] == 't' &&
                    name[7] == 'o' &&
                    name[8] == 'e' &&
                    name[9] == 'n' &&
                    name[10] == 't')
                {                                 /* setprotoent */
                  return -KEY_setprotoent;
                }

                goto unknown;

              default:
                goto unknown;
            }
          }

          goto unknown;

        default:
          goto unknown;
      }

    case 12: /* 2 tokens of length 12 */
      if (name[0] == 'g' &&
          name[1] == 'e' &&
          name[2] == 't' &&
          name[3] == 'n' &&
          name[4] == 'e' &&
          name[5] == 't' &&
          name[6] == 'b' &&
          name[7] == 'y')
      {
        switch (name[8])
        {
          case 'a':
            if (name[9] == 'd' &&
                name[10] == 'd' &&
                name[11] == 'r')
            {                                     /* getnetbyaddr */
              return -KEY_getnetbyaddr;
            }

            goto unknown;

          case 'n':
            if (name[9] == 'a' &&
                name[10] == 'm' &&
                name[11] == 'e')
            {                                     /* getnetbyname */
              return -KEY_getnetbyname;
            }

            goto unknown;

          default:
            goto unknown;
        }
      }

      goto unknown;

    case 13: /* 4 tokens of length 13 */
      if (name[0] == 'g' &&
          name[1] == 'e' &&
          name[2] == 't')
      {
        switch (name[3])
        {
          case 'h':
            if (name[4] == 'o' &&
                name[5] == 's' &&
                name[6] == 't' &&
                name[7] == 'b' &&
                name[8] == 'y')
            {
              switch (name[9])
              {
                case 'a':
                  if (name[10] == 'd' &&
                      name[11] == 'd' &&
                      name[12] == 'r')
                  {                               /* gethostbyaddr */
                    return -KEY_gethostbyaddr;
                  }

                  goto unknown;

                case 'n':
                  if (name[10] == 'a' &&
                      name[11] == 'm' &&
                      name[12] == 'e')
                  {                               /* gethostbyname */
                    return -KEY_gethostbyname;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }
            }

            goto unknown;

          case 's':
            if (name[4] == 'e' &&
                name[5] == 'r' &&
                name[6] == 'v' &&
                name[7] == 'b' &&
                name[8] == 'y')
            {
              switch (name[9])
              {
                case 'n':
                  if (name[10] == 'a' &&
                      name[11] == 'm' &&
                      name[12] == 'e')
                  {                               /* getservbyname */
                    return -KEY_getservbyname;
                  }

                  goto unknown;

                case 'p':
                  if (name[10] == 'o' &&
                      name[11] == 'r' &&
                      name[12] == 't')
                  {                               /* getservbyport */
                    return -KEY_getservbyport;
                  }

                  goto unknown;

                default:
                  goto unknown;
              }
            }

            goto unknown;

          default:
            goto unknown;
        }
      }

      goto unknown;

    case 14: /* 1 tokens of length 14 */
      if (name[0] == 'g' &&
          name[1] == 'e' &&
          name[2] == 't' &&
          name[3] == 'p' &&
          name[4] == 'r' &&
          name[5] == 'o' &&
          name[6] == 't' &&
          name[7] == 'o' &&
          name[8] == 'b' &&
          name[9] == 'y' &&
          name[10] == 'n' &&
          name[11] == 'a' &&
          name[12] == 'm' &&
          name[13] == 'e')
      {                                           /* getprotobyname */
        return -KEY_getprotobyname;
      }

      goto unknown;

    case 16: /* 1 tokens of length 16 */
      if (name[0] == 'g' &&
          name[1] == 'e' &&
          name[2] == 't' &&
          name[3] == 'p' &&
          name[4] == 'r' &&
          name[5] == 'o' &&
          name[6] == 't' &&
          name[7] == 'o' &&
          name[8] == 'b' &&
          name[9] == 'y' &&
          name[10] == 'n' &&
          name[11] == 'u' &&
          name[12] == 'm' &&
          name[13] == 'b' &&
          name[14] == 'e' &&
          name[15] == 'r')
      {                                           /* getprotobynumber */
        return -KEY_getprotobynumber;
      }

      goto unknown;

    default:
      goto unknown;
  }

unknown:
  return 0;
}

STATIC void
S_checkcomma(pTHX_ const char *s, const char *name, const char *what)
{
    dVAR;

    PERL_ARGS_ASSERT_CHECKCOMMA;

    if (*s == ' ' && s[1] == '(') {	/* XXX gotta be a better way */
	if (ckWARN(WARN_SYNTAX)) {
	    int level = 1;
	    const char *w;
	    for (w = s+2; *w && level; w++) {
		if (*w == '(')
		    ++level;
		else if (*w == ')')
		    --level;
	    }
	    while (isSPACE(*w))
		++w;
	    /* the list of chars below is for end of statements or
	     * block / parens, boolean operators (&&, ||, //) and branch
	     * constructs (or, and, if, until, unless, while, err, for).
	     * Not a very solid hack... */
	    if (!*w || !strchr(";&/|})]oaiuwef!=", *w))
		Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
			    "%s (...) interpreted as function",name);
	}
    }
    while (s < PL_bufend && isSPACE(*s))
	s++;
    if (*s == '(')
	s++;
    while (s < PL_bufend && isSPACE(*s))
	s++;
    if (isIDFIRST_lazy_if(s,UTF)) {
	const char * const w = s++;
	while (isALNUM_lazy_if(s,UTF))
	    s++;
	while (s < PL_bufend && isSPACE(*s))
	    s++;
	if (*s == ',') {
	    GV* gv;
	    if (keyword(w, s - w, 0))
		return;

	    gv = gv_fetchpvn_flags(w, s - w, 0, SVt_PVCV);
	    if (gv && GvCVu(gv))
		return;
	    Perl_croak(aTHX_ "No comma allowed after %s", what);
	}
    }
}

/* Either returns sv, or mortalizes sv and returns a new SV*.
   Best used as sv=new_constant(..., sv, ...).
   If s, pv are NULL, calls subroutine with one argument,
   and type is used with error messages only. */

STATIC SV *
S_new_constant(pTHX_ const char *s, STRLEN len, const char *key, STRLEN keylen,
	       SV *sv, SV *pv, const char *type, STRLEN typelen)
{
    dVAR; dSP;
    HV * const table = GvHV(PL_hintgv);		 /* ^H */
    SV *res;
    SV **cvp;
    SV *cv, *typesv;
    const char *why1 = "", *why2 = "", *why3 = "";

    PERL_ARGS_ASSERT_NEW_CONSTANT;

    if (!table || !(PL_hints & HINT_LOCALIZE_HH)) {
	SV *msg;
	
	why2 = (const char *)
	    (strEQ(key,"charnames")
	     ? "(possibly a missing \"use charnames ...\")"
	     : "");
	msg = Perl_newSVpvf(aTHX_ "Constant(%s) unknown: %s",
			    (type ? type: "undef"), why2);

	/* This is convoluted and evil ("goto considered harmful")
	 * but I do not understand the intricacies of all the different
	 * failure modes of %^H in here.  The goal here is to make
	 * the most probable error message user-friendly. --jhi */

	goto msgdone;

    report:
	msg = Perl_newSVpvf(aTHX_ "Constant(%s): %s%s%s",
			    (type ? type: "undef"), why1, why2, why3);
    msgdone:
	yyerror(SvPVX_const(msg));
 	SvREFCNT_dec(msg);
  	return sv;
    }
    cvp = hv_fetch(table, key, keylen, FALSE);
    if (!cvp || !SvOK(*cvp)) {
	why1 = "%^H{";
	why2 = key;
	why3 = "} is not defined";
	goto report;
    }
    sv_2mortal(sv);			/* Parent created it permanently */
    cv = *cvp;
    if (!pv && s)
  	pv = newSVpvn_flags(s, len, SVs_TEMP);
    if (type && pv)
  	typesv = newSVpvn_flags(type, typelen, SVs_TEMP);
    else
  	typesv = &PL_sv_undef;

    PUSHSTACKi(PERLSI_OVERLOAD);
    ENTER ;
    SAVETMPS;

    PUSHMARK(SP) ;
    EXTEND(sp, 3);
    if (pv)
 	PUSHs(pv);
    PUSHs(sv);
    if (pv)
 	PUSHs(typesv);
    PUTBACK;
    call_sv(cv, G_SCALAR | ( PL_in_eval ? 0 : G_EVAL));

    SPAGAIN ;

    /* Check the eval first */
    if (!PL_in_eval && SvTRUE(ERRSV)) {
 	sv_catpvs(ERRSV, "Propagated");
	yyerror(SvPV_nolen_const(ERRSV)); /* Duplicates the message inside eval */
	(void)POPs;
	res = SvREFCNT_inc_simple(sv);
    }
    else {
 	res = POPs;
	SvREFCNT_inc_simple_void(res);
    }

    PUTBACK ;
    FREETMPS ;
    LEAVE ;
    POPSTACK;

    if (!SvOK(res)) {
 	why1 = "Call to &{%^H{";
 	why2 = key;
 	why3 = "}} did not return a defined value";
 	sv = res;
 	goto report;
    }

    return res;
}

/* Returns a NUL terminated string, with the length of the string written to
   *slp
   */
STATIC char *
S_scan_word(pTHX_ register char *s, char *dest, STRLEN destlen, int allow_package, STRLEN *slp)
{
    dVAR;
    register char *d = dest;
    register char * const e = d + destlen - 3;  /* two-character token, ending NUL */

    PERL_ARGS_ASSERT_SCAN_WORD;

    for (;;) {
	if (d >= e)
	    Perl_croak(aTHX_ ident_too_long);
	if (isALNUM(*s))	/* UTF handled below */
	    *d++ = *s++;
	else if (allow_package && (s[0] == ':') && (s[1] == ':') && (s[2] != '$')) {
	    *d++ = *s++;
	    *d++ = *s++;
	}
	else if (UTF && UTF8_IS_START(*s) && isALNUM_utf8(s)) {
	    char *t = s + UTF8SKIP(s);
	    size_t len;
	    while (UTF8_IS_CONTINUED(*t) && is_utf8_mark(t))
		t += UTF8SKIP(t);
	    len = t - s;
	    if (d + len > e)
		Perl_croak(aTHX_ ident_too_long);
	    Copy(s, d, len, char);
	    d += len;
	    s = t;
	}
	else {
	    *d = '\0';
	    *slp = d - dest;
	    return s;
	}
    }
}

STATIC char *
S_scan_ident(pTHX_ register char *s, register const char *send, char *dest, STRLEN destlen, I32 ck_uni)
{
    dVAR;
    register char *d = dest;
    register char * const e = d + destlen + 3;    /* two-character token, ending NUL */

    PERL_ARGS_ASSERT_SCAN_IDENT;

    /* skip sigil */
    s++;

    if (isSPACE(*s))
	s = PEEKSPACE(s);
    if (isDIGIT(*s)) {
	while (isDIGIT(*s)) {
	    if (d >= e)
		Perl_croak(aTHX_ ident_too_long);
	    *d++ = *s++;
	}
    }
    else {
	/* allow initial ^ */
	if (*s == '^') {
	    *d++ = *s++;
	}
	for (;;) {
	    if (d >= e)
		Perl_croak(aTHX_ ident_too_long);
	    if (isALNUM(*s))	/* UTF handled below */
		*d++ = *s++;
	    else if (*s == ':' && s[1] == ':') {
		*d++ = *s++;
		*d++ = *s++;
	    }
	    else if (UTF && UTF8_IS_START(*s) && isALNUM_utf8(s)) {
		char *t = s + UTF8SKIP(s);
		while (UTF8_IS_CONTINUED(*t) && is_utf8_mark(t))
		    t += UTF8SKIP(t);
		if (d + (t - s) > e)
		    Perl_croak(aTHX_ ident_too_long);
		Copy(s, d, t - s, char);
		d += t - s;
		s = t;
	    }
	    else
		break;
	}
    }
    *d = '\0';
    d = dest;
    if (*d) {
	if (PL_lex_state != LEX_NORMAL) {
	    if (PL_lex_brackets == 0) {
		if (intuit_more(s)) {
		    PL_lex_state = LEX_INTERPNORMAL;
		} else {
		    PL_lex_state = LEX_INTERPEND;
		}
	    }
	}
	return s;
    }
    if (*s == '$' && s[1] &&
	(isALNUM_lazy_if(s+1,UTF) || s[1] == '$' || s[1] == '{' || strnEQ(s+1,"::",2)) )
    {
	return s;
    }
    if (*s == '{') {
	*d = '\0';
	return s;
    }
    else if (ck_uni)
	check_uni();
    if (s < send)
	*d = *s++;
    d[1] = '\0';
    if (*d == '^') {
	*d++ = *s++;
    }
    if (PL_lex_state == LEX_INTERPNORMAL && !PL_lex_brackets && !intuit_more(s))
	PL_lex_state = LEX_INTERPEND;
    return s;
}

void
Perl_pmflag(pTHX_ U32* pmfl, int ch)
{
    PERL_ARGS_ASSERT_PMFLAG;

    PERL_UNUSED_CONTEXT;
    if (ch<256) {
        const char c = (char)ch;
        switch (c) {
            CASE_STD_PMMOD_FLAGS_PARSE_SET(pmfl);
            case GLOBAL_PAT_MOD:    *pmfl |= PMf_GLOBAL; break;
            case CONTINUE_PAT_MOD:  *pmfl |= PMf_CONTINUE; break;
            case ONCE_PAT_MOD:      *pmfl |= PMf_KEEP; break;
            case KEEPCOPY_PAT_MOD:  *pmfl |= PMf_KEEPCOPY; break;
        }
    }
}

STATIC char *
S_scan_pat(pTHX_ char *start, I32 type)
{
    dVAR;
    PMOP *pm;
    char *s;
    const char * const valid_flags =
	(const char *)((type == OP_QR) ? QR_PAT_MODS : M_PAT_MODS);

    PL_lex_stuff.flags = LEXf_INPAT;
    s = scan_str(start,TRUE,FALSE, &PL_lex_stuff);
#ifdef PERL_MAD
    char *modstart;
#endif

    PERL_ARGS_ASSERT_SCAN_PAT;

    if (!s) {
	Perl_croak(aTHX_
		   (const char *)
		   "Search pattern not terminated");
    }

    pm = (PMOP*)newPMOP(type, 0);
#ifdef PERL_MAD
    modstart = s;
#endif
    while (*s && strchr(valid_flags, *s))
	pmflag(&pm->op_pmflags,*s++);

    if (IN_CODEPOINTS)
	pm->op_pmflags |= PMf_UTF8;

#ifdef PERL_MAD
    if (PL_madskills && modstart != s) {
	SV* tmptoken = newSVpvn(modstart, s - modstart);
	append_madprops(newMADPROP('m', MAD_SV, tmptoken, 0), (OP*)pm, 0);
    }
#endif
    /* issue a warning if /c is specified,but /g is not */
    if ((pm->op_pmflags & PMf_CONTINUE) && !(pm->op_pmflags & PMf_GLOBAL)
	    && ckWARN(WARN_REGEXP))
    {
        Perl_warner(aTHX_ packWARN(WARN_REGEXP), 
            "Use of /c modifier is meaningless without /g" );
    }

    PL_lex_op = (OP*)pm;
    pl_yylval.ival = type;
    return s;
}

STATIC char *
S_scan_subst(pTHX_ char *start)
{
    dVAR;
    register char *s;
    register PMOP *pm;
    I32 first_start;
#ifdef PERL_MAD
    char *modstart;
#endif

    PERL_ARGS_ASSERT_SCAN_SUBST;

    pl_yylval.ival = OP_NULL;

    PL_lex_stuff.flags = LEXf_INPAT;
    s = scan_str(start,TRUE,FALSE, &PL_lex_stuff);

    if (!s)
	Perl_croak(aTHX_ "Substitution pattern not terminated");

    if (s[-1] == PL_multi_open)
	s--;
#ifdef PERL_MAD
    if (PL_madskills) {
	CURMAD('q', PL_thisopen);
	CURMAD('_', PL_thiswhite);
	CURMAD('Q', PL_thisclose);
	PL_realtokenstart = s - SvPVX(PL_linestr);
    }
#endif

    first_start = PL_multi_start;
    PL_lex_repl.flags = LEXf_REPL;
    s = scan_str(s,TRUE,FALSE, &PL_lex_repl);
    if (!s) {
	if (PL_lex_stuff.str_sv) {
	    SvREFCNT_dec(PL_lex_stuff.str_sv);
	    PL_lex_stuff.str_sv = NULL;
	}
	Perl_croak(aTHX_ "Substitution replacement not terminated");
    }
    PL_multi_start = first_start;	/* so whole substitution is taken together */

    pm = (PMOP*)newPMOP(OP_SUBST, 0);

#ifdef PERL_MAD
    if (PL_madskills) {
	CURMAD('z', PL_thisopen);
	CURMAD('R', PL_thisstuff);
	CURMAD('Z', PL_thisclose);
    }
    modstart = s;
#endif

    while (*s) {
	if (strchr(S_PAT_MODS, *s))
	    pmflag(&pm->op_pmflags,*s++);
	else
	    break;
    }

    if (IN_CODEPOINTS)
	pm->op_pmflags |= PMf_UTF8;

#ifdef PERL_MAD
    if (PL_madskills) {
	if (modstart != s)
	    curmad('m', newSVpvn(modstart, s - modstart));
	append_madprops(PL_thismad, (OP*)pm, 0);
	PL_thismad = 0;
    }
#endif
    if ((pm->op_pmflags & PMf_CONTINUE) && ckWARN(WARN_REGEXP)) {
        Perl_warner(aTHX_ packWARN(WARN_REGEXP), "Use of /c modifier is meaningless in s///" );
    }

    PL_lex_op = (OP*)pm;
    pl_yylval.ival = OP_SUBST;
    return s;
}

STATIC char *
S_scan_trans(pTHX_ char *start)
{
    dVAR;
    register char* s;
    OP *o;
    short *tbl;
    U8 squash;
    U8 del;
    U8 complement;
#ifdef PERL_MAD
    char *modstart;
#endif

    PERL_ARGS_ASSERT_SCAN_TRANS;

    pl_yylval.ival = OP_NULL;

    PL_lex_stuff.flags = LEXf_INPAT;
    s = scan_str(start,TRUE,FALSE, &PL_lex_stuff);
    if (!s)
	Perl_croak(aTHX_ "Transliteration pattern not terminated");

    if (s[-1] == PL_multi_open)
	s--;
#ifdef PERL_MAD
    if (PL_madskills) {
	CURMAD('q', PL_thisopen);
	CURMAD('_', PL_thiswhite);
	CURMAD('Q', PL_thisclose);
	PL_realtokenstart = s - SvPVX(PL_linestr);
    }
#endif

    PL_lex_stuff.flags = LEXf_REPL;
    s = scan_str(s,TRUE,FALSE, &PL_lex_repl);
    if (!s) {
	if (PL_lex_stuff.str_sv) {
	    SvREFCNT_dec(PL_lex_stuff.str_sv);
	    PL_lex_stuff.str_sv = NULL;
	}
	Perl_croak(aTHX_ "Transliteration replacement not terminated");
    }
    if (PL_madskills) {
	CURMAD('z', PL_thisopen);
	CURMAD('R', PL_thisstuff);
	CURMAD('Z', PL_thisclose);
    }

    complement = del = squash = 0;
#ifdef PERL_MAD
    modstart = s;
#endif
    while (1) {
	switch (*s) {
	case 'c':
	    complement = OPpTRANS_COMPLEMENT;
	    break;
	case 'd':
	    del = OPpTRANS_DELETE;
	    break;
	case 's':
	    squash = OPpTRANS_SQUASH;
	    break;
	default:
	    goto no_more;
	}
	s++;
    }
  no_more:

    tbl = (short *)PerlMemShared_calloc(complement&&!del?258:256, sizeof(short));
    o = newPVOP(OP_TRANS, 0, (char*)tbl);
    o->op_private &= ~OPpTRANS_ALL;
    o->op_private |= del|squash|complement|
      (IN_CODEPOINTS? OPpTRANS_UTF8 : 0);

    PL_lex_op = o;
    pl_yylval.ival = OP_TRANS;

#ifdef PERL_MAD
    if (PL_madskills) {
	if (modstart != s)
	    curmad('m', newSVpvn(modstart, s - modstart));
	append_madprops(PL_thismad, o, 0);
	PL_thismad = 0;
    }
#endif

    return s;
}

STATIC char *
S_scan_heredoc(pTHX_ register char *s)
{
    dVAR;
    SV *herewas;
    I32 op_type = OP_SCALAR;
    I32 len;
    SV *tmpstr;
    char term;
    const char *found_newline;
    register char *d;
    register char *e;
    char *peek;
    const int outer = (PL_rsfp && !(PL_lex_inwhat == OP_SCALAR));
#ifdef PERL_MAD
    I32 stuffstart = s - SvPVX(PL_linestr);
    char *tstart;
 
    PL_realtokenstart = -1;
#endif

    PERL_ARGS_ASSERT_SCAN_HEREDOC;

    s += 2;
    d = PL_tokenbuf;
    e = PL_tokenbuf + sizeof PL_tokenbuf - 1;
    if (!outer)
	*d++ = '\n';
    peek = s;
    while (SPACE_OR_TAB(*peek))
	peek++;
    if (*peek == '`' || *peek == '\'' || *peek =='"') {
	s = peek;
	term = *s++;
	s = delimcpy(d, e, s, PL_bufend, term, &len);
	d += len;
	if (s < PL_bufend)
	    s++;
    }
    else {
	if (*s == '\\')
	    s++, term = '\'';
	else
	    term = '"';
	if (!isALNUM_lazy_if(s,UTF))
	    deprecate_old("bare << to mean <<\"\"");
	for (; isALNUM_lazy_if(s,UTF); s++) {
	    if (d < e)
		*d++ = *s;
	}
    }
    if (d >= PL_tokenbuf + sizeof PL_tokenbuf - 1)
	Perl_croak(aTHX_ "Delimiter for here document is too long");
    *d++ = '\n';
    *d = '\0';
    len = d - PL_tokenbuf;

#ifdef PERL_MAD
    if (PL_madskills) {
	tstart = PL_tokenbuf + !outer;
	PL_thisclose = newSVpvn(tstart, len - !outer);
	tstart = SvPVX(PL_linestr) + stuffstart;
	PL_thisopen = newSVpvn(tstart, s - tstart);
	stuffstart = s - SvPVX(PL_linestr);
    }
#endif
#ifndef PERL_STRICT_CR
    d = strchr(s, '\r');
    if (d) {
	char * const olds = s;
	s = d;
	while (s < PL_bufend) {
	    if (*s == '\r') {
		*d++ = '\n';
		if (*++s == '\n')
		    s++;
	    }
	    else if (*s == '\n' && s[1] == '\r') {	/* \015\013 on a mac? */
		*d++ = *s++;
		s++;
	    }
	    else
		*d++ = *s++;
	}
	*d = '\0';
	PL_bufend = d;
	SvCUR_set(PL_linestr, PL_bufend - SvPVX_const(PL_linestr));
	s = olds;
    }
#endif
#ifdef PERL_MAD
    found_newline = 0;
#endif
    if ( outer || !(found_newline = (char*)memchr((void*)s, '\n', PL_bufend - s)) ) {
        herewas = newSVpvn(s,PL_bufend-s);
    }
    else {
#ifdef PERL_MAD
        herewas = newSVpvn(s-1,found_newline-s+1);
#else
        s--;
        herewas = newSVpvn(s,found_newline-s);
#endif
    }
#ifdef PERL_MAD
    if (PL_madskills) {
	tstart = SvPVX(PL_linestr) + stuffstart;
	if (PL_thisstuff)
	    sv_catpvn(PL_thisstuff, tstart, s - tstart);
	else
	    PL_thisstuff = newSVpvn(tstart, s - tstart);
    }
#endif
    s += SvCUR(herewas);

#ifdef PERL_MAD
    stuffstart = s - SvPVX(PL_linestr);

    if (found_newline)
	s--;
#endif

    tmpstr = newSV_type(SVt_PV);
    SvGROW(tmpstr, 80);
    if (term == '\'') {
	op_type = OP_CONST;
    }
    else if (term == '`') {
	op_type = OP_BACKTICK;
    }
    PL_lex_stuff.flags = LEXf_HEREDOC; /* single quote delimiter is handled specially in parse */

    CLINE;
    PL_multi_start = CopLINE(PL_curcop);
    PL_multi_open = PL_multi_close = '<';
    term = *PL_tokenbuf;
    if (!outer) {
	d = s;
	while (s < PL_bufend &&
	  (*s != term || memNE(s,PL_tokenbuf,len)) ) {
	    if (*s++ == '\n')
		CopLINE_inc(PL_curcop);
	}
	if (s >= PL_bufend) {
	    CopLINE_set(PL_curcop, (line_t)PL_multi_start);
	    missingterminator(PL_tokenbuf);
	}
	sv_setpvn(tmpstr,d+1,s-d);
#ifdef PERL_MAD
	if (PL_madskills) {
	    if (PL_thisstuff)
		sv_catpvn(PL_thisstuff, d + 1, s - d);
	    else
		PL_thisstuff = newSVpvn(d + 1, s - d);
	    stuffstart = s - SvPVX(PL_linestr);
	}
#endif
	s += len - 1;
	CopLINE_inc(PL_curcop);	/* the preceding stmt passes a newline */

	sv_catpvn(herewas,s,PL_bufend-s);
	sv_setsv(PL_linestr,herewas);
	PL_oldoldbufptr = PL_oldbufptr = PL_bufptr = s = PL_linestart = SvPVX(PL_linestr);
	PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
	PL_last_lop = PL_last_uni = NULL;
    }
    else
	sv_setpvn(tmpstr,"",0);   /* avoid "uninitialized" warning */
    while (s >= PL_bufend) {	/* multiple line string? */
#ifdef PERL_MAD
	if (PL_madskills) {
	    tstart = SvPVX(PL_linestr) + stuffstart;
	    if (PL_thisstuff)
		sv_catpvn(PL_thisstuff, tstart, PL_bufend - tstart);
	    else
		PL_thisstuff = newSVpvn(tstart, PL_bufend - tstart);
	}
#endif
	if (!outer ||
	 !(PL_oldoldbufptr = PL_oldbufptr = s = PL_linestart = filter_gets(PL_linestr, PL_rsfp, 0))) {
	    CopLINE_set(PL_curcop, (line_t)PL_multi_start);
	    missingterminator(PL_tokenbuf);
	}
#ifdef PERL_MAD
	stuffstart = s - SvPVX(PL_linestr);
#endif
	CopLINE_inc(PL_curcop);
	PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
	PL_last_lop = PL_last_uni = NULL;
#ifndef PERL_STRICT_CR
	if (PL_bufend - PL_linestart >= 2) {
	    if ((PL_bufend[-2] == '\r' && PL_bufend[-1] == '\n') ||
		(PL_bufend[-2] == '\n' && PL_bufend[-1] == '\r'))
	    {
		PL_bufend[-2] = '\n';
		PL_bufend--;
		SvCUR_set(PL_linestr, PL_bufend - SvPVX_const(PL_linestr));
	    }
	    else if (PL_bufend[-1] == '\r')
		PL_bufend[-1] = '\n';
	}
	else if (PL_bufend - PL_linestart == 1 && PL_bufend[-1] == '\r')
	    PL_bufend[-1] = '\n';
#endif
	if (PERLDB_LINE && PL_curstash != PL_debstash)
	    update_debugger_info(PL_linestr, NULL, 0);
	if (*s == term && memEQ(s,PL_tokenbuf,len)) {
	    STRLEN off = PL_bufend - 1 - SvPVX_const(PL_linestr);
	    *(SvPVX(PL_linestr) + off ) = ' ';
	    sv_catsv(PL_linestr,herewas);
	    PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
	    s = SvPVX(PL_linestr) + off; /* In case PV of PL_linestr moved. */
	}
	else {
	    s = PL_bufend;
	    sv_catsv(tmpstr,PL_linestr);
	}
    }
    s++;
    PL_multi_end = CopLINE(PL_curcop);
    if (SvCUR(tmpstr) + 5 < SvLEN(tmpstr)) {
	SvPV_shrink_to_cur(tmpstr);
    }
    SvREFCNT_dec(herewas);
    PL_lex_stuff.str_sv = tmpstr;
    pl_yylval.ival = op_type;
    return s;
}

/* scan_str
   takes: start position in buffer
	  keep_quoted preserve \ on the embedded delimiter(s)
	  keep_delims preserve the delimiters around the string
   returns: position to continue reading from buffer
   side-effects: multi_start, multi_close, lex_repl or lex_stuff, and
   	updates the read buffer.

   This subroutine pulls a string out of the input.  It is called for:
   	q		single quotes		q(literal text)
	'		single quotes		'literal text'
	qq		double quotes		qq(interpolate $here please)
	"		double quotes		"interpolate $here please"
	qx		backticks		qx(/bin/ls -l)
	`		backticks		`/bin/ls -l`
	qw		quote words		@EXPORT_OK = qw( func() $spam )
	m//		regexp match		m/this/
	s///		regexp substitute	s/this/that/
	tr///		string transliterate	tr/this/that/
	y///		string transliterate	y/this/that/
	($*@)		sub prototypes		sub foo ($)
	(stuff)		sub attr parameters	sub foo : attr(stuff)
	
   In most of these cases (all but <>, patterns and transliterate)
   yylex() calls scan_str().  m// makes yylex() call scan_pat() which
   calls scan_str().  s/// makes yylex() call scan_subst() which calls
   scan_str().  tr/// and y/// make yylex() call scan_trans() which
   calls scan_str().

   It skips whitespace before the string starts, and treats the first
   character as the delimiter.  If the delimiter is one of ([{< then
   the corresponding "close" character )]}> is used as the closing
   delimiter.  It allows quoting of delimiters, and if the string has
   balanced delimiters ([{<>}]) it allows nesting.

   On success, the SV with the resulting string is put into lex_stuff or,
   if that is already non-NULL, into lex_repl. The second case occurs only
   when parsing the RHS of the special constructs s/// and tr/// (y///).
   The terminating delimiter character is stuffed into lex_delim or
   lex_repl_delim
*/

STATIC char *
S_scan_str(pTHX_ char *start, int escape, int keep_delims, yy_str_info *str_info)
{
    dVAR;
    SV *sv;				/* scalar value: string */
    const char *tmps;			/* temp string, used for delimiter matching */
    register char *s = start;		/* current position in the buffer */
    register char term;			/* terminating character */
    register char *to;			/* current position in the sv's data */
    I32 brackets = 1;			/* bracket nesting level */
    char termstr[UTF8_MAXBYTES];		/* terminating string */
    STRLEN termlen;			/* length of terminating string */
#ifdef PERL_MAD
    int stuffstart;
    char *tstart;
#endif

    PERL_ARGS_ASSERT_SCAN_STR;

    /* skip space before the delimiter */
    if (isSPACE(*s)) {
	s = PEEKSPACE(s);
    }

#ifdef PERL_MAD
    if (PL_realtokenstart >= 0) {
	stuffstart = PL_realtokenstart;
	PL_realtokenstart = -1;
    }
    else
	stuffstart = start - SvPVX(PL_linestr);
#endif
    /* mark where we are, in case we need to report errors */
    CLINE;

    /* after skipping whitespace, the next character is the terminator */
    term = *s;
    termlen = UTF8SKIP(s);
    Copy(s, termstr, termlen, char);

    /* mark where we are */
    PL_multi_start = CopLINE(PL_curcop);
    PL_multi_open = term;

    /* find corresponding closing delimiter */
    if (term && (tmps = strchr("([{< )]}> )]}>",term)))
	termstr[0] = term = tmps[5];

    PL_multi_close = term;

    /* create a new SV to hold the contents.  79 is the SV's initial length.
       What a random number. */
    sv = newSV_type(SVt_PV);
    SvGROW(sv, 80);
    (void)SvPOK_only(sv);		/* validate pointer */

    /* move past delimiter and try to read a complete string */
    if (keep_delims)
	sv_catpvn(sv, s, termlen);
    s += termlen;
#ifdef PERL_MAD
    tstart = SvPVX(PL_linestr) + stuffstart;
    if (!PL_thisopen && !keep_delims) {
	PL_thisopen = newSVpvn(tstart, s - tstart);
	stuffstart = s - SvPVX(PL_linestr);
    }
#endif
    for (;;) {
    	/* extend sv if need be */
	SvGROW(sv, SvCUR(sv) + (PL_bufend - s) + 1);
	/* set 'to' to the next character in the sv's string */
	to = SvPVX(sv)+SvCUR(sv);

	/* if open delimiter is the close delimiter read unbridle */
	if (PL_multi_open == PL_multi_close) {
	    for (; s < PL_bufend; s++,to++) {
	    	/* embedded newlines increment the current line number */
		if (*s == '\n' && !PL_rsfp)
		    CopLINE_inc(PL_curcop);
		/* handle quoted delimiters */
		if (escape && *s == '\\' && s+1 < PL_bufend) {
		    *to++ = *s++;
		}
		/* terminate when run out of buffer (the for() condition), or
		   have found the terminator */
		else if (*s == term) {
		    if (termlen == 1)
			break;
		    if (s+termlen <= PL_bufend && memEQ(s, (char*)termstr, termlen))
			break;
		}
		*to = *s;
	    }
	}
	
	/* if the terminator isn't the same as the start character (e.g.,
	   matched brackets), we have to allow more in the quoting, and
	   be prepared for nested brackets.
	*/
	else {
	    /* read until we run out of string, or we find the terminator */
	    for (; s < PL_bufend; s++,to++) {
	    	/* embedded newlines increment the line count */
		if (*s == '\n' && !PL_rsfp)
		    CopLINE_inc(PL_curcop);
		/* backslashes can escape the open or closing characters */
		if (escape && *s == '\\' && s+1 < PL_bufend) {
		    *to++ = *s++;
		}
		/* allow nested opens and closes */
		else if (*s == PL_multi_close && --brackets <= 0)
		    break;
		else if (*s == PL_multi_open)
		    brackets++;
		*to = *s;
	    }
	}
	/* terminate the copied string and update the sv's end-of-string */
	*to = '\0';
	SvCUR_set(sv, to - SvPVX_const(sv));

	/*
	 * this next chunk reads more into the buffer if we're not done yet
	 */

  	if (s < PL_bufend)
	    break;		/* handle case where we are done yet :-) */

#ifndef PERL_STRICT_CR
	if (to - SvPVX_const(sv) >= 2) {
	    if ((to[-2] == '\r' && to[-1] == '\n') ||
		(to[-2] == '\n' && to[-1] == '\r'))
	    {
		to[-2] = '\n';
		to--;
		SvCUR_set(sv, to - SvPVX_const(sv));
	    }
	    else if (to[-1] == '\r')
		to[-1] = '\n';
	}
	else if (to - SvPVX_const(sv) == 1 && to[-1] == '\r')
	    to[-1] = '\n';
#endif
	
	/* if we're out of file, or a read fails, bail and reset the current
	   line marker so we can report where the unterminated string began
	*/
#ifdef PERL_MAD
	if (PL_madskills) {
	    char * const tstart = SvPVX(PL_linestr) + stuffstart;
	    if (PL_thisstuff)
		sv_catpvn(PL_thisstuff, tstart, PL_bufend - tstart);
	    else
		PL_thisstuff = newSVpvn(tstart, PL_bufend - tstart);
	}
#endif
	if (!PL_rsfp ||
	 !(PL_oldoldbufptr = PL_oldbufptr = s = PL_linestart = filter_gets(PL_linestr, PL_rsfp, 0))) {
	    sv_free(sv);
	    CopLINE_set(PL_curcop, (line_t)PL_multi_start);
	    return NULL;
	}
#ifdef PERL_MAD
	stuffstart = 0;
#endif
	/* we read a line, so increment our line counter */
	CopLINE_inc(PL_curcop);

	/* update debugger info */
	if (PERLDB_LINE && PL_curstash != PL_debstash)
	    update_debugger_info(PL_linestr, NULL, 0);

	/* having changed the buffer, we must update PL_bufend */
	PL_bufend = SvPVX(PL_linestr) + SvCUR(PL_linestr);
	PL_last_lop = PL_last_uni = NULL;
    }

    /* at this point, we have successfully read the delimited string */

#ifdef PERL_MAD
    if (PL_madskills) {
	char * const tstart = SvPVX(PL_linestr) + stuffstart;
	const int len = s - tstart;
	if (PL_thisstuff)
	    sv_catpvn(PL_thisstuff, tstart, len);
	else
	    PL_thisstuff = newSVpvn(tstart, len);
	if (!PL_thisclose && !keep_delims)
	    PL_thisclose = newSVpvn(s,termlen);
    }
#endif

    if (keep_delims)
	sv_catpvn(sv, s, termlen);
    s += termlen;

    PL_multi_end = CopLINE(PL_curcop);

    /* if we allocated too much space, give some back */
    if (SvCUR(sv) + 5 < SvLEN(sv)) {
	SvLEN_set(sv, SvCUR(sv) + 1);
	SvPV_renew(sv, SvLEN(sv));
    }


    /*     assert(str_info->str_sv == NULL); */ /* Might fail if compilation was aborted inside a s///  */
    str_info->str_sv = sv;

    return s;
}

/*
  scan_num
  takes: pointer to position in buffer
  returns: pointer to new position in buffer
  side-effects: builds ops for the constant in pl_yylval.op

  Read a number in any of the formats that Perl accepts:

  \d(_?\d)*(\.(\d(_?\d)*)?)?[Ee][\+\-]?(\d(_?\d)*)	12 12.34 12.
  \.\d(_?\d)*[Ee][\+\-]?(\d(_?\d)*)			.34
  0b[01](_?[01])*
  0[0-7](_?[0-7])*
  0x[0-9A-Fa-f](_?[0-9A-Fa-f])*

  Like most scan_ routines, it uses the PL_tokenbuf buffer to hold the
  thing it reads.

  If it reads a number without a decimal point or an exponent, it will
  try converting the number to an integer and see if it can do so
  without loss of precision.
*/

char *
Perl_scan_num(pTHX_ const char *start, YYSTYPE* lvalp)
{
    dVAR;
    register const char *s = start;	/* current position in buffer */
    register char *d;			/* destination in temp buffer */
    register char *e;			/* end of temp buffer */
    NV nv;				/* number read, as a double */
    SV *sv = NULL;			/* place to put the converted number */
    bool floatit;			/* boolean: int or float? */
    const char *lastub = NULL;		/* position of last underbar */
    static char const number_too_long[] = "Number too long";

    PERL_ARGS_ASSERT_SCAN_NUM;

    /* We use the first character to decide what type of number this is */

    switch (*s) {
    default:
      Perl_croak(aTHX_ "panic: scan_num");

    /* if it starts with a 0, it could be an octal number, a decimal in
       0.13 disguise, or a hexadecimal number, or a binary number. */
    case '0':
	{
	  /* variables:
	     u		holds the "number so far"
	     shift	the power of 2 of the base
			(hex == 4, octal == 3, binary == 1)
	     overflowed	was the number more than we can hold?

	     Shift is used when we add a digit.  It also serves as an "are
	     we in octal/hex/binary?" indicator to disallow hex characters
	     when in octal mode.
	   */
	    NV n = 0.0;
	    UV u = 0;
	    I32 shift;
	    bool overflowed = FALSE;
	    bool just_zero  = TRUE;	/* just plain 0 or binary number? */
	    static const NV nvshift[5] = { 1.0, 2.0, 4.0, 8.0, 16.0 };
	    static const char* const bases[5] =
	      { "", "binary", "", "octal", "hexadecimal" };
	    static const char* const Bases[5] =
	      { "", "Binary", "", "Octal", "Hexadecimal" };
	    static const char* const maxima[5] =
	      { "",
		"0b11111111111111111111111111111111",
		"",
		"037777777777",
		"0xffffffff" };
	    const char *base, *Base, *max;

	    /* check for hex */
	    if (s[1] == 'x') {
		shift = 4;
		s += 2;
		just_zero = FALSE;
	    } else if (s[1] == 'b') {
		shift = 1;
		s += 2;
		just_zero = FALSE;
	    }
	    /* check for a decimal in disguise */
	    else if (s[1] == '.' || s[1] == 'e' || s[1] == 'E')
		goto decimal;
	    /* so it must be octal */
	    else {
		shift = 3;
		s++;
	    }

	    if (*s == '_') {
	       if (ckWARN(WARN_SYNTAX))
		   Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
			       "Misplaced _ in number");
	       lastub = s++;
	    }

	    base = bases[shift];
	    Base = Bases[shift];
	    max  = maxima[shift];

	    /* read the rest of the number */
	    for (;;) {
		/* x is used in the overflow test,
		   b is the digit we're adding on. */
		UV x, b;

		switch (*s) {

		/* if we don't mention it, we're done */
		default:
		    goto out;

		/* _ are ignored -- but warned about if consecutive */
		case '_':
		    if (lastub && s == lastub + 1 && ckWARN(WARN_SYNTAX))
		        Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				    "Misplaced _ in number");
		    lastub = s++;
		    break;

		/* 8 and 9 are not octal */
		case '8': case '9':
		    if (shift == 3)
			yyerror(Perl_form(aTHX_ "Illegal octal digit '%c'", *s));
		    /* FALL THROUGH */

	        /* octal digits */
		case '2': case '3': case '4':
		case '5': case '6': case '7':
		    if (shift == 1)
			yyerror(Perl_form(aTHX_ "Illegal binary digit '%c'", *s));
		    /* FALL THROUGH */

		case '0': case '1':
		    b = *s++ & 15;		/* ASCII digit -> value of digit */
		    goto digit;

	        /* hex digits */
		case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
		case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
		    /* make sure they said 0x */
		    if (shift != 4)
			goto out;
		    b = (*s++ & 7) + 9;

		    /* Prepare to put the digit we have onto the end
		       of the number so far.  We check for overflows.
		    */

		  digit:
		    just_zero = FALSE;
		    if (!overflowed) {
			x = u << shift;	/* make room for the digit */

			if ((x >> shift) != u
			    && !(PL_hints & HINT_NEW_BINARY)) {
			    overflowed = TRUE;
			    n = (NV) u;
			    if (ckWARN_d(WARN_OVERFLOW))
				Perl_warner(aTHX_ packWARN(WARN_OVERFLOW),
					    "Integer overflow in %s number",
					    base);
			} else
			    u = x | b;		/* add the digit to the end */
		    }
		    if (overflowed) {
			n *= nvshift[shift];
			/* If an NV has not enough bits in its
			 * mantissa to represent an UV this summing of
			 * small low-order numbers is a waste of time
			 * (because the NV cannot preserve the
			 * low-order bits anyway): we could just
			 * remember when did we overflow and in the
			 * end just multiply n by the right
			 * amount. */
			n += (NV) b;
		    }
		    break;
		}
	    }

	  /* if we get here, we had success: make a scalar value from
	     the number.
	  */
	  out:

	    /* final misplaced underbar check */
	    if (s[-1] == '_') {
	        if (ckWARN(WARN_SYNTAX))
		    Perl_warner(aTHX_ packWARN(WARN_SYNTAX), "Misplaced _ in number");
	    }

	    sv = newSV(0);
	    if (overflowed) {
		if (n > 4294967295.0 && ckWARN(WARN_PORTABLE))
		    Perl_warner(aTHX_ packWARN(WARN_PORTABLE),
				"%s number > %s non-portable",
				Base, max);
		sv_setnv(sv, n);
	    }
	    else {
#if UVSIZE > 4
		if (u > 0xffffffff && ckWARN(WARN_PORTABLE))
		    Perl_warner(aTHX_ packWARN(WARN_PORTABLE),
				"%s number > %s non-portable",
				Base, max);
#endif
		sv_setuv(sv, u);
	    }
	    if (just_zero && (PL_hints & HINT_NEW_INTEGER))
		sv = new_constant(start, s - start, "integer",
				  sv, NULL, NULL, 0);
	    else if (PL_hints & HINT_NEW_BINARY)
		sv = new_constant(start, s - start, "binary", sv, NULL, NULL, 0);
	}
	break;

    /*
      handle decimal numbers.
      we're also sent here when we read a 0 as the first digit
    */
    case '1': case '2': case '3': case '4': case '5':
    case '6': case '7': case '8': case '9': case '.':
      decimal:
	d = PL_tokenbuf;
	e = PL_tokenbuf + sizeof PL_tokenbuf - 6; /* room for various punctuation */
	floatit = FALSE;

	/* read next group of digits and _ and copy into d */
	while (isDIGIT(*s) || *s == '_') {
	    /* skip underscores, checking for misplaced ones
	       if -w is on
	    */
	    if (*s == '_') {
		if (lastub && s == lastub + 1 && ckWARN(WARN_SYNTAX))
		    Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				"Misplaced _ in number");
		lastub = s++;
	    }
	    else {
	        /* check for end of fixed-length buffer */
		if (d >= e)
		    Perl_croak(aTHX_ number_too_long);
		/* if we're ok, copy the character */
		*d++ = *s++;
	    }
	}

	/* final misplaced underbar check */
	if (lastub && s == lastub + 1) {
	    if (ckWARN(WARN_SYNTAX))
		Perl_warner(aTHX_ packWARN(WARN_SYNTAX), "Misplaced _ in number");
	}

	/* read a decimal portion if there is one.  avoid
	   3..5 being interpreted as the number 3. followed
	   by .5
	*/
	if (*s == '.' && s[1] != '.') {
	    floatit = TRUE;
	    *d++ = *s++;

	    if (*s == '_') {
	        if (ckWARN(WARN_SYNTAX))
		    Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				"Misplaced _ in number");
		lastub = s;
	    }

	    /* copy, ignoring underbars, until we run out of digits.
	    */
	    for (; isDIGIT(*s) || *s == '_'; s++) {
	        /* fixed length buffer check */
		if (d >= e)
		    Perl_croak(aTHX_ number_too_long);
		if (*s == '_') {
		   if (lastub && s == lastub + 1 && ckWARN(WARN_SYNTAX))
		       Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				   "Misplaced _ in number");
		   lastub = s;
		}
		else
		    *d++ = *s;
	    }
	    /* fractional part ending in underbar? */
	    if (s[-1] == '_') {
	        if (ckWARN(WARN_SYNTAX))
		    Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				"Misplaced _ in number");
	    }
	    if (*s == '.' && isDIGIT(s[1])) {
		/* oops, it's really a v-string, but without the "v" */
		Perl_croak(aTHX_ "Too many decimal points in number");
	    }
	}

	/* read exponent part, if present */
	if ((*s == 'e' || *s == 'E') && strchr("+-0123456789_", s[1])) {
	    floatit = TRUE;
	    s++;

	    /* regardless of whether user said 3E5 or 3e5, use lower 'e' */
	    *d++ = 'e';		/* At least some Mach atof()s don't grok 'E' */

	    /* stray preinitial _ */
	    if (*s == '_') {
	        if (ckWARN(WARN_SYNTAX))
		    Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				"Misplaced _ in number");
	        lastub = s++;
	    }

	    /* allow positive or negative exponent */
	    if (*s == '+' || *s == '-')
		*d++ = *s++;

	    /* stray initial _ */
	    if (*s == '_') {
	        if (ckWARN(WARN_SYNTAX))
		    Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				"Misplaced _ in number");
	        lastub = s++;
	    }

	    /* read digits of exponent */
	    while (isDIGIT(*s) || *s == '_') {
	        if (isDIGIT(*s)) {
		    if (d >= e)
		        Perl_croak(aTHX_ number_too_long);
		    *d++ = *s++;
		}
		else {
		   if (((lastub && s == lastub + 1) ||
			(!isDIGIT(s[1]) && s[1] != '_'))
	   	    && ckWARN(WARN_SYNTAX))
		       Perl_warner(aTHX_ packWARN(WARN_SYNTAX),
				   "Misplaced _ in number");
		   lastub = s++;
		}
	    }
	}


	/* make an sv from the string */
	sv = newSV(0);

	/*
           We try to do an integer conversion first if no characters
           indicating "float" have been found.
	 */

	if (!floatit) {
    	    UV uv;
	    const int flags = grok_number (PL_tokenbuf, d - PL_tokenbuf, &uv);

            if (flags == IS_NUMBER_IN_UV) {
              if (uv <= IV_MAX)
		sv_setiv(sv, uv); /* Prefer IVs over UVs. */
              else
	    	sv_setuv(sv, uv);
            } else if (flags == (IS_NUMBER_IN_UV | IS_NUMBER_NEG)) {
              if (uv <= (UV) IV_MIN)
                sv_setiv(sv, -(IV)uv);
              else
	    	floatit = TRUE;
            } else
              floatit = TRUE;
        }
	if (floatit) {
	    /* terminate the string */
	    *d = '\0';
	    nv = Atof(PL_tokenbuf);
	    sv_setnv(sv, nv);
	}

	if ( floatit
	     ? (PL_hints & HINT_NEW_FLOAT) : (PL_hints & HINT_NEW_INTEGER) ) {
	    const char *const key = floatit ? "float" : "integer";
	    const STRLEN keylen = floatit ? 5 : 7;
	    sv = S_new_constant(aTHX_ PL_tokenbuf, d - PL_tokenbuf,
				key, keylen, sv, NULL, NULL, 0);
	}
	break;
    }

    /* make the op for the constant and return */

    if (sv)
	lvalp->opval = newSVOP(OP_CONST, 0, sv);
    else
	lvalp->opval = NULL;

    return (char *)s;
}

I32
Perl_start_subparse(pTHX_ U32 flags)
{
    dVAR;
    const I32 oldsavestack_ix = PL_savestack_ix;
    CV* const outsidecv = PL_compcv;

    if (PL_compcv) {
	assert(SvTYPE(PL_compcv) == SVt_PVCV);
    }
    SAVEI32(PL_subline);
    save_item(PL_subname);
    SAVESPTR(PL_compcv);

    PL_compcv = (CV*)newSV_type(SVt_PVCV);
    CvFLAGS(PL_compcv) |= flags;

    PL_subline = CopLINE(PL_curcop);
    CvPADLIST(PL_compcv) = pad_new(padnew_SAVE|padnew_SAVESUB);
    CvOUTSIDE(PL_compcv) = (CV*)SvREFCNT_inc_simple(outsidecv);
    CvOUTSIDE_SEQ(PL_compcv) = PL_cop_seqmax;

    return oldsavestack_ix;
}

#ifdef __SC__
#pragma segment Perl_yylex
#endif
int
Perl_yywarn(pTHX_ const char *const s)
{
    dVAR;

    PERL_ARGS_ASSERT_YYWARN;

    PL_in_eval |= EVAL_WARNONLY;
    yyerror(s);
    PL_in_eval &= ~EVAL_WARNONLY;
    return 0;
}

int
Perl_yyerror(pTHX_ const char *const s)
{
    dVAR;
    const char *where = NULL;
    const char *context = NULL;
    int contlen = -1;
    SV *msg;
    int yychar  = PL_parser->yychar;

    PERL_ARGS_ASSERT_YYERROR;

    if (!yychar || (yychar == ';' && !PL_rsfp))
	where = "at EOF";
    else if (PL_oldoldbufptr && PL_bufptr > PL_oldoldbufptr &&
      PL_bufptr - PL_oldoldbufptr < 200 && PL_oldoldbufptr != PL_oldbufptr &&
      PL_oldbufptr != PL_bufptr) {
	/*
		Only for NetWare:
		The code below is removed for NetWare because it abends/crashes on NetWare
		when the script has error such as not having the closing quotes like:
		    if ($var eq "value)
		Checking of white spaces is anyway done in NetWare code.
	*/
#ifndef NETWARE
	while (isSPACE(*PL_oldoldbufptr))
	    PL_oldoldbufptr++;
#endif
	context = PL_oldoldbufptr;
	contlen = PL_bufptr - PL_oldoldbufptr;
    }
    else if (PL_oldbufptr && PL_bufptr > PL_oldbufptr &&
      PL_bufptr - PL_oldbufptr < 200 && PL_oldbufptr != PL_bufptr) {
	/*
		Only for NetWare:
		The code below is removed for NetWare because it abends/crashes on NetWare
		when the script has error such as not having the closing quotes like:
		    if ($var eq "value)
		Checking of white spaces is anyway done in NetWare code.
	*/
#ifndef NETWARE
	while (isSPACE(*PL_oldbufptr))
	    PL_oldbufptr++;
#endif
	context = PL_oldbufptr;
	contlen = PL_bufptr - PL_oldbufptr;
    }
    else if (yychar > 255)
	where = "next token ???";
    else if (yychar == -2) { /* YYEMPTY */
	if (PL_lex_state == LEX_NORMAL ||
	   (PL_lex_state == LEX_KNOWNEXT && PL_lex_defer == LEX_NORMAL))
	    where = "at end of line";
	else if (PL_lex_flags & LEXf_INPAT)
	    where = "within pattern";
	else
	    where = "within string";
    }
    else {
	SV * const where_sv = newSVpvs_flags("next char ", SVs_TEMP);
	if (yychar < 32)
	    Perl_sv_catpvf(aTHX_ where_sv, "^%c", toCTRL(yychar));
	else if (isPRINT_LC(yychar)) {
	    const char string = yychar;
	    sv_catpvn(where_sv, &string, 1);
	}
	else
	    Perl_sv_catpvf(aTHX_ where_sv, "\\%03o", yychar & 255);
	where = SvPVX_const(where_sv);
    }
    msg = sv_2mortal(newSVpv(s, 0));
    Perl_sv_catpvf(aTHX_ msg, " at %s line %"IVdf", ",
        OutCopFILE(PL_curcop), (IV)CopLINE(PL_curcop));
    if (context)
	Perl_sv_catpvf(aTHX_ msg, "near \"%.*s\"\n", contlen, context);
    else
	Perl_sv_catpvf(aTHX_ msg, "%s\n", where);
    if (PL_multi_start < PL_multi_end && (U32)(CopLINE(PL_curcop) - PL_multi_end) <= 1) {
        Perl_sv_catpvf(aTHX_ msg,
        "  (Might be a runaway multi-line %c%c string starting on line %"IVdf")\n",
                (int)PL_multi_open,(int)PL_multi_close,(IV)PL_multi_start);
        PL_multi_end = 0;
    }
    if (PL_in_eval & EVAL_WARNONLY) {
	if (ckWARN_d(WARN_SYNTAX))
	    Perl_warner(aTHX_ packWARN(WARN_SYNTAX), "%"SVf, SVfARG(msg));
    }
    else
	qerror(msg);
    if (PL_error_count >= 10) {
	if (PL_in_eval && SvCUR(ERRSV))
	    Perl_croak(aTHX_ "%"SVf"%s has too many errors.\n",
		       SVfARG(ERRSV), OutCopFILE(PL_curcop));
	else
	    Perl_croak(aTHX_ "%s has too many errors.\n",
            OutCopFILE(PL_curcop));
    }
    PL_in_my = 0;
    return 0;
}
#ifdef __SC__
#pragma segment Main
#endif

STATIC char*
S_swallow_bom(pTHX_ char *s)
{
    dVAR;
    U8 *u8s = (U8*)s;
    const STRLEN slen = SvCUR(PL_linestr);
    PERL_ARGS_ASSERT_SWALLOW_BOM;
    switch (u8s[0]) {
    case 0xFF:
	if (u8s[1] == 0xFE) {
	    /* UTF-16 little-endian? (or UTF32-LE?) */
	    if (u8s[2] == 0 && u8s[3] == 0)  /* UTF-32 little-endian */
		Perl_croak(aTHX_ "Unsupported script encoding UTF32-LE");
#ifndef PERL_NO_UTF16_FILTER
	    if (DEBUG_p_TEST || DEBUG_T_TEST) PerlIO_printf(Perl_debug_log, "UTF16-LE script encoding (BOM)\n");
	    u8s += 2;
	utf16le:
	    if (PL_bufend > (char*)u8s) {
		char *news;
		I32 newlen;

		filter_add(utf16rev_textfilter, NULL);
		Newx(news, (PL_bufend - (char*)u8s) * 3 / 2 + 1, char);
		utf16_to_utf8_reversed((char*)u8s, news,
				       PL_bufend - (char*)s - 1,
				       &newlen);
		sv_setpvn(PL_linestr, (const char*)news, newlen);
#ifdef PERL_MAD
		s = SvPVX(PL_linestr);
  		Copy(news, s, newlen, char);
		s[newlen] = '\0';
#endif
		Safefree(news);
		s = SvPVX(PL_linestr);
#ifdef PERL_MAD
		/* FIXME - is this a general bug fix?  */
		s[newlen] = '\0';
#endif
		PL_bufend = SvPVX(PL_linestr) + newlen;
	    }
#else
	    Perl_croak(aTHX_ "Unsupported script encoding UTF16-LE");
#endif
	}
	break;
    case 0xFE:
	if ((U8)s[1] == 0xFF) {   /* UTF-16 big-endian? */
#ifndef PERL_NO_UTF16_FILTER
	    if (DEBUG_p_TEST || DEBUG_T_TEST) PerlIO_printf(Perl_debug_log, "UTF-16BE script encoding (BOM)\n");
	    s += 2;
	utf16be:
	    if (PL_bufend > (char *)s) {
		char *news;
		I32 newlen;

		filter_add(utf16_textfilter, NULL);
		Newx(news, (PL_bufend - (char*)u8s) * 3 / 2 + 1, char);
		utf16_to_utf8((char*)u8s, news,
			      PL_bufend - (char*)u8s,
			      &newlen);
		sv_setpvn(PL_linestr, (const char*)news, newlen);
		Safefree(news);
		u8s = (U8*)SvPVX(PL_linestr);
		PL_bufend = SvPVX(PL_linestr) + newlen;
	    }
#else
	    Perl_croak(aTHX_ "Unsupported script encoding UTF16-BE");
#endif
	}
	break;
    case 0xEF:
	if (slen > 2 && u8s[1] == 0xBB && u8s[2] == 0xBF) {
	    if (DEBUG_p_TEST || DEBUG_T_TEST) PerlIO_printf(Perl_debug_log, "UTF-8 script encoding (BOM)\n");
	    u8s += 3;                      /* UTF-8 */
	}
	break;
    case 0:
	if (slen > 3) {
	     if (u8s[1] == 0) {
		  if (u8s[2] == 0xFE && u8s[3] == 0xFF) {
		       /* UTF-32 big-endian */
		       Perl_croak(aTHX_ "Unsupported script encoding UTF32-BE");
		  }
	     }
	     else if (u8s[2] == 0 && u8s[3] != 0) {
		  /* Leading bytes
		   * 00 xx 00 xx
		   * are a good indicator of UTF-16BE. */
		  if (DEBUG_p_TEST || DEBUG_T_TEST) PerlIO_printf(Perl_debug_log, "UTF-16BE script encoding (no BOM)\n");
		  goto utf16be;
	     }
	}
#ifdef EBCDIC
    case 0xDD:
        if (slen > 3 && u8s[1] == 0x73 && u8s[2] == 0x66 && u8s[3] == 0x73) {
            if (DEBUG_p_TEST || DEBUG_T_TEST) PerlIO_printf(Perl_debug_log, "UTF-8 script encoding (BOM)\n");
            u8s += 4;                      /* UTF-8 */
        }
        break;
#endif

    default:
	 if (slen > 3 && u8s[1] == 0 && u8s[2] != 0 && u8s[3] == 0) {
		  /* Leading bytes
		   * xx 00 xx 00
		   * are a good indicator of UTF-16LE. */
	      if (DEBUG_p_TEST || DEBUG_T_TEST) PerlIO_printf(Perl_debug_log, "UTF-16LE script encoding (no BOM)\n");
	      goto utf16le;
	 }
    }
    return (char*)u8s;
}


#ifndef PERL_NO_UTF16_FILTER
static I32
utf16_textfilter(pTHX_ int idx, SV *sv, int maxlen)
{
    dVAR;
    const STRLEN old = SvCUR(sv);
    const I32 count = FILTER_READ(idx+1, sv, maxlen);
    DEBUG_P(PerlIO_printf(Perl_debug_log,
			  "utf16_textfilter(%p): %d %d (%d)\n",
			  FPTR2DPTR(void *, utf16_textfilter),
			  idx, maxlen, (int) count));
    if (count) {
	char* tmps;
	I32 newlen;
	Newx(tmps, SvCUR(sv) * 3 / 2 + 1, char);
	Copy(SvPVX_const(sv), tmps, old, char);
	utf16_to_utf8(SvPVX_const(sv) + old, tmps + old,
		      SvCUR(sv) - old, &newlen);
	sv_usepvn(sv, (char*)tmps, (STRLEN)newlen + old);
    }
    DEBUG_P({sv_dump(sv);});
    return SvCUR(sv);
}

static I32
utf16rev_textfilter(pTHX_ int idx, SV *sv, int maxlen)
{
    dVAR;
    const STRLEN old = SvCUR(sv);
    const I32 count = FILTER_READ(idx+1, sv, maxlen);
    DEBUG_P(PerlIO_printf(Perl_debug_log,
			  "utf16rev_textfilter(%p): %d %d (%d)\n",
			  FPTR2DPTR(void *, utf16rev_textfilter),
			  idx, maxlen, (int) count));
    if (count) {
	char* tmps;
	I32 newlen;
	Newx(tmps, SvCUR(sv) * 3 / 2 + 1, char);
	Copy(SvPVX_const(sv), tmps, old, char);
	utf16_to_utf8(SvPVX_const(sv) + old, tmps + old,
		      SvCUR(sv) - old, &newlen);
	sv_usepvn(sv, (char*)tmps, (STRLEN)newlen + old);
    }
    DEBUG_P({ sv_dump(sv); });
    return count;
}
#endif

/*
Returns a pointer to the next character after the parsed
vstring, as well as updating the passed in sv.

Function must be called like

	sv = newSV(5);
	s = scan_vstring(s,e,sv);

where s and e are the start and end of the string.
The sv should already be large enough to store the vstring
passed in, for performance reasons.

*/

char *
Perl_scan_vstring(pTHX_ const char *s, const char *const e, SV *sv)
{
    dVAR;
    const char *pos = s;

    PERL_ARGS_ASSERT_SCAN_VSTRING;

    if (*pos == 'v') pos++;  /* get past 'v' */
    while (pos < e && (isDIGIT(*pos) || *pos == '_'))
	pos++;
    if ( *pos != '.') {
	/* this may not be a v-string if followed by => */
	const char *next = pos;
	while (next < e && isSPACE(*next))
	    ++next;
	if ((e - next) >= 2 && *next == '=' && next[1] == '>' ) {
	    /* return string not v-string */
	    sv_setpvn(sv,(char *)s,pos-s);
	    return (char *)pos;
	}
    }

    return (char *)scan_version(s, sv, 1);
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
