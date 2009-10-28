#!./perl

print: $^STDOUT, "1..2\n"

# first test to see if we can run the tests.

$_ = 'test'
if (m/^test/) { print: $^STDOUT, "ok 1\n"; } else { print: $^STDOUT, "not ok 1\n";}
if (m/^foo/) { print: $^STDOUT, "not ok 2\n"; } else { print: $^STDOUT, "ok 2\n";}
