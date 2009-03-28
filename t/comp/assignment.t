#!./perl -w

BEGIN {
    require './test.pl';
}

plan( tests => 4 );

my ($x, $y, $z);
$x = ($y = 3);
is( $x, 3);
is( $y, 3);

$y = 8;
$x = $y += 13;
is( $y, 21 );
is( $x, 21 );
