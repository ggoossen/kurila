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

#define INSTR_ARG_NULL {NULL}

struct instruction {
    Perl_ppaddr_t	instr_ppaddr;
    OP*         instr_op;
    void*   instr_arg1;
};

#define RUN_SET_NEXT_INSTRUCTION(instr)		\
    STMT_START {							\
	DEBUG_t(PerlIO_printf(Perl_debug_log,				\
		"Instruction jump to 0x%p %s, was 0x%p %s at %s:%d\n",	\
		(void*)instr, instruction_name(instr),			\
		(void*)PL_run_next_instruction, instruction_name(PL_run_next_instruction), \
		__FILE__, __LINE__));					\
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
    int xcodeseq_size;                   /* Number of items in xcodeseq_instructions    */
    INSTRUCTION* xcodeseq_instructions;  /* List of xcodeseq_size items of INSTRUCTIONs */
    AV* xcodeseq_svs;                    /* Array with SVs to be freed with the codeseq */
};

#define INSTRf_HELEM_MOD          0x1
#define INSTRf_HELEM_MAYBE_LVSUB  0x2
#define INSTRf_HELEM_LVAL_DEFER   0x4
#define INSTRf_HELEM_LVAL_INTRO   0x8
#define INSTRf_HELEM_SPECIAL     0x10

/* #define OPpDEREF		(32|64)	/\* autovivify: Want ref to something: *\/ */
/* #define OPpDEREF_AV		32	/\*   Want ref to AV. *\/ */
/* #define OPpDEREF_HV		64	/\*   Want ref to HV. *\/ */
/* #define OPpDEREF_SV		(32|64)	/\*   Want ref to SV. *\/ */

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
