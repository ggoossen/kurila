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

struct op_instrpp {
    OP* op;
    INSTRUCTION** instrpp;
    int instr_idx;
};

typedef struct op_instrpp OP_INSTRPP;

void
Perl_compile_op(pTHX_ OP* startop, CODESEQ* codeseq)
{
    OP* o;
    int idx = 0;

    OP_INSTRPP* op_instrpp_compile;
    OP_INSTRPP* op_instrpp_list;
    OP_INSTRPP* op_instrpp_end;
    OP_INSTRPP* op_instrpp_append;

    Newx(op_instrpp_list, 128, OP_INSTRPP);
    op_instrpp_compile = op_instrpp_list;
    op_instrpp_append = op_instrpp_list;
    op_instrpp_end = op_instrpp_list + 128;

    PERL_ARGS_ASSERT_COMPILE_OP;
    codeseq->xcodeseq_size = 128;
    Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);

    o = startop;

    do {
	while (o) {
	    codeseq->xcodeseq_instructions[idx].instr_ppaddr = PL_ppaddr[o->op_type];
	    codeseq->xcodeseq_instructions[idx].instr_op = o;

	    /* Save other instruction for retrieval. */
	    if ((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOGOP) {
		assert(op_instrpp_append < op_instrpp_end);
		op_instrpp_append->op = cLOGOPo->op_other;
		op_instrpp_append->instrpp = &(cLOGOPo->op_other_instr);
		op_instrpp_append->instr_idx = -1;
		op_instrpp_append++;
	    }

	    idx++;
	    if (idx >= codeseq->xcodeseq_size) {
		codeseq->xcodeseq_size += 128;
		Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);
	    }
	    o = o->op_next;
	}
	codeseq->xcodeseq_instructions[idx].instr_ppaddr = NULL;
	idx++;
	if (idx >= codeseq->xcodeseq_size) {
	    codeseq->xcodeseq_size += 128;
	    Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);
	}

	/* continue compiling remaining branch. */
	{
	    while ( op_instrpp_compile < op_instrpp_append ) {
		/* check for already exisiting branch point */
		OP_INSTRPP* i;
		for (i=op_instrpp_list; i<op_instrpp_compile; i++) {
		    if (op_instrpp_compile->op == i->op) {
			op_instrpp_compile->instr_idx = i->instr_idx;
			break;
		    }
		}
		if (op_instrpp_compile->instr_idx == -1)
		    break;
		op_instrpp_compile++;
	    }
	}

	if (op_instrpp_compile >= op_instrpp_append)
	    break;

	op_instrpp_compile->instr_idx = idx;
	o = op_instrpp_compile->op;
	op_instrpp_compile++;

    } while(1);

    {
	OP_INSTRPP* i;
	for (i=op_instrpp_list; i<op_instrpp_compile; i++) {
	    assert(i->instr_idx != -1);
	    *(i->instrpp) = &(codeseq->xcodeseq_instructions[i->instr_idx]);
	}
    }

    DEBUG_x(codeseq_dump(codeseq));
}

INSTRUCTION*
Perl_codeseq_start_instruction(pTHX_ const CODESEQ* codeseq)
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

const char*
Perl_instruction_name(pTHX_ const INSTRUCTION* instr)
{
    Optype optype;
    if (!instr)
	return "(null)";
    if (!instr->instr_ppaddr)
	return "(finished)";

    for (optype = 0; optype < OP_CUSTOM; optype++) {
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
