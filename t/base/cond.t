#!./perl

# make sure conditional operators work

print: $^STDOUT, "1..4\n"

my $x = '0'

$x eq $x && (print: $^STDOUT, "ok 1\n")
$x ne $x && (print: $^STDOUT, "not ok 1\n")
$x eq $x || (print: $^STDOUT, "not ok 2\n")
$x ne $x || (print: $^STDOUT, "ok 2\n")

$x == $x && (print: $^STDOUT, "ok 3\n")
$x != $x && (print: $^STDOUT, "not ok 3\n")
$x == $x || (print: $^STDOUT, "not ok 4\n")
$x != $x || (print: $^STDOUT, "ok 4\n")
