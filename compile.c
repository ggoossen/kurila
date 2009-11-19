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
    int idx;
    OP_INSTRPP* op_instrpp_compile;
    OP_INSTRPP* op_instrpp_list;
    OP_INSTRPP* op_instrpp_end;
    OP_INSTRPP* op_instrpp_append;
};
typedef struct branch_point_pad BRANCH_POINT_PAD;

void
S_append_branch_point(pTHX_ BRANCH_POINT_PAD* bpp, OP* o, INSTRUCTION** instrp)
{
    DEBUG_g(Perl_deb("adding branch point "); dump_op_short(o); Perl_deb("\n"));
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
S_append_instruction_x(pTHX_ CODESEQ* codeseq, BRANCH_POINT_PAD* bpp, OP* o, Perl_ppaddr_t ppaddr, void* instr_arg1)
{
    codeseq->xcodeseq_instructions[bpp->idx].instr_ppaddr = ppaddr;
    codeseq->xcodeseq_instructions[bpp->idx].instr_op = o;
    codeseq->xcodeseq_instructions[bpp->idx].instr_arg1 = instr_arg1;

    bpp->idx++;
    if (bpp->idx >= codeseq->xcodeseq_size) {
	codeseq->xcodeseq_size += 32;
	Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);
    }

}

void
S_append_instruction(pTHX_ CODESEQ* codeseq, BRANCH_POINT_PAD* bpp, OP* o, Optype optype)
{
    S_append_instruction_x(codeseq, bpp, o, PL_ppaddr[optype], NULL);
}

void
S_register_branch_point(pTHX_ BRANCH_POINT_PAD* bpp, OP* o)
{
    DEBUG_g(Perl_deb("registering branch point "); dump_op_short(o); Perl_deb("\n"));
    if (bpp->op_instrpp_append >= bpp->op_instrpp_end) {
	OP_INSTRPP* old_lp = bpp->op_instrpp_list;
	int new_size = 128 + (bpp->op_instrpp_end - bpp->op_instrpp_list);
	Renew(bpp->op_instrpp_list, new_size, OP_INSTRPP);
	bpp->op_instrpp_end = bpp->op_instrpp_list + new_size;
	bpp->op_instrpp_compile = bpp->op_instrpp_list + (bpp->op_instrpp_compile - old_lp);
	bpp->op_instrpp_append = bpp->op_instrpp_list + (bpp->op_instrpp_append - old_lp);
    }
    assert(bpp->op_instrpp_append < bpp->op_instrpp_end);
    bpp->op_instrpp_append->op = bpp->op_instrpp_compile->op;
    bpp->op_instrpp_append->instrpp = bpp->op_instrpp_compile->instrpp;
    bpp->op_instrpp_append->instr_idx = bpp->op_instrpp_compile->instr_idx;
    bpp->op_instrpp_append++;

    bpp->op_instrpp_compile->op = o;
    bpp->op_instrpp_compile->instrpp = NULL;
    bpp->op_instrpp_compile->instr_idx = bpp->idx;
    bpp->op_instrpp_compile++;
}

void
S_save_branch_point(pTHX_ BRANCH_POINT_PAD* bpp, INSTRUCTION** instrp)
{
    DEBUG_g(Perl_deb("registering branch point "); Perl_deb("\n"));
    if (bpp->op_instrpp_append >= bpp->op_instrpp_end) {
	OP_INSTRPP* old_lp = bpp->op_instrpp_list;
	int new_size = 128 + (bpp->op_instrpp_end - bpp->op_instrpp_list);
	Renew(bpp->op_instrpp_list, new_size, OP_INSTRPP);
	bpp->op_instrpp_end = bpp->op_instrpp_list + new_size;
	bpp->op_instrpp_compile = bpp->op_instrpp_list + (bpp->op_instrpp_compile - old_lp);
	bpp->op_instrpp_append = bpp->op_instrpp_list + (bpp->op_instrpp_append - old_lp);
    }
    assert(bpp->op_instrpp_append < bpp->op_instrpp_end);
    bpp->op_instrpp_append->op = bpp->op_instrpp_compile->op;
    bpp->op_instrpp_append->instrpp = bpp->op_instrpp_compile->instrpp;
    bpp->op_instrpp_append->instr_idx = bpp->op_instrpp_compile->instr_idx;
    bpp->op_instrpp_append++;

    bpp->op_instrpp_compile->op = NULL;
    bpp->op_instrpp_compile->instrpp = instrp;
    bpp->op_instrpp_compile->instr_idx = bpp->idx;
    bpp->op_instrpp_compile++;
}

