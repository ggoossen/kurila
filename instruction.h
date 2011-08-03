/*    instruction.h
 *
 *    Copyright (C) 2009 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
=head2 C<INSTRUCTION>

C<INSTRUCTION> is a single instruction, it holds a pointer to a pp
function, some flags, a pointer to a C<OP> and a customizable pointer.

Executing an instruction consist of setting C<PL_op> to the
C<instr_op> field and then calling the C<instr_ppaddr> function.

=cut
*/

struct instruction {
    Perl_ppaddr_t	instr_ppaddr;
    OP*                 instr_op;
    INSTR_FLAGS         instr_flags;
    void*               instr_arg;
};

/*
=head2 C<CODESEQ>

Represent a list of C<INSTRUCTION>

C<compile_op> can be used to compile an optree into a C<CODESEQ>.

C<CODESEQ>s are reference counted. Initialy C<new_codeseq> the
reference count is one, and can be manipulated using
C<codeseq_refcnt_inc> and C<codeseq_refcnt_dec>.

=cut
*/

struct codeseq {
    int           xcodeseq_size;                   /* Number of items in xcodeseq_instructions    */
    INSTRUCTION*  xcodeseq_instructions;           /* List of xcodeseq_size items of INSTRUCTIONs */
    AV*           xcodeseq_svs;                    /* Array with SVs to be freed with the codeseq */
    void**        xcodeseq_allocated_data_list;    /* Misc allocated data which should be freed with the codeseq */
    int           xcodeseq_allocated_data_size;    /* Number of items in xcodeseq_allocated_data_list */
    int           xcodeseq_refcnt;                 /* Reference count */
};

#define INSTRf_TARG_IN_ARG2       0x1
#define INSTRf_REF                0x2

#define INSTRf_UNSTACK_LEAVESCOPE 0x100
#define INSTRf_SORT_INPLACE       0x100
#define INSTRf_REVERSE_INPLACE    0x100
#define INSTRf_RV2AV_BOOLKEYS     0x100

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
