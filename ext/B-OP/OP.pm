package B::OP

use warnings
use B

require DynaLoader
our @ISA = qw(DynaLoader)
our $VERSION = '1.10'

B::OP->bootstrap: $VERSION

@B::OP::ISA = @:  'B::OBJECT' 
@B::UNOP::ISA = @:  'B::OP' 
@B::BINOP::ISA = @:  'B::UNOP' 
@B::LOGOP::ISA = @:  'B::UNOP' 
@B::LISTOP::ISA = @:  'B::BINOP' 
@B::SVOP::ISA = @:  'B::OP' 
@B::PADOP::ISA = @:  'B::OP' 
@B::PVOP::ISA = @:  'B::OP' 
@B::LOOP::ISA = @:  'B::LISTOP' 
@B::PMOP::ISA = @:  'B::LISTOP' 
@B::COP::ISA = @:  'B::OP' 
@B::ROOTOP::ISA = @:  'B::UNOP' 

@B::optype = qw(OP UNOP BINOP LOGOP LISTOP PMOP SVOP PADOP PVOP LOOP COP ROOTOP)

use constant OP_LIST    => 141    # MUST FIX CONSTANTS.

# This is where we implement op.c in Perl. Sssh.
sub linklist
    my $o = shift
    if ( $o->can: "first" and $o->first and  $o->first->$ )
        $o->next:  < $o->first->linklist 
        my $kid = $o->first
        while ($kid->$)
            if (  $kid->sibling->$ )
                $kid->next:  < $kid->sibling->linklist 
            else
                $kid->next: $o
            
            $kid = $kid->sibling
        
    else
        $o->next: $o
    
    $o->clean
    return $o->next


sub append_elem( $class, $type, $first, $last)
    return $last  unless $first and $first->$
    return $first unless $last  and $last->$

    if ( $first->type != $type
           or ( $type == (OP_LIST: )and ( $first->flags ^&^ B::OPf_PARENS ) ) )
        return B::LISTOP->new:  $type, 0, $first, $last 
    

    if ( $first->flags ^&^ B::OPf_KIDS )

        $first->last->sibling: $last
    else
        $first->flags:  $first->flags ^|^ B::OPf_KIDS 
        $first->first: $last
    
    $first->last: $last
    return $first


sub prepend_elem( $class, $type, $first, $last)
    if ( $last->type != $type )
        return B::LISTOP->new:  $type, 0, $first, $last 
    

    if ( $type == (OP_LIST: ))
        $first->sibling:  < $last->first->sibling 
        $last->first->sibling: $first
        $last->flags:  $last->flags ^&^ ^~^B::OPf_PARENS 
            unless ( $first->flags ^&^ B::OPf_PARENS )
    else
        unless ( $last->flags ^&^ B::OPf_KIDS )
            $last->last: $first
            $last->flags:  $last->flags ^|^ B::OPf_KIDS 
        
        $first->sibling:  < $last->first 
        $last->first: $first
    
    $last->flags:  $last->flags ^|^ B::OPf_KIDS 
    return $last    # I cannot believe this works.


sub scope
    my $o = shift
    return unless $o and $o->$
    if ( $o->flags ^&^ B::OPf_PARENS )
        $o = B::OP->prepend_elem:  < (B::opnumber: "lineseq"), <
                                       (B::OP->new:  "enter", 0 ), $o 
        $o->type:  < (B::opnumber: "leave") 
    else
        if ( $o->type == (B::opnumber: "lineseq") )
            my $kid
            $o->type:  < (B::opnumber: "scope") 
            $kid = $o->first
            die: "This probably shouldn't happen (\$kid->null)\n"
                if ( $kid->type == B::opnumber: "nextstate"
                     or $kid->type == (B::opnumber: "dbstate") )
        else
            $o = B::LISTOP->new:  "scope", 0, $o, undef 
        
    
    return  @: $o


1
__END__

=head1 NAME

B::OP - Inspect and manipulate op trees.

=head1 DESCRIPTION

=head2 OP-RELATED CLASSES

C<B::OP>, C<B::UNOP>, C<B::BINOP>, C<B::LOGOP>, C<B::LISTOP>, C<B::PMOP>,
C<B::SVOP>, C<B::PADOP>, C<B::PVOP>, C<B::LOOP>, C<B::COP>.

These classes correspond in the obvious way to the underlying C
structures of similar names. The inheritance hierarchy mimics the
underlying C "inheritance":

                                 B::OP
                                   |
                   +---------------+--------+--------+-------+
                   |               |        |        |       |
                B::UNOP          B::SVOP B::PADOP  B::COP  B::PVOP
                 ,'  `-.
                /       `--.
           B::BINOP     B::LOGOP
               |
               |
           B::LISTOP
             ,' `.
            /     \
        B::LOOP B::PMOP

Access methods correspond to the underlying C structre field names,
with the leading "class indication" prefix (C<"op_">) removed.

Most fields also have an set method, prefixed with "set_".

=head2 B::OP Methods

These methods get the values of similarly named fields within the OP
data structure.  See top of C<op.h> for more info.

=over 4

=item next

=item sibling

=item name

This returns the op name as a string (e.g. "add", "rv2av").

=item ppaddr

This returns the function name as a string (e.g. "PL_ppaddr[OP_ADD]",
"PL_ppaddr[OP_RV2AV]").

=item desc

This returns the op description from the global C PL_op_desc array
(e.g. "addition" "array deref").

=item targ

=item type

=item opt

=item flags

=item private

=item spare

=item free

Frees the opcode and all child opcodes.
The object should not be used after this.

