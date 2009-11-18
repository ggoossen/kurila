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
    int recursion;
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

SV*
S_instr_fold_constants(pTHX_ INSTRUCTION* instr, OP *o)
{
    dVAR;
    SV * VOL sv = NULL;
    int ret = 0;
    I32 oldscope;
    SV * const oldwarnhook = PL_warnhook;
    SV * const olddiehook  = PL_diehook;
    const INSTRUCTION* VOL old_next_instruction = run_get_next_instruction();
    dJMPENV;

    oldscope = PL_scopestack_ix;

    PL_op = o;
    create_eval_scope(G_FAKINGEVAL);

    PL_warnhook = PERL_WARNHOOK_FATAL;
    PL_diehook  = NULL;
    JMPENV_PUSH(ret);

    switch (ret) {
    case 0:
	RUN_SET_NEXT_INSTRUCTION(instr);
	CALLRUNOPS(aTHX);
	sv = *(PL_stack_sp--);
	if (o->op_targ && sv == PAD_SV(o->op_targ))	/* grab pad temp? */
	    pad_swipe(o->op_targ,  FALSE);
	else if (SvTEMP(sv)) {			/* grab mortal temp? */
	    SvREFCNT_inc_simple_void(sv);
	    SvTEMP_off(sv);
	}
	break;
    case 3:
	/* Something tried to die.  Abandon constant folding.  */
	/* Pretend the error never happened.  */
	CLEAR_ERRSV();
	break;
    default:
	JMPENV_POP;
	/* Don't expect 1 (setjmp failed) or 2 (something called my_exit)  */
	PL_warnhook = oldwarnhook;
	PL_diehook  = olddiehook;
	assert(0);
	/* XXX note that this croak may fail as we've already blown away
	 * the stack - eg any nested evals */
	Perl_croak(aTHX_ "panic: fold_constants JMPENV_PUSH returned %d", ret);
    }
    JMPENV_POP;
    PL_warnhook = oldwarnhook;
    PL_diehook  = olddiehook;
    if (PL_scopestack_ix > oldscope)
	delete_eval_scope();
    assert(PL_scopestack_ix == oldscope);
    RUN_SET_NEXT_INSTRUCTION(old_next_instruction); 

    return sv;
}

void
    S_add_op(CODESEQ* codeseq, BRANCH_POINT_PAD* bpp, OP* o, bool *may_constant_fold);

void
S_add_kids(CODESEQ* codeseq, BRANCH_POINT_PAD* bpp, OP* o, bool *may_constant_fold)
{
    if (o->op_flags & OPf_KIDS) {
	OP* kid;
	for (kid=cUNOPo->op_first; kid; kid=kid->op_sibling)
	    S_add_op(codeseq, bpp, kid, may_constant_fold);
    }
}

