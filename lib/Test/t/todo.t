# -*-perl-*-
use Test < qw(:DEFAULT $TESTOUT $TESTERR $ntest);

### This test is crafted in such a way as to prevent Test::Harness from
### seeing the todo tests, otherwise you get people sending in bug reports
### about Test.pm having "UNEXPECTEDLY SUCCEEDED" tests.

open my $f, ">", "todo";
$TESTOUT = \*$f;
$TESTERR = \*$f;
my $tests = 5; 
plan tests => $tests, todo => \$: 2..$tests; 


# tests to go to the output file
ok(1);
ok(1);
ok(0,1);
ok(0,1,"need more tuits");
ok(1,1);

close $f;
$TESTOUT = *STDOUT{IO};
$TESTERR = *STDERR{IO};
$ntest = 1;

open $f, "<", "todo";
my $out = join '', @( ~< *$f);
close $f;
unlink "todo";

my $expect = <<"EXPECT";
1..5 todo 2 3 4 5;
ok 1
ok 2 # ($^PROGRAM_NAME at line 17 TODO?!)
not ok 3
# Test 3 got: '0' ($^PROGRAM_NAME at line 18 *TODO*)
#   Expected: '1'
not ok 4
# Test 4 got: '0' ($^PROGRAM_NAME at line 19 *TODO*)
#   Expected: '1' (need more tuits)
ok 5 # ($^PROGRAM_NAME at line 20 TODO?!)
EXPECT


sub commentless {
  my $in = @_[0];
  $in =~ s/^#[^\n]*\n//mg;
  $in =~ s/\n#[^\n]*$//mg;
  return $in;
}

print \*STDOUT, "1..1\n";
ok( commentless($out), commentless($expect) );
