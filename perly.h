#ifdef PERL_CORE

/* A Bison parser, made by GNU Bison 2.4.1.  */

/* Skeleton interface for Bison's Yacc-like parsers in C
   
      Copyright (C) 1984, 1989, 1990, 2000, 2001, 2002, 2003, 2004, 2005, 2006
   Free Software Foundation, Inc.
   
   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.
   
   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */


/* Tokens.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
   /* Put the tokens into the symbol table, so that GDB and other debuggers
      know about them.  */
   enum yytokentype {
     WORD = 258,
     METHOD = 259,
     THING = 260,
     PMFUNC = 261,
     PRIVATEVAR = 262,
     FUNC0SUB = 263,
     UNIOPSUB = 264,
     COMPSUB = 265,
     LABEL = 266,
     SUB = 267,
     ANONSUB = 268,
     BLOCKSUB = 269,
     PACKAGE = 270,
     USE = 271,
     WHILE = 272,
     UNTIL = 273,
     IF = 274,
     UNLESS = 275,
     ELSE = 276,
     ELSIF = 277,
     CONTINUE = 278,
     FOR = 279,
     LOOPEX = 280,
     DOTDOT = 281,
     FUNC0 = 282,
     FUNC1 = 283,
     FUNC = 284,
     UNIOP = 285,
     LSTOP = 286,
     RELOP = 287,
     EQOP = 288,
     MULOP = 289,
     ADDOP = 290,
     DO = 291,
     NOAMP = 292,
     ANONARY = 293,
     ANONARYL = 294,
     ANONHSH = 295,
     ANONHSHL = 296,
     ANONSCALAR = 297,
     ANONSCALARL = 298,
     LOCAL = 299,
     MY = 300,
     MYSUB = 301,
     REQUIRE = 302,
     COLONATTR = 303,
     SPECIALBLOCK = 304,
     PREC_LOW = 305,
     RETURNOP = 306,
     DOROP = 307,
     OROP = 308,
     ANDOP = 309,
     NOTOP = 310,
     ASSIGNOP = 311,
     TERNARY_ELSE = 312,
     TERNARY_IF = 313,
     HASHEXPAND = 314,
     ARRAYEXPAND = 315,
     DORDOR = 316,
     OROR = 317,
     ANDAND = 318,
     BITOROP = 319,
     BITANDOP = 320,
     SHIFTOP = 321,
     MATCHOP = 322,
     SREFGEN = 323,
     UMINUS = 324,
     POWOP = 325,
     POSTDEC = 326,
     POSTINC = 327,
     PREDEC = 328,
     PREINC = 329,
     ASLICE = 330,
     HSLICE = 331,
     DEREFAMP = 332,
     DEREFSTAR = 333,
     DEREFHSH = 334,
     DEREFARY = 335,
     DEREFSCL = 336,
     ARROW = 337,
     PEG = 338
   };
#endif



#endif /* PERL_CORE */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef union YYSTYPE
{

/* Line 1676 of yacc.c  */

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



/* Line 1676 of yacc.c  */
} YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
#endif




