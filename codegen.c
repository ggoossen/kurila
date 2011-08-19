/*    codegen.c
 *
 *    Copyright (C) 2009 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
=head2 Code-generation

The code-generation step is the process of translating the optree in
an instruction list.  The C<compile_op> function translates the
optreee C<o> into a C<codeseq>. This function uses C<add_op>, which
appends the instruction for the C<o> optree branch to the instruction
list in the code generation pad.  By default an optree is converted to
an instruction list by first adding the child branches using C<add_op>
and after that append the instruction for the op.  If a the optype has
a OA_MARK then before the children a "pp_pushmark" instruction is
added.	This is the default which is fine for ops which just operating
on their arguments.  Of course this doesn't work for ops like
conditionals and loops, these ops have their own code generation in
C<compile_op>.

During code-generation the codeseq generated may be realloc so, no
pointers to it can be made.
Also the optree may be shared between threads and may not be modified
in any way.

=head3 Constant folding

C<add_op> has the C<may_constant_fold> argument which should be
set to false if the instructions added to the codesequence may not be
constant folded.

If an op may be constant folded and non of its children sets
C<may_constant_fold> to false, the sequence of instruction then is
converted by executing the instructions for this op and executing
them, and replacing the instruction which a C<instr_const> instruction
with the returned C<SV>.

To handle special cases if there is a constant (or constant folded
op), C<svp_const_instruction> can be used to retrieve the value of the
constant of the last instruction (which should be constant or constant
folded).

=head3 Jump targets

Jumping is done by setting the "next instruction pointer", to save the
instruction C<save_branch_point> which saves the translation point
into the address specified. Note that the during translation the
addresses of the instruction are not yet fixed (they might be
C<realloced>), so the addresses actually writing of the intruction
address to the specified address happens at the end of the
code-generation.

=head3 Pointers to instructions

Because after code-generation the instruction sequence is copied,
pointers to an instruction can not be made during
code-generation. Instead C<save_instr_from_to_pparg> can be used to
save a pointer to an instruction to the instr_arg of an instruction.

=head3 Thread-safety

Because the optree can't be modified during code-generation, arguments
can be added to the instruction, these have the C<void*> type by
default so they should normally be typecasted.

=head3 Debugging

If perl is compiled with C<-DDEBUGGING> the command line options
C<-DG> and C<-Dg> can be used. The C<-DG> option will dump the result
of the code generation after it is finished (note that the labels in
this dump are generation by the dump and only pointers to the
instruction are present in the actual code). The C<-Dg> option will
trace the code generation process.

=cut
*/

#include "EXTERN.h"
#define PERL_IN_CODEGEN_C
#include "perl.h"

struct target_instrpp {
    INSTRUCTION** instrpp;
    int target_idx;
};
typedef struct target_instrpp TARGET_INSTRPP;

struct target_to_pparg {
    int instr_idx;
    int target_idx;
};
typedef struct target_to_pparg TARGET_TO_PPARG;

struct codegen_pad {
    CODESEQ codeseq;
    int idx;
    TARGET_INSTRPP* target_instrpp_list;
    int target_instrpp_size;
    int target_instrpp_used;
    TARGET_TO_PPARG* target_to_pparg_list;
    int target_to_pparg_size;
    int target_to_pparg_used;
    void** allocated_data_list;
    void** allocated_data_end;
    void** allocated_data_append;
    int recursion_depth;
};

void
S_append_instruction(pTHX_ CODEGEN_PAD* bpp, OP* o,
    Optype optype, INSTR_FLAGS instr_flags, void* instr_arg)
{
    PERL_ARGS_ASSERT_APPEND_INSTRUCTION;
    /* +1 to reserve an extra space for an (finished) instruction */
    if (bpp->idx + 1 >= bpp->codeseq.xcodeseq_size) {
	bpp->codeseq.xcodeseq_size += 32;
	Renew(bpp->codeseq.xcodeseq_instructions, bpp->codeseq.xcodeseq_size, INSTRUCTION);
    }
    bpp->codeseq.xcodeseq_instructions[bpp->idx].instr_ppaddr = PL_ppaddr[optype];
    bpp->codeseq.xcodeseq_instructions[bpp->idx].instr_op = o;
    bpp->codeseq.xcodeseq_instructions[bpp->idx].instr_flags = instr_flags;
    bpp->codeseq.xcodeseq_instructions[bpp->idx].instr_arg = instr_arg;

    bpp->idx++;
}

void
S_append_allocated_data(pTHX_ CODEGEN_PAD* bpp, void* data)
{
    PERL_ARGS_ASSERT_APPEND_ALLOCATED_DATA;
    if (bpp->allocated_data_append >= bpp->allocated_data_end) {
	void** old_lp = bpp->allocated_data_list;
	int new_size = 128 + (bpp->allocated_data_end - bpp->allocated_data_list);
	Renew(bpp->allocated_data_list, new_size, void*);
	bpp->allocated_data_end = bpp->allocated_data_list + new_size;
	bpp->allocated_data_append = bpp->allocated_data_list + (bpp->allocated_data_append - old_lp);
    }
    *bpp->allocated_data_append = data;
    bpp->allocated_data_append++;
}

void
S_save_branch_point(pTHX_ CODEGEN_PAD* bpp, INSTRUCTION** instrp)
{
    int idx = bpp->target_instrpp_used;
    PERL_ARGS_ASSERT_SAVE_BRANCH_POINT;
    DEBUG_g(Perl_deb(aTHX_ "registering branch point "); Perl_deb(aTHX_ "\n"));
    if (idx >= bpp->target_instrpp_size) {
	bpp->target_instrpp_size += 128;
	Renew(bpp->target_instrpp_list, bpp->target_instrpp_size, TARGET_INSTRPP);
    }
    bpp->target_instrpp_list[idx].instrpp = instrp;
    bpp->target_instrpp_list[idx].target_idx = bpp->idx;
    bpp->target_instrpp_used++;
}

