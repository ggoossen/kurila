/*    instruction.h
 *
 *    Copyright (C) 2009 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/*
=head2 C<CODESEQ>

References the instruction

C<compile_op> can be used to compile an optree into a C<CODESEQ>.

C<CODESEQ>s are reference counted. Initialy C<new_codeseq> the
reference count is one, and can be manipulated using
C<codeseq_refcnt_inc> and C<codeseq_refcnt_dec>.

=cut
*/

struct codeseq {
    INSTRUCTION*  xcodeseq_startinstruction;
    int           xcodeseq_refcnt;                 /* Reference count */
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