=back

=head2 B::UNOP METHOD

=over 4

=item first

=back

=head2 B::BINOP METHOD

=over 4

=item last

=back

=head2 B::LOGOP METHOD

=over 4

=item other

=back

=head2 B::LISTOP METHOD

=over 4

=item children

=back

=head2 B::PMOP Methods

=over 4

=item pmreplroot

=item pmreplstart

=item precomp

=item pmflags

=item reflags

Additional flags stored in regexp->extflags.
Extension and partially overlapping with op->pmflags.
Exactly the RXf_PMf_ flags, 0x800-0x1FFFF, are the same, the rest
are new for the new matcher.

=item pmoffset

Only when perl was compiled with ithreads.

=item pmstashpv

Only when perl was compiled with ithreads.

=item pmstash

Only when perl was compiled without ithreads.

=back

=head2 B::SVOP METHOD

=over 4

=item sv

=item gv

=back

=head2 B::PADOP METHOD

=over 4

=item padix

=back

=head2 B::PVOP METHOD

=over 4

=item pv

=back

=head2 B::LOOP Methods

=over 4

=item redoop

=item nextop

=item lastop

=back

=head2 B::COP Methods

=over 4

=item label

=item stash

=item stashpv

=item file

=item cop_seq

=item line

=item warnings

=item io

=item hints

=back



=head1 CREATING OPTREES

=head2 SYNOPSIS

    use B::OP;
    # Do nothing, slowly.
      CHECK {
        my $null = B::OP->new("null",0);
        my $enter = B::OP->new("enter",0);
        my $cop = B::COP->new(0, "hiya", 0);
        my $leave = B::LISTOP->new("leave", 0, $enter, $null);
        $leave->set_children(3);
        $enter->set_sibling($cop);
        $enter->set_next($cop);
        $cop->set_sibling($null);
        $null->set_next($leave);
        $cop->set_next($leave);

        # Tell Perl where to find our tree.
        B::set_main_root($leave);
        B::set_main_start($enter);
      }

=head2 WARNING

This module will create segmentation faults if you don't know how to
use it properly. Further warning: sometimes B<I> don't know how to use
it properly.

There B<are> lots of other methods and utility functions, but they are
not documented here. This is deliberate, rather than just through
laziness. You are expected to have read the Perl and XS sources to this
module before attempting to do anything with it.

Patches welcome.

=head2 DESCRIPTION

This module also allows you to create and manipulate the Perl optree in Perl space.

Well, if you're intimately familiar with Perl's internals, you can.

C<B::OP> turns C<B>'s accessor methods into get-set methods.
Hence, instead of merely saying

    $op2 = $op->next;

you can now say

    $op->set_next($op2);

to set the next op in the chain. It also adds constructor methods to
create new ops. This is where it gets really hairy.

    B::OP->new     ( type, flags )
    B::UNOP->new   ( type, flags, first )
    B::BINOP->new  ( type, flags, first, last )
    B::LOGOP->new  ( type, flags, first, other )
    B::LISTOP->new ( type, flags, first, last )
    B::COP->new    ( flags, name, first )

In all of the above constructors, C<type> is either a numeric value
representing the op type (C<62> is the addition operator, for instance)
or the name of the op. (C<"add">)

(Incidentally, if you know about custom ops and have registed them
properly with the interpreter, you can create custom ops by name: 
C<B::OP->new("mycustomop",0)>, or whatever.)

C<first>, C<last> and C<other> are ops to be attached to the current op;
these should be C<B::OP> objects. If you haven't created the ops yet,
don't worry; give a false value, and fill them in later:

    $x = B::UNOP->new("negate", 0, undef);
    # ... create some more ops ...
    $x->first($y);

In addition, one may create a new C<nextstate> operator with

    B::op->newstate ( flags, label, op)

in the same manner as C<B::COP::new> - this will also, however, add the
C<lineseq> op.

Finally, you can set the main root and the starting op by passing ops
to the C<B::set_main_root> and C<B::set_main_start> functions.

This module can obviously be used for all sorts of fun purposes. The
best one will be in conjuction compilation subs.

=head2 OTHER METHODS

=over 3

=item  $b_sv->sv

Returns a real SV instead of a C<B::SV>. For instance:

    $b_sv = $svop->sv;
    if ($b_sv->sv == 3) {
        print "SVOP's SV has an IV of 3\n"
    }

You can't use this to set the SV. That would be scary.

=item $op->dump

Runs C<Perl_op_dump> on an op; this is roughly equivalent to
C<B::Debug>, but not quite.

=item $b_sv->dump

Runs C<Perl_sv_dump> on an SV; this is exactly equivalent to
C<< Devel::Peek::dump($b_sv->sv) >>

=item $b_op->linklist

Sets the C<op_next> pointers in the tree in correct execution order, 
overwriting the old C<next> pointers. You B<need> to do this once you've
created an op tree for execution, unless you've carefully threaded it
together yourself.

=back

=head2 EXPORT

None.

=head1 AUTHOR

Malcolm Beattie, C<mbeattie@sable.ox.ac.uk>
Simon Cozens, C<simon@cpan.org>
(Who else?)

=head1 MAINTAINERS

This module is a merge of C<B-Generate> and the C<B::OP> part of C<B>.

Josh ben Jore, Michael Schwern, Jim Cromie, Scott Walters, Gerard Goossen.

=head1 LICENSE

This module is available under the same licences as perl, the Artistic
license and the GPL.

=head1 SEE ALSO

L<B>, F<perlguts>, F<op.c>

=cut
