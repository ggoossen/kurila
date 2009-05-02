#!./perl

BEGIN { require './test.pl'; }

plan (4);

sub foo {
    my $x = nelems(@_);
    return $x;
}

my $x = &foo;
is(ref::svtype($x), 'CODE');
is((\$x)->("a", "b"), 2);

my $xssub = &Symbol::glob_name;
is( ref::svtype($xssub), 'CODE' );
is( (\$xssub)->(*BAR), 'main::BAR' );
