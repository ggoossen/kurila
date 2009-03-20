# -*-perl-*-

use Test < qw($ntest plan ok $TESTOUT $TESTERR);
our ($mycnt);

my $why = "zero != one";

sub myfail($f) {
    ok((nelems @$f), 1);

    my $t = @$f[0];
    ok(%$t{?diagnostic}, $why);
    ok(%$t{?'package'}, 'main');
    ok(%$t{?repetition}, 1);
    ok(%$t{?result}, 0);
    ok(%$t{?expected}, 1);
}

BEGIN { plan test => 6, onfail => \&myfail }

$mycnt = 0;

# sneak in a test that Test::Harness wont see
open my $j, ">", "junk";
$TESTOUT = $j;
$TESTERR = $j;
ok(0, 1, $why);
$TESTOUT = *STDOUT{IO};
$TESTERR = *STDERR{IO};
close $j;
unlink "junk";
$ntest = 1;
