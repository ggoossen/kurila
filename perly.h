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
     ANONARY = 296,
     ANONHSH = 297,
     LOCAL = 298,
     MY = 299,
     MYSUB = 300,
     REQUIRE = 301,
     COLONATTR = 302,
     PREC_LOW = 303,
     DOROP = 304,
     OROP = 305,
     ANDOP = 306,
     NOTOP = 307,
     ASSIGNOP = 308,
     DORDOR = 309,
     OROR = 310,
     ANDAND = 311,
     BITOROP = 312,
     BITANDOP = 313,
     SHIFTOP = 314,
     MATCHOP = 315,
     REFGEN = 316,
     UMINUS = 317,
     POWOP = 318,
     POSTDEC = 319,
     POSTINC = 320,
     PREDEC = 321,
     PREINC = 322,
     ASLICE = 323,
     HSLICE = 324,
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
#define ANONARY 296
#define ANONHSH 297
#define LOCAL 298
#define MY 299
#define MYSUB 300
#define REQUIRE 301
#define COLONATTR 302
#define PREC_LOW 303
#define DOROP 304
#define OROP 305
#define ANDOP 306
#define NOTOP 307
#define ASSIGNOP 308
#define DORDOR 309
#define OROR 310
#define ANDAND 311
#define BITOROP 312
#define BITANDOP 313
#define SHIFTOP 314
#define MATCHOP 315
#define REFGEN 316
#define UMINUS 317
#define POWOP 318
#define POSTDEC 319
#define POSTINC 320
#define PREDEC 321
#define PREINC 322
#define ASLICE 323
#define HSLICE 324
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



