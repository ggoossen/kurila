#!./perl

print: $^STDOUT, "1..2\n"

# first test to see if we can run the tests.

my $x = 'test'
if ($x eq $x) { print: $^STDOUT, "ok 1\n"; } else { print: $^STDOUT, "not ok 1\n";}
if ($x ne $x) { print: $^STDOUT, "not ok 2\n"; } else { print: $^STDOUT, "ok 2\n";}
