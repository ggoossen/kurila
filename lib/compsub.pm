package compsub;

sub define {
    my %arg = @_;
    $^H{'compsub'} = {
                        %{ $^H{'compsub'} || {} },
                        %arg,
                       };
}

1;
__END__

=head1 NAME

compsub - Package for defining compilation subroutines

=head1 SYNOPSIS

    package SomeThing;

    sub import {
        compsub::define( foo => sub { return $_[0] || B::OP->new('null', 0) } );
    }
    ...

    package main;

    use Something;
    ...
    foo $a, $b = (1, 2);

=head1 DESCRIPTION

=head2 Compilation subroutines

Compilation subroutines are subs who are called during compile time. They 
don't parse its arguments, but gets its arguments already parsed in the form
of a opcode tree. It receives one argument which is the opcode
of the argument list, or nothing if there were no argument at all.
The sub should return a opcode. The arguments to the function
are parsed normally, but the compsub can do anything it wants with
it.

=head2 Using compilation subs

Keywords for a compilation sub are lexically scoped, and can be declared for
example by a C<use Module>.
Use the name of the compilation sub to call it.

    foo $arg1, $arg2, @args;

The compilation sub is not affected by parenteses, i.e.

foo($arg1, $arg2), @args

@args is still passed to foo.
The compilation sub is called after parsing the arguments, and the compile time
setting changed and declarations made by the compilation sub do NOT affect the arguments.
What the compilation sub exactly does (at compile and run-time) is up to the sub.
Things it can do at compile time are for example: declare lexical variables,
pre-process constant arguments, declare other compilation subs, do some basic argument verification.
Things it can do at run-time are
for example: call a subroutine with its normal arguments, do nothing, evaluate
one of its arguments multiple times, call multiple subroutines with the same arguments.

=head2 Writing compilation subs

=over

B::OP
    compsub::define( foo => \&foo )

declares a compile time function 'foo'.

There is no verification of the "correctness" of the opcode tree
generated, so you may easily created opcode which generates
segfaults.

=item Freeing opcodes

Opcodes discarded are not automaticly freed. The opcodes are freed normally with freeing of the sub. If
you want to discard an opcode you have to explicitly call 'free' on
it. This also applies to the opcode passed to the compsub, i.e. if
it isn't used in the opcode tree returned by you, you should free the
it.

=item Examples

=over 4

=item Calling a subroutine or not depending on some global environment.

sub dolog {
    print $log, @_;
}

# this subroutines compiles when $ENV{DEBUG} is set to calling 'dolog' with its arguments,
# otherwise it will do nothing (including NOT evaluting its arguments).
sub compdebuglog {
   my $op = shift;
   if ($ENV{DEBUG}) {
     my $cvop = B::SVOP->new('const', 0, *dolog);
     $op ||= B::LISTOP->new('list', 0, $cvop, undef);
     return B::UNOP->new('entersub', 0, $op);
   } else {
     $op && $op->free; # we don't use $op, so we must explicitly free it.
     return B::OP->new('null', 0);
   }
}

compsub::define( debuglog => \&compdebuglog );

...

debuglog Dump($complexvar);

=item parsing arguments and declaring lexical variables

sub compparseparam {

}

=back

=back

=head1 IMPLEMENTATION

...

=head1 AUTHOR

Gerard Goossen E<lt>F<gerard@tty.nl>E<gt>.

=head1 BUGS

=cut

