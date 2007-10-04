package comptfunc;

sub define {
    my %arg = @_;
    $^H{'comptfunc'} = {
                        %{ $^H{'comptfunc'} || {} },
                        %arg,
                       };
}

1;
__END__

=head1 NAME

comptfunc - Package for defining compile time function

=head1 SYNOPSIS

    package SomeThing;

    sub import {
        comptfunc::define( foo => sub { return $_[0] || B::OP->new('null', 0) } );
    }
    ...

    package main;

    use Something;
    ...
    foo $a, $b = (1, 2);

=head1 DESCRIPTION

=head2 Compile time functions

Compile time functions are functions which are called during compile
time. Because they are called at compile time instead of being called
with normal arguments, they receive one argument which is the opcode
of the argument list, or nothing if there were no argument at all.
The function should return the opcode. The arguments to the function
are parsed normally, but the comptfunc can do anything it wants with
it.

=head2 Writing compile time functions

=over

B::OP
    comptfunc::define( foo => \&foo )

declares a compile time function 'foo'.

There is no verification of the "correctness" of the opcode tree
generated, so you may easily created opcode which generates
segfaults.

=item Freeing opcodes

Opcodes discarded are not automaticly freed. The opcodes are freed normally with freeing of the sub. If
you want to discard an opcode you have to explicitly call 'free' on
it. This also applies to the opcode passed to the comptfunc, i.e. if
it isn't used in the opcode tree returned by you, you should free the
it.

=item Examples

sub debuglog {
   my $op = shift;
   if ($ENV{DEBUG}) {
     return B:: $op || B::OP->new('null', 0);
   } else {
     $op && $op->free;
     return B::OP->new('null', 0);
   }
}

comptfunc::define( debuglog => 

=back

=head1 IMPLEMENTATION

What follows is subject to change RSN.


=head1 AUTHOR

Gerard Goossen E<lt>F<gerard@tty.nl>E<gt>.

=head1 BUGS

Because it is used for overloading, the per-package hash %OVERLOAD now
has a special meaning in Perl. The symbol table is filled with names
looking like line-noise.

For the purpose of inheritance every overloaded package behaves as if
C<fallback> is present (possibly undefined). This may create
interesting effects if some package is not overloaded, but inherits
from two overloaded packages.

Relation between overloading and tie()ing is broken.  Overloading is
triggered or not basing on the I<previous> class of tie()d value.

This happens because the presence of overloading is checked too early,
before any tie()d access is attempted.  If the FETCH()ed class of the
tie()d value does not change, a simple workaround is to access the value
immediately after tie()ing, so that after this call the I<previous> class
coincides with the current one.

B<Needed:> a way to fix this without a speed penalty.

Barewords are not covered by overloaded string constants.

This document is confusing.  There are grammos and misleading language
used in places.  It would seem a total rewrite is needed.

=cut