void
S_add_op(CODESEQ* codeseq, BRANCH_POINT_PAD* bpp, OP* o, bool *may_constant_fold)
{
    bool kid_may_constant_fold;
    int start_idx = bpp->idx;

    bpp->recursion++;
    DEBUG_g(
	Perl_deb("%*sCompiling op sequence ", 2*bpp->recursion, "");
	dump_op_short(o);
	    PerlIO_printf(Perl_debug_log, "\n") );
    
    assert(o);

    switch (o->op_type) {
    case OP_CONST:
    case OP_LIST:
    case OP_SCALAR:
    case OP_NULL:
	kid_may_constant_fold = TRUE;
	break;
    case OP_UCFIRST:
    case OP_LCFIRST:
    case OP_UC:
    case OP_LC:
    case OP_SLT:
    case OP_SGT:
    case OP_SLE:
    case OP_SGE:
    case OP_SCMP:
	/* XXX what about the numeric ops? */
	if (PL_hints & HINT_LOCALE)
	    kid_may_constant_fold = FALSE;
	else
	    kid_may_constant_fold = TRUE;
	break;
    default:
	kid_may_constant_fold = (PL_opargs[o->op_type] & OA_FOLDCONST) != 0;
	break;
    }

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
	OP* op_block;
	OP* kid;

	op_block = cLISTOPo->op_first;
	assert(op_block->op_type == OP_NULL);

	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	for (kid=op_block->op_sibling; kid; kid=kid->op_sibling)
	    S_add_op(codeseq, bpp, kid, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, o->op_type);

	grepstart_idx = bpp->idx-1;

	S_save_branch_point(bpp, &(o->op_unstack_instr));
	S_add_op(codeseq, bpp, cUNOPx(op_block)->op_first, &kid_may_constant_fold);

	S_append_instruction(codeseq, bpp, o, is_grep ? OP_GREPWHILE : OP_MAPWHILE );

	codeseq->xcodeseq_instructions[grepstart_idx].instr_arg1 = (void*)(bpp->idx - grepstart_idx - 1);

	break;
    }
    case OP_COND_EXPR: {
	/*
	  ...
	  <op_first>
	  cond_expr                label1
	  <op_true>
	  instr_jump               label2
	  label1:
	  <op_false>
	  label2:
	  ...
	*/
	int jump_idx;
	OP* op_first = cLOGOPo->op_first;
	OP* op_true = op_first->op_sibling;
	OP* op_false = op_true->op_sibling;

	S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold);

	S_append_instruction(codeseq, bpp, o, o->op_type);

	/* true branch */
	S_add_op(codeseq, bpp, op_true, &kid_may_constant_fold);
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
	jump_idx = bpp->idx-1;

	/* false branch */
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	S_add_op(codeseq, bpp, op_false, &kid_may_constant_fold);

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
	    S_add_op(codeseq, bpp, op_start, &kid_may_constant_fold);
	    cond_jump_idx = bpp->idx;
	    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_cond_jump, NULL);
	}

	S_save_branch_point(bpp, &(cLOOPo->op_redo_instr));
	S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold);

	S_save_branch_point(bpp, &(cLOOPo->op_next_instr));
	if (op_cont)
	    S_add_op(codeseq, bpp, op_cont, &kid_may_constant_fold);

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
	      pp_pushmark
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

	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	{
	    if (op_expr->op_type == OP_RANGE) {
		/* Basically turn for($x..$y) into the same as for($x,$y), but we
		 * set the STACKED flag to indicate that these values are to be
		 * treated as min/max values by 'pp_iterinit'.
		 */
		LOGOP* const range = (LOGOP*)op_expr;
		UNOP* const flip = cUNOPx(range->op_first);
		S_add_op(codeseq, bpp, flip->op_first, &kid_may_constant_fold);
		S_add_op(codeseq, bpp, flip->op_first->op_sibling, &kid_may_constant_fold);
		o->op_flags |= OPf_STACKED; /* FIXME manipulation of the optree */
	    }
	    else {
		S_add_op(codeseq, bpp, op_expr, &kid_may_constant_fold);
	    }
	    if (op_sv->op_type != OP_NOTHING)
		S_add_op(codeseq, bpp, op_sv, &kid_may_constant_fold);
	}
	S_append_instruction(codeseq, bpp, o, OP_ENTERITER);

	start_idx = bpp->idx;
	S_append_instruction(codeseq, bpp, o, OP_ITER);

	cond_jump_idx = bpp->idx;
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_cond_jump, NULL);

	S_save_branch_point(bpp, &(cLOOPo->op_redo_instr));
	S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold);

	S_save_branch_point(bpp, &(cLOOPo->op_next_instr));
	S_append_instruction_x(codeseq, bpp, NULL, PL_ppaddr[OP_UNSTACK], NULL);
	if (op_cont)
	    S_add_op(codeseq, bpp, op_cont, &kid_may_constant_fold);

	/* loop */
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, (void*)(start_idx - bpp->idx - 1));

	codeseq->xcodeseq_instructions[cond_jump_idx].instr_arg1 = (void*)(bpp->idx - cond_jump_idx - 1);
	S_append_instruction_x(codeseq, bpp, NULL, PL_ppaddr[OP_LEAVELOOP], NULL);

	S_save_branch_point(bpp, &(cLOOPo->op_last_instr));
		
	break;
    }
    case OP_WHILE_AND: {
	OP* op_first = cLOGOPo->op_first;
	OP* op_other = op_first->op_sibling;
	if (o->op_private & OPpWHILE_AND_ONCE) {
	    /*
	      ...
	      label1:
	      <op_other>
	      <op_first>
	      or                   label1
	      ...
	    */
	    S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	    S_add_op(codeseq, bpp, op_other, &kid_may_constant_fold);
	    S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold);
	    S_append_instruction(codeseq, bpp, o, OP_OR);
	}
	else {
	    /*
	      ...
	      instr_jump           label2
	      label1:
	      <op_other>
	      label2:
	      <op_first>
	      or                   label1
	      ...
	    */
	    int start_idx;
	    start_idx = bpp->idx;
	    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
	    S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	    S_add_op(codeseq, bpp, op_other, &kid_may_constant_fold);
	    codeseq->xcodeseq_instructions[start_idx].instr_arg1 = (void*)(bpp->idx - start_idx - 1);
	    S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold);
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
	  <op_first>
	  o->op_type            label1
	  <op_other>
	  label1:
	  ...
	*/
	OP* op_first = cLOGOPo->op_first;
	OP* op_other = op_first->op_sibling;
	assert((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOGOP);

	S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, o->op_type);
	S_add_op(codeseq, bpp, op_other, &kid_may_constant_fold);
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	break;
    }
    case OP_ONCE:
    {
	/*
	  ...
	  o->op_type            label1
	  <op_first>
	  instr_jump            label2
	  label1:
	  <op_other>
	  label2:
	  ...
	*/
	int start_idx;
	OP* op_first = cLOGOPo->op_first;
	OP* op_other = op_first->op_sibling;
	assert((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOGOP);

	S_append_instruction(codeseq, bpp, o, o->op_type);

	S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold);

	start_idx = bpp->idx;
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
		    
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	S_add_op(codeseq, bpp, op_other, &kid_may_constant_fold);
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
	S_add_op(codeseq, bpp, cLOGOPo->op_first, &kid_may_constant_fold);
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
	S_add_op(codeseq, bpp, flip->op_first, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, OP_FLIP);
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	S_add_op(codeseq, bpp, flip->op_first->op_sibling, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, OP_FLOP);
	S_save_branch_point(bpp, &(cLOGOPo->op_first->op_unstack_instr));
		
	break;
    }
    case OP_REGCOMP:
    {
	OP* op_first = cLOGOPo->op_first;
	if (o->op_flags & OPf_STACKED)
	    S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	if (op_first->op_type == OP_REGCRESET) {
	    S_append_instruction(codeseq, bpp, op_first, op_first->op_type);
	    S_add_op(codeseq, bpp, cUNOPx(op_first)->op_first, &kid_may_constant_fold);
	}
	else {
	    S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold);
	}
	S_append_instruction(codeseq, bpp, o, o->op_type);
	break;
    }
    case OP_ENTERGIVEN:
    {
	/*
	  ...
	  <op_cond>
	  entergiven          label1
	  <op_block>
	  label1:
	  leavegiven
	  ...
	*/
	OP* op_cond = cLOGOPo->op_first;
	OP* op_block = op_cond->op_sibling;
	S_add_op(codeseq, bpp, op_cond, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, o->op_type);
	S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold);
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	S_append_instruction(codeseq, bpp, o, OP_LEAVEGIVEN);

	break;
    }
    case OP_ENTERWHEN:
    {
	if (o->op_flags & OPf_SPECIAL) {
	    /*
	      ...
	      enterwhen          label1
	      <op_block>
	      label1:
	      leavewhen
	      ...
	    */
	    OP* op_block = cLOGOPo->op_first;
	    S_append_instruction(codeseq, bpp, o, o->op_type);
	    S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold);
	    S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	    S_append_instruction(codeseq, bpp, o, OP_LEAVEWHEN);
	}
	else {
	    /*
	      ...
	      <op_cond>
	      enterwhen          label1
	      <op_block>
	      label1:
	      leavewhen
	      ...
	    */
	    OP* op_cond = cLOGOPo->op_first;
	    OP* op_block = op_cond->op_sibling;
	    S_add_op(codeseq, bpp, op_cond, &kid_may_constant_fold);
	    S_append_instruction(codeseq, bpp, o, o->op_type);
	    S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold);
	    S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	    S_append_instruction(codeseq, bpp, o, OP_LEAVEWHEN);
	}

	break;
    }
    case OP_SUBST:
    {
	/*
	  ...
	  <kids>
	  pp_subst       label1 label2
	  instr_jump     label3
	  label1:
	  substcont
	  label2:
	  <o->op_pmreplroot>
	  label3:
	  ...
	*/
		  
	int start_idx;
	OP* kid;

	for (kid=cUNOPo->op_first; kid; kid=kid->op_sibling)
	    S_add_op(codeseq, bpp, kid, &kid_may_constant_fold);

	S_append_instruction(codeseq, bpp, o, o->op_type);

	start_idx = bpp->idx;
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
		    
	S_save_branch_point(bpp, &(cPMOPo->op_pmreplroot_instr));
	S_append_instruction(codeseq, bpp, cPMOPo->op_pmreplrootu.op_pmreplroot, OP_SUBSTCONT);

	S_save_branch_point(bpp, &(cPMOPo->op_pmreplstart_instr));
	if (cPMOPo->op_pmreplrootu.op_pmreplroot)
	    S_add_op(codeseq, bpp, cPMOPo->op_pmreplrootu.op_pmreplroot, &kid_may_constant_fold);

	S_save_branch_point(bpp, &(cPMOPo->op_subst_next_instr));
	codeseq->xcodeseq_instructions[start_idx].instr_arg1 = (void*)(bpp->idx - start_idx - 1);
	break;
    }
    case OP_SORT:
    {
	/*
	      ...
	      pp_pushmark
	      [kids]
	      pp_sort               label2
	      instr_jump            label1
          label2:
	      [op_block]
	      (finished)
	  label1:
              ...        
	*/
	int start_idx;
	OP* kid;
	OP* op_block;
	bool has_block = (o->op_flags & OPf_STACKED && o->op_flags & OPf_SPECIAL);

	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);

	op_block = cUNOPo->op_first;
	kid = has_block ? op_block->op_sibling : op_block;
	for (; kid; kid=kid->op_sibling)
	    S_add_op(codeseq, bpp, kid, &kid_may_constant_fold);

	S_append_instruction(codeseq, bpp, o, OP_SORT);
	start_idx = bpp->idx;
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
	if (has_block) {
	    S_save_branch_point(bpp, &(o->op_unstack_instr));
	    S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold);
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
	  pp_pushmark
	  <o->children>
	  o->op_type          label1
	  ...
	*/
	OP* kid;
	S_save_branch_point(bpp, &(o->op_unstack_instr));
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_kids(codeseq, bpp, o, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, o->op_type);
	break;
    }
    case OP_AELEM:
    {
	/*
	  [op_av]
	  [op_index]
	  o->op_type
	*/
	OP* op_av = cUNOPo->op_first;
	OP* op_index = op_av->op_sibling;
	bool index_is_constant = TRUE;
	/* if (op_index->op_type == OP_CONST */
	/*     && ((op_av->op_type == OP_RV2AV  */
	/* 	    && cUNOPx(op_av)->op_first->op_first == OP_GV) */
	/* 	)) { */
	/* } */
	S_add_op(codeseq, bpp, op_av, &index_is_constant);
	S_add_op(codeseq, bpp, op_index, &kid_may_constant_fold);
	kid_may_constant_fold = kid_may_constant_fold && index_is_constant;
	/* if (index_is_constant) { */
	/*     if (op_av->op_type == OP_RV2AV */
	/* 	&& cUNOPx(op_av)->op_first->op_first == OP_GV) { */
	/* 	assert( */
	/* 	/\* Convert to AELEMFAST *\/ */
	/*     } */
	    
	/* } */
	S_append_instruction(codeseq, bpp, o, o->op_type);
	break;
    }
    case OP_DELETE:
    {
	if (o->op_private & OPpSLICE)
	    S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_kids(codeseq, bpp, o, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, OP_DELETE);
	break;
    }
    case OP_LSLICE:
    {
	/*
	      pp_pushmark
	      [op_subscript]
	      pp_pushmark
	      [op_listval]
	      pp_lslice
	*/
	OP* op_subscript = cBINOPo->op_first;
	OP* op_listval = op_subscript->op_sibling;
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_op(codeseq, bpp, op_subscript, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_op(codeseq, bpp, op_listval, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, OP_LSLICE);
	break;
    }
    case OP_REPEAT:
    {
	if (o->op_private & OPpREPEAT_DOLIST)
	    S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_kids(codeseq, bpp, o, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, OP_REPEAT);
	break;
    }
    case OP_NULL:
    case OP_SCALAR:
    case OP_LINESEQ:
    case OP_SCOPE:
    {
	S_add_kids(codeseq, bpp, o, &kid_may_constant_fold);
	break;
    }
    case OP_LAST:
    {
	S_append_instruction(codeseq, bpp, o, o->op_type);
	o = NULL;
	break;
    }
    case OP_NEXTSTATE:
    case OP_DBSTATE:
    {
	S_append_instruction(codeseq, bpp, o, o->op_type);
	PL_curcop = ((COP*)o);
	break;
    }
    case OP_AASSIGN:
    {
	OP* op_right = cBINOPo->op_first;
	OP* op_left = op_right->op_sibling;
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_op(codeseq, bpp, op_right, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_op(codeseq, bpp, op_left, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, OP_AASSIGN);
	break;
    }
    case OP_LIST:
    {
	/* S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK); */
	if (o->op_flags & OPf_KIDS) {
	    OP* kid;
	    for (kid=cUNOPo->op_first; kid; kid=kid->op_sibling) {
		S_add_op(codeseq, bpp, kid, &kid_may_constant_fold);
	    }
	}
	kid_may_constant_fold = FALSE;
	break;
    }
    default:
    {
	if (PL_opargs[o->op_type] & OA_MARK)
	    S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_kids(codeseq, bpp, o, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, o->op_type);
	break;
    }
    }

    if (kid_may_constant_fold && bpp->idx > start_idx + 1) {
    	SV* constsv;
    	codeseq->xcodeseq_instructions[bpp->idx].instr_ppaddr = NULL;
    	constsv = S_instr_fold_constants(&(codeseq->xcodeseq_instructions[start_idx]), o);
    	if (constsv) {
    	    bpp->idx = start_idx; /* FIXME remove pointer sets from bpp */
    	    SvREADONLY_on(constsv);
    	    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_const, (void*)constsv);
    	    Perl_av_create_and_push(aTHX_ &codeseq->xcodeseq_svs, constsv);
    	}
    }

    *may_constant_fold = *may_constant_fold && kid_may_constant_fold;
    bpp->recursion--;
}

/*
=item compile_op
Compiles to op into the codeseq, assumes the pad is setup correctly
*/
void
Perl_compile_op(pTHX_ OP* startop, CODESEQ* codeseq)
{
    dSP;
    OP* o;

    BRANCH_POINT_PAD bpp;

    PUSHSTACKi(PERLSI_COMPILE);
    ENTER;
    SAVETMPS;

    save_scalar(PL_errgv);

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
	bool may_constant_fold = TRUE;
	S_add_op(codeseq, &bpp, o, &may_constant_fold);

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

    FREETMPS ;
    LEAVE ;
    POPSTACK;

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
    SvREFCNT_dec(codeseq->xcodeseq_svs);
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
