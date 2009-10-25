 /*    perly.y
 *
 *    Copyright (c) 1991-2002, 2003, 2004, 2005, 2006 Larry Wall
 *    Copyright (c) 2007, 2008 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
 * 'I see,' laughed Strider.  'I look foul and feel fair.  Is that it?
 *  All that is gold does not glitter, not all those who wander are lost.'
 *
 *     [p.171 of _The Lord of the Rings_, I/x: "Strider"]
 */

/*
 * This file holds the grammar for the Perl language. If edited, you need
 * to run regen_perly.pl, which re-creates the files perly.h, perly.tab
 * and perly.act which are derived from this.
 *
 * Note that these derived files are included and compiled twice; once
 * from perly.c, and once from madly.c. The second time, a number of MAD
 * macros are defined, which compile in extra code that allows the parse
 * tree to be accurately dumped. In particular:
 *
 * MAD            defined if compiling madly.c
 * DO_MAD(A)      expands to A  under madly.c, to null otherwise
 * IF_MAD(a,b)    expands to A under madly.c, to B otherwise
 * TOKEN_GETMAD() expands to token_getmad() under madly.c, to null otherwise
 * TOKEN_FREE()   similarly
 * OP_GETMAD()    similarly
 * IVAL(i)        expands to (i)->tk_lval.ival or (i)
 * PVAL(p)        expands to (p)->tk_lval.pval or (p)
 *
 * The main job of of this grammar is to call the various newFOO()
 * functions in op.c to build a syntax tree of OP structs.
 * It relies on the lexer in toke.c to do the tokenizing.
 *
 * Note: due to the way that the cleanup code works WRT to freeing ops on
 * the parse stack, it is dangerous to assign to the $n variables within
 * an action.
 */

/*  Make the parser re-entrant. */

%pure_parser

/* FIXME for MAD - is the new mintro on while and until important?  */

%start prog

%union {
    I32 ionlyval;
    char *pval; /* __DEFAULT__ (marker for regen_perly.pl;
				must always be 1st union member) */
    OP *opval;
    GV *gvval;
    struct {
        I32 ival;
        SV *location;
#ifdef PERL_MAD
        MADTOKEN* madtoken;
#endif
    } i_tkval;
    struct {
        char *pval;
        SV *location;
#ifdef PERL_MAD
        MADTOKEN* madtoken;
#endif
    } p_tkval;
}

%token <i_tkval> '{' '}' '[' ']' '-' '+' '$' '@' '%' '*' '&' ';'

%token <opval> WORD METHOD THING PMFUNC
%token <i_tkval> PRIVATEVAR
%token <opval> FUNC0SUB UNIOPSUB COMPSUB
%token <p_tkval> LABEL
%token <i_tkval> SUB ANONSUB BLOCKSUB PACKAGE USE
%token <i_tkval> WHILE UNTIL IF UNLESS ELSE ELSIF CONTINUE FOR
%token <i_tkval> LOOPEX DOTDOT
%token <i_tkval> FUNC0 FUNC1 FUNC UNIOP LSTOP
%token <i_tkval> RELOP EQOP MULOP ADDOP
%token <i_tkval> DO LOOPDO NOAMP NOAMPCALL
%token <i_tkval> ANONSCALAR
%token <i_tkval> LOCAL MY MYSUB REQUIRE
%token <i_tkval> COLONATTR
%token <i_tkval> SPECIALBLOCK
%token <i_tkval> LAYOUTLISTEND
%token <i_tkval> EMPTYAH

%type <i_tkval> optional_semicolon

%type <ionlyval> prog progstart remember mremember
%type <ionlyval> startsub startanonsub startblocksub
%type <ionlyval> mintro
%type <i_tkval> startproto endproto
%type <opval> optassign protoargs

%type <opval> decl subrout mysubrout package use peg

%type <opval> mydef

%type <opval> block dblock mblock lineseq line loop cond else
%type <opval> expr term subscripted scalar star sideff
%type <opval> assignexpr
%type <opval> argexpr texpr iexpr mexpr miexpr
%type <opval> listexpr listexprcom indirob listop method layoutlistexpr
%type <opval> subname protoassign proto subbody cont my_scalar
%type <opval> myattrterm myterm
%type <opval> termbinop termunop anonymous termdo
%type <p_tkval> label

%nonassoc <i_tkval> PREC_LOW
%nonassoc LOOPEX

%right <i_tkval> RETURNTOKEN
%left <i_tkval> OROP DOROP
%left <i_tkval> ANDOP
%right <i_tkval> NOTOP
%nonassoc LSTOP
%left <i_tkval> ','
%right <i_tkval> ASSIGNOP
%right <i_tkval> TERNARY_IF TERNARY_ELSE
%right <i_tkval> '<' ARRAYEXPAND HASHEXPAND
%right <i_tkval> ANONHSHL ANONARYL ANONSCALARL
%left <i_tkval> AHOP
%nonassoc DOTDOT
%left <i_tkval> OROR DORDOR
%left <i_tkval> ANDAND
%left <i_tkval> BITOROP
%left <i_tkval> BITANDOP
%nonassoc EQOP
%nonassoc RELOP
%nonassoc UNIOP UNIOPSUB
%nonassoc REQUIRE
%nonassoc COMPSUB
%left <i_tkval> SHIFTOP
%left ADDOP
%left MULOP
%left <i_tkval> MATCHOP
%right <i_tkval> '!' '~' UMINUS SREFGEN '?'
%right <i_tkval> POWOP
%nonassoc <i_tkval> CALLOP
%nonassoc <i_tkval> PREINC PREDEC POSTINC POSTDEC
%left <i_tkval> ARROW DEREFSCL DEREFARY DEREFHSH DEREFSTAR DEREFAMP HSLICE ASLICE
%nonassoc <i_tkval> ')'
%left <i_tkval> '(' ':'
%left '[' '{' ANONSCALAR

%token <i_tkval> PEG

%% /* RULES */

/* The whole program */
prog	:	progstart
	/*CONTINUED*/	lineseq
			{ 
                            $$ = $1; newPROG(block_end($1,$2)); 
                        }
	;

/* An ordinary block */
block	:
	'{' remember lineseq '}'
			{
                            $$ = block_end($2, $3);
                            TOKEN_GETMAD($1,$$,'{');
                            TOKEN_GETMAD($4,$$,'}');
			}
	;

/* A block which must be a block */
dblock	:
                        {
                            PL_parser->expect = XBLOCK;
                        }
	'{' 
                        {
                            PL_parser->expect = XSTATE;
                        }
            remember lineseq '}'
			{
                            $$ = block_end($4, $5);
                            TOKEN_GETMAD($2,$$,'{');
                            TOKEN_GETMAD($6,$$,'}');
			}
	;

