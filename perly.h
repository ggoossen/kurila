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
     GIVEN = 280,
     WHEN = 281,
     DEFAULT = 282,
     LOOPEX = 283,
     DOTDOT = 284,
     FUNC0 = 285,
     FUNC1 = 286,
     FUNC = 287,
     UNIOP = 288,
     LSTOP = 289,
     RELOP = 290,
     EQOP = 291,
     MULOP = 292,
     ADDOP = 293,
     DO = 294,
     NOAMP = 295,
     HSLICE = 296,
     ASLICE = 297,
     ANONARY = 298,
     ANONHSH = 299,
     LOCAL = 300,
     MY = 301,
     MYSUB = 302,
     REQUIRE = 303,
     COLONATTR = 304,
     PREC_LOW = 305,
     DOROP = 306,
     OROP = 307,
     ANDOP = 308,
     NOTOP = 309,
     ASSIGNOP = 310,
     DORDOR = 311,
     OROR = 312,
     ANDAND = 313,
     BITOROP = 314,
     BITANDOP = 315,
     SHIFTOP = 316,
     MATCHOP = 317,
     REFGEN = 318,
     UMINUS = 319,
     POWOP = 320,
     POSTDEC = 321,
     POSTINC = 322,
     PREDEC = 323,
     PREINC = 324,
     DEREFAMP = 325,
     DEREFSTAR = 326,
     DEREFHSH = 327,
     DEREFARY = 328,
     DEREFSCL = 329,
     ARROW = 330,
     PEG = 331
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
#define GIVEN 280
#define WHEN 281
#define DEFAULT 282
#define LOOPEX 283
#define DOTDOT 284
#define FUNC0 285
#define FUNC1 286
#define FUNC 287
#define UNIOP 288
#define LSTOP 289
#define RELOP 290
#define EQOP 291
#define MULOP 292
#define ADDOP 293
#define DO 294
#define NOAMP 295
#define HSLICE 296
#define ASLICE 297
#define ANONARY 298
#define ANONHSH 299
#define LOCAL 300
#define MY 301
#define MYSUB 302
#define REQUIRE 303
#define COLONATTR 304
#define PREC_LOW 305
#define DOROP 306
#define OROP 307
#define ANDOP 308
#define NOTOP 309
#define ASSIGNOP 310
#define DORDOR 311
#define OROR 312
#define ANDAND 313
#define BITOROP 314
#define BITANDOP 315
#define SHIFTOP 316
#define MATCHOP 317
#define REFGEN 318
#define UMINUS 319
#define POWOP 320
#define POSTDEC 321
#define POSTINC 322
#define PREDEC 323
#define PREINC 324
#define DEREFAMP 325
#define DEREFSTAR 326
#define DEREFHSH 327
#define DEREFARY 328
#define DEREFSCL 329
#define ARROW 330
#define PEG 331




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



