BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
}

BEGIN { $| = 1; print "1..25\n"; }

END {print "not ok 1\n" unless $loaded;}

use Time::HiRes qw(tv_interval);

$loaded = 1;

print "ok 1\n";

use strict;

my $have_gettimeofday	= defined &Time::HiRes::gettimeofday;
my $have_usleep		= defined &Time::HiRes::usleep;
my $have_ualarm		= defined &Time::HiRes::ualarm;
my $have_time		= defined &Time::HiRes::time;

import Time::HiRes 'gettimeofday'	if $have_gettimeofday;
import Time::HiRes 'usleep'		if $have_usleep;
import Time::HiRes 'ualarm'		if $have_ualarm;

use Config;

sub skip {
    map { print "ok $_ (skipped)\n" } @_;
}

sub ok {
    my ($n, $result, @info) = @_;
    if ($result) {
    	print "ok $n\n";
    }
    else {
	print "not ok $n\n";
    	print "# @info\n" if @info;
    }
}

if (!$have_gettimeofday) {
    skip 2..6;
}
else {
    my @one = gettimeofday();
    ok 2, @one == 2, 'gettimeofday returned ', 0+@one, ' args';
    ok 3, $one[0] > 850_000_000, "@one too small";

    sleep 1;

    my @two = gettimeofday();
    ok 4, ($two[0] > $one[0] || ($two[0] == $one[0] && $two[1] > $one[1])),
    	    "@two is not greater than @one";

    my $f = Time::HiRes::time();
    ok 5, $f > 850_000_000, "$f too small";
    ok 6, $f - $two[0] < 2, "$f - @two >= 2";
}

if (!$have_usleep) {
    skip 7..8;
}
else {
    my $one = time;
    usleep(10_000);
    my $two = time;
    usleep(10_000);
    my $three = time;
    ok 7, $one == $two || $two == $three, "slept too long, $one $two $three";

    if (!$have_gettimeofday) {
    	skip 8;
    }
    else {
    	my $f = Time::HiRes::time();
	usleep(500_000);
        my $f2 = Time::HiRes::time();
	my $d = $f2 - $f;
	ok 8, $d > 0.4 && $d < 0.8, "slept $d secs $f to $f2";
    }
}

# Two-arg tv_interval() is always available.
{
    my $f = tv_interval [5, 100_000], [10, 500_000];
    ok 9, abs($f - 5.4) < 0.001, $f;
}

if (!$have_gettimeofday) {
    skip 10;
}
else {
    my $r = [gettimeofday()];
    my $f = tv_interval $r;
    ok 10, $f < 2, $f;
}

if (!$have_usleep || !$have_gettimeofday) {
    skip 11;
}
else {
    my $r = [gettimeofday()];
    #jTime::HiRes::sleep 0.5;
    Time::HiRes::sleep( 0.5 );
    my $f = tv_interval $r;
    ok 11, $f > 0.4 && $f < 0.8, "slept $f secs";
}

if (!$have_ualarm) {
    skip 12..13;
}
else {
    my $tick = 0;
    local $SIG{ALRM} = sub { $tick++ };

    my $one = time; $tick = 0; ualarm(10_000); sleep until $tick;
    my $two = time; $tick = 0; ualarm(10_000); sleep until $tick;
    my $three = time;
    ok 12, $one == $two || $two == $three, "slept too long, $one $two $three";

    $tick = 0;
    ualarm(10_000, 10_000);
    sleep until $tick >= 3;
    ok 13, 1;
    ualarm(0);
}

# new test: did we even get close?

if (!$have_time) {
    skip 14
} else {
 my ($t1, $tf, $t2);
 for my $i (1 .. 20) {
     $t1 = time();
     $tf = Time::HiRes::time();
     $t2 = 1 + time();
     last if (($t2 - $t1) <= 1) && $t1 <= $tf;
 }
 ok 14, (($t1 <= $tf) && ($tf <= $t2)),
      "Time::HiRes::time $tf not bracketed by [$t1, $t2]";

}

