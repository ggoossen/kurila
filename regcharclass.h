/*  -*- buffer-read-only: t -*-
 *
 *    regcharclass.h
 *
 *    Copyright (C) 2007, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 * !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
 * This file is built by Porting/regcharclass.pl.
 * 
 * Any changes made here will be lost!
 *
 */

/*
	LNBREAK: Line Break: \R

	"\x0D\x0A"      # CRLF - Network (Windows) line ending
	0x0A            # LF  | LINE FEED
	0x0B            # VT  | VERTICAL TAB
	0x0C            # FF  | FORM FEED
	0x0D            # CR  | CARRIAGE RETURN
	0x85            # NEL | NEXT LINE
	0x2028          # LINE SEPARATOR
	0x2029          # PARAGRAPH SEPARATOR
*/
/*** GENERATED CODE ***/
#define is_LNBREAK(s,is_utf8)                                               \
( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0C ) ? 1                        \
: ( 0x0D == ((U8*)s)[0] ) ?                                                 \
    ( ( 0x0A == ((U8*)s)[1] ) ? 2 : 1 )                                     \
: ( is_utf8 ) ?                                                             \
    ( ( 0xC2 == ((U8*)s)[0] ) ?                                             \
	( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                                 \
    : ( 0xE2 == ((U8*)s)[0] ) ?                                             \
	( ( ( 0x80 == ((U8*)s)[1] ) && ( 0xA8 == ((U8*)s)[2] || 0xA9 == ((U8*)s)[2] ) ) ? 3 : 0 )\
    : 0 )                                                                   \
: ( 0x85 == ((U8*)s)[0] ) )

/*** GENERATED CODE ***/
#define is_LNBREAK_safe(s,e,is_utf8)                                        \
( ((e)-(s) > 2) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0C ) ? 1                    \
    : ( 0x0D == ((U8*)s)[0] ) ?                                             \
	( ( 0x0A == ((U8*)s)[1] ) ? 2 : 1 )                                 \
    : ( is_utf8 ) ?                                                         \
	( ( 0xC2 == ((U8*)s)[0] ) ?                                         \
	    ( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                             \
	: ( 0xE2 == ((U8*)s)[0] ) ?                                         \
	    ( ( ( 0x80 == ((U8*)s)[1] ) && ( 0xA8 == ((U8*)s)[2] || 0xA9 == ((U8*)s)[2] ) ) ? 3 : 0 )\
	: 0 )                                                               \
    : ( 0x85 == ((U8*)s)[0] ) )                                             \
: ((e)-(s) > 1) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0C ) ? 1                    \
    : ( 0x0D == ((U8*)s)[0] ) ?                                             \
	( ( 0x0A == ((U8*)s)[1] ) ? 2 : 1 )                                 \
    : ( is_utf8 ) ?                                                         \
	( ( ( 0xC2 == ((U8*)s)[0] ) && ( 0x85 == ((U8*)s)[1] ) ) ? 2 : 0 )  \
    : ( 0x85 == ((U8*)s)[0] ) )                                             \
: ((e)-(s) > 0) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) ? 1                    \
    : ( !( is_utf8 ) ) ?                                                    \
	( 0x85 == ((U8*)s)[0] )                                             \
    : 0 )                                                                   \
: 0 )

/*** GENERATED CODE ***/
#define is_LNBREAK_utf8(s)                                                  \
( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0C ) ? 1                        \
: ( 0x0D == ((U8*)s)[0] ) ?                                                 \
    ( ( 0x0A == ((U8*)s)[1] ) ? 2 : 1 )                                     \
: ( 0xC2 == ((U8*)s)[0] ) ?                                                 \
    ( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                                     \
: ( 0xE2 == ((U8*)s)[0] ) ?                                                 \
    ( ( ( 0x80 == ((U8*)s)[1] ) && ( 0xA8 == ((U8*)s)[2] || 0xA9 == ((U8*)s)[2] ) ) ? 3 : 0 )\
: 0 )

/*** GENERATED CODE ***/
#define is_LNBREAK_utf8_safe(s,e)                                           \
( ((e)-(s) > 2) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0C ) ? 1                    \
    : ( 0x0D == ((U8*)s)[0] ) ?                                             \
	( ( 0x0A == ((U8*)s)[1] ) ? 2 : 1 )                                 \
    : ( 0xC2 == ((U8*)s)[0] ) ?                                             \
	( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                                 \
    : ( 0xE2 == ((U8*)s)[0] ) ?                                             \
	( ( ( 0x80 == ((U8*)s)[1] ) && ( 0xA8 == ((U8*)s)[2] || 0xA9 == ((U8*)s)[2] ) ) ? 3 : 0 )\
    : 0 )                                                                   \
: ((e)-(s) > 1) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0C ) ? 1                    \
    : ( 0x0D == ((U8*)s)[0] ) ?                                             \
	( ( 0x0A == ((U8*)s)[1] ) ? 2 : 1 )                                 \
    : ( 0xC2 == ((U8*)s)[0] ) ?                                             \
	( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                                 \
    : 0 )                                                                   \
: ((e)-(s) > 0) ?                                                           \
    ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D )                          \
: 0 )

/*** GENERATED CODE ***/
#define is_LNBREAK_latin1(s)                                                \
( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0C ) ? 1                        \
: ( 0x0D == ((U8*)s)[0] ) ?                                                 \
    ( ( 0x0A == ((U8*)s)[1] ) ? 2 : 1 )                                     \
