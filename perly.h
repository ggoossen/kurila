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
     HASHBRACK = 295,
     NOAMP = 296,
     LOCAL = 297,
     MY = 298,
     MYSUB = 299,
     REQUIRE = 300,
     COLONATTR = 301,
     PREC_LOW = 302,
     DOROP = 303,
     OROP = 304,
     ANDOP = 305,
     NOTOP = 306,
     ASSIGNOP = 307,
     DORDOR = 308,
     OROR = 309,
     ANDAND = 310,
     BITOROP = 311,
     BITANDOP = 312,
     SHIFTOP = 313,
     MATCHOP = 314,
     REFGEN = 315,
     UMINUS = 316,
     POWOP = 317,
     POSTDEC = 318,
     POSTINC = 319,
     PREDEC = 320,
     PREINC = 321,
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
#define HASHBRACK 295
#define NOAMP 296
#define LOCAL 297
#define MY 298
#define MYSUB 299
#define REQUIRE 300
#define COLONATTR 301
#define PREC_LOW 302
#define DOROP 303
#define OROP 304
#define ANDOP 305
#define NOTOP 306
#define ASSIGNOP 307
#define DORDOR 308
#define OROR 309
#define ANDAND 310
#define BITOROP 311
#define BITANDOP 312
#define SHIFTOP 313
#define MATCHOP 314
#define REFGEN 315
#define UMINUS 316
#define POWOP 317
#define POSTDEC 318
#define POSTINC 319
#define PREDEC 320
#define PREINC 321
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