unless (defined &Time::HiRes::gettimeofday
	&& defined &Time::HiRes::ualarm
	&& defined &Time::HiRes::usleep) {
    for (15..17) {
	print "ok $_ # skipped\n";
    }
} else {
    use Time::HiRes qw (time alarm sleep);

    my ($f, $r, $i);

    $f = time; 
    print "# time...$f\n";
    print "ok 15\n";

    $r = [Time::HiRes::gettimeofday()];
    sleep (0.5);
    print "# sleep...", Time::HiRes::tv_interval($r), "\nok 16\n";

    $r = [Time::HiRes::gettimeofday()];
    $i = 5;
    $SIG{ALRM} = "tick";
    while ($i > 0)
    {
	alarm(0.3);
	select (undef, undef, undef, 10);
	print "# Select returned! $i ", Time::HiRes::tv_interval ($r), "\n";
    }

    sub tick
    {
	$i--;
	print "# Tick! $i ", Time::HiRes::tv_interval ($r), "\n";
    }
    alarm(0); # can't cancel usig %SIG

    print "ok 17\n";
}

unless (defined &Time::HiRes::setitimer
	&& defined &Time::HiRes::getitimer
	&& exists &Time::HiRes::ITIMER_VIRTUAL
	&& $Config{d_select}
	&& $Config{sig_name} =~ m/\bVTALRM\b/) {
    for (18..19) {
	print "ok $_ # Skip: no virtual interval timers\n";
    }
} else {
    use Time::HiRes qw (setitimer getitimer ITIMER_VIRTUAL);

    my $i = 3;
    my $r = [Time::HiRes::gettimeofday()];

    $SIG{VTALRM} = sub {
	$i ? $i-- : setitimer(ITIMER_VIRTUAL, 0);
	print "# Tick! $i ", Time::HiRes::tv_interval($r), "\n";
    };	

    print "# setitimer: ", join(" ", setitimer(ITIMER_VIRTUAL, 0.5, 0.4)), "\n";

    # Assume interval timer granularity of 0.05 seconds.  Too bold?
    print "not " unless abs(getitimer(ITIMER_VIRTUAL) / 0.5) - 1 < 0.1;
    print "ok 18\n";

    print "# getitimer: ", join(" ", getitimer(ITIMER_VIRTUAL)), "\n";

    while (getitimer(ITIMER_VIRTUAL)) {
	my $j; $j++ for 1..1000; # Can't be unbreakable, must test getitimer().
    }

    print "# getitimer: ", join(" ", getitimer(ITIMER_VIRTUAL)), "\n";

    print "not " unless getitimer(ITIMER_VIRTUAL) == 0;
    print "ok 19\n";

    $SIG{VTALRM} = 'DEFAULT';
}

if ($have_gettimeofday) {
    my ($t0, $td);

    my $sleep = 1.5; # seconds
    my $limit = 0.1; # 10% is acceptable slosh for timers
    my $msg;

    $t0 = gettimeofday();
    $a = abs(sleep($sleep)        / $sleep         - 1.0);
    $td = gettimeofday() - $t0;

    $msg = "$td went by while sleeping $sleep, ratio $a\n";

    if ($td < $sleep * (1 + $limit)) {
	print $a < $limit ? "ok 20 # $msg" : "not ok 20 # $msg";
    } else {
	print "ok 20 # Skip: $msg";
    }

    $t0 = gettimeofday();
    $a = abs(usleep($sleep * 1E6) / ($sleep * 1E6) - 1.0);
    $td = gettimeofday() - $t0;

    $msg = "$td went by while sleeping $sleep, ratio $a\n";

    if ($td < $sleep * (1 + $limit)) {
	print $a < $limit ? "ok 21 # $msg" : "not ok 21 # $msg";
    } else {
	print "ok 21 # Skip: $msg";
    }

} else {
    for (20..21) {
	print "ok $_ # Skip: no gettimeofday\n";
    }
}

eval { sleep(-1) };
print $@ =~ /::sleep\(-1\): negative time not invented yet/ ?
    "ok 22\n" : "not ok 22\n";

eval { usleep(-2) };
print $@ =~ /::usleep\(-2\): negative time not invented yet/ ?
    "ok 23\n" : "not ok 23\n";

if ($have_ualarm) {
    eval { alarm(-3) };
    print $@ =~ /::alarm\(-3, 0\): negative time not invented yet/ ?
	"ok 24\n" : "not ok 24\n";

    eval { ualarm(-4) };
    print $@ =~ /::ualarm\(-4, 0\): negative time not invented yet/ ?
    "ok 25\n" : "not ok 25\n";
} else {
    skip 24;
    skip 25;
}
