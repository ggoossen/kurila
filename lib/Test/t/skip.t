# -*-perl-*-
use Test < qw($TESTOUT $TESTERR $ntest plan ok skip); 
plan tests => 6;

open my $f, ">", "skips" or die "open skips: $^OS_ERROR";
$TESTOUT = $f;
$TESTERR = $f;

skip(1, 0);  #should skip

my $skipped=1;
skip('hop', sub { $skipped = 0 });
skip(sub {'jump'}, sub { $skipped = 0 });
skip('skipping stones is more fun', sub { $skipped = 0 });

close $f;

$TESTOUT = $^STDOUT{IO};
$TESTERR = $^STDERR{IO};
$ntest = 1;
open $f, "<", "skips" or die "open skips: $^OS_ERROR";

ok $skipped, 1, 'not skipped?';

my @T = @( ~< *$f );
chop @T;
my @expect = split m/\n+/, join('', @( ~< *DATA));
ok (nelems @T), 4;
for my $x (0 .. nelems(@T)-1) {
    ok @T[$x], @expect[$x];
}

END { close $f; unlink "skips" }

__DATA__
ok 1 # skip

ok 2 # skip hop

ok 3 # skip jump

ok 4 # skip skipping stones is more fun
