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
     LOOPDO = 292,
     NOAMP = 293,
     NOAMPCALL = 294,
     ANONSCALAR = 295,
     LOCAL = 296,
     MY = 297,
     MYSUB = 298,
     REQUIRE = 299,
     COLONATTR = 300,
     SPECIALBLOCK = 301,
     LAYOUTLISTEND = 302,
     EMPTYAH = 303,
     PREC_LOW = 304,
     RETURNTOKEN = 305,
     DOROP = 306,
     OROP = 307,
     ANDOP = 308,
     NOTOP = 309,
     ASSIGNOP = 310,
     TERNARY_ELSE = 311,
     TERNARY_IF = 312,
     HASHEXPAND = 313,
     ARRAYEXPAND = 314,
     ANONSCALARL = 315,
     ANONARYL = 316,
     ANONHSHL = 317,
     AHOP = 318,
     DORDOR = 319,
     OROR = 320,
     ANDAND = 321,
     BITOROP = 322,
     BITANDOP = 323,
     SHIFTOP = 324,
     MATCHOP = 325,
     SREFGEN = 326,
     UMINUS = 327,
     POWOP = 328,
     CALLOP = 329,
     POSTDEC = 330,
     POSTINC = 331,
     PREDEC = 332,
     PREINC = 333,
     ASLICE = 334,
     HSLICE = 335,
     DEREFAMP = 336,
     DEREFSTAR = 337,
     DEREFHSH = 338,
     DEREFARY = 339,
     DEREFSCL = 340,
     ARROW = 341,
     PEG = 342
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
#define BLOCKSUB 269
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
#define LOOPDO 292
#define NOAMP 293
#define NOAMPCALL 294
#define ANONSCALAR 295
#define LOCAL 296
#define MY 297
#define MYSUB 298
#define REQUIRE 299
#define COLONATTR 300
#define SPECIALBLOCK 301
#define LAYOUTLISTEND 302
#define EMPTYAH 303
#define PREC_LOW 304
#define RETURNTOKEN 305
#define DOROP 306
#define OROP 307
#define ANDOP 308
#define NOTOP 309
#define ASSIGNOP 310
#define TERNARY_ELSE 311
#define TERNARY_IF 312
#define HASHEXPAND 313
#define ARRAYEXPAND 314
#define ANONSCALARL 315
#define ANONARYL 316
#define ANONHSHL 317
#define AHOP 318
#define DORDOR 319
#define OROR 320
#define ANDAND 321
#define BITOROP 322
#define BITANDOP 323
#define SHIFTOP 324
#define MATCHOP 325
#define SREFGEN 326
#define UMINUS 327
#define POWOP 328
#define CALLOP 329
#define POSTDEC 330
#define POSTINC 331
#define PREDEC 332
#define PREINC 333
#define ASLICE 334
#define HSLICE 335
#define DEREFAMP 336
#define DEREFSTAR 337
#define DEREFHSH 338
#define DEREFARY 339
#define DEREFSCL 340
#define ARROW 341
#define PEG 342



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




