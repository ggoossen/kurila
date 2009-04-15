#!./perl -w

# Please keep this test this simple. (ie just one test.)
# There's some sort of not-croaking properly problem in Storable when built
# with 5.005_03. This test shows it up, whereas malice.t does not.
# In particular, don't use Test; as this covers up the problem.



BEGIN {
  die "Oi! No! Don't change this test so that Carp is used before Storable"
    if defined &Carp::carp;
}
use Storable < qw(freeze thaw);

print $^STDOUT, "1..2\n";

for my $test (@(1,2)) {
  try {thaw "\xFF\xFF"};
  if ($^EVAL_ERROR->{?description} =~ m/Storable binary image v127.255 more recent than I am \(v2\.\d+\)/)
    {
      print $^STDOUT, "ok $test\n";
    } else {
      chomp $^EVAL_ERROR;
      print $^STDOUT, "not ok $test # Expected a meaningful croak. Got '$^EVAL_ERROR'\n";
    }
}
