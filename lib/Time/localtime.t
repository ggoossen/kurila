#!./perl

BEGIN
    require "./test.pl"

my(@times, @methods)
BEGIN
    @times   = @: -2**62, -2**50, -2**33, -2**31-1, -1, 0, 1, 2**31-1, 2**33, 2**50, 2**62, time
    @methods = qw(sec min hour mday mon year wday yday isdst)

    plan: tests => ((nelems: @times) * (nelems: @methods)) + 1

    use_ok: 'Time::localtime'

for my $time (@times)
    my $localtime = $: localtime: $time          # This is the OO localtime.
    my @localtime = @: CORE::localtime $time    # This is the localtime function

    for my $method (@methods)
        is: ($localtime->?$method: ), shift @localtime, "localtime($time)->$method"
