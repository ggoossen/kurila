#!./perl -w

BEGIN 
    require './test.pl'


plan:  tests => 6 

my ($x, $y, $z)
$x = ($y = 3)
is:  $x, 3
is:  $y, 3

$y = 8
$x = $y += 13
is:  $y, 21 
is:  $x, 21 

sub foo($y, $z) { $y + $z }
$x = foo: 21, 44
is:  $x, 65 

$y = 109
is:  (not $x = 109), '' 
