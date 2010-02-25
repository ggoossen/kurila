#! perl

BEGIN
    require "./test.pl"

plan: tests => 3

is:  (join: "*", qw[aap noot] +@+ qw[mies zus]), "aap*noot*mies*zus" 
is:  (join: "*", 1..3 +@+ 5..6), "1*2*3*5*6" 
is:  (join: "*", 1..3 +@+ 5..6 +@+ 8..8), "1*2*3*5*6*8" 
