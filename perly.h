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
     PRIVATEVAR = 262,
     FUNC0SUB = 263,
     UNIOPSUB = 264,
     COMPSUB = 265,
     LABEL = 266,
     SUB = 267,
     ANONSUB = 268,
     PACKAGE = 269,
     USE = 270,
     WHILE = 271,
     UNTIL = 272,
     IF = 273,
     UNLESS = 274,
     ELSE = 275,
     ELSIF = 276,
     CONTINUE = 277,
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
     ANONARYL = 293,
     ANONHSH = 294,
     ANONHSHL = 295,
     ANONSCALAR = 296,
     ANONSCALARL = 297,
     LOCAL = 298,
     MY = 299,
     MYSUB = 300,
     REQUIRE = 301,
     COLONATTR = 302,
     SPECIALBLOCK = 303,
     PREC_LOW = 304,
     DOROP = 305,
     OROP = 306,
     ANDOP = 307,
     NOTOP = 308,
     ASSIGNOP = 309,
     TERNARY_ELSE = 310,
     TERNARY_IF = 311,
     HASHEXPAND = 312,
     ARRAYEXPAND = 313,
     DORDOR = 314,
     OROR = 315,
     ANDAND = 316,
     BITOROP = 317,
     BITANDOP = 318,
     SHIFTOP = 319,
     MATCHOP = 320,
     SREFGEN = 321,
     UMINUS = 322,
     POWOP = 323,
     POSTDEC = 324,
     POSTINC = 325,
     PREDEC = 326,
     PREINC = 327,
     ASLICE = 328,
     HSLICE = 329,
     DEREFAMP = 330,
     DEREFSTAR = 331,
     DEREFHSH = 332,
     DEREFARY = 333,
     DEREFSCL = 334,
     ARROW = 335,
     PEG = 336
   };
#endif
/* Tokens.  */
#define WORD 258
#define METHOD 259
#define THING 260
#define PMFUNC 261
#define PRIVATEVAR 262
#define FUNC0SUB 263
#define UNIOPSUB 264
#define COMPSUB 265
#define LABEL 266
#define SUB 267
#define ANONSUB 268
#define PACKAGE 269
#define USE 270
#define WHILE 271
#define UNTIL 272
#define IF 273
#define UNLESS 274
#define ELSE 275
#define ELSIF 276
#define CONTINUE 277
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
#define ANONARYL 293
#define ANONHSH 294
#define ANONHSHL 295
#define ANONSCALAR 296
#define ANONSCALARL 297
#define LOCAL 298
#define MY 299
#define MYSUB 300
#define REQUIRE 301
#define COLONATTR 302
#define SPECIALBLOCK 303
#define PREC_LOW 304
#define DOROP 305
#define OROP 306
#define ANDOP 307
#define NOTOP 308
#define ASSIGNOP 309
#define TERNARY_ELSE 310
#define TERNARY_IF 311
#define HASHEXPAND 312
#define ARRAYEXPAND 313
#define DORDOR 314
#define OROR 315
#define ANDAND 316
#define BITOROP 317
#define BITANDOP 318
#define SHIFTOP 319
#define MATCHOP 320
#define SREFGEN 321
#define UMINUS 322
#define POWOP 323
#define POSTDEC 324
#define POSTINC 325
#define PREDEC 326
#define PREINC 327
#define ASLICE 328
#define HSLICE 329
#define DEREFAMP 330
#define DEREFSTAR 331
#define DEREFHSH 332
#define DEREFARY 333
#define DEREFSCL 334
#define ARROW 335
#define PEG 336




#endif /* PERL_CORE */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef union YYSTYPE
{
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
/* Line 1489 of yacc.c.  */
	YYSTYPE;
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif



