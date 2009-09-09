#!./perl

BEGIN
    require "./test.pl"


my(@times, @methods)
BEGIN
    @times   = @: -2**62, -2**50, -2**33, -2**31-1, -1, 0, 1, 2**31-1, 2**33, 2**50, 2**62, time
    @methods = qw(sec min hour mday mon year wday yday isdst)

    plan tests => (nelems(@times) * nelems(@methods)) + 1

    use_ok 'Time::gmtime'


for my $time (@times)
    my $gmtime = $: gmtime $time          # This is the OO gmtime.
    my @gmtime = @: CORE::gmtime $time    # This is the gmtime function

    for my $method (@methods)
        is($gmtime->?$method, shift @gmtime, "gmtime($time)->$method")
