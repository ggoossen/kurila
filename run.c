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
    assert(PL_run_next_instruction);

    do {
	const INSTRUCTION* instr = PL_run_next_instruction;
	PERL_ASYNC_CHECK();
	PL_run_next_instruction++;
	PL_op = instr->instr_op;
	CALL_FPTR(instr->instr_ppaddr)(aTHX_ instr->instr_arg);
    } while (PL_run_next_instruction && PL_run_next_instruction->instr_ppaddr);

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
	if (cxstack[cxstack_ix+1].blk_eval.cur_top_env == PL_top_env) {
	    if (run_get_next_instruction())
		CALLRUNOPS(aTHX);
	    return 0;
	}
	break;
    default:
	assert(0);
    }
    return 3;
}

int
Perl_runops_debug(pTHX)
{
    dVAR;
    assert(PL_run_next_instruction);
    if (!PL_run_next_instruction->instr_ppaddr) {
	/* Perl_ck_warner_d(aTHX_ packWARN(WARN_DEBUGGING), "NULL OP IN RUN"); */
	return 0;
    }

    DEBUG_l(Perl_deb(aTHX_ "Entering new RUNOPS level\n"));
    do {
	const INSTRUCTION* instr = PL_run_next_instruction;
	PERL_ASYNC_CHECK();
	assert(PL_stack_base[0] == &PL_sv_undef);
	assert(PL_stack_sp >= PL_stack_base);
	if (PL_debug) {
	    runop_debug();
	}
	PL_run_next_instruction++;
	PL_op = instr->instr_op;
	CALL_FPTR(instr->instr_ppaddr)(aTHX_ instr->instr_arg);
    } while (PL_run_next_instruction && PL_run_next_instruction->instr_ppaddr);
    DEBUG_l(Perl_deb(aTHX_ "leaving RUNOPS level\n"));

    TAINT_NOT;
    return 0;
}

void
Perl_run_exec_codeseq(pTHX_ const CODESEQ* codeseq)
{
    const INSTRUCTION* old_next_instruction;
    old_next_instruction = run_get_next_instruction();
    RUN_SET_NEXT_INSTRUCTION(codeseq_start_instruction(codeseq));

    CALLRUNOPS(aTHX);

    PL_run_next_instruction = old_next_instruction;
}

const INSTRUCTION*
Perl_run_get_next_instruction(pTHX)
{
    return PL_run_next_instruction;
}

void
Perl_run_set_next_instruction(pTHX_ const INSTRUCTION* instr)
{
    /* assert(instr); */
    PL_run_next_instruction = instr;
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
