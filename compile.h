/*    compile.h
 *
 *    Copyright (C) 2009 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*

=head1 Code-Generation

Code-Generation is the step of converting an optree to an code sequence.

=cut

*/

/*
=head2 C<INSTRUCTION>

C<INSTRUCTION> is a single instruction, it holds a pointer to a pp function and
a pointer to the C<OP> containing more information.

Executing an instruction consist of setting C<PL_op> to the C<instr_op> field and
then calling the C<instr_ppaddr> function.

C<instr_ppaddr> can be C<NULL> indicating the end of the instructions.

=cut
*/

struct instruction {
    INSTRUCTION*		(CPERLscope(*instr_ppaddr))(pTHX);
    OP*         instr_op;
};

#define RUN_SET_NEXT_INSTRUCTION(instr)		\
    STMT_START {							\
	DEBUG_t(Perl_deb(aTHX_ "Instruction jump to %p, was %p\n",	\
		(void*)instr, (void*)PL_run_next_instruction));		\
	run_set_next_instruction(instr);				\
    } STMT_END								\

/*
=head2 C<CODESEQ>

Represent a list of C<INSTRUCTION>

C<compile_op> can be used to compile an optree into a C<CODESEQ>.

Allocating/freeing must be done using C<new_codeseq> and C<free_codeseq>.

=cut
*/

struct codeseq {
    int xcodeseq_size;
    INSTRUCTION* xcodeseq_instructions;
};

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
