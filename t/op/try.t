#!./perl

print "1..6\n";

require './test.pl';

try {
    print "ok 1\n";
    die "ok 3\n";
    1;
} || print "ok 2\n$@->{description}";

my $test = 4;

# return from try {} should clear $@ correctly
{
    my $status = try {
	try { die };
	print "# eval \{ return \} test\n";
	return; # removing this changes behavior
    };
    print "not " if $@;
    print "ok $test\n";
    $test++;
}

# Check that eval catches bad goto calls
#   (BUG ID 20010305.003)
{
    try {
	try { goto foo; };
	print ($@ ? "ok $test\n" : "not ok $test\n");
	last;
	foreach my $i (1) {
	    foo: print "not ok $test\n";
	    print "# jumped into foreach\n";
	}
    };
    print "not ok $test\n" if $@;
    $test++;
}

# [perl #34682] escaping an eval with last could coredump or dup output

my $got = runperl (
    prog => 
    'no strict; sub A::TIEARRAY { L: { try { last L } } } tie my @a, q(A); warn qq(ok\n)',
                   stderr => 1);
$test++;

print "not " unless $got =~ qr/^ok\n/;
print "ok $test - eval and last\n"; $test++;
