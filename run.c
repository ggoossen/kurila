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
    OP* oldop = PL_op;
    INSTRUCTION* instr = PL_instruction;
    assert(PL_instruction);

    do {
	PL_op = instr->instr_op;
    } while ((PL_instruction = instr = instr->instr_ppaddr(aTHX)));

    PL_op = oldop;

    TAINT_NOT;
    return 0;
}

int
Perl_runops_debug(pTHX)
{
    dVAR;
    OP* oldop = PL_op;
    INSTRUCTION* instr = PL_instruction;
    assert(PL_instruction);

    DEBUG_l(Perl_deb(aTHX_ "Entering new RUNOPS level\n"));
    do {
	assert(PL_stack_base[0] == &PL_sv_undef);
	assert(PL_stack_sp >= PL_stack_base);
	if (PL_debug) {
	    Perl_runop_debug(aTHX);
	}
	PL_op = instr->instr_op;
    } while ((PL_instruction = instr = instr->instr_ppaddr(aTHX)));
    DEBUG_l(Perl_deb(aTHX_ "leaving RUNOPS level\n"));

    PL_op = oldop;

    TAINT_NOT;
    return 0;
}

void
Perl_run_exec_codeseq(pTHX_ const CODESEQ* codeseq)
{
    INSTRUCTION* old_instruction;
    PERL_ARGS_ASSERT_RUN_EXEC_CODESEQ;
    old_instruction = PL_instruction;
    PL_instruction = codeseq_start_instruction(codeseq);

    CALLRUNOPS(aTHX);

    PL_instruction = old_instruction;
}

INSTRUCTION*
Perl_run_get_next_instruction(pTHX)
{
    return PL_instruction + 1;
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
