#!./perl

BEGIN
    require "./test.pl"

plan: tests => 6

my $foo = sub() return "foo"
my $x = \ $foo

is:  ($x->&->& <: ), "foo"
is: \($x->&), \ $foo 
is: \($x->&), $x

do
    my $bar = sub() return "bar"
    $x->& = $bar
    is:  \($x->&), $x 
    isnt:  \($x->&), \ $bar 
    is:  ($x->&->& <: ), "bar" 