/* Saves the instruction index difference to the pparg of the "instr_from_index" added instruction */
void
S_save_instr_from_to_pparg(pTHX_ CODEGEN_PAD* codegen_pad, int instr_from_index, int instr_to_index)
{
    int idx = codegen_pad->target_to_pparg_used;
    PERL_ARGS_ASSERT_SAVE_INSTR_FROM_TO_PPARG;
    if (idx >= codegen_pad->target_to_pparg_size) {
	codegen_pad->target_to_pparg_size += 128;
	Renew(codegen_pad->target_to_pparg_list, codegen_pad->target_to_pparg_size, TARGET_TO_PPARG);
    }
    codegen_pad->target_to_pparg_list[idx].instr_idx = instr_from_index;
    codegen_pad->target_to_pparg_list[idx].target_idx = instr_to_index;
    codegen_pad->target_to_pparg_used++;
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
    INSTRUCTION* VOL old_instruction = PL_instruction;
    I32 oldsp = PL_stack_sp - PL_stack_base;
    dJMPENV;

    PERL_ARGS_ASSERT_INSTR_FOLD_CONSTANTS;
    DEBUG_g( Perl_deb(aTHX_ "Constant folding "); dump_op_short(o); PerlIO_printf(Perl_debug_log, "\n") );

    oldscope = PL_scopestack_ix;

    PL_op = o;
    create_eval_scope(G_FAKINGEVAL);

    PL_warnhook = PERL_WARNHOOK_FATAL;
    PL_diehook	= NULL;
    JMPENV_PUSH(ret);

    switch (ret) {
    case 0:
	if (list) {
	    PUSHMARK(PL_stack_sp);
	}
	PL_instruction = instr;
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
		if (o->op_targ && sv == PAD_SV(o->op_targ)) {
		    if (!SvREADONLY(sv)) {
			SV* org_sv = sv;
			sv = newSVsv(org_sv);
			if (SvREADONLY(org_sv))
			    SvREADONLY_on(sv);
		    }
		}
		else if (SvTEMP(sv)) {			/* grab mortal temp */
		    SvREFCNT_inc_simple_void(sv);
		    SvTEMP_off(sv);
		}
		else {
		    SvREFCNT_inc_simple_void(sv);	/* immortal */
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
	/* Don't expect 1 (setjmp failed) or 2 (something called my_exit)
	 * the stack - eg any nested evals */
	Perl_croak(aTHX_ "panic: fold_constants JMPENV_PUSH returned %d", ret);
    }
    JMPENV_POP;
    PL_warnhook = oldwarnhook;
    PL_diehook	= olddiehook;
    if (PL_scopestack_ix > oldscope)
	delete_eval_scope();
    assert(PL_scopestack_ix == oldscope);
    PL_instruction = old_instruction;

    DEBUG_g( Perl_deb(aTHX_ "Constant folded into variable at 0x%p\n", sv); );

    return sv;
}

/*
=for apidoc add_kids

Add the instructions for all children of op C<o> to the codegenpad.

=cut
*/
void
S_add_kids(pTHX_ CODEGEN_PAD* bpp, OP* o, bool *may_constant_fold)
{
    PERL_ARGS_ASSERT_ADD_KIDS;
    if (o->op_flags & OPf_KIDS) {
	OP* kid;
	for (kid=cUNOPo->op_first; kid; kid=kid->op_sibling)
	    add_op(bpp, kid, may_constant_fold, 0);
    }
}

void
S_add_regcomp_op(pTHX_ CODEGEN_PAD* bpp, OP* op_regcomp, OP* pm, bool* kid_may_constant_fold)
{
    OP* op_first = cLOGOPx(op_regcomp)->op_first;
    PERL_ARGS_ASSERT_ADD_REGCOMP_OP;
    if (op_first->op_type == OP_REGCRESET) {
	append_instruction(bpp, op_first, op_first->op_type, 0, NULL);
	if (op_regcomp->op_flags & OPf_STACKED)
	    append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_op(bpp, cUNOPx(op_first)->op_first, kid_may_constant_fold, 0);
    }
    else {
	if (op_regcomp->op_flags & OPf_STACKED)
	    append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_op(bpp, op_first, kid_may_constant_fold, 0);
    }
    append_instruction(bpp, op_regcomp, op_regcomp->op_type, 0, (void*)pm);
}

#define ADDOPf_BOOLEANCONTEXT  1

/*
=for apidoc add_op

Add the instruction branch C<o> to the instruction list.  The
C<ADDOPf_BOOLEANCONTEXT> flag may be set to indicate the instruction
branch was called in boolean context.  The C<may_constant_fold> bool
pointer will be set to false if constant folding isn't allowed,
otherwise it won't be changed. If C<may_constant_fold> is true the
last constant expression can be retreived using
C<svp_const_instruction>.

=cut
*/

void
S_add_op(pTHX_ CODEGEN_PAD* bpp, OP* o, bool *may_constant_fold, int flags)
{
    bool kid_may_constant_fold = TRUE;
    int start_idx = bpp->idx;
    bool boolean_context = (flags & ADDOPf_BOOLEANCONTEXT) != 0;

    PERL_ARGS_ASSERT_ADD_OP;

    bpp->recursion_depth++;
    DEBUG_g(
	Perl_deb(aTHX_ "%*sCompiling op sequence ", 2*bpp->recursion_depth, "");
	dump_op_short(o);
	    PerlIO_printf(Perl_debug_log, "\n") );

    assert(o);

    switch (o->op_type) {
    case OP_GREPSTART:
    case OP_MAPSTART: {
	/*
	      ...
	      pushmark
	      <op_items>
	      grepstart		label2
	  label1:
	      <op_block>
	      grepwhile		label1
	  label2:
	      ...
	*/
	bool is_grep = o->op_type == OP_GREPSTART;
	int grepstart_idx, grepitem_idx;
	OP* op_block;
	OP* kid;

	op_block = cLISTOPo->op_first;

	append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	for (kid=op_block->op_sibling; kid; kid=kid->op_sibling)
	    add_op(bpp, kid, &kid_may_constant_fold, 0);
	grepstart_idx = bpp->idx;
	append_instruction(bpp, o, o->op_type, 0, NULL);

	grepitem_idx = bpp->idx;
	assert(op_block->op_type == OP_NULL);
	add_op(bpp, op_block, &kid_may_constant_fold, 0);

	append_instruction(bpp, o, is_grep ? OP_GREPWHILE : OP_MAPWHILE, 0, NULL );
	save_instr_from_to_pparg(bpp, bpp->idx-1, grepitem_idx);

	save_instr_from_to_pparg(bpp, grepstart_idx, bpp->idx);

	break;
    }
    case OP_COND_EXPR: {
	/*
	      ...
	      <op_first>
	      cond_expr		       label1
	      <op_true>
	      instr_jump	       label2
	  label1:
	      <op_false>
	  label2:
	      ...
	*/
	int jump_idx, cond_expr_idx;
	OP* op_first = cLOGOPo->op_first;
	OP* op_true = op_first->op_sibling;
	OP* op_false = op_true->op_sibling;
	bool cond_may_constant_fold = TRUE;

	add_op(bpp, op_first, &cond_may_constant_fold, 0);

	if (cond_may_constant_fold) {
	    SV* const constsv = *(svp_const_instruction(bpp, bpp->idx-1));
	    bpp->idx--;
	    add_op(bpp, SvTRUE(constsv) ? op_true : op_false , &kid_may_constant_fold, 0);
	    break;
	}

	cond_expr_idx = bpp->idx;
	append_instruction(bpp, o, o->op_type, 0, NULL);

	/* true branch */
	add_op(bpp, op_true, &kid_may_constant_fold, 0);

	jump_idx = bpp->idx;
	append_instruction(bpp, NULL, OP_INSTR_JUMP, 0, NULL);

	/* false branch */
	save_instr_from_to_pparg(bpp, cond_expr_idx, bpp->idx);
	add_op(bpp, op_false, &kid_may_constant_fold, 0);

	save_instr_from_to_pparg(bpp, jump_idx, bpp->idx);

	break;
    }
    case OP_ENTERLOOP: {
	/*
	      ...
	      enterloop		last=label3 redo=label4 next=label5
	  label1:
	      <op_start>
	      instr_cond_jump	label2
	  label4:
	      <op_block>
	  label5:
	      <op_cont>
	      unstack
	      instr_jump	label1
	  label2:
	      leaveloop
	  label3:
	      ...
	*/
	int start_idx;
	int cond_jump_idx = 0;
	OP* op_start = cLOOPo->op_first;
	OP* op_block = op_start->op_sibling;
	OP* op_cont = op_block->op_sibling;
	bool has_condition = op_start->op_type != OP_NOTHING;
	LOOP_INSTRUCTIONS* loop_instrs;
	Newx(loop_instrs, 1, LOOP_INSTRUCTIONS);
	append_allocated_data(bpp, loop_instrs);

	append_instruction(bpp, o, o->op_type, 0, loop_instrs);

	/* evaluate condition */
	start_idx = bpp->idx;
	if (has_condition) {
	    add_op(bpp, op_start, &kid_may_constant_fold, 0);
	    cond_jump_idx = bpp->idx;
	    append_instruction(bpp, NULL, OP_INSTR_COND_JUMP, 0, NULL);
	}

	save_branch_point(bpp, &(loop_instrs->redo_instr));
	add_op(bpp, op_block, &kid_may_constant_fold, 0);

	save_branch_point(bpp, &(loop_instrs->next_instr));
	if (op_cont)
	    add_op(bpp, op_cont, &kid_may_constant_fold, 0);

	/* loop */
	if (has_condition) {
	    append_instruction(bpp, NULL, OP_UNSTACK, INSTRf_UNSTACK_LEAVESCOPE, NULL);
	    append_instruction(bpp, NULL, OP_INSTR_JUMP, 0, NULL);
	    save_instr_from_to_pparg(bpp, bpp->idx-1, start_idx);

	    save_instr_from_to_pparg(bpp, cond_jump_idx, bpp->idx);
	}

	append_instruction(bpp, o, OP_LEAVELOOP, 0, NULL);

	save_branch_point(bpp, &(loop_instrs->last_instr));
	break;
    }
    case OP_FOREACH: {
	/*
	      ...
	      pp_pushmark
	      <op_expr>
	      <op_sv>
	      enteriter		redo=label_redo	 next=label_next  last=label_last
	  label_start:
	      iter
	      and		label_leave
	  label_redo:
	      <op_block>
	  label_next:
	      unstack
	      <op_cont>
	      instr_jump	label_start
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
	LOOP_INSTRUCTIONS* loop_instrs;
	Newx(loop_instrs, 1, LOOP_INSTRUCTIONS);
	append_allocated_data(bpp, loop_instrs);

	append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	{
	    if (op_expr->op_type == OP_RANGE) {
		/* Basically turn for($x..$y) into the same as for($x,$y), but we
		 * set the STACKED flag to indicate that these values are to be
		 * treated as min/max values by 'pp_iterinit'.
		 */
		LOGOP* const range = (LOGOP*)op_expr;
		UNOP* const flip = cUNOPx(range->op_first);
		add_op(bpp, flip->op_first, &kid_may_constant_fold, 0);
		add_op(bpp, flip->op_first->op_sibling, &kid_may_constant_fold, 0);
	    }
	    else if (op_expr->op_type == OP_REVERSE) {
		add_kids(bpp, op_expr, &kid_may_constant_fold);
	    }
	    else {
		add_op(bpp, op_expr, &kid_may_constant_fold, 0);
	    }
	    if (op_sv->op_type != OP_NOTHING)
		add_op(bpp, op_sv, &kid_may_constant_fold, 0);
	}
	append_instruction(bpp, o, OP_ENTERITER, 0, loop_instrs);

	start_idx = bpp->idx;
	append_instruction(bpp, o, OP_ITER, 0, NULL);

	cond_jump_idx = bpp->idx;
	append_instruction(bpp, NULL, OP_INSTR_COND_JUMP, 0, NULL);

	save_branch_point(bpp, &(loop_instrs->redo_instr));
	add_op(bpp, op_block, &kid_may_constant_fold, 0);

	save_branch_point(bpp, &(loop_instrs->next_instr));
	append_instruction(bpp, NULL, OP_UNSTACK, INSTRf_UNSTACK_LEAVESCOPE, NULL);
	if (op_cont)
	    add_op(bpp, op_cont, &kid_may_constant_fold, 0);

	/* loop */
	append_instruction(bpp, NULL, OP_INSTR_JUMP, 0, NULL);
	save_instr_from_to_pparg(bpp, bpp->idx-1, start_idx);

	save_instr_from_to_pparg(bpp, cond_jump_idx, bpp->idx);
	append_instruction(bpp, NULL, OP_LEAVELOOP, 0, NULL);

	save_branch_point(bpp, &(loop_instrs->last_instr));

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
		  unstack
		  <op_first>
		  or		       label1
		  ...
	    */
	    int restart_idx = bpp->idx;
	    add_op(bpp, op_other, &kid_may_constant_fold, 0);
	    append_instruction(bpp, NULL, OP_UNSTACK, 0, NULL);
	    add_op(bpp, op_first, &kid_may_constant_fold, 0);
	    append_instruction(bpp, o, OP_OR, 0, NULL);
	    save_instr_from_to_pparg(bpp, bpp->idx-1, restart_idx);
	}
	else {
	    /*
		  ...
		  instr_jump	       label2
	      label1:
		  <op_other>
		  unstack
	      label2:
		  <op_first>
		  or		       label1
		  ...
	    */
	    int start_idx, restart_idx;
	    start_idx = bpp->idx;
	    append_instruction(bpp, NULL, OP_INSTR_JUMP, 0, NULL);

	    restart_idx = bpp->idx;
	    add_op(bpp, op_other, &kid_may_constant_fold, 0);
	    append_instruction(bpp, NULL, OP_UNSTACK, 0, NULL);

	    save_instr_from_to_pparg(bpp, start_idx, bpp->idx);
	    add_op(bpp, op_first, &kid_may_constant_fold, 0);

	    append_instruction(bpp, o, OP_OR, 0, NULL);
	    save_instr_from_to_pparg(bpp, bpp->idx-1, restart_idx);
	}

	break;
    }
    case OP_AND:
    case OP_OR:
    case OP_DOR: {
	/*
	      ...
	      <op_first>
	      o->op_type	    label1
	      <op_other>
	  label1:
	      ...
	*/
	OP* op_first = cLOGOPo->op_first;
	OP* op_other = op_first->op_sibling;
	bool cond_may_constant_fold = TRUE;
	int addop_cond_flags = 0;
	int or_idx;

	if ((o->op_flags & OPf_WANT) == OPf_WANT_VOID)
	    addop_cond_flags |= ADDOPf_BOOLEANCONTEXT;
	add_op(bpp, op_first, &cond_may_constant_fold, addop_cond_flags);

	if (cond_may_constant_fold) {
	    SV* const constsv = *(svp_const_instruction(bpp, bpp->idx-1));
	    bool const cond_true = ((o->op_type == OP_AND &&  SvTRUE(constsv)) ||
		(o->op_type == OP_OR  && !SvTRUE(constsv)) ||
		(o->op_type == OP_DOR && !SvOK(constsv)));

	    if (cond_true) {
		bpp->idx--;
		add_op(bpp, op_other, &kid_may_constant_fold, 0);
	    }
	    break;
	}

	or_idx = bpp->idx;
	append_instruction(bpp, o, o->op_type, 0, NULL);
	add_op(bpp, op_other, &kid_may_constant_fold, 0);
	save_instr_from_to_pparg(bpp, or_idx, bpp->idx);
	break;
    }
    case OP_ANDASSIGN:
    case OP_ORASSIGN:
    case OP_DORASSIGN: {
	/*
	      ...
	      <op_first>
	      o->op_type	    label1
	      <op_other>
	  label1:
	      ...
	*/
	OP* op_first = cLOGOPo->op_first;
	OP* op_other = op_first->op_sibling;
	int optype_idx;

	add_op(bpp, op_first, &kid_may_constant_fold, 0);
	optype_idx = bpp->idx;
	append_instruction(bpp, o, o->op_type, 0, NULL);
	add_op(bpp, op_other, &kid_may_constant_fold, 0);
	save_instr_from_to_pparg(bpp, optype_idx, bpp->idx);
	break;
    }
    case OP_ONCE: {
	/*
	      ...
	      o->op_type	    label1
	      <op_first>
	      instr_jump	    label2
	  label1:
	      <op_other>
	  label2:
	      ...
	*/
	int start_idx, op_idx;
	OP* op_first = cLOGOPo->op_first;
	OP* op_other = op_first->op_sibling;
	assert((PL_opargs[o->op_type] & OA_CLASS_MASK) == OA_LOGOP);

	op_idx = bpp->idx;
	append_instruction(bpp, o, o->op_type, 0, NULL);

	add_op(bpp, op_first, &kid_may_constant_fold, 0);

	start_idx = bpp->idx;
	append_instruction(bpp, NULL, OP_INSTR_JUMP, 0, NULL);

	save_instr_from_to_pparg(bpp, op_idx, bpp->idx);
	add_op(bpp, op_other, &kid_may_constant_fold, 0);
	save_instr_from_to_pparg(bpp, start_idx, bpp->idx);

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
	int entertry_idx = bpp->idx;
	append_instruction(bpp, o, OP_ENTERTRY, 0, NULL);
	add_op(bpp, cLOGOPo->op_first, &kid_may_constant_fold, 0);
	append_instruction(bpp, o, OP_LEAVETRY, 0, NULL);
	save_instr_from_to_pparg(bpp, entertry_idx, bpp->idx);
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

	    add_op(bpp, flip->op_first, &kid_may_constant_fold, 0);
	    add_op(bpp, flip->op_first->op_sibling, &kid_may_constant_fold, 0);
	    append_instruction(bpp, o, OP_FLOP, 0, NULL);

	    if (kid_may_constant_fold) {
		/* replace instructions with constant list instruction */
		SV* constsv;
		append_instruction(bpp, NULL, OP_INSTR_END, 0, NULL);
		bpp->codeseq.xcodeseq_instructions[bpp->idx].instr_ppaddr = NULL;
		constsv = instr_fold_constants(&(bpp->codeseq.xcodeseq_instructions[start_idx]), o, TRUE);
		if (constsv) {
		    bpp->idx = start_idx; /* backtrack to start of constant instructions */
		    append_instruction(bpp, NULL, OP_INSTR_CONST_LIST, 0, (void*)constsv);
		    Perl_av_create_and_push(aTHX_ &bpp->codeseq.xcodeseq_svs, constsv);
		}
		else {
		    bpp->idx--; /* remove OP_INSTR_END */
		}
	    }

	    break;
	}

	/*
	      ...
	      pp_range	     label1
	      <o->op_first->op_first>
	      flip	     label2
	  label1:
	      <o->op_first->op_first->op_sibling>
	      flop
	  label2:
	      ...
	*/

	{
	    int flip_idx, range_idx;
	    range_idx = bpp->idx;
	    append_instruction(bpp, o, o->op_type, 0, NULL);
	    add_op(bpp, flip->op_first, &kid_may_constant_fold, 0);
	    flip_idx = bpp->idx;
	    append_instruction(bpp, o, OP_FLIP, 0, NULL);

	    save_instr_from_to_pparg(bpp, range_idx, bpp->idx);
	    add_op(bpp, flip->op_first->op_sibling, &kid_may_constant_fold, 0);
	    append_instruction(bpp, o, OP_FLOP, 0, NULL);
	    save_instr_from_to_pparg(bpp, flip_idx, bpp->idx);
	}

	break;
    }
    case OP_MATCH:
    case OP_QR:
    case OP_PUSHRE: {
	OP* kid;

	for (kid=cUNOPo->op_first; kid; kid=kid->op_sibling)
	    if (kid->op_type == OP_REGCOMP)
		add_regcomp_op(bpp, kid, o, &kid_may_constant_fold);
	    else
		add_op(bpp, kid, &kid_may_constant_fold, 0);

	append_instruction(bpp, o, o->op_type, 0, NULL);
	break;
    }
    case OP_ENTERGIVEN: {
	/*
	      ...
	      <op_cond>
	      entergiven	  label1
	      <op_block>
	  label1:
	      leavegiven
	      ...
	*/
	int entergiven_idx;
	OP* op_cond = cLOGOPo->op_first;
	OP* op_block = op_cond->op_sibling;
	add_op(bpp, op_cond, &kid_may_constant_fold, 0);
	entergiven_idx = bpp->idx;
	append_instruction(bpp, o, o->op_type, 0, NULL);
	add_op(bpp, op_block, &kid_may_constant_fold, 0);
	save_instr_from_to_pparg(bpp, entergiven_idx, bpp->idx);
	append_instruction(bpp, o, OP_LEAVEGIVEN, 0, NULL);

	break;
    }
    case OP_ENTERWHEN: {
	if (o->op_flags & OPf_SPECIAL) {
	    /*
		  ...
		  enterwhen	     label1
		  <op_block>
	      label1:
		  leavewhen
		  ...
	    */
	    int enterwhen_idx;
	    OP* op_block = cLOGOPo->op_first;
	    enterwhen_idx = bpp->idx;
	    append_instruction(bpp, o, o->op_type, 0, NULL);

	    add_op(bpp, op_block, &kid_may_constant_fold, 0);

	    save_instr_from_to_pparg(bpp, enterwhen_idx, bpp->idx);
	    append_instruction(bpp, o, OP_LEAVEWHEN, 0, NULL);
	}
	else {
	    /*
		  ...
		  <op_cond>
		  enterwhen	     label1
		  <op_block>
	      label1:
		  leavewhen
		  ...
	    */
	    int enterwhen_idx;
	    OP* op_cond = cLOGOPo->op_first;
	    OP* op_block = op_cond->op_sibling;

	    add_op(bpp, op_cond, &kid_may_constant_fold, 0);

	    enterwhen_idx = bpp->idx;
	    append_instruction(bpp, o, o->op_type, 0, NULL);

	    add_op(bpp, op_block, &kid_may_constant_fold, 0);

	    save_instr_from_to_pparg(bpp, enterwhen_idx, bpp->idx);
	    append_instruction(bpp, o, OP_LEAVEWHEN, 0, NULL);
	}

	break;
    }
    case OP_SUBST: {
	/*
	      ...
	      <kids>
	      pp_subst	     label1 label2
	      instr_jump     label3
	  label1:
	      substcont
	  label2:
	      <o->op_pmreplroot>
	  label3:
	      ...
	*/

	int start_idx, subst_idx;
	OP* kid;
	SUBSTCONT_INSTRUCTIONS* substcont_instrs;
	Newx(substcont_instrs, 1, SUBSTCONT_INSTRUCTIONS);
	substcont_instrs->pm = (PMOP*)o;
	append_allocated_data(bpp, substcont_instrs);

	for (kid=cUNOPo->op_first; kid; kid=kid->op_sibling)
	    if (kid->op_type == OP_REGCOMP)
		add_regcomp_op(bpp, kid, o, &kid_may_constant_fold);
	    else
		add_op(bpp, kid, &kid_may_constant_fold, 0);

	subst_idx = bpp->idx;
	append_instruction(bpp, o, o->op_type, 0, NULL);

	start_idx = bpp->idx;
	append_instruction(bpp, NULL, OP_INSTR_JUMP, 0, NULL);

	save_instr_from_to_pparg(bpp, subst_idx, bpp->idx);
	append_instruction(bpp, cPMOPo->op_pmreplrootu.op_pmreplroot, OP_SUBSTCONT, 0, substcont_instrs);

	save_branch_point(bpp, &(substcont_instrs->pmreplstart_instr));
	if (cPMOPo->op_pmreplrootu.op_pmreplroot) {
	    add_kids(bpp, cPMOPo->op_pmreplrootu.op_pmreplroot, &kid_may_constant_fold);
	    append_instruction(bpp, cPMOPo->op_pmreplrootu.op_pmreplroot, cPMOPo->op_pmreplrootu.op_pmreplroot->op_type, 0, substcont_instrs);
	}

	save_branch_point(bpp, &(substcont_instrs->subst_next_instr));

	save_instr_from_to_pparg(bpp, start_idx, bpp->idx);

	break;
    }
    case OP_SORT: {
	/*
	      ...
	      pp_pushmark
	      [kids]
	      pp_sort		    label2
	      instr_jump	    label1
	  label2:
	      [op_block]
	      (finished)
	  label1:
	      ...
	*/
	OP* kid;
	append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);

	kid = (o->op_flags & OPf_STACKED && o->op_flags & OPf_SPECIAL)
	    ? cUNOPo->op_first->op_sibling
	    : cUNOPo->op_first;
	for (; kid; kid=kid->op_sibling)
	    add_op(bpp, kid, &kid_may_constant_fold, 0);

	{
	    int start_idx, sort_idx;
	    bool has_block = (o->op_flags & OPf_STACKED && o->op_flags & OPf_SPECIAL);

	    sort_idx = bpp->idx;
	    append_instruction(bpp, o, OP_SORT, 0, NULL);
	    start_idx = bpp->idx;
	    append_instruction(bpp, NULL, OP_INSTR_JUMP, 0, NULL);
	    if (has_block) {
		save_instr_from_to_pparg(bpp, sort_idx, bpp->idx);
		add_op(bpp, cUNOPo->op_first, &kid_may_constant_fold, 0);
		append_instruction(bpp, NULL, OP_INSTR_END, 0, NULL);
	    }
	    save_instr_from_to_pparg(bpp, start_idx, bpp->idx);
	}
	break;
    }
    case OP_FORMLINE: {
	/*
	      ...
	  label1:
	      pp_pushmark
	      <o->children>
	      o->op_type	  label1
	      ...
	*/
	int restart_idx = bpp->idx;
	append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_kids(bpp, o, &kid_may_constant_fold);
	append_instruction(bpp, o, o->op_type, 0, NULL);
	save_instr_from_to_pparg(bpp, bpp->idx -1, restart_idx);
	break;
    }
    case OP_RV2SV: {
	if (cUNOPo->op_first->op_type == OP_GV &&
	    !(cUNOPo->op_private & OPpDEREF)) {
	    GV* gv = cGVOPx_gv(cUNOPo->op_first);
	    append_instruction(bpp, o, OP_GVSV, 0, (void*)gv);
	    break;
	}
	add_kids(bpp, o, &kid_may_constant_fold);
	append_instruction(bpp, o, o->op_type, 0, NULL);
	break;
    }
    case OP_AELEM: {
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
	add_op(bpp, op_av, &kid_may_constant_fold, 0);
	add_op(bpp, op_index, &index_is_constant, 0);
	kid_may_constant_fold = kid_may_constant_fold && index_is_constant;
	if (index_is_constant) {
	    if ((op_av->op_type == OP_PADAV ||
		    (op_av->op_type == OP_RV2AV && cUNOPx(op_av)->op_first->op_type == OP_GV)) &&
		!(o->op_private & (OPpLVAL_INTRO|OPpLVAL_DEFER|OPpDEREF|OPpMAYBE_LVSUB))
		) {
		/* Convert to AELEMFAST */
		SV* const constsv = *(svp_const_instruction(bpp, bpp->idx-1));
		SvIV_please(constsv);
		if (SvIOKp(constsv)) {
		    IV i = SvIV(constsv) - CopARYBASE_get(PL_curcop);
		    OP* op_arg = op_av->op_type == OP_PADAV ? op_av : cUNOPx(op_av)->op_first;
		    op_arg->op_flags |= o->op_flags & OPf_MOD;
		    bpp->idx = start_idx;
		    append_instruction(bpp, op_arg,
			OP_AELEMFAST, 0, INT2PTR(void*, i));
		    break;
		}
	    }
	}
	append_instruction(bpp, o, o->op_type, 0, NULL);
	break;
    }
    case OP_HELEM: {
	/*
	  [op_hv]
	  [op_index]
	  o->op_type
	*/
	OP* op_hv = cUNOPo->op_first;
	OP* op_key = op_hv->op_sibling;
	bool key_is_constant = TRUE;
	int start_idx;

	start_idx = bpp->idx;
	add_op(bpp, op_hv, &kid_may_constant_fold, 0);
	add_op(bpp, op_key, &key_is_constant, 0);
	kid_may_constant_fold = kid_may_constant_fold && key_is_constant;
	if (key_is_constant) {
	    SV ** const keysvp = svp_const_instruction(bpp, bpp->idx-1);
	    if (SvOK(*keysvp) && !SvROK(*keysvp)) {
		STRLEN keylen;
		const char* key = SvPV_const(*keysvp, keylen);
		SV* shared_keysv = newSVpvn_share(key,
		    SvUTF8(*keysvp) ? -(I32)keylen : (I32)keylen,
		    0);
		*keysvp = shared_keysv;
	    }
	}
	append_instruction(bpp, o, o->op_type, 0, NULL);
	break;
    }
    case OP_DELETE: {
	if (o->op_private & OPpSLICE)
	    append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_kids(bpp, o, &kid_may_constant_fold);
	append_instruction(bpp, o, OP_DELETE, 0, NULL);
	break;
    }
    case OP_LSLICE: {
	/*
	      pp_pushmark
	      [op_subscript]
	      pp_pushmark
	      [op_listval]
	      pp_lslice
	*/
	OP* op_subscript = cBINOPo->op_first;
	OP* op_listval = op_subscript->op_sibling;
	append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_op(bpp, op_subscript, &kid_may_constant_fold, 0);
	append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_op(bpp, op_listval, &kid_may_constant_fold, 0);
	append_instruction(bpp, o, OP_LSLICE, 0, NULL);
	break;
    }
    case OP_RV2HV: {
	if (boolean_context) {
	    add_kids(bpp, o, &kid_may_constant_fold);
	    append_instruction(bpp, o, OP_RV2HV, INSTRf_REF | INSTRf_RV2AV_BOOLKEYS, NULL);
	    append_instruction(bpp, NULL, OP_BOOLKEYS, 0, NULL);
	    break;
	}
	goto compile_default;
    }
    case OP_REPEAT: {
	if (o->op_private & OPpREPEAT_DOLIST)
	    append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_kids(bpp, o, &kid_may_constant_fold);
	append_instruction(bpp, o, OP_REPEAT, 0, NULL);
	break;
    }
    case OP_NULL:
    case OP_SCALAR:
    case OP_LINESEQ:
    case OP_SCOPE: {
	add_kids(bpp, o, &kid_may_constant_fold);
	break;
    }
    case OP_NEXTSTATE:
    {
	/* Two NEXTSTATEs in a row serve no purpose. Except if they happen
	   to carry two labels. For now, take the easier option, and skip
	   this optimisation if the first NEXTSTATE has a label.  */
	if (o->op_sibling && o->op_sibling->op_type == OP_NEXTSTATE
	     && !CopLABEL((COP*)o)
	    )
	    break;
	append_instruction(bpp, o, o->op_type, 0, NULL);
	PL_curcop = ((COP*)o);
	break;
    }
    case OP_DBSTATE:
    {
	append_instruction(bpp, o, o->op_type, 0, NULL);
	PL_curcop = ((COP*)o);
	break;
    }
    case OP_SASSIGN: {
	OP* op_right = cUNOPo->op_first;
	OP* op_left = op_right->op_sibling;
	if (op_left && op_left->op_type == OP_PADSV
	    && !(op_left->op_private & OPpLVAL_INTRO)
	    && (PL_opargs[op_right->op_type] & OA_TARGLEX)
	    && (!(op_right->op_flags & OPf_STACKED))
	    ) {
	    assert(!(op_left->op_flags & OPf_STACKED));
	    if (PL_opargs[op_right->op_type] & OA_MARK)
		append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	    add_kids(bpp, op_right, &kid_may_constant_fold);
	    append_instruction(bpp, op_right, op_right->op_type,
		INSTRf_TARG_IN_ARG2, (void*)op_left->op_targ);
	    break;
	}
	goto compile_default;
    }
    case OP_AASSIGN:
    {
	OP* op_right = cBINOPo->op_first;
	OP* op_left = op_right->op_sibling;

	OP* inplace_av_op = is_inplace_av(o);
	if (inplace_av_op) {
	    if (inplace_av_op->op_type == OP_SORT) {
		append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
		append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
		if (inplace_av_op->op_flags & OPf_STACKED && !(inplace_av_op->op_flags & OPf_SPECIAL))
		    add_op(bpp, cLISTOPx(inplace_av_op)->op_first, &kid_may_constant_fold, 0);
		add_op(bpp, op_left, &kid_may_constant_fold, 0);

		o = inplace_av_op;
		{
		    int start_idx, sort_idx;
		    bool has_block = (o->op_flags & OPf_STACKED && o->op_flags & OPf_SPECIAL);

		    sort_idx = bpp->idx;
		    append_instruction(bpp, o, OP_SORT, INSTRf_SORT_INPLACE, NULL);
		    start_idx = bpp->idx;
		    append_instruction(bpp, NULL, OP_INSTR_JUMP, 0, NULL);
		    if (has_block) {
			save_instr_from_to_pparg(bpp, sort_idx, bpp->idx);
			add_op(bpp, cUNOPo->op_first, &kid_may_constant_fold, 0);
			append_instruction(bpp, NULL, OP_INSTR_END, 0, NULL);
		    }
		    save_instr_from_to_pparg(bpp, start_idx, bpp->idx);
		}
		break;
	    }
	    assert(inplace_av_op->op_type == OP_REVERSE);
	    append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	    append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	    add_op(bpp, op_left, &kid_may_constant_fold, 0);
	    append_instruction(bpp, inplace_av_op, OP_REVERSE, INSTRf_REVERSE_INPLACE, NULL);
	    break;
	}
	append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_op(bpp, op_right, &kid_may_constant_fold, 0);
	append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_op(bpp, op_left, &kid_may_constant_fold, 0);
	append_instruction(bpp, o, OP_AASSIGN, 0, NULL);
	break;
    }
    case OP_STRINGIFY:
    {
	if (cUNOPo->op_first->op_type == OP_CONCAT) {
	    add_op(bpp, cUNOPo->op_first, &kid_may_constant_fold, 0);
	    break;
	}
	goto compile_default;
    }
    case OP_CONCAT:
    {
	if ((o->op_flags & OPf_STACKED) && cBINOPo->op_last->op_type == OP_READLINE
	    /* RCATLINE does not do overloading, so make sure it isn't requried */
	    && cUNOPx(cBINOPo->op_last)->op_first->op_type == OP_GV
	    ) {
	    /*	/\* Turn "$a .= <FH>" into an OP_RCATLINE. AMS 20010917 *\/ */
	    add_op(bpp, cBINOPo->op_first, &kid_may_constant_fold, 0);
	    add_kids(bpp, cBINOPo->op_last, &kid_may_constant_fold);
	    append_instruction(bpp, cBINOPo->op_last, OP_RCATLINE, 0, NULL);
	    kid_may_constant_fold = FALSE;
	    break;
	}
	goto compile_default;
    }
    case OP_LIST: {
	if ((o->op_flags & OPf_WANT) == OPf_WANT_LIST) {
	    /* don't bother with the pushmark and the pp_list instruction in list context */
	    add_kids(bpp, o, &kid_may_constant_fold);
	    break;
	}
	goto compile_default;
    }

    case OP_GLOB: {
	if (o->op_flags & OPf_SPECIAL) {
	    /*
	          ...
	          pp_pushmark
		  <op_wildcard>
	          <op_glob-index>
		  pp_glob                  label1
		  <op_entersub->children>
		  pp_entersub
	      label1:
	          ...
	     */
	    OP* op_wildcard = cUNOPo->op_first;
	    OP* op_index = op_wildcard->op_sibling;
	    OP* op_entersub = op_index->op_sibling;
	    int glob_idx;
	    append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	    add_op(bpp, op_wildcard, &kid_may_constant_fold, 0);
	    add_op(bpp, op_index, &kid_may_constant_fold, 0);
	    glob_idx = bpp->idx;
	    append_instruction(bpp, o, o->op_type, 0, NULL);
	    /* add op_entersub ourself as to make sure pushmark isn't called twice */
	    add_kids(bpp, op_entersub, &kid_may_constant_fold);
	    append_instruction(bpp, op_entersub, op_entersub->op_type, 0, NULL);
	    save_instr_from_to_pparg(bpp, glob_idx, bpp->idx);
	    break;
	}
	goto compile_default;
    }

    case OP_CONST:
	append_instruction(bpp, NULL, OP_CONST, 0, (void*)cSVOPx_sv(o));
	break;

    case OP_STUB:
	if ((o->op_flags & OPf_WANT) == OPf_WANT_LIST) {
	    break; /* Scalar stub must produce undef.  List stub is noop */
	}
	goto compile_default;

    case OP_CUSTOM:
	if (PL_opargs[o->op_type] & OA_MARK)
	    append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_kids(bpp, o, &kid_may_constant_fold);
	append_instruction(bpp, o, o->op_type, 0, NULL);
	/* override ppaddr */
	bpp->codeseq.xcodeseq_instructions[bpp->idx-1].instr_ppaddr = (Perl_ppaddr_t)o->op_targ;
	break;

    default: {
      compile_default:
	if (PL_opargs[o->op_type] & OA_MARK)
	    append_instruction(bpp, NULL, OP_PUSHMARK, 0, NULL);
	add_kids(bpp, o, &kid_may_constant_fold);
	append_instruction(bpp, o, o->op_type, 0, NULL);
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
    case OP_SPRINTF:
	/* XXX what about the numeric ops? */
	if (IN_LOCALE_RUNTIME)
	    kid_may_constant_fold = FALSE;
	break;
    default:
	kid_may_constant_fold = kid_may_constant_fold && (OP_OPFLAGS(o) & OA_FOLDCONST) != 0;
	break;
    }

    if (kid_may_constant_fold && bpp->idx > start_idx + 1) {
	SV* constsv;
	append_instruction(bpp, NULL, OP_INSTR_END, 0, NULL);
	bpp->codeseq.xcodeseq_instructions[bpp->idx].instr_ppaddr = NULL;
	constsv = instr_fold_constants(&(bpp->codeseq.xcodeseq_instructions[start_idx]), o, FALSE);
	if (constsv) {
	    bpp->idx = start_idx; /* delete everything starting with start_idx */
	    SvREADONLY_on(constsv);
	    append_instruction(bpp, NULL, OP_CONST, 0, (void*)constsv);
	    Perl_av_create_and_push(aTHX_ &bpp->codeseq.xcodeseq_svs, constsv);
	}
	else {
	    /* constant folding failed */
	    kid_may_constant_fold = FALSE;
	    bpp->idx--; /* remove OP_INSTR_END */
	}
    }

    *may_constant_fold = *may_constant_fold && kid_may_constant_fold;
    bpp->recursion_depth--;
}

