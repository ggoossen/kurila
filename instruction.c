/*    compile.c
 *
 *    Copyright (C) 2009 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

#include "EXTERN.h"
#define PERL_IN_INSTRUCTION_C
#include "perl.h"

INSTRUCTION*
Perl_codeseq_start_instruction(pTHX_ const CODESEQ* codeseq)
{
    PERL_ARGS_ASSERT_CODESEQ_START_INSTRUCTION;
    return codeseq->xcodeseq_instructions;
}

void
Perl_codeseq_refcnt_inc(pTHX_ CODESEQ* codeseq)
{
    PERL_ARGS_ASSERT_CODESEQ_REFCNT_INC;
    ++codeseq->xcodeseq_refcnt;
}

void
Perl_codeseq_refcnt_dec(pTHX_ CODESEQ* codeseq)
{
    if (!codeseq)
	return;
    if (--codeseq->xcodeseq_refcnt == 0)
	free_codeseq(codeseq);
}

CODESEQ*
Perl_new_codeseq(pTHX)
{
    CODESEQ* codeseq;
    Newxz(codeseq, 1, CODESEQ);
    codeseq->xcodeseq_refcnt = 1;
    return codeseq;
}

STATIC void
S_free_codeseq(pTHX_ CODESEQ* codeseq)
{
    int i;
    SvREFCNT_dec(codeseq->xcodeseq_svs);
    Safefree(codeseq->xcodeseq_instructions);
    for (i=0; i<codeseq->xcodeseq_allocated_data_size; i++)
	Safefree(codeseq->xcodeseq_allocated_data_list[i]);
    Safefree(codeseq->xcodeseq_allocated_data_list);
    Safefree(codeseq);
}

const char*
Perl_instruction_name(pTHX_ const INSTRUCTION* instr)
{
    Optype optype;
    if (!instr)
	return "(null)";
    if (!instr->instr_ppaddr)
	return "(finished)";

    for (optype = 0; optype < OP_max; optype++) {
	if (PL_ppaddr[optype] == instr->instr_ppaddr) {
	    return PL_op_name[optype];
	}
    }
    return "(unknown)";
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
