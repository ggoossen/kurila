#!./perl

BEGIN 
    require './test.pl'

BEGIN 
    if ($^OS_NAME eq 'riscos')
        skip_all: "kill() not implemented on this platform"

plan: tests => 5

ok:  (kill: 0, $^PID), 'kill(0, $pid) returns true if $pid exists' 

# It's not easy to come up with an individual PID that is known not to exist,
# so just check that at least some PIDs in a large range are reported not to
# exist.
my $count = 0
my $total = 30_000
for my $pid (1 .. $total)
    ++$count if kill: 0, $pid

# It is highly unlikely that all of the above PIDs are genuinely in use,
# so $count should be less than $total.
ok:  $count +< $total, 'kill(0, $pid) returns false if $pid does not exist' 

# Verify that trying to kill a non-numeric PID is fatal
my @bad_pids = @:
    @: undef , 'undef'
    @: ''    , 'empty string'
    @: 'abcd', 'alphabetic'

for my $case ( @bad_pids )
  my @: $pid, $name = $case
  dies_like:  { (kill: 0, $pid) }
              qr/^Can't kill a non-numeric process ID/, "dies killing $name pid"
