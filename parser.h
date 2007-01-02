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
    AV	    *comppad; /* value of PL_comppad when this value was created */
#ifdef DEBUGGING
    const char  *name; /* token/rule name for -Dpv */
#endif
} yy_stack_frame;

typedef struct yy_parser {

    /* parser state */

    struct yy_parser *old_parser; /* previous value of PL_parser */
    int		    yychar;	/* The lookahead symbol.  */
    YYSTYPE	    yylval;	/* value of lookahead symbol, set by yylex() */

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
    U32		lex_defer;	/* state after determined token */
    I32		lex_dojoin;	/* doing an array interpolation */
    int		lex_expect;	/* expect after determined token */
    I32		lex_formbrack;	/* bracket count at outer format level */
    OP		*lex_inpat;	/* in pattern $) and $| are special */
    I32		lex_inwhat;	/* what kind of quoting are we in */
    OP		*lex_op;	/* extra info to pass back on op */
    SV		*lex_repl;	/* runtime replacement from s/// */
    I32		lex_starts;	/* how many interps done on level */
    SV		*lex_stuff;	/* runtime pattern from m// or s/// */
    I32		multi_start;	/* 1st line of multi-line string */
    I32		multi_open;	/* delimiter of said string */
    I32		multi_close;	/* delimiter of said string */
    char	pending_ident;	/* pending identifier lookup */
    bool	preambled;
    SUBLEXINFO	sublex_info;

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
#endif
} yy_parser;
    

