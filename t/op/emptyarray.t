#! perl

BEGIN
    require "./test.pl"

plan: tests => 4

is:  (ref::svtype: $@), 'ARRAY' 
is:  (join: "*", $@), "" 

my $x = \ $@
my $y = \ $@
push: $x->$, "aap"
is:  (join: "*", $x->$), "aap" 
is:  (join: "*", $y->$), "" 