int
S_find_branch_point(pTHX_ BRANCH_POINT_PAD* bpp, OP* o)
{
    OP_INSTRPP* i;
    for (i=bpp->op_instrpp_list; i<bpp->op_instrpp_compile; i++) {
	if (o == i->op)
	    return i->instr_idx;
    }
    return -1;
}

void
S_add_op(CODESEQ* codeseq, BRANCH_POINT_PAD* bpp, OP* o)
{

    DEBUG_g(Perl_deb("Compiling op sequence "); dump_op_short(o); Perl_deb("\n"));
    
    while (o) {
	    DEBUG_g(Perl_deb("Compiling op "); dump_op_short(o); Perl_deb("\n"));

	    switch (o->op_type) {
	    case OP_GREPSTART:
	    case OP_MAPSTART: {
		/*
		      ...
		      pushmark
		      <o->op_start>
		      grepstart         label2
		  label1:
		      <o->op_more_op>
		      grepwhile         label1
		  label2:
		      ...
		*/
		bool is_grep = o->op_type == OP_GREPSTART;
		int grepstart_idx;
		S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
		S_add_op(codeseq, bpp, o->op_start);
		S_append_instruction(codeseq, bpp, o, o->op_type);

		grepstart_idx = bpp->idx-1;

		S_save_branch_point(bpp, &(o->op_unstack_instr));
		S_add_op(codeseq, bpp, o->op_more_op);

		S_append_instruction(codeseq, bpp, o, is_grep ? OP_GREPWHILE : OP_MAPWHILE );

		S_register_branch_point(bpp, o->op_next);

		codeseq->xcodeseq_instructions[grepstart_idx].instr_arg1 = (void*)(bpp->idx - grepstart_idx - 1);

		break;
	    }
	    case OP_COND_EXPR: {
		/*
		      ...
		      cond_expr                label1
		      <cLOGOPo->op_op_other>
		      instr_jump               label2
		  label1:
		      <cLOGOPo->op_start>
		  label2:
		      ...
		*/
		int jump_idx;
		S_append_instruction(codeseq, bpp, o, o->op_type);

		/* true branch */
		S_add_op(codeseq, bpp, cLOGOPo->op_other);
		S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
		jump_idx = bpp->idx-1;

		/* false branch */
		S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
		S_add_op(codeseq, bpp, cLOGOPo->op_start);

		S_register_branch_point(bpp, o->op_next);

		codeseq->xcodeseq_instructions[jump_idx].instr_arg1 = (void*)(bpp->idx - jump_idx - 1);
		break;
	    }
	    case OP_ENTERLOOP: {
		/*
		      ...
		      enterloop         last=label3 redo=label4 next=label5
		  label1:
		      <op_start>
		      instr_cond_jump   label2
		  label4:
		      <op_block>
		  label5:
		      <op_cont>
		      instr_jump        label1
		  label2:
		      leaveloop
		  label3:
		      ...
		*/
		int start_idx;
		int cond_jump_idx;
		OP* op_start = cLOOPo->op_first;
		OP* op_block = op_start->op_sibling;
		OP* op_cont = op_block->op_sibling;
		bool has_condition = op_start->op_type != OP_NOTHING;
		S_append_instruction(codeseq, bpp, o, o->op_type);

		/* evaluate condition */
		start_idx = bpp->idx;
		if (has_condition) {
		    S_add_op(codeseq, bpp, sequence_op(op_start));
		    cond_jump_idx = bpp->idx;
		    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_cond_jump, NULL);
		}

		S_save_branch_point(bpp, &(cLOOPo->op_redo_instr));
		S_add_op(codeseq, bpp, sequence_op(op_block));

		S_save_branch_point(bpp, &(cLOOPo->op_next_instr));
		S_add_op(codeseq, bpp, sequence_op(op_cont));

		/* loop */
		if (has_condition) {
		    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, (void*)(start_idx - bpp->idx - 1));

		    codeseq->xcodeseq_instructions[cond_jump_idx].instr_arg1 = (void*)(bpp->idx - cond_jump_idx - 1);
		}
		
		S_append_instruction(codeseq, bpp, o, OP_LEAVELOOP);

		S_save_branch_point(bpp, &(cLOOPo->op_last_instr));
		break;
	    }
	    case OP_FOREACH: {
		/*
		      ...
		      <op_expr>
		      <op_sv>
		      enteriter         redo=label_redo  next=label_next  last=label_last
                  label_start:
		      iter
		      and               label_leave
		  label_redo:
		      <op_block>
		  label_next:
		      unstack
		      <op_cont>
		      instr_jump        label_start
		  label_leave:
		      leaveloop
                  label_last:
		      ...
		*/
		int start_idx;
		int cond_jump_idx;
		OP* op_expr = cLOOPo->op_first;
		OP* op_sv = op_expr->op_sibling;
		OP* op_block = op_sv->op_sibling;
		OP* op_cont = op_block->op_sibling;

		{
		    if (op_expr->op_type == OP_RANGE) {
			/* Basically turn for($x..$y) into the same as for($x,$y), but we
			 * set the STACKED flag to indicate that these values are to be
			 * treated as min/max values by 'pp_iterinit'.
			 */
			LOGOP* const range = (LOGOP*)op_expr;
			UNOP* const flip = cUNOPx(range->op_first);
			S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
			S_add_op(codeseq, bpp, sequence_op(flip->op_first));
			S_add_op(codeseq, bpp, sequence_op(flip->op_first->op_sibling));
			o->op_flags |= OPf_STACKED; /* FIXME manipulation of the optree */
		    }
		    else {
			S_add_op(codeseq, bpp, sequence_op(op_expr));
		    }
		    if (op_sv->op_type != OP_NOTHING)
			S_add_op(codeseq, bpp, sequence_op(op_sv));
		}
		S_append_instruction(codeseq, bpp, o, OP_ENTERITER);

		start_idx = bpp->idx;
		S_append_instruction(codeseq, bpp, o, OP_ITER);

		cond_jump_idx = bpp->idx;
		S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_cond_jump, NULL);

		S_save_branch_point(bpp, &(cLOOPo->op_redo_instr));
		S_add_op(codeseq, bpp, sequence_op(op_block));

		S_save_branch_point(bpp, &(cLOOPo->op_next_instr));
		S_append_instruction_x(codeseq, bpp, NULL, PL_ppaddr[OP_UNSTACK], NULL);
		S_add_op(codeseq, bpp, sequence_op(op_cont));

		/* loop */
		S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, (void*)(start_idx - bpp->idx - 1));

		codeseq->xcodeseq_instructions[cond_jump_idx].instr_arg1 = (void*)(bpp->idx - cond_jump_idx - 1);
		S_append_instruction_x(codeseq, bpp, NULL, PL_ppaddr[OP_LEAVELOOP], NULL);

		S_save_branch_point(bpp, &(cLOOPo->op_last_instr));
		
		break;
	    }
	    case OP_WHILE_AND: {
		if (o->op_private & OPpWHILE_AND_ONCE) {
		    /*
                          ...
		      label1:
		          <cLOGOPo->op_other>
		          <cLOGOPo->op_start>
		          or                   label1
		          ...
		    */
		    S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
		    S_add_op(codeseq, bpp, cLOGOPo->op_other);
		    S_add_op(codeseq, bpp, cLOGOPo->op_start);
		    S_append_instruction(codeseq, bpp, o, OP_OR);
		}
		else {
		    /*
                          ...
			  instr_jump           label2
		      label1:
		          <cLOGOPo->op_other>
	              label2:
		          <cLOGOPo->op_start>
		          or                   label1
		          ...
		    */
		    int start_idx;
		    start_idx = bpp->idx;
		    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
		    S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
		    S_add_op(codeseq, bpp, cLOGOPo->op_other);
		    codeseq->xcodeseq_instructions[start_idx].instr_arg1 = (void*)(bpp->idx - start_idx - 1);
		    S_add_op(codeseq, bpp, cLOGOPo->op_start);
		    S_append_instruction(codeseq, bpp, o, OP_OR);
		}

		break;
	    }
	    case OP_AND:
	    case OP_ANDASSIGN:
	    case OP_OR:
	    case OP_ORASSIGN:
	    case OP_DOR:
	    case OP_DORASSIGN:
	    {
		/*
                      ...
		      <o->op_start>
		      o->op_type            label1
		      <cLOGOPo->op_other>
		  label1:
		      ...
		*/
		assert((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOGOP);

		S_add_op(codeseq, bpp, o->op_start);
		S_append_instruction(codeseq, bpp, o, o->op_type);
		S_add_op(codeseq, bpp, cLOGOPo->op_other);
		S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
		break;
	    }
	    case OP_ONCE:
	    {
		/*
                      ...
		      o->op_type            label1
		      <cLOGOPo->op_other>
		      instr_jump            label2
		  label1:
		      <o->op_start>
                  label2:
		      ...
		*/
		int start_idx;
		assert((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOGOP);

		S_append_instruction(codeseq, bpp, o, o->op_type);

		S_add_op(codeseq, bpp, cLOGOPo->op_other);

		start_idx = bpp->idx;
		S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
		    
		S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
		S_add_op(codeseq, bpp, o->op_start);
		codeseq->xcodeseq_instructions[start_idx].instr_arg1 = (void*)(bpp->idx - start_idx - 1);

		break;
	    }
	    case OP_ENTERTRY: {
		/*
                      ...
		      pp_entertry     label1
		      <o->op_first>
		      pp_leavetry
		  label1:
		      ...
		*/
		S_append_instruction(codeseq, bpp, o, OP_ENTERTRY);
		S_add_op(codeseq, bpp, sequence_op(cLOGOPo->op_first));
		S_append_instruction(codeseq, bpp, o, OP_LEAVETRY);
		S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
		break;
	    }
	    case OP_RANGE: {
		/*
                      ...
		      pp_range       label2
                  label1:
		      <o->op_first->op_first>
		      flip           label3
		  label2:
		      <o->op_first->op_first->op_sibling>
		      flop           label1
		  label3:
		      ...
		*/
		  
		UNOP* flip = cUNOPx(cLOGOPo->op_first);
		S_append_instruction(codeseq, bpp, o, o->op_type);
		S_add_op(codeseq, bpp, sequence_op(flip->op_first));
		S_append_instruction(codeseq, bpp, o, OP_FLIP);
		S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
		S_add_op(codeseq, bpp, sequence_op(flip->op_first->op_sibling));
		S_append_instruction(codeseq, bpp, o, OP_FLOP);
		S_save_branch_point(bpp, &(cLOGOPo->op_first->op_unstack_instr));
		
		break;
	    }
	    case OP_REGCOMP:
	    case OP_SUBSTCONT:
	    {
		/*
                      ...
		      o->op_type
		      ...
		*/
		S_append_instruction(codeseq, bpp, o, o->op_type);
		break;
	    }
	    case OP_ENTERGIVEN:
	    case OP_ENTERWHEN:
	    {
		/*
                      ...
		      o->op_type          label1
		      <o->op_first->op_sibling>
		  label1:
		      ...
		*/
		S_append_instruction(codeseq, bpp, o, o->op_type);
		S_add_op(codeseq, bpp, sequence_op(cLOGOPo->op_first->op_sibling));
		S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));

		break;
	    }
	    case OP_SUBST:
	    {
		/*
                      ...
		      pp_subst       label1 label2
		      instr_jump     label3
                  label1:
		      <o->op_pmreplroot>
		      <o->op_pmreplstart>
		  label3:
		      ...
		*/
		  
		int start_idx;
		S_append_instruction(codeseq, bpp, o, o->op_type);

		start_idx = bpp->idx;
		S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
		    
		S_save_branch_point(bpp, &(cPMOPo->op_pmreplroot_instr));
		S_add_op(codeseq, bpp, cPMOPo->op_pmreplrootu.op_pmreplroot);

		S_save_branch_point(bpp, &(cPMOPo->op_pmreplstart_instr));
		S_add_op(codeseq, bpp, cPMOPo->op_pmstashstartu.op_pmreplstart);

		S_save_branch_point(bpp, &(cPMOPo->op_subst_next_instr));
		codeseq->xcodeseq_instructions[start_idx].instr_arg1 = (void*)(bpp->idx - start_idx - 1);
		break;
	    }
	    case OP_SORT:
	    {
		int start_idx;
		S_append_instruction(codeseq, bpp, o, o->op_type);
		start_idx = bpp->idx;
		S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
		if (o->op_flags & OPf_STACKED && o->op_flags & OPf_SPECIAL) {
		    OP *kid = cLISTOPo->op_first->op_sibling;	/* pass pushmark */
		    kid = cUNOPx(kid)->op_first;			/* pass null */
		    kid = cUNOPx(kid)->op_first;			/* pass leave */
		    S_save_branch_point(bpp, &(o->op_unstack_instr));
		    S_add_op(codeseq, bpp, kid);
		    S_append_instruction_x(codeseq, bpp, NULL, NULL, NULL);
		}
		codeseq->xcodeseq_instructions[start_idx].instr_arg1 = (void*)(bpp->idx - start_idx - 1);
		break;
	    }
	    case OP_FORMLINE:
	    {
		/*
                      ...
		  label1:
		      <o->children>
		      o->op_type          label1
		      ...
		*/
		OP* kid;
		S_save_branch_point(bpp, &(o->op_unstack_instr));
		for (kid = cUNOPo->op_first; kid; kid=kid->op_sibling)
		    S_add_op(codeseq, bpp, sequence_op(kid));
		S_append_instruction(codeseq, bpp, o, o->op_type);
		break;
	    }
	    case OP_NULL:
	    {
		break;
	    }
	    case OP_LAST:
	    {
		S_append_instruction(codeseq, bpp, o, o->op_type);
		o = NULL;
		break;
	    }
	    default:
		S_append_instruction(codeseq, bpp, o, o->op_type);
		break;
	    }

	    if (o)
		o = o->op_next;
    }
}

