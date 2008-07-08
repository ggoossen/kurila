#ifdef PERL_CORE
/* A Bison parser, made by GNU Bison 2.3.  */

/* Skeleton interface for Bison's Yacc-like parsers in C

   Copyright (C) 1984, 1989, 1990, 2000, 2001, 2002, 2003, 2004, 2005, 2006
   Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.  */

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
     PRIVATEREF = 262,
     FUNC0SUB = 263,
     UNIOPSUB = 264,
     LSTOPSUB = 265,
     COMPSUB = 266,
     LABEL = 267,
     SUB = 268,
     ANONSUB = 269,
     PACKAGE = 270,
     USE = 271,
     WHILE = 272,
     UNTIL = 273,
     IF = 274,
     UNLESS = 275,
     ELSE = 276,
     ELSIF = 277,
     FOR = 278,
     LOOPEX = 279,
     DOTDOT = 280,
     FUNC0 = 281,
     FUNC1 = 282,
     FUNC = 283,
     UNIOP = 284,
     LSTOP = 285,
     RELOP = 286,
     EQOP = 287,
     MULOP = 288,
     ADDOP = 289,
     DO = 290,
     NOAMP = 291,
     ANONARY = 292,
     ANONHSH = 293,
     ANONSCALAR = 294,
     LOCAL = 295,
     MY = 296,
     MYSUB = 297,
     REQUIRE = 298,
     COLONATTR = 299,
     PREC_LOW = 300,
     DOROP = 301,
     OROP = 302,
     ANDOP = 303,
     NOTOP = 304,
     ASSIGNOP = 305,
     DORDOR = 306,
     OROR = 307,
     ANDAND = 308,
     BITOROP = 309,
     BITANDOP = 310,
     SHIFTOP = 311,
     MATCHOP = 312,
     SREFGEN = 313,
     UMINUS = 314,
     POWOP = 315,
     POSTDEC = 316,
     POSTINC = 317,
     PREDEC = 318,
     PREINC = 319,
     ASLICE = 320,
     HSLICE = 321,
     DEREFAMP = 322,
     DEREFSTAR = 323,
     DEREFHSH = 324,
     DEREFARY = 325,
     DEREFSCL = 326,
     ARROW = 327,
     PEG = 328
   };
#endif
/* Tokens.  */
#define WORD 258
#define METHOD 259
#define THING 260
#define PMFUNC 261
#define PRIVATEREF 262
#define FUNC0SUB 263
#define UNIOPSUB 264
#define LSTOPSUB 265
#define COMPSUB 266
#define LABEL 267
#define SUB 268
#define ANONSUB 269
#define PACKAGE 270
#define USE 271
#define WHILE 272
#define UNTIL 273
#define IF 274
#define UNLESS 275
#define ELSE 276
#define ELSIF 277
#define FOR 278
#define LOOPEX 279
#define DOTDOT 280
#define FUNC0 281
#define FUNC1 282
#define FUNC 283
#define UNIOP 284
#define LSTOP 285
#define RELOP 286
#define EQOP 287
#define MULOP 288
#define ADDOP 289
#define DO 290
#define NOAMP 291
#define ANONARY 292
#define ANONHSH 293
#define ANONSCALAR 294
#define LOCAL 295
#define MY 296
#define MYSUB 297
#define REQUIRE 298
#define COLONATTR 299
#define PREC_LOW 300
#define DOROP 301
#define OROP 302
#define ANDOP 303
#define NOTOP 304
#define ASSIGNOP 305
#define DORDOR 306
#define OROR 307
#define ANDAND 308
#define BITOROP 309
#define BITANDOP 310
#define SHIFTOP 311
#define MATCHOP 312
#define SREFGEN 313
#define UMINUS 314
#define POWOP 315
#define POSTDEC 316
#define POSTINC 317
#define PREDEC 318
#define PREINC 319
#define ASLICE 320
#define HSLICE 321
#define DEREFAMP 322
#define DEREFSTAR 323
#define DEREFHSH 324
#define DEREFARY 325
#define DEREFSCL 326
#define ARROW 327
#define PEG 328




#endif /* PERL_CORE */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef union YYSTYPE
{
    I32	ival; /* __DEFAULT__ (marker for regen_perly.pl;
				must always be 1st union member) */
    char *pval;
    OP *opval;
    GV *gvval;
#ifdef PERL_IN_MADLY_C
    MADTOKEN* p_tkval;
    MADTOKEN* i_tkval;
#else
    char *p_tkval;
    I32	i_tkval;
#endif
#ifdef PERL_MAD
    MADTOKEN* tkval;
#endif
}
/* Line 1489 of yacc.c.  */
	YYSTYPE;
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif



