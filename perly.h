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
     ANONHSH = 294,
     ANONSCALAR = 295,
     LOCAL = 296,
     MY = 297,
     MYSUB = 298,
     REQUIRE = 299,
     COLONATTR = 300,
     PREC_LOW = 301,
     DOROP = 302,
     OROP = 303,
     ANDOP = 304,
     NOTOP = 305,
     ASSIGNOP = 306,
     DORDOR = 307,
     OROR = 308,
     ANDAND = 309,
     BITOROP = 310,
     BITANDOP = 311,
     SHIFTOP = 312,
     MATCHOP = 313,
     SREFGEN = 314,
     UMINUS = 315,
     POWOP = 316,
     POSTDEC = 317,
     POSTINC = 318,
     PREDEC = 319,
     PREINC = 320,
     ASLICE = 321,
     HSLICE = 322,
     DEREFAMP = 323,
     DEREFSTAR = 324,
     DEREFHSH = 325,
     DEREFARY = 326,
     DEREFSCL = 327,
     ARROW = 328,
     PEG = 329
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
#define CONTINUE 278
#define FOR 279
#define LOOPEX 280
#define DOTDOT 281
#define FUNC0 282
#define FUNC1 283
#define FUNC 284
#define UNIOP 285
#define LSTOP 286
#define RELOP 287
#define EQOP 288
#define MULOP 289
#define ADDOP 290
#define DO 291
#define NOAMP 292
#define ANONARY 293
#define ANONHSH 294
#define ANONSCALAR 295
#define LOCAL 296
#define MY 297
#define MYSUB 298
#define REQUIRE 299
#define COLONATTR 300
#define PREC_LOW 301
#define DOROP 302
#define OROP 303
#define ANDOP 304
#define NOTOP 305
#define ASSIGNOP 306
#define DORDOR 307
#define OROR 308
#define ANDAND 309
#define BITOROP 310
#define BITANDOP 311
#define SHIFTOP 312
#define MATCHOP 313
#define SREFGEN 314
#define UMINUS 315
#define POWOP 316
#define POSTDEC 317
#define POSTINC 318
#define PREDEC 319
#define PREINC 320
#define ASLICE 321
#define HSLICE 322
#define DEREFAMP 323
#define DEREFSTAR 324
#define DEREFHSH 325
#define DEREFARY 326
#define DEREFSCL 327
#define ARROW 328
#define PEG 329




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