remember:	/* NULL */	/* start a full lexical scope */
			{ $$ = block_start(TRUE); }
	;

progstart:
		{
		    PL_parser->expect = XSTATE; $$ = block_start(TRUE);
		}
	;


mblock	:	
                        {
                            PL_parser->expect = XBLOCK;
                        }
               '{' mremember lineseq '}'
			{
                            $$ = block_end($3, $4);
                            TOKEN_GETMAD($2,$$,'{');
                            TOKEN_GETMAD($5,$$,'}');
			}
	;

mremember:	/* NULL */	/* start a partial lexical scope */
			{ $$ = block_start(FALSE); }
	;

/* A collection of "lines" in the program */
lineseq	:	/* NULL */
			{ $$ = (OP*)NULL; }
	|	lineseq decl
			{
			$$ = IF_MAD(
				append_list(OP_LINESEQ,
			    	    (LISTOP*)$1, (LISTOP*)$2),
				$1);
			}
	|	lineseq line
			{   $$ = append_list(OP_LINESEQ,
				(LISTOP*)$1, (LISTOP*)$2);
			    PL_pad_reset_pending = TRUE;
			    if ($1 && $2)
				PL_hints |= HINT_BLOCK_SCOPE;
			}
	;

/* A "line" in the program */
line	:	cond
                        {
                            $$ = newSTATEOP(0, NULL, $1, $1->op_location);
                        }
	|	loop	/* loops add their own labels */
			{ $$ = $1; }
        |       ';'
                        {
                            $$ = IF_MAD( newOP(OP_NULL, 0, LOCATION($1)),
                                    (OP*)NULL);
                            TOKEN_GETMAD($1,$$,';');
                            APPEND_MADPROPS_PV("nullstatement",$$,'>');
                            PL_parser->expect = XSTATE;
                        }
	|	sideff ';'
			{
                            SV* loc = $1 ? $1->op_location : LOCATION($2);
                            $$ = newSTATEOP(0, NULL, $1, loc);
                            PL_parser->expect = XSTATE;
                            TOKEN_GETMAD($2,$$,';');
                        }
	;

/* An expression which may have a side-effect */
sideff	:	error
			{ $$ = (OP*)NULL; }
	|	expr
			{ $$ = $1; }
	|	expr IF expr
			{
                            $$ = newLOGOP(OP_AND, 0, $3, $1, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'i');
                            APPEND_MADPROPS_PV("modif", $$, '>');
			}
	|	expr UNLESS expr
			{ 
                            $$ = newLOGOP(OP_OR, 0, $3, $1, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'i');
                            APPEND_MADPROPS_PV("modif", $$, '>');
			}
	|	expr WHILE expr
                        {
                            $$ = newLOOPOP(OPf_PARENS, 1, scalar($3), $1, FALSE, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'w');
			}
	|	LOOPDO block optional_semicolon WHILE expr
                        {
                            TOKEN_GETMAD($3,$2,'x');
                            $$ = newLOOPOP(OPf_PARENS, 1, scalar($5), $2, TRUE, LOCATION($4));
                            TOKEN_GETMAD($4,$$,'w');
                            TOKEN_GETMAD($1,$$,'W');
			}
	|	expr UNTIL iexpr
			{ 
                            $$ = newLOOPOP(OPf_PARENS, 1, $3, $1, FALSE, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'w');
			}
	|	LOOPDO block optional_semicolon UNTIL iexpr
                        {
                            TOKEN_GETMAD($3,$2,'x');
                            $$ = newLOOPOP(OPf_PARENS, 1, $5, $2, TRUE, LOCATION($4));
                            TOKEN_GETMAD($4,$$,'w');
                            TOKEN_GETMAD($1,$$,'W');
			}
	;

optional_semicolon
        :       /* NULL */
                        {
                            $$.ival = 0;
#ifdef PERL_MAD
                            $$.madtoken = newMADTOKEN(0, NULL);
#endif
                        }
        |       ';'
                        {
                            PL_parser->expect = XSTATE;
                            $$ = $1;
                        }
        ;

/* else and elsif blocks */
else	:	/* NULL */
			{ $$ = (OP*)NULL; }
	|	ELSE mblock
			{ ($2)->op_flags |= OPf_PARENS; $$ = scope($2);
			  TOKEN_GETMAD($1,$$,'I');
			}
	|	ELSIF '(' mexpr ')' mblock optional_semicolon else
			{ 
                            TOKEN_GETMAD($6,$5,'x');
			    $$ = newCONDOP(0, $3, scope($5), $7, LOCATION($1));
			    PL_hints |= HINT_BLOCK_SCOPE;
                            TOKEN_GETMAD($1,$$,'I');
                            TOKEN_GETMAD($2,$$,'(');
                            TOKEN_GETMAD($4,$$,')');
                            APPEND_MADPROPS_PV("if", $$, '>');
			}
	;

/* Real conditional expressions */
cond	:	IF '(' remember mexpr ')' mblock optional_semicolon else
			{
                            TOKEN_GETMAD($7,$6,'x');
			    $$ = block_end($3,
                                newCONDOP(0, $4, scope($6), $8, LOCATION($1)));
                            TOKEN_GETMAD($1,$$,'I');
                            TOKEN_GETMAD($2,$$,'(');
                            TOKEN_GETMAD($5,$$,')');
                            APPEND_MADPROPS_PV("if", $$, '>');
			}
	|	UNLESS '(' remember miexpr ')' mblock optional_semicolon else
			{
                            TOKEN_GETMAD($7,$6,'x');
			    $$ = block_end($3,
                                newCONDOP(0, $4, scope($6), $8, LOCATION($1)));
                            TOKEN_GETMAD($1,$$,'I');
                            TOKEN_GETMAD($2,$$,'(');
                            TOKEN_GETMAD($5,$$,')');
                            APPEND_MADPROPS_PV("if", $$, '>');
			}
	;

/* Continue blocks */
cont	:	/* NULL */
			{
                            $$ = (OP*)NULL;
#ifdef PERL_MAD
                            if (PL_madskills) {
                                /* FIXME produces different results in "do" blocks */
                                $$ = newOP(OP_NULL,0, NULL);
                                APPEND_MADPROPS_PV("value", $$, '>');
                            }
#endif /* PERL_MAD */
                        }
        |       CONTINUE dblock
                        { $$ = scope($2);
                            TOKEN_GETMAD($1,$$,'o');
                        }
	;

/* Loops: while, until, for, and a bare block */
loop	:	label WHILE remember '(' texpr ')'
			{
                            /* insert "defined $_ = " before "~< $fh" */
                            if ($5->op_type == OP_READLINE) {
                                OP* mydef;
                                mydef = newOP(OP_PADSV, 0, NULL);
                                mydef->op_targ = allocmy("$_");
                                $<opval>$ = newUNOP(OP_DEFINED, 0,
                                    newASSIGNOP(0, mydef,
                                        0, $5, $5->op_location), $5->op_location );
                            }
                            else {
                                $<opval>$ = $5;
                            }
                        }
                    mintro mblock optional_semicolon cont
			{
                            OP *innerop;
                            TOKEN_GETMAD($10,$9,'x');
			    $$ = block_end($3,
                                newSTATEOP(0, PVAL($1),
                                    innerop = newWHILEOP(0, 1, (LOOP*)(OP*)NULL,
                                        LOCATION($2), $<opval>7, $9, $11, $8), LOCATION($2)));
                            TOKEN_GETMAD($1,innerop,'L');
                            TOKEN_GETMAD($2,innerop,'W');
                            TOKEN_GETMAD($4,innerop,'(');
                            TOKEN_GETMAD($6,innerop,')');
			}

	|	label UNTIL '(' remember iexpr ')' mintro mblock optional_semicolon cont
			{ 
                            OP *innerop;
                            TOKEN_GETMAD($9,$8,'x');
			    $$ = block_end($4,
				   newSTATEOP(0, PVAL($1),
				     innerop = newWHILEOP(0, 1, (LOOP*)(OP*)NULL,
                                         LOCATION($2), $5, $8, $10, $7), LOCATION($2)));
                            TOKEN_GETMAD($1,innerop,'L');
                            TOKEN_GETMAD($2,innerop,'W');
                            TOKEN_GETMAD($3,innerop,'(');
                            TOKEN_GETMAD($6,innerop,')');
			}
	|	label FOR MY remember my_scalar '(' mexpr ')' mblock optional_semicolon cont
			{ OP *innerop;
                          TOKEN_GETMAD($10,$9,'x');
			  $$ = block_end($4,
                              innerop = newFOROP(0, PVAL($1),
                                  $5, scalar($7), $9, $11, LOCATION($2)));
			  TOKEN_GETMAD($1,((LISTOP*)innerop)->op_first->op_sibling,'L');
			  TOKEN_GETMAD($2,((LISTOP*)innerop)->op_first->op_sibling,'W');
			  TOKEN_GETMAD($3,((LISTOP*)innerop)->op_first->op_sibling,'d');
			  TOKEN_GETMAD($6,((LISTOP*)innerop)->op_first->op_sibling,'(');
			  TOKEN_GETMAD($8,((LISTOP*)innerop)->op_first->op_sibling,')');
			}
	|	label FOR remember mydef '(' mexpr ')' mblock optional_semicolon cont
			{ OP *innerop;
                          TOKEN_GETMAD($9,$8,'x');
			  $$ = block_end($3,
			     innerop = newFOROP(0, PVAL($1),
                                 $4, scalar($6), $8, $10, LOCATION($2)));
			  TOKEN_GETMAD($1,((LISTOP*)innerop)->op_first->op_sibling,'L');
			  TOKEN_GETMAD($2,((LISTOP*)innerop)->op_first->op_sibling,'W');
			  TOKEN_GETMAD($5,((LISTOP*)innerop)->op_first->op_sibling,'(');
			  TOKEN_GETMAD($7,((LISTOP*)innerop)->op_first->op_sibling,')');
			}
	;

/* determine whether there are any new my declarations */
mintro	:	/* NULL */
			{ $$ = (PL_min_intro_pending != -1 &&
			    PL_max_intro_pending >=  PL_min_intro_pending);
			  intro_my(); }

/* Boolean expression */
texpr	:	/* NULL means true */
			{ YYSTYPE tmplval;
			  (void)scan_num("1", &tmplval);
			  $$ = tmplval.opval; }
	|	expr
			{ $$ = $1; }
	;

/* Inverted boolean expression */
iexpr	:	expr
			{ $$ = invert(scalar($1)); }
	;

/* Expression with its own lexical scope */
mexpr	:	expr
			{ $$ = $1; intro_my(); }
	;

miexpr	:	iexpr
			{ $$ = $1; intro_my(); }
	;


/* Optional "MAIN:"-style loop labels */
label	:	/* empty */
			{
			  $$.pval = NULL;
#ifdef PERL_MAD
			  $$.madtoken = newMADTOKEN(OP_NULL, 0);
#endif
			  $$.pval = NULL;
			  $$.location = NULL;
			}
	|	LABEL
			{ $$ = $1; }
	;

/* Some kind of declaration - just hang on peg in the parse tree */
decl	:	subrout
			{ $$ = $1; }
	|	mysubrout
			{ $$ = $1; }
	|	package
			{ $$ = $1; }
	|	use
			{ $$ = $1; }

    /* these two are only used by MAD */

	|	peg
			{ $$ = $1; }
	;

peg	:	PEG
                        {
                            $$ = newOP(OP_NULL,0, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'p');
                            APPEND_MADPROPS_PV("peg",$$,'>');
			}
	;

/* Unimplemented "my sub foo { }" */
mysubrout:	MYSUB startsub subname proto subbody
			{ 
#ifdef MAD
			  $$ = newMYSUB($2, $3, $4, NULL, $5);
			  TOKEN_GETMAD($1,$$,'d');
#else
			  newMYSUB($2, $3, $4, NULL, $5);
			  $$ = (OP*)NULL;
#endif
			}
	;

/* Subroutine definition */
subrout	:	SUB startsub subname proto subbody
			{
#ifdef MAD
                            CV* new;
                            $$ = newOP(OP_NULL,0, LOCATION($1));
                            op_getmad($3,$$,'n');
                            TOKEN_GETMAD($1,$$,'d');
                            APPEND_MADPROPS_PV("sub", $$, '<');
                            new = newNAMEDSUB($2, $3, $4, $5);
                            op_getmad(CvROOT(new),$$,'&');
                            /* SvREFCNT_dec(new);  leak reference */
#else
                            CV* new = newNAMEDSUB($2, $3, $4, $5);
                            CvREFCNT_dec(new);
                            $$ = (OP*)NULL;
#endif
			}
        |       SPECIALBLOCK startsub subbody
                        {
#ifdef MAD
                            CV* new;
                            $$ = newOP(OP_NULL,0, LOCATION($1));
                            op_getmad($3,$$,'&');
                            TOKEN_GETMAD($1,$$,'d');
                            APPEND_MADPROPS_PV("sub", $$, '<');
                            new = newSUB($2, NULL, $3);
                            SVcpREPLACE(SvLOCATION(cvTsv(new)), LOCATION($1));
                            process_special_block(IVAL($1), new);
                            /* SvREFCNT_dec(new);  leak reference */
#else
                            CV* new = cv_2mortal(newSUB($2,
                                    newOP(OP_STUB, 0, LOCATION($1)), $3));
                            $<opval>2 = NULL;
                            $<opval>3 = NULL;
                            SVcpREPLACE(SvLOCATION(cvTsv(new)), LOCATION($1));
                            process_special_block(IVAL($1), new);
                            $$ = (OP*)NULL;
#endif
                        }
	;

