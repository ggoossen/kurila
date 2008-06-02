#!./perl

print "1..94\n";

try {
    print "ok 1\n";
    die "ok 3\n";
    1;
} || print "ok 2\n$@->{description}";

my $t = 4;

# return from eval {} should clear $@ correctly
{
    my $status = try {
	try { die };
	print "# eval \{ return \} test\n";
	return; # removing this changes behavior
    };
    print "not " if $@;
    print "ok $t\n";
    $t++;
}

# Check that eval catches bad goto calls
#   (BUG ID 20010305.003)
{
    try {
	try { goto foo; };
	print ($@ ? "ok $t\n" : "not ok $t\n");
	last;
	foreach my $i (1) {
	    foo: print "not ok $t\n";
	    print "# jumped into foreach\n";
	}
    };
    print "not ok $t\n" if $@;
    $t++;
}

# [perl #34682] escaping an eval with last could coredump or dup output

$got = runperl (
    prog => 
    'no strict; sub A::TIEARRAY { L: { try { last L } } } tie my @a, q(A); warn qq(ok\n)',
stderr => 1);

print "not " unless $got =~ qr/^ok\n/;
print "ok $test - eval and last\n"; $test++;
