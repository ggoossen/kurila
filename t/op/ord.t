#!./perl

print "1..3\n";

# compile time evaluation

# 65	ASCII
# 193	EBCDIC
if (ord('A') == 65 || ord('A') == 193) {print "ok 1\n";} else {print "not ok 1\n";}

# run time evaluation

$x = 'ABC';
if (ord($x) == 65 || ord($x) == 193) {print "ok 2\n";} else {print "not ok 2\n";}

if (chr 65 eq 'A' || chr 193 eq 'A') {print "ok 3\n";} else {print "not ok 3\n";}
