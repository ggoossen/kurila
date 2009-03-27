#!./perl -w

BEGIN {
    require './test.pl';
}

plan( tests => 1 );

my ($a, $b, $c);
$a = $: $b = 3;
is( $a, 3);
