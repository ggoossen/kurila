#!./perl

BEGIN {
    unless (PerlIO::Layer->find( 'perlio')) {
	print "1..0 # Skip: not perlio\n";
	exit 0;
    }
    require Config;
}

use Fcntl < qw(SEEK_SET SEEK_CUR SEEK_END); # Not 0, 1, 2 everywhere.

$^OUTPUT_AUTOFLUSH = 1;

use Test::More tests => 52;

my $fh;
my $var = "aaa\n";
ok(open($fh,"+<",\$var));

is( ~< $fh, $var);

ok(eof($fh));

ok(seek($fh,0,SEEK_SET));
ok(!eof($fh));

ok(print $fh "bbb\n");
is($var, "bbb\n");
$var = "foo\nbar\n";
ok(seek($fh,0,SEEK_SET));
ok(!eof($fh));
is( ~< $fh, "foo\n");
ok(close $fh, $^OS_ERROR);

# Test that semantics are similar to normal file-based I/O
# Check that ">" clobbers the scalar
$var = "Something";
open $fh, ">", \$var;
is($var, "");
#  Check that file offset set to beginning of scalar
my $off = tell($fh);
is($off, 0);
# Check that writes go where they should and update the offset
$var = "Something";
print $fh "Brea";
$off = tell($fh);
is($off, 4);
is($var, "Breathing");
close $fh;

# Check that ">>" appends to the scalar
$var = "Something ";
open $fh, ">>", \$var;
$off = tell($fh);
is($off, 10);
is($var, "Something ");
#  Check that further writes go to the very end of the scalar
$var .= "else ";
is($var, "Something else ");

$off = tell($fh);
is($off, 10);

print $fh "is here";
is($var, "Something else is here");
close $fh;

# Check that updates to the scalar from elsewhere do not
# cause problems
$var = "line one\nline two\nline three\n";
open $fh, "<", \$var;
while ( ~< $fh) {
    $var = "foo";
}
close $fh;
is($var, "foo");

# Check that dup'ing the handle works

$var = '';
open $fh, "+>", \$var;
print $fh "xxx\n";
open my $dup,'+<&',$fh;
print $dup "yyy\n";
seek($dup,0,SEEK_SET);
is( ~< $dup, "xxx\n");
is( ~< $dup, "yyy\n");
close($fh);
close($dup);

open $fh, '<', \42;
is( ~< $fh, "42", "reading from non-string scalars");
close $fh;

do {
    use warnings;
    my $warn = 0;
    local $^WARN_HOOK = sub { $warn++ };
    open my $fh, '>', \my $scalar;
    print $fh "foo";
    close $fh;
    is($warn, 0, "no warnings when writing to an undefined scalar");
};

do {
    use warnings;
    my $warn = 0;
    local $^WARN_HOOK = sub { $warn++ };
    for (1..2) {
        open my $fh, '>', \my $scalar;
        close $fh;
    }
    is($warn, 0, "no warnings when reusing a lexical");
};

do {
    use warnings;
    my $warn = 0;
    local $^WARN_HOOK = sub { $warn++ };
    my $scalar = 3;
    undef $scalar;
    open my $fh, '<', \$scalar;
    close $fh;
    is($warn, 0, "no warnings reading an undef, allocated scalar");
};

my $data = "a non-empty PV";
$data = undef;
open(MEM, '<', \$data) or die "Fail: $^OS_ERROR\n";
my $x = join '', @: ~< *MEM;
is($x, '');

do {
    # [perl #35929] verify that works with $/ (i.e. test PerlIOScalar_unread)
    my $s = <<'EOF';
line A
line B
a third line
EOF
    open(F, '<', \$s) or die "Could not open string as a file";
    local $^INPUT_RECORD_SEPARATOR = "";
    my $ln = ~< *F;
    close F;
    is($ln, $s, "[perl #35929]");
};

# [perl #40267] PerlIO::scalar doesn't respect readonly-ness
do {
    ok(!(defined open(F, '>', \undef)), "[perl #40267] - $^OS_ERROR");
    close F;

    my $ro = \43;
    ok(!(defined open(F, '>', $ro)), $^OS_ERROR);
    close F;
    # but we can read from it
    ok(open(F, '<', $ro), $^OS_ERROR);
    is( ~< *F, 43);
    close F;
};

do {
    # Check that we zero fill when needed when seeking,
    # and that seeking negative off the string does not do bad things.

    my $foo;

    ok(open(F, '>', \$foo));

    # Seeking forward should zero fill.

    ok(seek(F, 50, SEEK_SET));
    print F "x";
    is(length($foo), 51);
    like($foo, qr/^\0{50}x$/);

    is(tell(F), 51);
    ok(seek(F, 0, SEEK_SET));
    is(length($foo), 51);

    # Seeking forward again should zero fill but only the new bytes.

    ok(seek(F, 100, SEEK_SET));
    print F "y";
    is(length($foo), 101);
    like($foo, qr/^\0{50}x\0{49}y$/);
    is(tell(F), 101);

    # Seeking back and writing should not zero fill.

    ok(seek(F, 75, SEEK_SET));
    print F "z";
    is(length($foo), 101);
    like($foo, qr/^\0{50}x\0{24}z\0{24}y$/);
    is(tell(F), 76);

    # Seeking negative should not do funny business.

    ok(!seek(F,  -50, SEEK_SET), $^OS_ERROR);
    ok(seek(F, 0, SEEK_SET));
    ok(!seek(F,  -50, SEEK_CUR), $^OS_ERROR);
    ok(!seek(F, -150, SEEK_END), $^OS_ERROR);
};

