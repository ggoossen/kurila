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

struct branch_point_pad {
    OP_INSTRPP* op_instrpp_compile;
    OP_INSTRPP* op_instrpp_list;
    OP_INSTRPP* op_instrpp_end;
    OP_INSTRPP* op_instrpp_append;
};
typedef struct branch_point_pad BRANCH_POINT_PAD;

void
    S_append_branch_point(pTHX_ BRANCH_POINT_PAD* bpp, OP* o, INSTRUCTION** instrp)
{
    DEBUG_x(Perl_deb("adding branch point "); dump_op_short(o); Perl_deb("\n"));
    if (bpp->op_instrpp_append >= bpp->op_instrpp_end) {
	OP_INSTRPP* old_lp = bpp->op_instrpp_list;
	int new_size = 128 + (bpp->op_instrpp_end - bpp->op_instrpp_list);
	Renew(bpp->op_instrpp_list, new_size, OP_INSTRPP);
	bpp->op_instrpp_end = bpp->op_instrpp_list + new_size;
	bpp->op_instrpp_compile = bpp->op_instrpp_list + (bpp->op_instrpp_compile - old_lp);
	bpp->op_instrpp_append = bpp->op_instrpp_list + (bpp->op_instrpp_append - old_lp);
    }
    assert(bpp->op_instrpp_append < bpp->op_instrpp_end);
    bpp->op_instrpp_append->op = o;
    bpp->op_instrpp_append->instrpp = instrp;
    bpp->op_instrpp_append->instr_idx = -1;
    bpp->op_instrpp_append++;
}

void
Perl_compile_op(pTHX_ OP* startop, CODESEQ* codeseq)
{
    OP* o;
    int idx = 0;

    BRANCH_POINT_PAD bpp;

    Newx(bpp.op_instrpp_list, 128, OP_INSTRPP);
    bpp.op_instrpp_compile = bpp.op_instrpp_list;
    bpp.op_instrpp_append = bpp.op_instrpp_list;
    bpp.op_instrpp_end = bpp.op_instrpp_list + 128;

    PERL_ARGS_ASSERT_COMPILE_OP;
    codeseq->xcodeseq_size = 128;
    Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);

    o = startop;

    do {
	while (o) {
	    DEBUG_x(Perl_deb("Compiling op "); dump_op_short(o); Perl_deb("\n"));

	    codeseq->xcodeseq_instructions[idx].instr_ppaddr = PL_ppaddr[o->op_type];
	    codeseq->xcodeseq_instructions[idx].instr_op = o;
	    codeseq->xcodeseq_instructions[idx].instr_arg = NULL;

	    idx++;
	    if (idx >= codeseq->xcodeseq_size) {
		codeseq->xcodeseq_size += 128;
		Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);
	    }

	    /* Save other instruction for retrieval. */
            if (o->op_type == OP_ENTERTRY) {
		S_append_branch_point(&bpp, cLOGOPo->op_other->op_next, &(cLOGOPo->op_other_instr));
            }
            else if ((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOGOP) {
		S_append_branch_point(&bpp, cLOGOPo->op_other, &(cLOGOPo->op_other_instr));
	    }
	    else if (o->op_type == OP_SUBST) {
		S_append_branch_point(&bpp, cPMOPo->op_pmreplrootu.op_pmreplroot, &(cPMOPo->op_pmreplroot_instr));
		S_append_branch_point(&bpp, cPMOPo->op_pmstashstartu.op_pmreplstart, &(cPMOPo->op_pmreplstart_instr));
		S_append_branch_point(&bpp, cPMOPo->op_next, &(cPMOPo->op_subst_next_instr));
	    }
            else if ((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOOP) {
		S_append_branch_point(&bpp, cLOOPo->op_lastop->op_next, &(cLOOPo->op_last_instr));
		S_append_branch_point(&bpp, cLOOPo->op_nextop, &(cLOOPo->op_next_instr));
		S_append_branch_point(&bpp, cLOOPo->op_redoop, &(cLOOPo->op_redo_instr));
	    }
	    else if (o->op_type == OP_GREPSTART || o->op_type == OP_MAPSTART) {
		o = o->op_next;

		S_append_branch_point(&bpp, cLOGOPo->op_other->op_next, &(cLOGOPo->op_other_instr));
	    }
	    else if (o->op_type == OP_LAST) {
		o = NULL;
	    }
	    else if (o->op_type == OP_UNSTACK) {
		S_append_branch_point(&bpp, o->op_next,
		    &(o->op_unstack_instr));
		o = NULL;
	    }

	    if (o)
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
	    while ( bpp.op_instrpp_compile < bpp.op_instrpp_append ) {
		/* check for already exisiting branch point */
		OP_INSTRPP* i;
		for (i=bpp.op_instrpp_list; i<bpp.op_instrpp_compile; i++) {
		    if (bpp.op_instrpp_compile->op == i->op) {
			bpp.op_instrpp_compile->instr_idx = i->instr_idx;
			break;
		    }
		}
		if (bpp.op_instrpp_compile->instr_idx == -1)
		    break;
		bpp.op_instrpp_compile++;
	    }
	}

	if (bpp.op_instrpp_compile >= bpp.op_instrpp_append)
	    break;

	bpp.op_instrpp_compile->instr_idx = idx;
	o = bpp.op_instrpp_compile->op;
	bpp.op_instrpp_compile++;

    } while(1);

    {
	OP_INSTRPP* i;
	for (i=bpp.op_instrpp_list; i<bpp.op_instrpp_compile; i++) {
	    assert(i->instr_idx != -1);
	    *(i->instrpp) = &(codeseq->xcodeseq_instructions[i->instr_idx]);
	}
    }

    Safefree(bpp.op_instrpp_list);

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
