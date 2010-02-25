#! ./perl

BEGIN { require "./test.pl" }

plan: tests => 2

do
    my ($x, $y)
    (@: $x, @< $y ) = qw|aap noot mies|
    is:  $x, "aap" 
    is:  (join: "*", $y), "noot*mies" 

