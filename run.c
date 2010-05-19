/*    run.c
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999,
 *    2000, 2001, 2004, 2005, 2006, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/* This file contains the main Perl opcode execution loop. It just
 * calls the pp_foo() function associated with each op, and expects that
 * function to return a pointer to the next op to be executed, or null if
 * it's the end of the sub or program or whatever.
 *
 * There is a similar loop in dump.c, Perl_runops_debug(), which does
 * the same, but also checks for various debug flags each time round the
 * loop.
 *
 * Why this function requires a file all of its own is anybody's guess.
 * DAPM.
 */

#include "EXTERN.h"
#define PERL_IN_RUN_C
#include "perl.h"

/*
 * 'Away now, Shadowfax!  Run, greatheart, run as you have never run before!
 *  Now we are come to the lands where you were foaled, and every stone you
 *  know.  Run now!  Hope is in speed!'                    --Gandalf
 *
 *     [p.600 of _The Lord of the Rings_, III/xi: "The Palantír"]
 */

int
Perl_runops_standard(pTHX)
{
    dVAR;
    register OP *op = PL_op;
    while ((PL_op = op = CALL_FPTR(op->op_ppaddr)(aTHX))) {
    }

    TAINT_NOT;
    return 0;
}

int
Perl_runops_continue_from_jmpenv(pTHX_ int ret)
{
    switch (ret) {
    case 1:
	STATUS_ALL_FAILURE;
	/* FALL THROUGH */
    case 2:
	/* my_exit() was called */
	DEBUG_l(Perl_deb(aTHX_ "popping jumplevel was %p, now %p\n",
			 (void*)PL_top_env, (void*)PL_top_env->je_prev));
	PL_top_env = PL_top_env->je_prev;
	JMPENV_JUMP(ret);
	/* NOTREACHED */
	break;
    case 3:
	if (PL_restartop) {
	    PL_restartjmpenv = NULL;
	    PL_op = PL_restartop;
	    PL_restartop = 0;
	    CALLRUNOPS(aTHX);
	    return 0;
	}
	break;
    default:
	assert(0);
    }
    return 3;
}

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
