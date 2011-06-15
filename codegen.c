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

/*
=item compile_op
Compiles to op into the codeseq, assumes the pad is setup correctly
*/
void
Perl_compile_op(pTHX_ OP* rootop, CODESEQ* codeseq)
{
    PERL_ARGS_ASSERT_COMPILE_OP;

    assert(rootop->op_next);
    codeseq->xcodeseq_startinstruction = rootop->op_next;
    rootop->op_next = NULL;
}

void
Perl_compile_cv(pTHX_ CV* cv)
{
    PERL_ARGS_ASSERT_COMPILE_CV;

    if (CvCODESEQ(cv))
	return;

    CvCODESEQ(cv) = new_codeseq();

    CvCODESEQ(cv)->xcodeseq_startinstruction = CvSTART(cv);
#ifndef USE_ITHREADS
    CvSTART(cv) = NULL;
#endif
}

#ifdef USE_ITHREADS
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

    ncodeseq->xcodeseq_startinstruction = codeseq->xcodeseq_startinstruction;

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
