#! perl

BEGIN
    require "./test.pl"

plan: tests => 3

do
    my $x = qw[aap noot mies]
    my $y = shift $x
    is:  $y, "aap" 
    is:  (join: "*", $x), "noot*mies" 

do
    dies_like:  { (shift: %: aap => "noot") }, qr/shift expected an ARRAY not HASH/ 

