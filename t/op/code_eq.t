#!./perl

BEGIN 
    require './test.pl'


plan: tests => 10

my $x = sub() "foo"
my $y = sub() "bar"
my $x_copy = $x

is:  $x &== $x, 1, "&== true"
is:  $x &== $y, '', "&== false"
is:  $x &== $x_copy, 1, "&== true for copied sub"

dies_like:  { 1 &== $x }, qr/Expected a CODE but got a PLAINVALUE/ 
dies_like:  { $x &== 1 }, qr/Expected a CODE but got a PLAINVALUE/ 

## code_ne

is:  $x &!= $x, '', "&!= false"
is:  $x &!= $y, 1, "&!= true"
is:  $x &!= $x_copy, '', "&!= false for copied sub"

dies_like:  { 1 &!= $x }, qr/Expected a CODE but got a PLAINVALUE/ 
dies_like:  { $x &!= 1 }, qr/Expected a CODE but got a PLAINVALUE/ 

