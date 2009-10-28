#!./perl

use Config

print: $^STDOUT, "1..2\n"

eval <<'EOP'
	no ops 'fileno';	# equiv to "perl -M-ops=fileno"
	$a = fileno STDIN;
EOP

print: $^STDOUT, $^EVAL_ERROR->{?description} =~ m/trapped/ ?? "ok 1\n" !! "not ok 1\n# $^EVAL_ERROR\n"

eval <<'EOP'
	use ops ':default';	# equiv to "perl -M(as above) -Mops=:default"
	eval 1;
EOP

print: $^STDOUT, $^EVAL_ERROR->{?description} =~ m/trapped/ ?? "ok 2\n" !! "not ok 2\n# $^EVAL_ERROR\n"

1
