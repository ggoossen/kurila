#!./perl

BEGIN { require './test.pl'; }

plan(8)

sub foo
    my $x = nelems(@_)
    return 'foo' . $x

sub bar
    my $x = nelems(@_)
    return 'bar' . $x

my $x = &foo
is(ref::svtype($x), 'CODE')
is((\$x)->("a", "b"), 'foo2')

my $xssub = &Symbol::glob_name
is( ref::svtype($xssub), 'CODE' )
is( (\$xssub)->(*BAR), 'main::BAR' )

do
    my $x = &foo
    ok( $x )
    is( ($x <: "a"), 'foo1')
    my $y = $x
    is( ($y <: "a"), 'foo1')
    $y = &bar
    is( ($y <: "a"), 'bar1')

eval_dies_like( '&foo()', qr/syntax error/ )