startsub:	/* NULL */	/* start a regular subroutine scope */
			{ $$ = start_subparse(0); 
                        }

	;

startanonsub:	/* NULL */	/* start an anonymous subroutine scope */
			{ $$ = start_subparse(CVf_ANON);
			}
	;

startblocksub:	/* NULL */	/* start an anonymous subroutine scope */
			{ $$ = start_subparse(CVf_ANON|CVf_BLOCK);
			}
	;

/* Name of a subroutine - must be a bareword, could be special */
subname	:	WORD	{
			  $$ = $1;
                        }
	;

startproto :    '('
			{ 
                            CvFLAGS(PL_compcv) |= CVf_PROTO;
                            PL_parser->in_my = KEY_my;
                            $$ = $1;
                        }
	;

endproto :    ')'
			{ 
                            $$ = $1;
                            PL_parser->in_my = FALSE;
                            PL_parser->expect = XBLOCK;
                        }
	;

protoassign :   /* NULL */
			{ 
                            $$ = NULL;
                        }
        |      ASSIGNOP term 
			{ 
                            CvFLAGS(PL_compcv) |= CVf_ASSIGNARG;
                            $$ = $2;
                            TOKEN_GETMAD($1,$$,'o');
                        }
	;

optassign : '?' ASSIGNOP
			{ 
                            CvFLAGS(PL_compcv) |= CVf_OPTASSIGNARG;
                            $$ = newOP(OP_PADSV, 0, LOCATION($1));
                            $$->op_targ = allocmy("$^is_assignment");
                            TOKEN_GETMAD($1,$$,'H');
                            TOKEN_GETMAD($2,$$,'o');
                        }
        ;

protoargs :     protoassign
			{ 
                            $$ = append_elem(OP_LIST, $1, NULL);
                        }
        |       argexpr protoassign
			{ 
                            $$ = prepend_elem(OP_LIST, $2, $1);
                        }
        |       optassign term
			{ 
                            $$ = append_elem(OP_LIST, $2, $1);
                        }
        |       argexpr optassign term
			{ 
                            $$ = prepend_elem(OP_LIST, $2, $1);
                            $$ = prepend_elem(OP_LIST, $3, $$);
                        }
        ;

/* Subroutine prototype */
proto	:	/* NULL */
			{
                            pad_add_name("@_", NULL, FALSE);
                            CvFLAGS(PL_compcv) |= CVf_DEFARGS;
                            intro_my();
                            $$ = (OP*)NULL; 
                        }
	|	startproto protoargs mintro endproto
			{ 
                            $$ = $2;
                            if (! $$)
                                $$ = newOP(OP_STUB, 0, LOCATION($1) );

                            TOKEN_GETMAD($1,$$,'(');
                            TOKEN_GETMAD($4,$$,')');
                        }
	;

/* Subroutine body - a block */
subbody	:	dblock	{ $$ = $1; }
	;

package :	PACKAGE WORD ';'
			{
#ifdef MAD
			  $$ = package($2);
			  TOKEN_GETMAD($1,$$,'o');
			  TOKEN_GETMAD($3,$$,';');
                          APPEND_MADPROPS_PV("package",$$,'>');
#else
			  package($2);
			  $$ = (OP*)NULL;
#endif
			}
	;

use	:	USE startsub THING WORD listexpr ';'
			{ 
                            CV* cv;
#ifdef PERL_MAD
                            $$ = utilize(IVAL($1), $2, $3, $4, $5);
                            TOKEN_GETMAD($1,$$,'o');
                            TOKEN_GETMAD($6,$$,';');
                            cv = svTcv(cSVOPx($$)->op_sv);
#else
                            cv = utilize(IVAL($1), $2, $3, $4, $5);
                            $$ = (OP*)NULL;
#endif
                            $<opval>3 = NULL;
                            $<opval>4 = NULL;
                            $<opval>5 = NULL;
                            process_special_block(KEY_BEGIN, cv);
			}
	;

