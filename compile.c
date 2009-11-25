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

/* Saves the instruction index difference to the pparg of the "instr_from_index" added instruction */
void
S_save_instr_from_to_pparg(pTHX_ CODESEQ* codeseq, int instr_from_index, int instr_to_index)
{
    codeseq->xcodeseq_instructions[instr_from_index].instr_arg1 = (void*)(instr_to_index - instr_from_index - 1);
}

/* executes the instruction given to it, and returns the SV pushed on the stack by it.
   if C<list> is true, items added to the stack are returned as an AV.
   NULL is returned if an error occured during execution.
   The caller is responsible for decrementing the reference count of the returned SV.
 */
SV*
S_instr_fold_constants(pTHX_ INSTRUCTION* instr, OP* o, bool list)
{
    dVAR;
    SV * VOL sv = NULL;
    int ret = 0;
    I32 oldscope;
    SV * const oldwarnhook = PL_warnhook;
    SV * const olddiehook  = PL_diehook;
    const INSTRUCTION* VOL old_next_instruction = run_get_next_instruction();
    I32 oldsp = PL_stack_sp - PL_stack_base;
    dJMPENV;

    DEBUG_g( Perl_deb("Constant folding "); dump_op_short(o); PerlIO_printf(Perl_debug_log, "\n") );

    oldscope = PL_scopestack_ix;

    PL_op = o;
    create_eval_scope(G_FAKINGEVAL);

    PL_warnhook = PERL_WARNHOOK_FATAL;
    PL_diehook  = NULL;
    JMPENV_PUSH(ret);

    switch (ret) {
    case 0:
	if (list) {
	    PUSHMARK(PL_stack_sp);
	}
	RUN_SET_NEXT_INSTRUCTION(instr);
	CALLRUNOPS(aTHX);
	if (list) {
	    SV** spi;
	    AV* av = newAV();
	    for (spi = PL_stack_base + oldsp + 1; spi <= PL_stack_sp; spi++)
		av_push(av, newSVsv(*spi));
	    PL_stack_sp = PL_stack_base + oldsp;
	    sv = MUTABLE_SV(av);
	}
	else {
	    if (PL_stack_sp - 1 == PL_stack_base + oldsp) {
		sv = *(PL_stack_sp--);
		if (o->op_targ && sv == PAD_SV(o->op_targ)) {	/* grab pad temp? */
		    pad_swipe(o->op_targ,  FALSE);
		}
		else if (SvTEMP(sv)) {			/* grab mortal temp? */
		    SvREFCNT_inc_simple_void(sv);
		    SvTEMP_off(sv);
		}
		else {
		    SvREFCNT_inc_simple_void(sv);       /* immortal ? */
		}
	    }
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
    S_add_op(CODESEQ* codeseq, BRANCH_POINT_PAD* bpp, OP* o, bool *may_constant_fold, int flags);

void
S_add_kids(CODESEQ* codeseq, BRANCH_POINT_PAD* bpp, OP* o, bool *may_constant_fold)
{
    if (o->op_flags & OPf_KIDS) {
	OP* kid;
	for (kid=cUNOPo->op_first; kid; kid=kid->op_sibling)
	    S_add_op(codeseq, bpp, kid, may_constant_fold, 0);
    }
}

#define ADDOPf_BOOLEANCONTEXT  1

void
S_add_op(CODESEQ* codeseq, BRANCH_POINT_PAD* bpp, OP* o, bool *may_constant_fold, int flags)
{
    bool kid_may_constant_fold = TRUE;
    int start_idx = bpp->idx;
    bool boolean_context = (flags & ADDOPf_BOOLEANCONTEXT) != 0;

    bpp->recursion++;
    DEBUG_g(
	Perl_deb("%*sCompiling op sequence ", 2*bpp->recursion, "");
	dump_op_short(o);
	    PerlIO_printf(Perl_debug_log, "\n") );
    
    assert(o);

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
	    S_add_op(codeseq, bpp, kid, &kid_may_constant_fold, 0);
	S_append_instruction(codeseq, bpp, o, o->op_type);

	grepstart_idx = bpp->idx-1;

	S_save_branch_point(bpp, &(o->op_unstack_instr));
	S_add_op(codeseq, bpp, cUNOPx(op_block)->op_first, &kid_may_constant_fold, 0);

	S_append_instruction(codeseq, bpp, o, is_grep ? OP_GREPWHILE : OP_MAPWHILE );

	S_save_instr_from_to_pparg(codeseq, grepstart_idx, bpp->idx);

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

	S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold, 0);

	S_append_instruction(codeseq, bpp, o, o->op_type);

	/* true branch */
	S_add_op(codeseq, bpp, op_true, &kid_may_constant_fold, 0);

	jump_idx = bpp->idx;
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);

	/* false branch */
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	S_add_op(codeseq, bpp, op_false, &kid_may_constant_fold, 0);

	S_save_instr_from_to_pparg(codeseq, jump_idx, bpp->idx);

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
	    S_add_op(codeseq, bpp, op_start, &kid_may_constant_fold, 0);
	    cond_jump_idx = bpp->idx;
	    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_cond_jump, NULL);
	}

	S_save_branch_point(bpp, &(cLOOPo->op_redo_instr));
	S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold, 0);

	S_save_branch_point(bpp, &(cLOOPo->op_next_instr));
	if (op_cont)
	    S_add_op(codeseq, bpp, op_cont, &kid_may_constant_fold, 0);

	/* loop */
	if (has_condition) {
	    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, (void*)(start_idx - bpp->idx - 1));

	    S_save_instr_from_to_pparg(codeseq, cond_jump_idx, bpp->idx);
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
		S_add_op(codeseq, bpp, flip->op_first, &kid_may_constant_fold, 0);
		S_add_op(codeseq, bpp, flip->op_first->op_sibling, &kid_may_constant_fold, 0);
	    }
	    else if (op_expr->op_type == OP_REVERSE) {
		S_add_kids(codeseq, bpp, op_expr, &kid_may_constant_fold);
	    }
	    else {
		S_add_op(codeseq, bpp, op_expr, &kid_may_constant_fold, 0);
	    }
	    if (op_sv->op_type != OP_NOTHING)
		S_add_op(codeseq, bpp, op_sv, &kid_may_constant_fold, 0);
	}
	S_append_instruction(codeseq, bpp, o, OP_ENTERITER);

	start_idx = bpp->idx;
	S_append_instruction(codeseq, bpp, o, OP_ITER);

	cond_jump_idx = bpp->idx;
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_cond_jump, NULL);

	S_save_branch_point(bpp, &(cLOOPo->op_redo_instr));
	S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold, 0);

	S_save_branch_point(bpp, &(cLOOPo->op_next_instr));
	S_append_instruction_x(codeseq, bpp, NULL, PL_ppaddr[OP_UNSTACK], NULL);
	if (op_cont)
	    S_add_op(codeseq, bpp, op_cont, &kid_may_constant_fold, 0);

	/* loop */
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
	S_save_instr_from_to_pparg(codeseq, bpp->idx-1, start_idx);

	S_save_instr_from_to_pparg(codeseq, cond_jump_idx, bpp->idx);
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
	    S_add_op(codeseq, bpp, op_other, &kid_may_constant_fold, 0);
	    S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold, 0);
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
	    S_add_op(codeseq, bpp, op_other, &kid_may_constant_fold, 0);

	    S_save_instr_from_to_pparg(codeseq, start_idx, bpp->idx);
	    S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold, 0);

	    S_append_instruction(codeseq, bpp, o, OP_OR);
	}

	break;
    }
    case OP_AND:
    case OP_OR:
    case OP_DOR: {
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
	bool cond_may_constant_fold = TRUE;
	int addop_cond_flags = 0;
	assert((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOGOP);

	if ((o->op_flags & OPf_WANT) == OPf_WANT_VOID)
	    addop_cond_flags |= ADDOPf_BOOLEANCONTEXT;
	S_add_op(codeseq, bpp, op_first, &cond_may_constant_fold, addop_cond_flags);

	S_append_instruction(codeseq, bpp, o, o->op_type);
	S_add_op(codeseq, bpp, op_other, &kid_may_constant_fold, 0);
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	break;
    }
    case OP_ANDASSIGN:
    case OP_ORASSIGN:
    case OP_DORASSIGN: {
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
	bool cond_may_constant_fold = TRUE;
	assert((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOGOP);

	S_add_op(codeseq, bpp, op_first, &cond_may_constant_fold, 0);

	S_append_instruction(codeseq, bpp, o, o->op_type);
	S_add_op(codeseq, bpp, op_other, &kid_may_constant_fold, 0);
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

	S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold, 0);

	start_idx = bpp->idx;
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
		    
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	S_add_op(codeseq, bpp, op_other, &kid_may_constant_fold, 0);
	S_save_instr_from_to_pparg(codeseq, start_idx, bpp->idx);

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
	S_add_op(codeseq, bpp, cLOGOPo->op_first, &kid_may_constant_fold, 0);
	S_append_instruction(codeseq, bpp, o, OP_LEAVETRY);
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	break;
    }
    case OP_RANGE: {
	UNOP* flip = cUNOPx(cLOGOPo->op_first);

	if ((o->op_flags & OPf_WANT) == OPf_WANT_LIST) {
	    /*
	          ...
	          <o->op_first->op_first>
	          <o->op_first->op_first->op_sibling>
	          flop
	          ...
	    */
		  
	    int start_idx = bpp->idx;

	    S_add_op(codeseq, bpp, flip->op_first, &kid_may_constant_fold, 0);
	    S_add_op(codeseq, bpp, flip->op_first->op_sibling, &kid_may_constant_fold, 0);
	    S_append_instruction(codeseq, bpp, o, OP_FLOP);
		
	    if (kid_may_constant_fold) {
		SV* constsv;
		S_append_instruction_x(codeseq, bpp, NULL, PL_ppaddr[OP_INSTR_END], NULL);
		constsv = S_instr_fold_constants(&(codeseq->xcodeseq_instructions[start_idx]), o, TRUE);
		if (constsv) {
		    bpp->idx = start_idx; /* FIXME remove pointer sets from bpp */
		    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_const_list, (void*)constsv);
		    Perl_av_create_and_push(aTHX_ &codeseq->xcodeseq_svs, constsv);
		}
		else {
		    bpp->idx--; /* remove OP_INSTR_END */
		}
	    }

	    break;
	}

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
		  
	S_append_instruction(codeseq, bpp, o, o->op_type);
	S_add_op(codeseq, bpp, flip->op_first, &kid_may_constant_fold, 0);
	S_append_instruction(codeseq, bpp, o, OP_FLIP);
	S_save_branch_point(bpp, &(cLOGOPo->op_other_instr));
	S_add_op(codeseq, bpp, flip->op_first->op_sibling, &kid_may_constant_fold, 0);
	S_append_instruction(codeseq, bpp, o, OP_FLOP);
	S_save_branch_point(bpp, &(cLOGOPo->op_first->op_unstack_instr));
		
	break;
    }
    case OP_REGCOMP:
    {
	OP* op_first = cLOGOPo->op_first;
	if (op_first->op_type == OP_REGCRESET) {
	    S_append_instruction(codeseq, bpp, op_first, op_first->op_type);
	    if (o->op_flags & OPf_STACKED)
		S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	    S_add_op(codeseq, bpp, cUNOPx(op_first)->op_first, &kid_may_constant_fold, 0);
	}
	else {
	    if (o->op_flags & OPf_STACKED)
		S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	    S_add_op(codeseq, bpp, op_first, &kid_may_constant_fold, 0);
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
	S_add_op(codeseq, bpp, op_cond, &kid_may_constant_fold, 0);
	S_append_instruction(codeseq, bpp, o, o->op_type);
	S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold, 0);
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
	    S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold, 0);
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
	    S_add_op(codeseq, bpp, op_cond, &kid_may_constant_fold, 0);
	    S_append_instruction(codeseq, bpp, o, o->op_type);
	    S_add_op(codeseq, bpp, op_block, &kid_may_constant_fold, 0);
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
	    S_add_op(codeseq, bpp, kid, &kid_may_constant_fold, 0);

	S_append_instruction(codeseq, bpp, o, o->op_type);

	start_idx = bpp->idx;
	S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
		    
	S_save_branch_point(bpp, &(cPMOPo->op_pmreplroot_instr));
	S_append_instruction(codeseq, bpp, cPMOPo->op_pmreplrootu.op_pmreplroot, OP_SUBSTCONT);

	S_save_branch_point(bpp, &(cPMOPo->op_pmreplstart_instr));
	if (cPMOPo->op_pmreplrootu.op_pmreplroot)
	    S_add_op(codeseq, bpp, cPMOPo->op_pmreplrootu.op_pmreplroot, &kid_may_constant_fold, 0);

	S_save_branch_point(bpp, &(cPMOPo->op_subst_next_instr));

	S_save_instr_from_to_pparg(codeseq, start_idx, bpp->idx);

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
	OP* kid;
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);

	kid = (o->op_flags & OPf_STACKED && o->op_flags & OPf_SPECIAL) ? cUNOPo->op_first->op_sibling
	    : cUNOPo->op_first;
	for (; kid; kid=kid->op_sibling)
	    S_add_op(codeseq, bpp, kid, &kid_may_constant_fold, 0);

      compile_sort_without_kids:
	{
	    int start_idx;
	    bool has_block = (o->op_flags & OPf_STACKED && o->op_flags & OPf_SPECIAL);

	    S_append_instruction(codeseq, bpp, o, OP_SORT);
	    start_idx = bpp->idx;
	    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_jump, NULL);
	    if (has_block) {
		S_save_branch_point(bpp, &(o->op_unstack_instr));
		S_add_op(codeseq, bpp, cUNOPo->op_first, &kid_may_constant_fold, 0);
		S_append_instruction_x(codeseq, bpp, NULL, PL_ppaddr[OP_INSTR_END], NULL);
	    }
	    S_save_instr_from_to_pparg(codeseq, start_idx, bpp->idx);
	}
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
	S_save_branch_point(bpp, &(o->op_unstack_instr));
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_kids(codeseq, bpp, o, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, o->op_type);
	break;
    }
    case OP_RV2SV:
    {
	if (cUNOPo->op_first->op_type == OP_GV &&
	    !(cUNOPo->op_private & OPpDEREF)) {
	    GV* gv = cGVOPx_gv(cUNOPo->op_first);
	    S_append_instruction_x(codeseq, bpp, o, PL_ppaddr[OP_GVSV], (void*)gv);
	    break;
	}
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
	int start_idx;
	start_idx = bpp->idx;
	S_add_op(codeseq, bpp, op_av, &kid_may_constant_fold, 0);
	S_add_op(codeseq, bpp, op_index, &index_is_constant, 0);
	kid_may_constant_fold = kid_may_constant_fold && index_is_constant;
	if (index_is_constant) {
	    if ((op_av->op_type == OP_PADAV || 
		    (op_av->op_type == OP_RV2AV && cUNOPx(op_av)->op_first->op_type == OP_GV)) &&
		!(o->op_private & (OPpLVAL_INTRO|OPpLVAL_DEFER|OPpDEREF|OPpMAYBE_LVSUB))
		) {
		/* Convert to AELEMFAST */
		SV* const constsv = *(S_svp_const_instruction(codeseq, bpp, bpp->idx-1));
		SvIV_please(constsv);
		if (SvIOKp(constsv)) {
		    IV i = SvIV(constsv) - CopARYBASE_get(PL_curcop);
		    OP* op_arg = op_av->op_type == OP_PADAV ? op_av : cUNOPx(op_av)->op_first;
		    op_arg->op_flags |= o->op_flags & OPf_MOD;
		    op_arg->op_private |= o->op_private & OPpLVAL_DEFER;
		    bpp->idx = start_idx;
		    S_append_instruction_x(codeseq, bpp, op_arg,
			Perl_pp_aelemfast, INT2PTR(void*, i));
		    break;
		}
	    }
	}
	S_append_instruction(codeseq, bpp, o, o->op_type);
	break;
    }
    case OP_HELEM:
    {
	/*
	  [op_hv]
	  [op_index]
	  o->op_type
	*/
	OP* op_hv = cUNOPo->op_first;
	OP* op_key = op_hv->op_sibling;
	bool key_is_constant = TRUE;
	int start_idx;
	int flags = 0;
	if (o->op_flags & OPf_MOD)
	    flags |= INSTRf_HELEM_MOD;
	if (o->op_private & OPpMAYBE_LVSUB)
	    flags |= INSTRf_HELEM_MAYBE_LVSUB;
	if (o->op_private & OPpLVAL_DEFER)
	    flags |= INSTRf_HELEM_LVAL_DEFER;
	if (o->op_private & OPpLVAL_INTRO)
	    flags |= INSTRf_HELEM_LVAL_INTRO;
	if (o->op_flags & OPf_SPECIAL)
	    flags |= INSTRf_HELEM_SPECIAL;
	flags |= (o->op_private & OPpDEREF);

	start_idx = bpp->idx;
	S_add_op(codeseq, bpp, op_hv, &kid_may_constant_fold, 0);
	S_add_op(codeseq, bpp, op_key, &key_is_constant, 0);
	kid_may_constant_fold = kid_may_constant_fold && key_is_constant;
	if (key_is_constant) {
	    SV ** const keysvp = S_svp_const_instruction(codeseq, bpp, bpp->idx-1);
	    STRLEN keylen;
	    const char* key = SvPV_const(*keysvp, keylen);
	    SV* shared_keysv = newSVpvn_share(key,
		                              SvUTF8(*keysvp) ? -(I32)keylen : (I32)keylen,
		                              0);
	    SvREFCNT_dec(*keysvp);
	    *keysvp = shared_keysv;
	}
	S_append_instruction_x(codeseq, bpp, o, PL_ppaddr[o->op_type], (void*)flags);
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
	S_add_op(codeseq, bpp, op_subscript, &kid_may_constant_fold, 0);
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_op(codeseq, bpp, op_listval, &kid_may_constant_fold, 0);
	S_append_instruction(codeseq, bpp, o, OP_LSLICE);
	break;
    }
    case OP_RV2HV: {
	if (boolean_context) {
	    o->op_flags |= ( OPf_REF | OPf_MOD );
	    S_add_kids(codeseq, bpp, o, &kid_may_constant_fold);
	    S_append_instruction(codeseq, bpp, o, OP_RV2HV);
	    S_append_instruction(codeseq, bpp, NULL, OP_BOOLKEYS);
	    break;
	}
	goto compile_default;
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

	OP* inplace_av_op = is_inplace_av(o);
	if (inplace_av_op) {
	    if (inplace_av_op->op_type == OP_SORT) {
		inplace_av_op->op_private |= OPpSORT_INPLACE;
	    
		S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
		S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
		if (inplace_av_op->op_flags & OPf_STACKED && !(inplace_av_op->op_flags & OPf_SPECIAL))
		    S_add_op(codeseq, bpp, cLISTOPx(inplace_av_op)->op_first, &kid_may_constant_fold, 0);
		S_add_op(codeseq, bpp, op_left, &kid_may_constant_fold, 0);

		o = inplace_av_op;
		goto compile_sort_without_kids;
	    }
	    assert(inplace_av_op->op_type == OP_REVERSE);
	    inplace_av_op->op_private |= OPpREVERSE_INPLACE;
	    S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	    S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	    S_add_op(codeseq, bpp, op_left, &kid_may_constant_fold, 0);
	    S_append_instruction(codeseq, bpp, inplace_av_op, OP_REVERSE);
	    break;
	}
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_op(codeseq, bpp, op_right, &kid_may_constant_fold, 0);
	S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_op(codeseq, bpp, op_left, &kid_may_constant_fold, 0);
	S_append_instruction(codeseq, bpp, o, OP_AASSIGN);
	break;
    }
    case OP_STRINGIFY:
    {
	if (cUNOPo->op_first->op_type == OP_CONCAT) {
	    S_add_op(codeseq, bpp, cUNOPo->op_first, &kid_may_constant_fold, 0);
	    break;
	}
	goto compile_default;
    }
    case OP_CONCAT:
    {
	if ((o->op_flags & OPf_STACKED) && cBINOPo->op_last->op_type == OP_READLINE) {
	    /* 	/\* Turn "$a .= <FH>" into an OP_RCATLINE. AMS 20010917 *\/ */
	    S_add_op(codeseq, bpp, cBINOPo->op_first, &kid_may_constant_fold, 0);
	    S_add_kids(codeseq, bpp, cBINOPo->op_last, &kid_may_constant_fold);
	    cBINOPo->op_last->op_type = OP_RCATLINE;
	    cBINOPo->op_last->op_flags |= OPf_STACKED;
	    S_append_instruction(codeseq, bpp, cBINOPo->op_last, OP_RCATLINE);
	    kid_may_constant_fold = FALSE;
	    break;
	}
	goto compile_default;
    }
    case OP_LIST: {
	if ((o->op_flags & OPf_WANT) == OPf_WANT_LIST) {
	    /* don't bother with the pushmark and the pp_list instruction in list context */
	    S_add_kids(codeseq, bpp, o, &kid_may_constant_fold);
	    break;
	}
	goto compile_default;
    }

    case OP_STUB:
	if ((o->op_flags & OPf_WANT) == OPf_WANT_LIST) {
	    break; /* Scalar stub must produce undef.  List stub is noop */
	}
	goto compile_default;

    default: {
      compile_default:
	if (PL_opargs[o->op_type] & OA_MARK)
	    S_append_instruction(codeseq, bpp, NULL, OP_PUSHMARK);
	S_add_kids(codeseq, bpp, o, &kid_may_constant_fold);
	S_append_instruction(codeseq, bpp, o, o->op_type);
	break;
    }
    }

    switch (o->op_type) {
    case OP_CONST:
    case OP_SCALAR:
    case OP_NULL:
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
	break;
    default:
	kid_may_constant_fold = kid_may_constant_fold && (PL_opargs[o->op_type] & OA_FOLDCONST) != 0;
	break;
    }

    if (kid_may_constant_fold && bpp->idx > start_idx + 1) {
    	SV* constsv;
	S_append_instruction_x(codeseq, bpp, NULL, PL_ppaddr[OP_INSTR_END], NULL);
    	constsv = S_instr_fold_constants(&(codeseq->xcodeseq_instructions[start_idx]), o, FALSE);
    	if (constsv) {
    	    bpp->idx = start_idx; /* FIXME remove pointer sets from bpp */
    	    SvREADONLY_on(constsv);
    	    S_append_instruction_x(codeseq, bpp, NULL, Perl_pp_instr_const, (void*)constsv);
    	    Perl_av_create_and_push(aTHX_ &codeseq->xcodeseq_svs, constsv);
    	}
	else {
	    /* constant folding failed */
	    kid_may_constant_fold = FALSE;
	    bpp->idx--; /* remove OP_INSTR_END */
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

    BRANCH_POINT_PAD bpp;

    /* preserve current state */
    PUSHSTACKi(PERLSI_COMPILE);
    ENTER;
    SAVETMPS;

    save_scalar(PL_errgv);
    SAVEVPTR(PL_curcop);

    /* create scratch pad */
    Newx(bpp.op_instrpp_list, 128, OP_INSTRPP);
    bpp.idx = 0;
    bpp.op_instrpp_compile = bpp.op_instrpp_list;
    bpp.op_instrpp_append = bpp.op_instrpp_list;
    bpp.op_instrpp_end = bpp.op_instrpp_list + 128;

    PERL_ARGS_ASSERT_COMPILE_OP;
    codeseq->xcodeseq_size = 12;
    Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);

    {
	/* actually compile */
	bool may_constant_fold = TRUE;
	S_add_op(codeseq, &bpp, startop, &may_constant_fold, 0);

	S_append_instruction_x(codeseq, &bpp, NULL, PL_ppaddr[OP_INSTR_END], NULL);
    }

    /* mark remaining instruction with NULL */
    while (bpp.idx < codeseq->xcodeseq_size) {
	codeseq->xcodeseq_instructions[bpp.idx].instr_ppaddr = NULL;
	bpp.idx++;
    }

    {
	/* resolve instruction pointers */
	OP_INSTRPP* i;
	for (i=bpp.op_instrpp_list; i<bpp.op_instrpp_compile; i++) {
	    assert(i->instr_idx != -1);
	    if (i->instrpp)
		*(i->instrpp) = &(codeseq->xcodeseq_instructions[i->instr_idx]);
	}
    }

    DEBUG_G(codeseq_dump(codeseq));

    Safefree(bpp.op_instrpp_list);

    /* restore original state */
    FREETMPS ;
    LEAVE ;
    POPSTACK;
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

/* Checks if o acts as an in-place operator on an array. o points to the
 * assign op. Returns the the in-place operator if available or NULL otherwise */

OP *
S_is_inplace_av(pTHX_ OP *o) {
    OP *oright = cBINOPo->op_first;
    OP *oleft = cBINOPo->op_first->op_sibling;
    OP *sortop;

    PERL_ARGS_ASSERT_IS_INPLACE_AV;

    /* Only do inplace sort in void context */
    assert(o->op_type == OP_AASSIGN);

    if ((o->op_flags & OPf_WANT) != OPf_WANT_VOID)
	return NULL;

    /* check that the sort is the first arg on RHS of assign */

    assert(oright->op_type == OP_LIST);
    oright = cLISTOPx(oright)->op_first;
    if (!oright || oright->op_sibling)
	return NULL;
    if (oright->op_type != OP_SORT && oright->op_type != OP_REVERSE)
	return NULL;
    sortop = oright;
    oright = cLISTOPx(oright)->op_first;
    if (sortop->op_flags & OPf_STACKED)
	oright = oright->op_sibling; /* skip block */

    if (!oright || oright->op_sibling)
	return NULL;

    /* Check that the LHS and RHS are both assignments to a variable */
    if (!oright ||
    	(oright->op_type != OP_RV2AV && oright->op_type != OP_PADAV)
    	|| (oright->op_private & OPpLVAL_INTRO)
    )
    	return NULL;

    assert(oleft->op_type == OP_LIST);
    oleft = cLISTOPx(oleft)->op_first;
    if (!oleft || oleft->op_sibling)
	return NULL;

    if ((oleft->op_type != OP_PADAV && oleft->op_type != OP_RV2AV)
	|| (oleft->op_private & OPpLVAL_INTRO)
	)
	return NULL;

    /* check the array is the same on both sides */
    if (oleft->op_type == OP_RV2AV) {
    	if (oright->op_type != OP_RV2AV
    	    || !cUNOPx(oright)->op_first
    	    || cUNOPx(oright)->op_first->op_type != OP_GV
    	    || cGVOPx_gv(cUNOPx(oleft)->op_first) !=
    	       cGVOPx_gv(cUNOPx(oright)->op_first)
    	)
    	    return NULL;
    }
    else if (oright->op_type != OP_PADAV
    	|| oright->op_targ != oleft->op_targ
    )
    	return NULL;

    return sortop;
}

SV**
S_svp_const_instruction(pTHX_ CODESEQ *codeseq, BRANCH_POINT_PAD *bpp, int instr_index)
{
    INSTRUCTION* instr = &codeseq->xcodeseq_instructions[instr_index];
    PERL_ARGS_ASSERT_SVP_CONST_INSTRUCTION;
    PERL_UNUSED_VAR(bpp);
    if (instr->instr_op) {
	assert(instr->instr_op->op_type == OP_CONST);
	return &cSVOPx_sv(instr->instr_op);
    }
    else {
	return (SV**)& instr->instr_arg1;
    }
}

void
Perl_compile_cv(pTHX_ CV* cv)
{
    PAD* oldpad;
    AV * const cvpad = (AV *)*av_fetch(CvPADLIST(cv), 1, FALSE);

    PERL_ARGS_ASSERT_COMPILE_CV;

    if (CvCODESEQ(cv))
	return;

    CvCODESEQ(cv) = new_codeseq();

    PAD_SAVE_LOCAL(oldpad, cvpad);

    compile_op(CvROOT(cv), CvCODESEQ(cv));

    PAD_RESTORE_LOCAL(oldpad);
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
