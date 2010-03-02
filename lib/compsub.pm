package compsub

sub define
    my %arg = %:  < @_ 
    # warning: alwyas create a new hash; %^H is saved, and altering
    # values referenced by it, will have effect on it.
    $^HINTS{+'compsub'} = \%:
        < ( $^HINTS{?'compsub'} || \$% )->%
        < %arg
        


1
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

=head1 WARNING

This module will create segmentation faults if you don't know how to
use it properly. You are expected to be familiar with the perl internals
to use this module properly.

=head1 DESCRIPTION

=head2 Compilation subroutines

Compilation subroutines are lexically scoped keywords with perl sub
attached to it which gets called during compile time. When the
keyword is used the arguments to it are normally parsed, but after that
the perl sub attached to the keyword is called with as argument the argument
of its keyword as opcode tree. The sub returns an opcode tree.
Thus the sub receive an opcode tree, and returns a opcode tree.

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
Things it can do at compile time are for example: pre-process constant arguments,
do some basic argument verfication, declare other compilation subs, inline calls.
Things it can do at run-time are
for example: call a subroutine with its normal arguments, do nothing, evaluate
one of its arguments multiple times, call multiple subroutines with the same arguments.

=head2 Writing compilation subs

A compilation subs are lexical scope, and can be declared into the lexical scope
currently being compiled using:

    compsub::define( foo => \&compfoo )

This defines a compilation subroutine C<foo>, which gets compiled using C<compfoo>.
To declare the function at compile-time, you usually have to define it in a BEGIN block
or in an C<import> routine.
When C<foo> is used C<compfoo> gets called with as argument the opcode for the
list following C<foo>. C<compfoo> is expected to return an opcode, this opcode
will be inserted in the place where C<foo> is called. Opcodes are instances of
C<B::OP> or one of its subclasses.

There is no verification of the "correctness" of the opcode tree
generated, so you may easily created opcode trees which wrong and generate
segfaults or manipulate random memory and stuff like that.

See also C<B::OP> about creating and maniuplating op trees.

=item Freeing opcodes

Opcodes discarded are not automaticly freed. The opcodes are freed normally with freeing of the sub. If
you want to discard an opcode you have to explicitly call 'free' on
it. This also applies to the opcode passed to the compsub, i.e. if
it isn't used in the opcode tree returned by you, you should free the
it.

=item Examples

=over 4

=item Calling a subroutine or not depending on some global environment.

This example creates a compilation sub C<debuglog>, which calls C<dolog> if C<$ENV{DEBUG}>
is set. Thus checking for C<$ENV{DEBUG}> is done at compile time, and if
it not set no code is executed at run-time.


  sub dolog {
      print $log, @_;
  }
  
  # this subroutines compiles when $ENV{DEBUG} is set to calling 'dolog' with its arguments,
  # otherwise it will do nothing (including NOT evaluting its arguments).
  sub compdebuglog {
     my $op = shift;
     if ($ENV{DEBUG}) {
       my $cvop = B::SVOP->new('const', 0, *dolog);
       $op = B::LISTOP->new('list', 0, ($op ? ($op, $cvop) : ($cvop, undef)));
       return B::UNOP->new('entersub', B::OPf_STACKED|B::OPf_SPECIAL, $op);
     } else {
       $op && $op->free; # we don't use $op, so we must explicitly free it.
       return B::OP->new('null', 0);
     }
  }
  
  compsub::define( debuglog => \&compdebuglog );
  
  ...
  
  debuglog Dump($complexvar);

=item parsing arguments and declaring lexical variables

In this example a keyword C<params> is created.
This keyword expects a list of compile-time constant string arguments, and
as last argument a hashref. It creates a lexical scope variable for each
string argument. At run-time the lexical scoped variables set to the hash value
with their name.


    # assumes argument like: 'foo' => \$foo, 'bar' => \$bar, { @_ }
    sub parseparams {
        my $values = pop @_;
        while (my $name = shift @_) {
            $_[0] = $values->{$name};
            shift @_;
        }
    }

    # assumes argument like C<'foo', 'bar', { @_ }>
    # this will be converted like C<parseparams('foo', \(my $foo), 'bar', \(my $bar), { @_ })>
    sub compparams {
        my $op = shift;
        $op or return B::UNOP->new('null', 0);
        my $kid = $op->first;
        while (ref $kid ne "B::NULL") {
            if ($kid->name eq "const") {
                # allocate a 'my' variable
                my $targ = B::PAD::allocmy( '$' . ${ $kid->sv->object_2svref } );
                # introduce the 'my' variable, and insert it into the list of argument.
                my $padsv = B::OP->new('padsv', B::OPf_MOD);
                $padsv->set_private(B::OPpLVAL_INTRO);
                $padsv->set_targ($targ);
                $padsv->set_sibling($kid->sibling);
                $kid->set_sibling($padsv);

                $kid = $padsv;
            } elsif ($kid->name eq "list" or $kid->name eq "pushmark") {
                # ignore
            } elsif ($kid->name eq "anonhash") {
                # ignore, assume it is the last item in the list.
            } else {
                die "Expected constant opcode but got " . $kid->name;
            }
            $kid = $kid->sibling;
        }
        my $cvop = B::SVOP->new('const', 0, *parseparams);
        $op = B::LISTOP->new('list', 0, ($op ? ($op, $cvop) : ($cvop, undef)));
        my $entersubop = B::UNOP->new('entersub', B::OPf_STACKED|B::OPf_SPECIAL, $op);
        return $entersubop;
    }

    BEGIN {
        compsub::define( params => \&compparams )
    }

    {
        sub foobar {
            params 'foo', 'bar', { @_ };
            is $foo, 'foo-value', '$foo declared and initialized';
            is $bar, 'bar-value';
        }

        foobar( foo => "foo-value", bar => "bar-value" );
    }

=back

=back

=head2 IMPLEMENTATION

The hint hash C<%^H> is used to define the lexical scoped keyword. And is used during
tokenizing to find the subroutine. After it a C<listexpr> is expected by the parser. After
parsing the C<listexpr>, C<ck_compsub> calls the subroutine and returns the opcode return
by the sub.

=head1 AUTHOR

Gerard Goossen E<lt>F<gerard@tty.nl>E<gt>.

=head1 BUGS

=cut

