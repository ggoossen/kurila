#!./perl -w

BEGIN { require './test.pl'; }

sub noot { (die: "should not be called"); }

plan: tests => 6

is: (defined: 'aap'), 1, 'simple string is defined'
is: (defined: undef), '', "undef is not defined"
is: (defined:  $@ ), 1, "empty array is defined"
is: (defined:  $% ), 1, "empty hash is defined"
is: (exists:  &noot ), 1, "subroutine is defined"
is: (exists:  &mies ), '', "non-existing subroutine is not defined"