: ( 0x85 == ((U8*)s)[0] ) )

/*** GENERATED CODE ***/
#define is_LNBREAK_latin1_safe(s,e)                                         \
( ((e)-(s) > 1) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0C ) ? 1                    \
    : ( 0x0D == ((U8*)s)[0] ) ?                                             \
	( ( 0x0A == ((U8*)s)[1] ) ? 2 : 1 )                                 \
    : ( 0x85 == ((U8*)s)[0] ) )                                             \
: ((e)-(s) > 0) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) || 0x85 == ((U8*)s)[0] )\
: 0 )

/*
	LNBREAK_CP: Line Break: \R

	0x0A            # LF  | LINE FEED
	0x0B            # VT  | VERTICAL TAB
	0x0C            # FF  | FORM FEED
	0x0D            # CR  | CARRIAGE RETURN
	0x85            # NEL | NEXT LINE
	0x2028          # LINE SEPARATOR
	0x2029          # PARAGRAPH SEPARATOR
*/
/*** GENERATED CODE ***/
#define is_LNBREAK_CP(s,is_utf8)                                            \
( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) ? 1                        \
: ( is_utf8 ) ?                                                             \
    ( ( 0xC2 == ((U8*)s)[0] ) ?                                             \
	( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                                 \
    : ( 0xE2 == ((U8*)s)[0] ) ?                                             \
	( ( ( 0x80 == ((U8*)s)[1] ) && ( 0xA8 == ((U8*)s)[2] || 0xA9 == ((U8*)s)[2] ) ) ? 3 : 0 )\
    : 0 )                                                                   \
: ( 0x85 == ((U8*)s)[0] ) )

/*** GENERATED CODE ***/
#define is_LNBREAK_CP_safe(s,e,is_utf8)                                     \
( ((e)-(s) > 2) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) ? 1                    \
    : ( is_utf8 ) ?                                                         \
	( ( 0xC2 == ((U8*)s)[0] ) ?                                         \
	    ( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                             \
	: ( 0xE2 == ((U8*)s)[0] ) ?                                         \
	    ( ( ( 0x80 == ((U8*)s)[1] ) && ( 0xA8 == ((U8*)s)[2] || 0xA9 == ((U8*)s)[2] ) ) ? 3 : 0 )\
	: 0 )                                                               \
    : ( 0x85 == ((U8*)s)[0] ) )                                             \
: ((e)-(s) > 1) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) ? 1                    \
    : ( is_utf8 ) ?                                                         \
	( ( ( 0xC2 == ((U8*)s)[0] ) && ( 0x85 == ((U8*)s)[1] ) ) ? 2 : 0 )  \
    : ( 0x85 == ((U8*)s)[0] ) )                                             \
: ((e)-(s) > 0) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) ? 1                    \
    : ( !( is_utf8 ) ) ?                                                    \
	( 0x85 == ((U8*)s)[0] )                                             \
    : 0 )                                                                   \
: 0 )

/*** GENERATED CODE ***/
#define is_LNBREAK_CP_utf8(s)                                               \
( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) ? 1                        \
: ( 0xC2 == ((U8*)s)[0] ) ?                                                 \
    ( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                                     \
: ( 0xE2 == ((U8*)s)[0] ) ?                                                 \
    ( ( ( 0x80 == ((U8*)s)[1] ) && ( 0xA8 == ((U8*)s)[2] || 0xA9 == ((U8*)s)[2] ) ) ? 3 : 0 )\
: 0 )

/*** GENERATED CODE ***/
#define is_LNBREAK_CP_utf8_safe(s,e)                                        \
( ((e)-(s) > 2) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) ? 1                    \
    : ( 0xC2 == ((U8*)s)[0] ) ?                                             \
	( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                                 \
    : ( 0xE2 == ((U8*)s)[0] ) ?                                             \
	( ( ( 0x80 == ((U8*)s)[1] ) && ( 0xA8 == ((U8*)s)[2] || 0xA9 == ((U8*)s)[2] ) ) ? 3 : 0 )\
    : 0 )                                                                   \
: ((e)-(s) > 1) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) ? 1                    \
    : ( 0xC2 == ((U8*)s)[0] ) ?                                             \
	( ( 0x85 == ((U8*)s)[1] ) ? 2 : 0 )                                 \
    : 0 )                                                                   \
: ((e)-(s) > 0) ?                                                           \
    ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D )                          \
: 0 )

/*** GENERATED CODE ***/
#define is_LNBREAK_CP_latin1(s)                                             \
( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) || 0x85 == ((U8*)s)[0] )

/*** GENERATED CODE ***/
#define is_LNBREAK_CP_latin1_safe(s,e)                                      \
( ((e)-(s) > 0) ?                                                           \
    ( ( 0x0A <= ((U8*)s)[0] && ((U8*)s)[0] <= 0x0D ) || 0x85 == ((U8*)s)[0] )\
: 0 )

/*** GENERATED CODE ***/
#define is_LNBREAK_CP_cp(cp)                                                \
( ( 0x0A <= cp && cp <= 0x0D ) || ( 0x0D < cp &&                            \
( 0x85 == cp || ( 0x85 < cp &&                                              \
( 0x2028 == cp || ( 0x2028 < cp &&                                          \
0x2029 == cp ) ) ) ) ) )

/* ex: set ro: */
