#!./perl

# Test || in weird situations.


package main
BEGIN { require './test.pl' };

plan:  tests => 5 


my ($a, $b, $c)

$^OS_ERROR = 1
$a = $^OS_ERROR
my $a_str = sprintf: "\%s", $a
my $a_num = sprintf: "\%d", $a

$c = $a || $b

is: $c, $a_str
is: $c+0, $a_num   # force numeric context.

$a =~ m/./g or die: "Match failed for some reason" # Make $a magic

$c = $a || $b

is: $c, $a_str
is: $c+0, $a_num   # force numeric context.

my $val = 3

$c = $val || $b
is: $c, 3

