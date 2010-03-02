#! perl

BEGIN
    require "./test.pl"

plan: tests => 4

is:  (ref::svtype: $%), 'HASH' 
is:  (join: "*", keys $%), "" 

my $x = \ $%
my $y = \ $%
$x->{+"aap"} = "noot"
is:  (join: "*", keys $x->$), "aap" 
is:  (join: "*", keys $y->$), "" 