/*
=item compile_op
Compiles to op into the codeseq, assumes the pad is setup correctly
*/
void
Perl_compile_op(pTHX_ OP* rootop, CODESEQ* codeseq)
{
    dSP;

    CODEGEN_PAD bpp;

    PERL_ARGS_ASSERT_COMPILE_OP;

    /* preserve current state */
    PUSHSTACKi(PERLSI_COMPILE);
    ENTER;
    SAVETMPS;

    save_scalar(PL_errgv);
    SAVEVPTR(PL_curcop);
    SAVEOP();
    SAVEVPTR(PL_instruction);
    SAVEBOOL(PL_tainting);
    PL_tainting = FALSE;

    /* create scratch pad */
    bpp.codeseq.xcodeseq_size = 12;
    bpp.recursion_depth = 0;
    Newx(bpp.codeseq.xcodeseq_instructions, bpp.codeseq.xcodeseq_size, INSTRUCTION);
    bpp.codeseq.xcodeseq_svs = NULL;
    bpp.idx = 0;
    bpp.target_instrpp_used = 0;
    bpp.target_instrpp_size = 128;
    Newx(bpp.target_instrpp_list, bpp.target_instrpp_size, TARGET_INSTRPP);
    bpp.target_to_pparg_list = NULL;
    bpp.target_to_pparg_size = 0;
    bpp.target_to_pparg_used = 0;
    bpp.allocated_data_list = NULL;
    bpp.allocated_data_end = NULL;
    bpp.allocated_data_append = NULL;

    {
	/* actually compile */
	bool may_constant_fold = TRUE;
	add_op(&bpp, rootop, &may_constant_fold, 0);

	append_instruction(&bpp, NULL, OP_INSTR_END, 0, NULL);
    }

    /* Final NULL instruction for safety (append_instruction reserves space for this) */
    bpp.codeseq.xcodeseq_instructions[bpp.idx].instr_ppaddr = NULL;
    bpp.codeseq.xcodeseq_instructions[bpp.idx].instr_arg = NULL;

    /* copy codeseq from the pad to the actual object */
    codeseq->xcodeseq_size = bpp.idx + 1;
    Renew(codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);
    Copy(bpp.codeseq.xcodeseq_instructions, codeseq->xcodeseq_instructions, codeseq->xcodeseq_size, INSTRUCTION);
    codeseq->xcodeseq_svs = bpp.codeseq.xcodeseq_svs;
    codeseq->xcodeseq_allocated_data_list = bpp.allocated_data_list;
    codeseq->xcodeseq_allocated_data_size = bpp.allocated_data_append - bpp.allocated_data_list;

    {
	/* resolve instruction pointers */
	TARGET_INSTRPP* i;
	for (i=bpp.target_instrpp_list; i<bpp.target_instrpp_list + bpp.target_instrpp_used; i++) {
	    assert(i->target_idx != -1);
	    if (i->instrpp)
		*(i->instrpp) = &(codeseq->xcodeseq_instructions[i->target_idx]);
	}
    }

    {
	TARGET_TO_PPARG* i;
	for (i=bpp.target_to_pparg_list; i<bpp.target_to_pparg_list + bpp.target_to_pparg_used; i++) {
	    codeseq->xcodeseq_instructions[i->instr_idx].instr_arg = &codeseq->xcodeseq_instructions[i->target_idx];
	}
    }

    DEBUG_G(codeseq_dump(codeseq));

    Safefree(bpp.target_instrpp_list);
    Safefree(bpp.target_to_pparg_list);
    Safefree(bpp.codeseq.xcodeseq_instructions);

    /* restore original state */
    FREETMPS ;
    LEAVE ;
    POPSTACK;
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
S_svp_const_instruction(pTHX_ CODEGEN_PAD *bpp, int instr_index)
{
    INSTRUCTION* instr = &bpp->codeseq.xcodeseq_instructions[instr_index];
    PERL_ARGS_ASSERT_SVP_CONST_INSTRUCTION;
    PERL_UNUSED_VAR(bpp);
    return (SV**)& instr->instr_arg;
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

#define INSTR_IN_CODESEQ(instr, codeseq)	\
    (codeseq) && (codeseq)->xcodeseq_instructions < instr && (codeseq)->xcodeseq_instructions + (codeseq)->xcodeseq_size >= instr

#if defined(USE_ITHREADS)

CODESEQ*
S_find_codeseq_with_instruction(pTHX_ const INSTRUCTION* instr, CLONE_PARAMS *param)
{
    PERL_ARGS_ASSERT_FIND_CODESEQ_WITH_INSTRUCTION;

    /* search for codeseq */
    if (INSTR_IN_CODESEQ(instr, CvCODESEQ(param->proto_perl->Imain_cv)))
	return CvCODESEQ(param->proto_perl->Imain_cv);

    {
	register I32 i;
	PERL_SI *si = param->proto_perl->Icurstackinfo;
	while (si) {
	    for (i = si->si_cxix; i >= 0; i--) {
		register const PERL_CONTEXT * const cx = &si->si_cxstack[i];
		switch (CxTYPE(cx)) {
		case CXt_SUB:
		    if (INSTR_IN_CODESEQ(instr, cx->blk_sub.codeseq))
			return cx->blk_sub.codeseq;
		    break;
		case CXt_FORMAT:
		    if (INSTR_IN_CODESEQ(instr, cx->blk_format.codeseq))
			return cx->blk_format.codeseq;
		    break;
		case CXt_EVAL:
		    if (INSTR_IN_CODESEQ(instr, cx->blk_eval.codeseq))
			return cx->blk_eval.codeseq;
		    break;
		}
	    }
	    si = si->si_next;
	}
    }

    return NULL;
}

INSTRUCTION*
Perl_instruction_dup(pTHX_ const INSTRUCTION* instr, CLONE_PARAMS *param)
{
    CODESEQ* codeseq;
    int offset;

    PERL_ARGS_ASSERT_INSTRUCTION_DUP;

    if (!instr)
	return NULL;

    codeseq = find_codeseq_with_instruction(instr, param);

    if (!codeseq) {
	/* hack to work around that call_sv doesn't using a codeseq, but directly creates an instruction list
	   on the C-stack, fortunately this is only an OP_INSTR_END instruction, which we can replace with
	   an NULL instruction */
	if (PL_ppaddr[OP_INSTR_END] == instr->instr_ppaddr) {
	    return NULL;
	}

	Perl_croak(aTHX_ "Could not find codesequence needed to clone instruction");
    }

    offset = instr - codeseq->xcodeseq_instructions;
    codeseq = codeseq_dup(codeseq, param);

    return codeseq->xcodeseq_instructions + offset;
}

LOOP_INSTRUCTIONS*
Perl_loop_instructions_dup(pTHX_ const LOOP_INSTRUCTIONS* loop_instrs, CLONE_PARAMS *param)
{
    CODESEQ* codeseq = find_codeseq_with_instruction(loop_instrs->next_instr, param);
    CODESEQ* ncodeseq;
    LOOP_INSTRUCTIONS* new_loop_instrs;

    PERL_ARGS_ASSERT_LOOP_INSTRUCTIONS_DUP;

    if (!codeseq)
	Perl_croak(aTHX_ "Could not find codesequence needed to clone loop instructions");

    ncodeseq = codeseq_dup(codeseq, param);

    /* a copy of LOOP_INSTRUCTIONS should already be in the allocated_data, but we can't reliably find it,
       so instead we just add it again */

    ncodeseq->xcodeseq_allocated_data_size++;
    Renew(ncodeseq->xcodeseq_allocated_data_list, ncodeseq->xcodeseq_allocated_data_size, void*);

    Newx(new_loop_instrs, 1, LOOP_INSTRUCTIONS);
    ncodeseq->xcodeseq_allocated_data_list[ncodeseq->xcodeseq_allocated_data_size-1] = (void*)loop_instrs;

    new_loop_instrs->next_instr = ncodeseq->xcodeseq_instructions + ( loop_instrs->next_instr - codeseq->xcodeseq_instructions );
    new_loop_instrs->redo_instr = ncodeseq->xcodeseq_instructions + ( loop_instrs->redo_instr - codeseq->xcodeseq_instructions );
    new_loop_instrs->last_instr = ncodeseq->xcodeseq_instructions + ( loop_instrs->last_instr - codeseq->xcodeseq_instructions );

    return new_loop_instrs;
}

CODESEQ*
Perl_codeseq_dup_inc(pTHX_ CODESEQ* codeseq, CLONE_PARAMS *const param)
{
    CODESEQ* ncodeseq = codeseq_dup(codeseq, param);
    PERL_ARGS_ASSERT_CODESEQ_DUP_INC;
    codeseq_refcnt_inc(ncodeseq);
    return ncodeseq;
}

CODESEQ*
Perl_codeseq_dup(pTHX_ CODESEQ* codeseq, CLONE_PARAMS *const param)
{
    CODESEQ* ncodeseq;

    PERL_ARGS_ASSERT_CODESEQ_DUP;

    ncodeseq = (CODESEQ*)(ptr_table_fetch(PL_ptr_table, codeseq));
    if (ncodeseq)
	return ncodeseq;

    ncodeseq = new_codeseq();

    ptr_table_store(PL_ptr_table, codeseq, ncodeseq);

    ncodeseq->xcodeseq_size = codeseq->xcodeseq_size;
    Newx(ncodeseq->xcodeseq_instructions, ncodeseq->xcodeseq_size, INSTRUCTION);
    Copy(codeseq->xcodeseq_instructions, ncodeseq->xcodeseq_instructions, ncodeseq->xcodeseq_size, INSTRUCTION);

    ncodeseq->xcodeseq_svs = MUTABLE_AV(sv_dup_inc((const SV *)codeseq->xcodeseq_svs, param ));

    ncodeseq->xcodeseq_allocated_data_size = codeseq->xcodeseq_allocated_data_size;
    Newx(ncodeseq->xcodeseq_allocated_data_list, ncodeseq->xcodeseq_allocated_data_size, void*);

    /* Fix references */
    {
	int i;
	int data_list_i = 0;
	for (i=0; i<ncodeseq->xcodeseq_size; i++) {
	    INSTRUCTION* instr = &ncodeseq->xcodeseq_instructions[i];
	    if (instr->instr_arg) {
		if (instr->instr_op == 0) {
		    if (PL_ppaddr[OP_INSTR_COND_JUMP] == instr->instr_ppaddr
			|| PL_ppaddr[OP_INSTR_JUMP] == instr->instr_ppaddr
			) {
			instr->instr_arg = ncodeseq->xcodeseq_instructions + ( (INSTRUCTION*)instr->instr_arg - codeseq->xcodeseq_instructions );
		    }
		    else if (PL_ppaddr[OP_INSTR_CONST_LIST] == instr->instr_ppaddr
			     || PL_ppaddr[OP_CONST] == instr->instr_ppaddr
			     ) {
			/* SV */
			instr->instr_arg = sv_dup((SV*)instr->instr_arg, param);
		    }
		    else {
			assert(0);
		    }
		}
		else {
		switch (instr->instr_op->op_type) {
		case OP_REGCOMP:
		    /* OP reference */
		    break;
		case OP_ENTERLOOP:
		case OP_FOREACH: {
		    /* LOOPINSTRUCTIONS */
		    LOOP_INSTRUCTIONS* proto_loop_instrs = (LOOP_INSTRUCTIONS*)instr->instr_arg;
		    LOOP_INSTRUCTIONS* loop_instrs;
		    Newx(loop_instrs, 1, LOOP_INSTRUCTIONS);
		    ncodeseq->xcodeseq_allocated_data_list[data_list_i++] = loop_instrs;

		    loop_instrs->next_instr = ncodeseq->xcodeseq_instructions + ( proto_loop_instrs->next_instr - codeseq->xcodeseq_instructions );
		    loop_instrs->redo_instr = ncodeseq->xcodeseq_instructions + ( proto_loop_instrs->redo_instr - codeseq->xcodeseq_instructions );
		    loop_instrs->last_instr = ncodeseq->xcodeseq_instructions + ( proto_loop_instrs->last_instr - codeseq->xcodeseq_instructions );

		    instr->instr_arg = loop_instrs;

		    break;
		}
		case OP_INSTR_CONST_LIST:
		case OP_GVSV:
		case OP_RV2SV:
		    /* SV */
		    instr->instr_arg = sv_dup((SV*)instr->instr_arg, param);
		    break;
		case OP_GREPSTART:
		case OP_MAPSTART:
		case OP_GREPWHILE:
		case OP_MAPWHILE:
		case OP_COND_EXPR:
		case OP_WHILE_AND:
		case OP_AND:
		case OP_OR:
		case OP_DOR:
		case OP_ANDASSIGN:
		case OP_ORASSIGN:
		case OP_DORASSIGN:
		case OP_ONCE:
		case OP_ENTERTRY:
		case OP_RANGE:
		case OP_ENTERGIVEN:
		case OP_ENTERWHEN:
		case OP_SORT:
		case OP_SUBST: {
		    assert( (INSTRUCTION*)instr->instr_arg >= codeseq->xcodeseq_instructions );
		    assert( (INSTRUCTION*)instr->instr_arg < codeseq->xcodeseq_instructions + codeseq->xcodeseq_size );
		    instr->instr_arg = ncodeseq->xcodeseq_instructions + ( (INSTRUCTION*)instr->instr_arg - codeseq->xcodeseq_instructions );
		    break;
		}
		case OP_SUBSTCONT: {
		    /* SUBSTINSTRUCTIONS */
		    SUBSTCONT_INSTRUCTIONS* proto_substcont_instrs = (SUBSTCONT_INSTRUCTIONS*)instr->instr_arg;
		    SUBSTCONT_INSTRUCTIONS* substcont_instrs;
		    substcont_instrs = (SUBSTCONT_INSTRUCTIONS*)(ptr_table_fetch(PL_ptr_table, proto_substcont_instrs));
		    if (!substcont_instrs) {
			Newx(substcont_instrs, 1, SUBSTCONT_INSTRUCTIONS);
			ncodeseq->xcodeseq_allocated_data_list[data_list_i++] = substcont_instrs;

			ptr_table_store(PL_ptr_table, proto_substcont_instrs, substcont_instrs);

			substcont_instrs->pmreplstart_instr = ncodeseq->xcodeseq_instructions + ( proto_substcont_instrs->pmreplstart_instr - codeseq->xcodeseq_instructions );
			substcont_instrs->subst_next_instr = ncodeseq->xcodeseq_instructions + ( proto_substcont_instrs->subst_next_instr - codeseq->xcodeseq_instructions );
			substcont_instrs->subst_next_instr = ncodeseq->xcodeseq_instructions + ( proto_substcont_instrs->subst_next_instr - codeseq->xcodeseq_instructions );
			substcont_instrs->pm = proto_substcont_instrs->pm;
		    }
		    instr->instr_arg = substcont_instrs;

		    break;
		}
		case OP_PADSV:
		    /* targ */
		    break;
		default:
		    if (PL_ppaddr[OP_AELEMFAST] == instr->instr_ppaddr)
			/* integer */
			break;
		    if (instr->instr_flags & INSTRf_TARG_IN_ARG2)
			break;
		    assert(0);
		}
		}
	    }
	}
	assert( data_list_i <= ncodeseq->xcodeseq_allocated_data_size );
    }

    return ncodeseq;
}
#endif /* defined(USE_ITHREADS) */

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