void
Perl_compile_op(pTHX_ OP* startop, CODESEQ* codeseq)
{
    OP* o;

    BRANCH_POINT_PAD bpp;

    Newx(bpp.op_instrpp_list, 128, OP_INSTRPP);
    bpp.idx = 0;
    bpp.op_instrpp_compile = bpp.op_instrpp_list;
    bpp.op_instrpp_append = bpp.op_instrpp_list;
    bpp.op_instrpp_end = bpp.op_instrpp_list + 128;

    PERL_ARGS_ASSERT_COMPILE_OP;
    codeseq->xcodeseq_size = 12;
    Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);

    o = startop;

    do {
	S_add_op(codeseq, &bpp, o);

	codeseq->xcodeseq_instructions[bpp.idx].instr_ppaddr = NULL;
	bpp.idx++;
	if (bpp.idx >= codeseq->xcodeseq_size) {
	    codeseq->xcodeseq_size += 128;
	    Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);
	}

	/* continue compiling remaining branch. */
	{
	    while ( bpp.op_instrpp_compile < bpp.op_instrpp_append ) {
		/* check for already exisiting branch point */
		int idx = S_find_branch_point(&bpp, bpp.op_instrpp_compile->op);
		bpp.op_instrpp_compile->instr_idx = idx;
		if (bpp.op_instrpp_compile->instr_idx == -1)
		    break;
		bpp.op_instrpp_compile++;
	    }
	}

	if (bpp.op_instrpp_compile >= bpp.op_instrpp_append)
	    break;

	assert(0);

	bpp.op_instrpp_compile->instr_idx = bpp.idx;
	o = bpp.op_instrpp_compile->op;
	bpp.op_instrpp_compile++;

    } while(1);

    {
	OP_INSTRPP* i;
	for (i=bpp.op_instrpp_list; i<bpp.op_instrpp_compile; i++) {
	    assert(i->instr_idx != -1);
	    if (i->instrpp)
		*(i->instrpp) = &(codeseq->xcodeseq_instructions[i->instr_idx]);
	}
    }

    while (bpp.idx < codeseq->xcodeseq_size) {
	codeseq->xcodeseq_instructions[bpp.idx].instr_ppaddr = NULL;
	bpp.idx++;
    }

    Safefree(bpp.op_instrpp_list);

    DEBUG_G(codeseq_dump(codeseq));
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
