/*    parser.h
 *
 *    Copyright (c) 2006, 2007, Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 * 
 * This file defines the layout of the parser object used by the parser
 * and lexer (perly.c, toke,c).
 */

#define YYEMPTY		(-2)

typedef struct {
    YYSTYPE val;    /* semantic value */
    short   state;
    I32     savestack_ix;	/* size of savestack at this state */
    AV	    *comppad; /* value of PL_comppad when this value was created */
#ifdef DEBUGGING
    const char  *name; /* token/rule name for -Dpv */
#endif
} yy_stack_frame;

#define LEXf_INPAT   0x01 /* pattern */
#define LEXf_SINGLEQ 0x02 /* single quoted, both q*...* or qr'..' */
#define LEXf_EXT_PAT 0x04 /* in an extended pattern */
#define LEXf_ATTRS 0x08 /* in attributes */
#define LEXf_DOUBLEQ 0x10 /* single quoted, both q*...* or qr'..' */
#define LEXf_BACKTICK 0x20 /* single quoted, both q*...* or qr'..' */
#define LEXf_QW 0x40 /* single quoted, both q*...* or qr'..' */
#define LEXf_PROTOTYPE 0x80 /* single quoted, both q*...* or qr'..' */
#define LEXf_REPL 0x100 /* single quoted, both q*...* or qr'..' */
#define LEXf_HEREDOC 0x200 /* single quoted, both q*...* or qr'..' */

typedef struct yy_str_info {
    SV *str_sv; /* SV holding the string */
    U16 flags;	/* flags for the lexer */
} yy_str_info;

typedef struct yy_parser {

    /* parser state */

    struct yy_parser *old_parser; /* previous value of PL_parser */
    YYSTYPE	    yylval;	/* value of lookahead symbol, set by yylex() */
    int		    yychar;	/* The lookahead symbol.  */

    /* Number of tokens to shift before error messages enabled.  */
    int		    yyerrstatus;

    int		    stack_size;
    int		    yylen;	/* length of active reduction */
    yy_stack_frame  *stack;	/* base of stack */
    yy_stack_frame  *ps;	/* current stack frame */

    /* lexer state */

    I32		lex_brackets;	/* bracket count */
    I32		lex_casemods;	/* casemod count */
    char	*lex_brackstack;/* what kind of brackets to pop */
    char	*lex_casestack;	/* what kind of case mods in effect */
    U8		lex_defer;	/* state after determined token */
    bool	lex_dojoin;	/* doing an array interpolation */
    U8		lex_expect;	/* expect after determined token */
    U8		expect;		/* how to interpret ambiguous tokens */
    U8 lex_flags;	/* flags for the lexer */
    OP		*lex_op;	/* extra info to pass back on op */
    U16		lex_inwhat;	/* what kind of quoting are we in */
    OPCODE	last_lop_op;	/* last list operator */
    I32		lex_starts;	/* how many interps done on level */

    yy_str_info lex_stuff; 	/* runtime pattern from m// or s/// */
    yy_str_info lex_repl; 	/* runtime pattern from m// or s/// */

    I32		multi_start;	/* 1st line of multi-line string */
    I32		multi_end;	/* last line of multi-line string */
    char	multi_open;	/* delimiter of said string */
    char	multi_close;	/* delimiter of said string */
    char	pending_ident;	/* pending identifier lookup */
    bool	preambled;
    /* XXX I32 space */
    SUBLEXINFO	sublex_info;
    SV		*linestr;	/* current chunk of src text */
    char	*bufptr;	
    char	*oldbufptr;	
    char	*oldoldbufptr;	
    char	*bufend;	
    char	*linestart;	/* beginning of most recently read line */
    char	*last_uni;	/* position of last named-unary op */
    char	*last_lop;	/* position of last list operator */
    line_t	copline;	/* current line number */
    U16		in_my;		/* we're compiling a "my"/"our" declaration */
    U8		lex_state;	/* next token is determined */
    U8		error_count;	/* how many compile errors so far, max 10 */
    PerlIO	*rsfp;		/* current source file pointer */
    AV		*rsfp_filters;	/* holds chain of active source filters */

#ifdef PERL_MAD
    SV		*endwhite;
    I32		faketokens;
    I32		lasttoke;
    SV		*nextwhite;
    I32		realtokenstart;
    SV		*skipwhite;
    SV		*thisclose;
    MADPROP *	thismad;
    SV		*thisopen;
    SV		*thisstuff;
    SV		*thistoken;
    SV		*thiswhite;

/* What we know when we're in LEX_KNOWNEXT state. */
    NEXTMADTOKE	nexttoke[6];	/* value of next token, if any */
    I32		curforce;
#else
    YYSTYPE	nextval[6];	/* value of next token, if any */
    I32		nexttype[6];	/* type of next token */
    I32		nexttoke;
#endif

    COP		*saved_curcop;	/* the previous PL_curcop */
    char	tokenbuf[256];

} yy_parser;


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

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
