#!./perl

print "1..2\n";

# first test to see if we can run the tests.

$_ = 'test';
if (m/^test/) { print "ok 1\n"; } else { print "not ok 1\n";}
if (m/^foo/) { print "not ok 2\n"; } else { print "ok 2\n";}
