#!./perl

BEGIN { require './test.pl'; }

plan(5)

sub foo
    my $x = nelems(@_)
    return $x


my $x = &foo
is(ref::svtype($x), 'CODE')
is((\$x)->("a", "b"), 2)

my $xssub = &Symbol::glob_name
is( ref::svtype($xssub), 'CODE' )
is( (\$xssub)->(*BAR), 'main::BAR' )

eval_dies_like( '&foo()', qr/foobar/ )
