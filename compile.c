/*    compile.c
 *
 *    Copyright (C) 2009 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

#include "EXTERN.h"
#define PERL_IN_COMPILE_C
#include "perl.h"

void
Perl_compile_op(pTHX_ OP* startop, CODESEQ* codeseq)
{
    OP* o;
    int idx = 0;

    PERL_ARGS_ASSERT_COMPILE_OP;
    codeseq->xcodeseq_size = 128;
    Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);

    o = startop;
    while (o) {
        codeseq->xcodeseq_instructions[idx].instr_ppaddr = o->op_ppaddr;
        codeseq->xcodeseq_instructions[idx].instr_op = o;
        idx++;
        if (idx > codeseq->xcodeseq_size) {
            codeseq->xcodeseq_size += 128;
            Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);
        }
        o = o->op_next;
    }
    codeseq->xcodeseq_instructions[idx].instr_ppaddr = NULL;
}

INSTRUCTION*
Perl_codeseq_start_instruction(pTHX_ CODESEQ* codeseq)
{
    PERL_ARGS_ASSERT_CODESEQ_START_INSTRUCTION;
    return codeseq->xcodeseq_instructions;
}

CODESEQ*
Perl_new_codeseq(pTHX)
{
    CODESEQ* codeseq;
    Newxz(codeseq, 1, CODESEQ);
    return codeseq;
}

void
Perl_free_codeseq(pTHX_ CODESEQ* codeseq)
{
    if (!codeseq)
        return;
    Safefree(codeseq->xcodeseq_instructions);
    Safefree(codeseq);
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
