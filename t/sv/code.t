#!./perl

BEGIN { require './test.pl'; }

plan (2);

sub foo {
    my $x = nelems(@_);
    return $x;
}

my $x = &foo;
is(ref::svtype($x), 'CODE');
is((\$x)->("a", "b"), 2);