/* Ordinary expressions; logical combinations */
expr	:	expr ANDOP expr
			{
                            $$ = newLOGOP(OP_AND, 0, $1, $3, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'o');
                            APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	expr OROP expr
			{ $$ = newLOGOP(IVAL($2), 0, $1, $3, LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	expr DOROP expr
			{ $$ = newLOGOP(OP_DOR, 0, $1, $3, LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	assignexpr %prec PREC_LOW
			{ $$ = $1; }
	;

assignexpr	:       argexpr ASSIGNOP assignexpr
                        { 
                            $$ = newASSIGNOP(OPf_STACKED, $1, IVAL($2), $3, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'o');
                            APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	argexpr %prec PREC_LOW
			{ $$ = $1; }
	;

/* Expressions are a list of terms joined by commas */
argexpr	:       argexpr ','
			{
#ifdef MAD
			  OP* op = newNULLLIST(NULL);
			  TOKEN_GETMAD($2,op,',');
			  $$ = append_elem(OP_LIST, $1, op);
                          APPEND_MADPROPS_PV(",", op, '>');
#else
			  $$ = $1;
#endif
			}
	|	argexpr ',' term
			{ 
			  OP* term = $3;
			  DO_MAD(
			      term = newUNOP(OP_NULL, 0, term, LOCATION($2));
			      TOKEN_GETMAD($2,term,',');
                              APPEND_MADPROPS_PV(",", term, '>');
			  )
			  $$ = append_elem(OP_LIST, $1, term);
			}
	|	term %prec PREC_LOW
			{ $$ = $1; }
	;

/* List operators */
listop	:	term ARROW method ':' layoutlistexpr /* $foo->bar(list) */
			{ $$ = convert(OP_ENTERSUB, OPf_STACKED,
				append_elem(OP_LIST,
				    prepend_elem(OP_LIST, scalar($1), $5),
				    newUNOP(OP_METHOD, 0, $3, $3->op_location)),
                                $3->op_location);
			  TOKEN_GETMAD($2,$$,'A');
			  TOKEN_GETMAD($4,$$,'(');
                          APPEND_MADPROPS_PV("method", $$, '>');
			}
	|	term ARROW method                     /* $foo->bar */
			{ $$ = convert(OP_ENTERSUB, OPf_STACKED,
				append_elem(OP_LIST, scalar($1),
				    newUNOP(OP_METHOD, 0, $3, $3->op_location)), $3->op_location);
			  TOKEN_GETMAD($2,$$,'A');
                          APPEND_MADPROPS_PV("method", $$, '>');
			}
	|	LSTOP ':' layoutlistexpr                       /* print @args */
                        {
                            $$ = convert(IVAL($1), 0, $3, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'o');
                            APPEND_MADPROPS_PV("listop", $$, '>');
			}
        |       ANONSCALARL listexpr  /* $: ... */
                        {
                            $$ = newUNOP(OP_ANONSCALAR, 0, scalar($2), LOCATION($1));
                            TOKEN_GETMAD($1,$$,'[');
			}
	|	FUNC '(' listexprcom ')'             /* print (@args) */
                        { 
                            $$ = convert(IVAL($1), 0, $3, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'o');
                            TOKEN_GETMAD($2,$$,'(');
                            TOKEN_GETMAD($4,$$,')');
                            APPEND_MADPROPS_PV("func", $$, '>');
			}
	;

/* Names of methods. May use $object->$methodname */
method :       METHOD
			{ $$ = $1; }
       |       scalar
			{ $$ = $1; }
       ;

/* Some kind of subscripted expression */
subscripted:    star '{' expr ';' '}'       /* *main::{something} like *STDOUT{IO} */
                        /* In this and all the hash accessors, ';' is
                         * provided by the tokeniser */
			{
                            $$ = newBINOP(OP_GELEM, 0, $1, scalar($3), $1->op_location);
			    PL_parser->expect = XOPERATOR;
			  TOKEN_GETMAD($2,$$,'{');
			  TOKEN_GETMAD($4,$$,';');
			  TOKEN_GETMAD($5,$$,'}');
			}
        |       term DEREFARY                /* somearef->@ */
                        {
                            $$ = newAVREF($1, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'a');
                        }
        |       term DEREFSCL                /* somearef->$ */
                        {
                            $$ = newSVREF($1, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'a');
                        }
        |       term DEREFHSH                /* somearef->% */
                        {
                            $$ = newHVREF($1, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'a');
                        }
        |       term DEREFAMP                /* somearef->& */
                        {
                            $$ = newCVREF(0, $1, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'a');
                        }
	|	term '[' expr ']'          /* $array[$element] */
                        { 
                            $$ = newBINOP(OP_AELEM, 0, scalar($1), scalar($3), LOCATION($2));
                            $$->op_private = IVAL($2);
                            TOKEN_GETMAD($2,$$,'[');
                            TOKEN_GETMAD($4,$$,']');
			}
	|	term ARROW '[' expr ']'      /* somearef->[$element] */
			{
                            $$ = newBINOP(OP_AELEM, 0,
                                ref(newAVREF($1, LOCATION($2)),OP_RV2AV),
                                scalar($4), LOCATION($3));
                            $$->op_private = IVAL($3);
                            TOKEN_GETMAD($2,$$,'a');
                            TOKEN_GETMAD($3,$$,'[');
                            TOKEN_GETMAD($5,$$,']');
			}
	|	term ARROW HSLICE expr ']'   /* someref->{[bar();]} */
			{ 
                            $$ = newLISTOP(OP_HSLICE, 0,
                                scalar($4),
                                ref(newHVREF($1, LOCATION($2)), OP_HSLICE), LOCATION($3));
                            $$->op_private = IVAL($3);
			    PL_parser->expect = XOPERATOR;
			  TOKEN_GETMAD($2,$$,'a');
			  TOKEN_GETMAD($3,$$,'{');
			  TOKEN_GETMAD($5,$$,'}');
			}
	|	term ARROW ASLICE expr ']'                     /* someref->[[...]] */
			{ $$ = newLISTOP(OP_ASLICE, 0,
					scalar($4),
					ref(newAVREF($1, LOCATION($2)), OP_ASLICE), LOCATION($3));
			  TOKEN_GETMAD($2,$$,'a');
			  TOKEN_GETMAD($3,$$,'[');
			  TOKEN_GETMAD($5,$$,']');
			}
	|	term HSLICE expr ']'    /* %foo{[bar();]} */
			{ $$ = newLISTOP(OP_HSLICE, 0,
					scalar($3),
					ref($1, OP_HSLICE), LOCATION($2));
                            $$->op_private = IVAL($2);
			    PL_parser->expect = XOPERATOR;
			  TOKEN_GETMAD($2,$$,'{');
			  TOKEN_GETMAD($4,$$,'}');
			}
	|	term ASLICE expr ']'    /* foo[[bar()]] */
			{ $$ = newLISTOP(OP_ASLICE, 0,
					scalar($3),
					ref($1, OP_ASLICE), LOCATION($2));
			    PL_parser->expect = XOPERATOR;
			  TOKEN_GETMAD($2,$$,'[');
			  TOKEN_GETMAD($4,$$,']');
			}
	|	term '{' expr ';' '}'   /* %foo{bar} or %foo{bar();} */
                        { 
                            $$ = newBINOP(OP_HELEM, 0, $1, scalar($3),
                                LOCATION($2));
                            $$->op_private = IVAL($2);
                            if ($$->op_private & OPpELEM_ADD) {
                                $$ = op_mod_assign($$, &(cBINOPx($$)->op_first), OP_HELEM);
                            }
			    PL_parser->expect = XOPERATOR;
                            TOKEN_GETMAD($2,$$,'{');
                            TOKEN_GETMAD($4,$$,';');
                            TOKEN_GETMAD($5,$$,'}');
			}
	|	term ARROW '{' expr ';' '}' /* somehref->{bar();} */
                        {
                            $$ = newBINOP(OP_HELEM, 0,
                                ref(newHVREF($1, LOCATION($2)),OP_RV2HV),
                                scalar($4), LOCATION($3));
                            $$->op_private = IVAL($3);
			    PL_parser->expect = XOPERATOR;
                            TOKEN_GETMAD($2,$$,'a');
                            TOKEN_GETMAD($3,$$,'{');
                            TOKEN_GETMAD($5,$$,';');
                            TOKEN_GETMAD($6,$$,'}');
			}
	|	term ARROW '(' ')'          /* $subref->() */
			{ $$ = newUNOP(OP_ENTERSUB, OPf_STACKED,
                                newCVREF(0, scalar($1), LOCATION($2)), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'a');
			  TOKEN_GETMAD($3,$$,'(');
			  TOKEN_GETMAD($4,$$,')');
			}
	|	term ARROW '(' expr ')'     /* $subref->(@args) */
			{ $$ = newUNOP(OP_ENTERSUB, OPf_STACKED,
				   append_elem(OP_LIST, $4,
				       newCVREF(0, scalar($1), LOCATION($2))), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'a');
			  TOKEN_GETMAD($3,$$,'(');
			  TOKEN_GETMAD($5,$$,')');
			}
    ;

/* Binary operators between terms */
termbinop:	term AHOP term                        /* $x +@+ $y */
                        { $$ = newBINOP(IVAL($2), 0, scalar($1), scalar($3), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term POWOP term                        /* $x ** $y */
                        { $$ = newBINOP(IVAL($2), 0, scalar($1), scalar($3), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term MULOP term                        /* $x * $y, $x x $y */
			{
			    $$ = newBINOP(IVAL($2), 0, scalar($1), scalar($3), LOCATION($2));
                            TOKEN_GETMAD($2,$$,'o');
                            APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term ADDOP term                        /* $x + $y */
			{ $$ = newBINOP(IVAL($2), 0, scalar($1), scalar($3), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term SHIFTOP term                      /* $x >> $y, $x << $y */
			{ $$ = newBINOP(IVAL($2), 0, scalar($1), scalar($3), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term RELOP term                        /* $x > $y, etc. */
			{ $$ = newBINOP(IVAL($2), 0, scalar($1), scalar($3), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term EQOP term                         /* $x == $y, $x eq $y */
			{ $$ = newBINOP(IVAL($2), 0, scalar($1), scalar($3), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term BITANDOP term                     /* $x & $y */
			{ $$ = newBINOP(IVAL($2), 0, scalar($1), scalar($3), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term BITOROP term                      /* $x | $y */
			{ $$ = newBINOP(IVAL($2), 0, scalar($1), scalar($3), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term DOTDOT term                       /* $x..$y, $x...$y */
			{
                            $$ = newBINOP(OP_RANGE, 0, scalar($1), scalar($3), LOCATION($2));
                            TOKEN_GETMAD($2,$$,'o');
                            APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term ANDAND term                       /* $x && $y */
			{ $$ = newLOGOP(OP_AND, 0, $1, $3, LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term OROR term                         /* $x || $y */
			{ $$ = newLOGOP(OP_OR, 0, $1, $3, LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term DORDOR term                       /* $x // $y */
			{ $$ = newLOGOP(OP_DOR, 0, $1, $3, LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	term MATCHOP term                      /* $x =~ /$y/ */
			{ $$ = bind_match(IVAL($2), $1, $3);
			  TOKEN_GETMAD($2,
				($$->op_type == OP_NOT
				    ? ((UNOP*)$$)->op_first : $$),
				'~');
                          APPEND_MADPROPS_PV("bind_match",
				($$->op_type == OP_NOT
				    ? ((UNOP*)$$)->op_first : $$),
                                             '>');
			}
    ;

/* Unary operators and terms */
termunop : '-' term %prec UMINUS                       /* -$x */
			{ $$ = newUNOP(OP_NEGATE, 0, scalar($2), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	'!' term                               /* !$x */
			{ $$ = newUNOP(OP_NOT, 0, scalar($2), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	'~' term                               /* ~$x */
			{ $$ = newUNOP(OP_COMPLEMENT, 0, scalar($2), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	'<' term                               /* <$x */
			{ $$ = newUNOP(OP_EXPAND, 0, scalar($2), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	ARRAYEXPAND term                               /* @< $x */
			{ $$ = newUNOP(OP_ARRAYEXPAND, 0, scalar($2), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	HASHEXPAND term                               /* %< $x */
			{ $$ = newUNOP(OP_HASHEXPAND, 0, scalar($2), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
                        }
	|	term POSTINC                           /* $x++ */
			{ $$ = newUNOP(OP_POSTINC, 0,
                                scalar($1), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
			}
	|	term POSTDEC                           /* $x-- */
			{ $$ = newUNOP(OP_POSTDEC, 0,
                                mod(scalar($1), OP_POSTDEC), LOCATION($2));
			  TOKEN_GETMAD($2,$$,'o');
			}
	|	PREINC term                            /* ++$x */
			{ $$ = newUNOP(OP_PREINC, 0,
                                mod(scalar($2), OP_PREINC), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	PREDEC term                            /* --$x */
			{ $$ = newUNOP(OP_PREDEC, 0,
                                mod(scalar($2), OP_PREDEC), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}

    ;

/* Constructors for anonymous data */
anonymous:
	BLOCKSUB startblocksub block	%prec '('
			{
                            $$ = newANONSUB($2, NULL, scalar($3));
                            TOKEN_GETMAD($1,$$,'o');
			}
        |       ANONSUB startanonsub proto dblock	%prec '('
			{
                            $$ = newANONSUB($2, $3, scalar($4));
                            TOKEN_GETMAD($1,$$,'o');
			}
	;

/* Things called with "do" */
termdo	:	DO dblock cont %prec '('               /* do { code */
                        {
                            OP* op_scope =
                                scope(newWHILEOP(0, 1, (LOOP*)(OP*)NULL,
                                        LOCATION($1), (OP*)NULL, $2, $3, 0));
                            TOKEN_GETMAD($1,op_scope,'o');
                            $$ = newSTATEOP(0, NULL, op_scope,
                                LOCATION($1));
                            $$ = scope($$);
                        }
	|	LABEL DO dblock cont %prec '('               /* do { code */
                        {
                            OP* op_scope = 
                                scope(newWHILEOP(0, 1, (LOOP*)(OP*)NULL,
                                        LOCATION($2), (OP*)NULL, $3, $4, 0));
                            TOKEN_GETMAD($1,op_scope,'L');
                            TOKEN_GETMAD($2,op_scope,'o');
                            $$ = newSTATEOP(0, PVAL($1), op_scope, LOCATION($2));
                            /* $$ = scope($$); should work */
			}
        ;

term	:	'?' term
                        { 
                            $$ = $2;
                            TOKEN_GETMAD($1,$$,'H');
                            $$->op_flags |= OPf_OPTIONAL;
                        }
        |       term CALLOP layoutlistexpr
			{ 
                            $1->op_private |= OPpENTERSUB_AMPER;
                            $$ = newUNOP(OP_ENTERSUB, OPf_STACKED,
				append_elem(OP_LIST, $3, scalar($1)), $1->op_location);
                            TOKEN_GETMAD($2,$$,'o');
                        }
        |       termbinop
			{ $$ = $1; }
	|	termunop
			{ $$ = $1; }
	|	anonymous
			{ $$ = $1; }
	|	termdo
			{ $$ = $1; }
	|	term TERNARY_IF term TERNARY_ELSE term
                        { 
                            $$ = newCONDOP(0, $1, $3, $5, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'?');
                            TOKEN_GETMAD($4,$$,':');
                            APPEND_MADPROPS_PV("?",$$,'>');
			}
	|	SREFGEN term                          /* \$x, \@y, \%z */
                        { $$ = newUNOP(OP_SREFGEN, 0, mod(scalar($2),OP_SREFGEN), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
                          APPEND_MADPROPS_PV("operator",$$,'>');
			}
	|	myattrterm	%prec UNIOP
			{ $$ = $1; }
	|	LOCAL term	%prec UNIOP
			{ $$ = localize($2,IVAL($1));
			  TOKEN_GETMAD($1,$$,'k');
			}
	|	'(' expr ')'
                        {
                            $$ = sawparens(IF_MAD(newUNOP(OP_NULL,0,$2, LOCATION($1)), $2));
                            APPEND_MADPROPS_PV("(", $$, '>');
                            TOKEN_GETMAD($1,$$,'(');
                            TOKEN_GETMAD($3,$$,')');
			}
	|	'(' ')'
			{
                            $$ = sawparens(newNULLLIST(LOCATION($1)));
                            TOKEN_GETMAD($1,$$,'(');
                            TOKEN_GETMAD($2,$$,')');
			}
	|	scalar	%prec '('
			{ $$ = $1; }
	|	star	%prec '('
			{ $$ = $1; }
	|       subscripted
			{ $$ = $1; }
	|	THING	%prec '('
			{ $$ = $1; }
	|	'&' indirob                                /* &foo; */
                        {
                            $$ = newCVREF(0,$2, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'&');
                            $$->op_flags |= OPf_SPECIAL;
                        }
	|	NOAMPCALL WORD ',' LAYOUTLISTEND                        /* &foo() */
			{
                            $$ = newUNOP(OP_ENTERSUB, OPf_STACKED | IVAL($1), scalar($2), $2->op_location);
                            TOKEN_GETMAD($1,$$,'(');
                            TOKEN_GETMAD($4,$$,')');
                            APPEND_MADPROPS_PV("amper", $$, '>');
			}
	|	NOAMPCALL WORD listexpr LAYOUTLISTEND                   /* &foo(@args) */
			{
                            $$ = newUNOP(OP_ENTERSUB, OPf_STACKED | IVAL($1),
				append_elem(OP_LIST, $3, scalar($2)), $2->op_location);
			  DO_MAD({
			      OP* op = $$;
			      if (op->op_type == OP_CONST) { /* defeat const fold */
				op = (OP*)op->op_madprop->mad_val;
			      }
			      TOKEN_GETMAD($1,op,'(');
			      TOKEN_GETMAD($4,op,')');
                              APPEND_MADPROPS_PV("amper", $$, '>');
			  })
			}
	|	NOAMP WORD listexpr                  /* foo(@args) */
			{ 
                          $$ = newUNOP(OP_ENTERSUB, OPf_STACKED,
                              append_elem(OP_LIST, $3, scalar($2)), $2->op_location);
			  TOKEN_GETMAD($1,$$,'o');
                          APPEND_MADPROPS_PV("noamp", $$, '>');
			}
	|	LOOPEX  /* loop exiting command (goto, last, dump, etc) */
                        {
                            $$ = newOP(IVAL($1), OPf_SPECIAL, LOCATION($1));
			    PL_hints |= HINT_BLOCK_SCOPE;
                            TOKEN_GETMAD($1,$$,'o');
			}
	|	LOOPEX term
			{ $$ = newLOOPEX(IVAL($1),$2);
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	RETURNTOKEN expr                        /* return $foo */
                        { $$ = newUNOP(OP_RETURN, OPf_STACKED, scalar($2), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	RETURNTOKEN
                        { $$ = newOP(OP_RETURN, 0, LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	NOTOP assignexpr                        /* not $foo */
                        { $$ = newUNOP(OP_NOT, 0, scalar($2), LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	UNIOP                                /* Unary op, $_ implied */
			{ 
                            $$ = newOP(IVAL($1), 0, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'o');
                            APPEND_MADPROPS_PV("uniop", $$, '>');
			}
	|	UNIOP block                          /* eval { foo }* */
			{ $$ = newUNOP(IVAL($1), 0, $2, LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
                          APPEND_MADPROPS_PV("uniop", $$, '>');
			}
	|	UNIOP term                           /* Unary op */
			{
                            $$ = newUNOP(IVAL($1), 0, $2, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'o');
                            APPEND_MADPROPS_PV("uniop", $$, '>');
			}
	|	REQUIRE                              /* require, $_ implied */
                        {
                            $$ = newOP(OP_REQUIRE, IVAL($1) ? OPf_SPECIAL : 0, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'o');
			}
	|	REQUIRE term                         /* require Foo */
                        { $$ = newUNOP(OP_REQUIRE, IVAL($1) ? OPf_SPECIAL : 0, $2, LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			}
	|	COMPSUB listexpr                  /* foo @args */
			{ 
                            $$ = newBINOP(OP_COMPSUB, 0, $1, $2, $1->op_location);
			}
	|	UNIOPSUB
			{ 
                            $$ = newUNOP(OP_ENTERSUB, OPf_STACKED, scalar($1), $1->op_location); 
                            APPEND_MADPROPS_PV("uniop", $$, '>');
                        }
	|	UNIOPSUB term                        /* Sub treated as unop */
			{ $$ = newUNOP(OP_ENTERSUB, OPf_STACKED,
			    append_elem(OP_LIST, $2, scalar($1)), $1->op_location);
                          APPEND_MADPROPS_PV("uniop", $$, '>');
                        }
	|	FUNC0                                /* Nullary operator */
			{ 
                            $$ = newOP(IVAL($1), 0, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'o');
			}
	|	FUNC0 ':' LAYOUTLISTEND
			{
                            $$ = newOP(IVAL($1), 0, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'o');
                            TOKEN_GETMAD($2,$$,'(');
                            TOKEN_GETMAD($3,$$,')');
			}
	|	FUNC0 ':' ',' LAYOUTLISTEND
			{
                            $$ = newOP(IVAL($1), 0, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'o');
                            TOKEN_GETMAD($2,$$,'(');
                            TOKEN_GETMAD($3,$$,')');
			}
	|	FUNC0SUB                             /* Sub treated as nullop */
			{ $$ = newUNOP(OP_ENTERSUB, OPf_STACKED,
				scalar($1), $1->op_location); }
	|	FUNC1 ':' LAYOUTLISTEND                                       /* not () */
			{ $$ = (IVAL($1) == OP_NOT)
                                ? newUNOP(IVAL($1), 0, newSVOP(OP_CONST, 0, newSViv(0), LOCATION($1)), LOCATION($1))
                                : newOP(IVAL($1), OPf_SPECIAL, LOCATION($1));

			  TOKEN_GETMAD($1,$$,'o');
			  TOKEN_GETMAD($2,$$,'(');
			  TOKEN_GETMAD($3,$$,')');
                          APPEND_MADPROPS_PV("func1", $$, '>');
			}
	|	FUNC1 ':' ',' LAYOUTLISTEND                                       /* not () */
			{ $$ = (IVAL($1) == OP_NOT)
                                ? newUNOP(IVAL($1), 0, newSVOP(OP_CONST, 0, newSViv(0), LOCATION($1)), LOCATION($1))
                                : newOP(IVAL($1), OPf_SPECIAL, LOCATION($1));

			  TOKEN_GETMAD($1,$$,'o');
			  TOKEN_GETMAD($2,$$,'(');
			  TOKEN_GETMAD($3,$$,')');
                          APPEND_MADPROPS_PV("func1", $$, '>');
			}
	|	FUNC1 ':' expr LAYOUTLISTEND                  /* not($foo) */
			{ $$ = newUNOP(IVAL($1), 0, $3, LOCATION($1));
			  TOKEN_GETMAD($1,$$,'o');
			  TOKEN_GETMAD($2,$$,'(');
			  TOKEN_GETMAD($4,$$,')');
                          APPEND_MADPROPS_PV("func1", $$, '>');
			}
	|	PMFUNC '(' argexpr ')'		/* m//, s///, tr/// */
			{ $$ = pmruntime($1, $3, 1);
			  TOKEN_GETMAD($2,$$,'(');
			  TOKEN_GETMAD($4,$$,')');
			}
	|	WORD
			{ $$ = $1; }
	|	listop
			{ $$ = $1; }
	;

/* "my" declarations, with optional attributes */
myattrterm:  MY myterm
			{ 
                            $$ = localize($2,IVAL($1));
                            TOKEN_GETMAD($1,$$,'d');
			}
	;

/* Things that can be "my"'d */
myterm	:	'(' expr ')'
			{ $$ = sawparens($2);
			  TOKEN_GETMAD($1,$$,'(');
			  TOKEN_GETMAD($3,$$,')');
			}
	|	'(' ')'
			{
                            $$ = sawparens(newNULLLIST(LOCATION($1)));
                            TOKEN_GETMAD($1,$$,'(');
                            TOKEN_GETMAD($2,$$,')');
			}
	|	scalar	%prec '('
			{ $$ = $1; }
	;

mydef :   /* NULL */
			{ 
                            $$ = newOP(OP_PADSV, 0, NULL);
                            $$->op_targ = allocmy("$_");
                        }

/* Basic list expressions */
listexpr:	/* NULL */ %prec PREC_LOW
			{ $$ = (OP*)NULL; }
	|	argexpr    %prec PREC_LOW
			{ $$ = $1; }
	;

listexprcom:	/* NULL */
			{ $$ = (OP*)NULL; }
	|	expr
			{ $$ = $1; }
	|	expr ','
			{
#ifdef MAD
			  OP* op = newNULLLIST(NULL);
			  TOKEN_GETMAD($2,op,',');
			  $$ = append_elem(OP_LIST, $1, op);
                          APPEND_MADPROPS_PV(",", op, '>');
#else
			  $$ = $1;
#endif

			}
	;

/* A little bit of trickery to make "for my $foo (@bar)" actually be
   lexical */
my_scalar:	scalar
			{ PL_parser->in_my = 0; $$ = my($1); }
	;

layoutlistexpr :    listexpr LAYOUTLISTEND
			{ 
#ifdef PERL_MAD
                            $$ = convert(OP_LIST, 0, $1, $1 ? $1->op_location : LOCATION($2) );
#else
                            $$ = $1
#endif
                            TOKEN_GETMAD($2,$$,')');
                        }
        |       ',' LAYOUTLISTEND
			{ 
                            $$ = NULL;
#ifdef PERL_MAD
                            $$ = newOP(OP_NULL,0, NULL);
#endif
                            TOKEN_GETMAD($2,$$,')');
                        }
        ;
    
scalar  :	PRIVATEVAR
			{ 
                            $$ = newPRIVATEVAROP(PL_parser->tokenbuf, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'X');
                        }
        |       ANONSCALAR expr ')'  /* $( ... ) */
                        { 
                            $$ = newUNOP(OP_ANONSCALAR, 0, scalar($2), LOCATION($1));
                            TOKEN_GETMAD($1,$$,'[');
                            TOKEN_GETMAD($3,$$,']');

                            if (PL_parser->lex_state == LEX_INTERPNORMAL) {
                                if ( PL_parser->lex_brackets == 0 )
                                    PL_parser->lex_state = LEX_INTERPEND;
                            }
			}
        |       ANONHSHL listexpr LAYOUTLISTEND /* %: ... */
                        {
                            $$ = newANONHASH($2, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'{');
                            TOKEN_GETMAD($3,$$,'}');
			}
        |       ANONHSHL ',' LAYOUTLISTEND /* %: ... */
                        {
                            $$ = newANONHASH(NULL, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'{');
                            TOKEN_GETMAD($3,$$,'}');
			}
        |       ANONARYL listexpr LAYOUTLISTEND  /* @: ... */
                        {
                            $$ = newANONARRAY($2, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'[');
                            TOKEN_GETMAD($3,$$,']');
			}
        |       ANONARYL ',' LAYOUTLISTEND  /* @: ... */
                        {
                            $$ = newANONARRAY(NULL, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'[');
                            TOKEN_GETMAD($3,$$,']');
			}
        |       EMPTYAH
			{ 
                            $$ = newOP(IVAL($1), 0, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'o');
                        }
	;

star	:	'*' indirob
                        {
                            $$ = newGVREF(0,$2, LOCATION($1));
                            TOKEN_GETMAD($1,$$,'*');
			}
        |       term DEREFSTAR                /* somearef->* */
                        {
                            $$ = newGVREF(0, $1, LOCATION($2));
                            TOKEN_GETMAD($2,$$,'a');
                        }
	;

/* Indirect objects */
indirob	:       WORD
                        { $$ = scalar($1); }
        |	scalar %prec PREC_LOW
			{ $$ = scalar($1); }
	|	block
			{ $$ = scope($1); }
	;
