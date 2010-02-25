#!./perl

BEGIN 
    require './test.pl'


print: $^STDOUT, "1..1\n"


our $y = 1
do
    my $y = 2
    do
        our $y = $y
        is: $y, 2, 'our shouldnt be visible until introduced'
    

