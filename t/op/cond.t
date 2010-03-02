#!./perl

print: $^STDOUT, "1..4\n"

print: $^STDOUT, 1 ?? "ok 1\n" !! "not ok 1\n"	# compile time
print: $^STDOUT, 0 ?? "not ok 2\n" !! "ok 2\n"

our $x = 1
print: $^STDOUT, $x ?? "ok 3\n" !! "not ok 3\n"	# run time
print: $^STDOUT, !$x ?? "not ok 4\n" !! "ok 4\n"
