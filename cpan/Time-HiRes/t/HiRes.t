#!./perl -w

use TestInit
use Config
use signals

use Test::More
plan: tests => 38

use Time::HiRes v1.9704 < qw(tv_interval)

ok: 1


my $have_gettimeofday    = Time::HiRes::d_gettimeofday:  < @_ 
my $have_usleep          = Time::HiRes::d_usleep:  < @_ 
my $have_nanosleep       = Time::HiRes::d_nanosleep:  < @_ 
my $have_ualarm          = Time::HiRes::d_ualarm:  < @_ 
my $have_clock_gettime   = Time::HiRes::d_clock_gettime:  < @_ 
my $have_clock_getres    = Time::HiRes::d_clock_getres:  < @_ 
my $have_clock_nanosleep = Time::HiRes::d_clock_nanosleep:  < @_ 
my $have_clock           = Time::HiRes::d_clock:  < @_ 
my $have_hires_stat      = Time::HiRes::d_hires_stat:  < @_ 

sub has_symbol
    my $symbol = shift
    eval "use Time::HiRes < qw($symbol)"
    return 0 unless $^EVAL_ERROR eq ''
    eval "my \$a = $symbol"
    return $^EVAL_ERROR eq ''


info: sprintf: "have_gettimeofday    = \%d\n", $have_gettimeofday
info: sprintf: "have_usleep          = \%d\n", $have_usleep
info: sprintf: "have_nanosleep       = \%d\n", $have_nanosleep
info: sprintf: "have_ualarm          = \%d\n", $have_ualarm
info: sprintf: "have_clock_gettime   = \%d\n", $have_clock_gettime
info: sprintf: "have_clock_getres    = \%d\n", $have_clock_getres
info: sprintf: "have_clock_nanosleep = \%d\n", $have_clock_nanosleep
info: sprintf: "have_clock           = \%d\n", $have_clock
info: sprintf: "have_hires_stat      = \%d\n", $have_hires_stat

Time::HiRes->import: 'gettimeofday'     if $have_gettimeofday
Time::HiRes->import: 'usleep'           if $have_usleep
Time::HiRes->import: 'nanosleep'        if $have_nanosleep
Time::HiRes->import: 'ualarm'           if $have_ualarm
Time::HiRes->import: 'clock_gettime'    if $have_clock_gettime
Time::HiRes->import: 'clock_getres'     if $have_clock_getres
Time::HiRes->import: 'clock_nanosleep'  if $have_clock_nanosleep
Time::HiRes->import: 'clock'            if $have_clock

use Config

use Time::HiRes q(gettimeofday)

my $have_alarm = config_value: 'd_alarm'
my $have_fork  = config_value: 'd_fork'
my $waitfor = 180 # 30-45 seconds is normal (load affects this).
my $timer_pid
my $TheEnd

if ($have_fork)
    info: "I am the main process $^PID, starting the timer process..."
    $timer_pid = fork:
    if (defined $timer_pid)
        if ($timer_pid == 0) # We are the kid, set up the timer.
            my $ppid = getppid:
            info: "I am the timer process $^PID, sleeping for $waitfor seconds..."
            (sleep: $waitfor)
            warn: "\n$^PROGRAM_NAME: overall time allowed for tests ($($waitfor)s) exceeded!\n"
            diag: "Terminating main process $ppid..."
            (kill: 'TERM', $ppid)
            diag: "This is the timer process $^PID, over and out."
            (exit: 0)
        else 
            info: "The timer process $timer_pid launched, continuing testing..."
            $TheEnd = (time: ) + $waitfor
        
    else 
        warn: "$^PROGRAM_NAME: fork failed: $^OS_ERROR\n"
    
else 
    diag: "# No timer process (need fork)\n"


my $xdefine = '' 

if ((open: my $fh, "<", "xdefine"))
    (chomp: ($xdefine = ~< $fh->*))
    (close: $fh)


# Ideally, we'd like to test that the timers are rather precise.
# However, if the system is busy, there are no guarantees on how
# quickly we will return.  This limit used to be 10%, but that
# was occasionally triggered falsely.  
# So let's try 25%.
# Another possibility might be to print "ok" if the test completes fine
# with (say) 10% slosh, "skip - system may have been busy?" if the test
# completes fine with (say) 30% slosh, and fail otherwise.  If you do that,
# consider changing over to test.pl at the same time.
# --A.D., Nov 27, 2001
my $limit = 0.25 # 25% is acceptable slosh for testing timers

:SKIP do 
    skip: 4, "no gettimeofday" unless $have_gettimeofday

    my @one = (gettimeofday: )
    ok:  (nelems @one) == 2, 'gettimeofday returned 2 args'
    ok: @one[0] +> 850_000_000, '@one[0] too small'

    sleep 1

    my @two = (gettimeofday: )
    ok: (@two[0] +> @one[0] || (@two[0] == @one[0] && @two[1] +> @one[1]))
        '@two is not greater than @one'

    my $f = (Time::HiRes::time: )
    ok: $f +> 850_000_000, "$f too small"
    ok: $f - @two[0] +< 2, "$f - @two[0] >= 2"


unless ($have_usleep)
    (skip: 7..8)

else 
    use Time::HiRes < qw(usleep)
    my $one = time
    usleep: 10_000
    my $two = time
    usleep: 10_000
    my $three = time
    ok: $one == $two || $two == $three, "slept too long, $one $two $three"

    unless ($have_gettimeofday)
        (skip: 8)
    else 
        my $f = (Time::HiRes::time: )
        usleep: 500_000
        my $f2 = (Time::HiRes::time: )
        my $d = $f2 - $f
        ok: $d +> 0.4 && $d +< 0.9, "slept $d secs $f to $f2"
    


# Two-arg tv_interval() is always available.
do 
    my $f = tv_interval: \(@: 5, 100_000), \(@: 10, 500_000)
    ok: (abs: $f - 5.4) +< 0.001, $f


unless ($have_gettimeofday)
    (skip: 10)

else 
    my $r = \ (gettimeofday: )
    my $f = tv_interval: $r
    ok: $f +< 2, $f


unless ($have_usleep && $have_gettimeofday)
    (skip: 11)

else 
    my $r = \ (gettimeofday: )
    Time::HiRes::sleep:  0.5 
    my $f = tv_interval: $r
    ok: $f +> 0.4 && $f +< 0.9, "slept $f instead of 0.5 secs."


unless ($have_ualarm && $have_alarm)
    (skip: 12..13)

else
    my $tick = 0
    local (signals::handler: "ALRM") = sub { $tick++ }

    my $one = time; $tick = 0; (ualarm: 10_000); while ($tick == 0) { }
    my $two = time; $tick = 0; (ualarm: 10_000); while ($tick == 0) { }
    my $three = time
    ok: $one == $two || $two == $three, "slept too long, $one $two $three"
    info: "tick = $tick, one = $one, two = $two, three = $three"

    $tick = 0; (ualarm: 10_000, 10_000); while ($tick +< 3) { }
    ok: 1
    ualarm: 0
    info: "tick = $tick, one = $one, two = $two, three = $three"


# Did we even get close?

unless ($have_gettimeofday)
    (skip: 14)
else 
    my $s = 0
    my $n
    for my $i (1 .. 100)
        $s += (Time::HiRes::time: ) - (time: )
        $n++
    
    # $s should be, at worst, equal to $n
    # (time() may be rounding down, up, or closest),
    # but allow 10% of slop.
    ok: (abs: $s) / $n +<= 1.10, "Time::HiRes::time() not close to time()"
    diag: "# s = $s, n = $n, s/n = ", (abs: $s)/$n, "\n"


my $has_ualarm = config_value: 'd_ualarm'

$has_ualarm ||= $xdefine =~ m/-DHAS_UALARM/

unless (   exists &Time::HiRes::gettimeofday
    && exists &Time::HiRes::ualarm
    && exists &Time::HiRes::usleep
    && $has_ualarm)
    for (15..17)
        diag: "ok $_ # Skip: no gettimeofday or no ualarm or no usleep\n"
    
else 
    use Time::HiRes < qw(time alarm sleep)
    try { require POSIX }
    my $use_sigaction =
        !$^EVAL_ERROR && exists &POSIX::sigaction && (POSIX::SIGALRM: ) +> 0

    my ($f, $r, $i, $not, $ok)

    $f = (time: )
    diag: "# time...$f\n"
    ok: 1

    $r = \(Time::HiRes::gettimeofday: )
    sleep: 0.5
    diag: "# sleep..." . Time::HiRes::tv_interval: $r
    ok: 1

    $r = \$( (Time::HiRes::gettimeofday: ))
    $i = 5
    my $oldaction
    if ($use_sigaction)
        $oldaction = (POSIX::SigAction->new: )
        (diag: (sprintf: "# sigaction tick, ALRM = \%d\n", (POSIX::SIGALRM: )))

        # Perl's deferred signals may be too wimpy to break through
        # a restartable select(), so use POSIX::sigaction if available.

        POSIX::sigaction: (POSIX::SIGALRM: )
                          (POSIX::SigAction->new: &tick)
                          $oldaction
            or die: "Error setting SIGALRM handler with sigaction: $^OS_ERROR\n"
    else 
        diag: "# SIG tick\n"
        (signals::handler: "ALRM") = &tick

    # On VMS timers can not interrupt select.
    if ($^OS_NAME eq 'VMS')
        $ok = "Skip: VMS select() does not get interrupted."
    else 
        while ($i +> 0)
            (alarm: 0.3)
            (select: undef, undef, undef, 3)
            my $ival = (Time::HiRes::tv_interval : $r)
            info: "Select returned! $i $ival"
            (info: (abs: $ival/3 - 1))
            # Whether select() gets restarted after signals is
            # implementation dependent.  If it is restarted, we
            # will get about 3.3 seconds: 3 from the select, 0.3
            # from the alarm.  If this happens, let's just skip
            # this particular test.  --jhi
            if ((abs: $ival/3.3 - 1) +< $limit)
                $ok = "Skip: your select() may get restarted by your SIGALRM (or just retry test)"
                undef $not
                last
            
            my $exp = 0.3 * (5 - $i)
            # This test is more sensitive, so impose a softer limit.
            if ((abs: $ival/$exp - 1) +> 4*$limit)
                my $ratio = (abs: $ival/$exp)
                $not = "while: $exp sleep took $ival ratio $ratio"
                last
            
            $ok = $i
        
    

    sub tick
        $i--
        my $ival = Time::HiRes::tv_interval : $r
        info: "Tick! $i $ival"
        my $exp = 0.3 * (5 - $i)
        # This test is more sensitive, so impose a softer limit.
        if ((abs: $ival/$exp - 1) +> 4*$limit)
            my $ratio = (abs: $ival/$exp)
            $not = "tick: $exp sleep took $ival ratio $ratio"
            $i = 0

    if ($use_sigaction)
        POSIX::sigaction: (POSIX::SIGALRM: ), $oldaction
    else 
        alarm: 0 # can't cancel usig %SIG

    ok: ! $not


:SKIP do
    if ( (not: exists &Time::HiRes::setitimer
                  && exists &Time::HiRes::getitimer
                  && has_symbol: 'ITIMER_VIRTUAL'
                  && (config_value: "sig_name") =~ m/\bVTALRM\b/
                         && $^OS_NAME !~ m/^(nto)$/) ) # nto: QNX 6 has the API but no implementation
        skip: 2, "no virtual interval timers"
    

    use Time::HiRes < qw(setitimer getitimer ITIMER_VIRTUAL)

    my $i = 3
    my $r = \(Time::HiRes::gettimeofday: )

    (signals::handler: "VTALRM") = sub 
            $i ?? $i-- !! setitimer: (ITIMER_VIRTUAL: ), 0
            info: "Tick! $i " . Time::HiRes::tv_interval: $r

    info: "setitimer: ", join: " ", (setitimer: ITIMER_VIRTUAL, 0.5, 0.4)

    # Assume interval timer granularity of $limit * 0.5 seconds.  Too bold?
    my $virt = getitimer: (ITIMER_VIRTUAL:  < @_ )
    ok:  defined $virt && (abs: $virt[0] / 0.5) - 1 +< $limit 

    info: "getitimer: ", join: " ", (getitimer: ITIMER_VIRTUAL)

    while ((getitimer: (ITIMER_VIRTUAL:  < @_ )))
        my $j
        for (1..1000) { $j++ } # Can't be unbreakable, must test getitimer().
    

    $virt = getitimer: (ITIMER_VIRTUAL:  < @_ )
    ok:  not defined $virt 

    (signals::handler: "VTALRM") = 'DEFAULT'


:SKIP do 
    if (not $have_gettimeofday &&
        $have_usleep)
        skip: 2, "no gettimeofday"
    

    use Time::HiRes < qw(usleep)

    my ($t0, $td)

    my $sleep = 1.5 # seconds
    my $msg

    $t0 = (time: )
    $a = abs: (sleep: $sleep)        / $sleep         - 1.0
    $td = (time: ) - $t0
    my $ratio = 1.0 + $a

    $msg = "$td went by while sleeping $sleep, ratio $ratio.\n"

    :SKIP do 
        if ( not $td +< $sleep * (1 + $limit))
            (skip: 1, $msg)
        
        ok: $a +< $limit, $msg

    $t0 = (time: )
    $a = abs: (usleep: $sleep * 1E6) / ($sleep * 1E6) - 1.0
    $td = (time: ) - $t0
    $ratio = 1.0 + $a

    $msg = "$td went by while sleeping $sleep, ratio $ratio.\n"

    :SKIP do 
        if ( not $td +< $sleep * (1 + $limit))
            (skip: 1, $msg)
        
        ok: $a +< $limit, $msg


:SKIP do 
    unless ($have_nanosleep)
        skip: 2, "no nanosleep"
    

    my $one = CORE::time
    nanosleep: 10_000_000
    my $two = CORE::time
    nanosleep: 10_000_000
    my $three = CORE::time
    ok: $one == $two || $two == $three, "slept too long, $one $two $three"

    unless ($have_gettimeofday)
        (skip: 23)
    else 
        my $f = (Time::HiRes::time: )
        nanosleep: 500_000_000
        my $f2 = (Time::HiRes::time: )
        my $d = $f2 - $f
        ok: $d +> 0.4 && $d +< 0.9, "slept $d secs $f to $f2"
    


try { (sleep: -1) }
like: $^EVAL_ERROR->{description}, qr/::sleep\(-1\): negative time not invented yet/

try { (usleep: -2) }
like: $^EVAL_ERROR->{description}, qr/::usleep\(-2\): negative time not invented yet/

if ($have_ualarm)
    try { (alarm: -3) }
    like: $^EVAL_ERROR->{description}, qr/::alarm\(-3, 0\): negative time not invented yet/

    try { (ualarm: -4) }
    like: $^EVAL_ERROR->{description}, qr/::ualarm\(-4, 0\): negative time not invented yet/
else 
    skip: 26
    skip: 27


if ($have_nanosleep)
    try { (nanosleep: -5) }
    like: $^EVAL_ERROR->{description}, qr/::nanosleep\(-5\): negative time not invented yet/
else 
    skip: 28


# Find the loop size N (a for() loop 0..N-1)
# that will take more than T seconds.

if ($have_ualarm)
    # http://groups.google.com/group/perl.perl5.porters/browse_thread/thread/adaffaaf939b042e/20dafc298df737f0%2320dafc298df737f0?sa=X&oi=groupsr&start=0&num=3
    # Perl changes [18765] and [18770], perl bug [perl #20920]

    info: "Finding delay loop...";

    my $T = 0.01
    use Time::HiRes < qw(time)
    my $DelayN = 1024
    my $i
    :N while(1)
            my $t0 = (time: )
            my $i = 0
            while ($i +< $DelayN) { $i++ }
            my $t1 = (time: )
            my $dt = $t1 - $t0
            info: "N = $DelayN, t1 = $t1, t0 = $t0, dt = $dt"
            last N if $dt +> $T
            $DelayN *= 2

    # The time-burner which takes at least T (default 1) seconds.
    my $Delay = sub(?$v)
            my $c = $v // 1
            my $n = $c * $DelayN
            my $i = 0
            while ($i +< $n) { $i++ }
        ;

    # Next setup a periodic timer (the two-argument alarm() of
    # Time::HiRes, behind the curtains the libc ualarm()) which has
    # a signal handler that takes so much time (on the first initial
    # invocation) that the first periodic invocation (second invocation)
    # will happen before the first invocation has finished.  In Perl 5.8.0
    # the "safe signals" concept was implemented, with unfortunately at least
    # one bug that caused a core dump on reentering the handler. This bug
    # was fixed by the time of Perl 5.8.1.

    # Do not try mixing sleep() and alarm() for testing this.

    my $a = 0; # Number of alarms we receive.
    my $A = 2; # Number of alarms we will handle before disarming.
    # (We may well get $A + 1 alarms.)

    (signals::handler: "ALRM") = sub 
            $a++
            info: "Alarm $a - " . (time: )
            alarm: 0 if $a +>= $A # Disarm the alarm.
            $Delay->& <: 2 # Try burning CPU at least for 2T seconds.
        ;

    use Time::HiRes < qw(alarm); 
    (alarm: $T, $T);  # Arm the alarm.

    $Delay->& <: 10; # Try burning CPU at least for 10T seconds.

    (ok: 1); # Not core dumping by now is considered to be the success.
else
    skip: 29


if ($have_clock_gettime &&
    # All implementations of clock_gettime() 
    # are SUPPOSED TO support CLOCK_REALTIME.
    (has_symbol: 'CLOCK_REALTIME'))
    my $ok = 0;
    :TRY for my $try (1..3)
            info: "CLOCK_REALTIME: try = $try"
            my $t0 = clock_gettime: (CLOCK_REALTIME:  < @_ )
            use Time::HiRes < qw(sleep)
            my $T = 1.5
            sleep: $T
            my $t1 = clock_gettime: (CLOCK_REALTIME:  < @_ )
            if ($t0 +> 0 && $t1 +> $t0)
                info: "t1 = $t1, t0 = $t0"
                my $dt = $t1 - $t0
                my $rt = abs: 1 - $dt / $T
                info: "dt = $dt, rt = $rt"
                if ($rt +<= 2 * $limit)
                    $ok = 1
                    last TRY
            else 
                diag: "Error: t0 = $t0, t1 = $t1"

            my $r = (rand: ) + (rand: )
            info: sprintf: "# Sleeping for \%.6f seconds...\n", $r
            sleep: $r
    ok: $ok
else
    info: "# No clock_gettime\n"
    skip: 30


if ($have_clock_getres)
    my $tr = (clock_getres: )
    (ok: $tr +> 0, "tr = $tr")
else 
    diag: "# No clock_getres\n"
    skip: 31


if ($have_clock_nanosleep &&
    (has_symbol: 'CLOCK_REALTIME'))
    my $s = 1.5e9
    my $t = (clock_nanosleep: (CLOCK_REALTIME:  < @_ ), $s)
    my $r = (abs: 1 - $t / $s)
    (ok: $r +< 2 * $limit)
else 
    diag: "# No clock_nanosleep\n"
    skip: 32


if ($have_clock)
    my @clock = (@:  (clock: ) )
    diag: "clock = $((join: ' ', @clock))"
    for my $i (1..3)
        my $j = 0
        while ($j +< 1e6) { $j++ }
        (push: @clock, (clock: ))
        diag: "clock = $((join: ' ', @clock))"
    
    my $ok = (@clock[0] +>= 0 &&
              @clock[1] +> @clock[0] &&
              @clock[2] +> @clock[1] &&
              @clock[3] +> @clock[2])
    (ok: $ok)
else 
    skip: 33


if ($have_ualarm)
    # 1_100_000 sligthly over 1_000_000,
    # 2_200_000 slightly over 2**31/1000,
    # 4_300_000 slightly over 2**32/1000.
    for my $t ((@: \(@: 34, 100_000)
                   \(@: 35, 1_100_000)
                   \(@: 36, 2_200_000)
                   \(@: 37, 4_300_000)))
        my (@: $i, $n) = $t->@
        my $alarmed = 0
        local (signals::handler: "ALRM") = sub { $alarmed++ }
        my $t0 = (Time::HiRes::time: )
        diag: "t0 = $t0"
        diag: "ualarm($n)"
        (ualarm: $n); 1 while $alarmed == 0
        my $t1 = (Time::HiRes::time: )
        diag: "t1 = $t1"
        my $dt = $t1 - $t0
        diag: "dt = $dt"
        my $r = $dt / ($n/1e6)
        diag: "r = $r"
        (ok: ($n +< 1_000_000 || # Too much noise.
               $r +>= 0.8 && $r +<= 1.6), "ualarm($n) close enough")
    
else 
    diag: "# No ualarm\n"
    skip: 34..37


if ($^OS_NAME =~ m/^(cygwin|MSWin)/)
    diag: "$^OS_NAME: timestamps may not be good enough"
    (skip: 38)
 elsif ((Time::HiRes::d_hires_stat: ))
    my @stat
    my @atime
    my @mtime
    for (1..5)
        (Time::HiRes::sleep: (rand: 0.1) + 0.1)
        (open: my $x, ">", "$^PID")
        (print: $x, $^PID)
        (close: $x)
        @stat = (@: (Time::HiRes::stat: "$^PID") )
        (push: @mtime, @stat[?9])
        (Time::HiRes::sleep: (rand: 0.1) + 0.1)
        (open: $x, "<", "$^PID")
        ~< $x->*
        (close: $x)
        @stat = (@: (Time::HiRes::stat: $^PID) )
        (push: @atime, @stat[?8])
    
    1 while (unlink: $^PID)
    diag: "mtime = $((join: ' ', @mtime))"
    diag: "atime = $((join: ' ', @atime))"
    my $ai = 0
    my $mi = 0
    my $ss = 0
    for my $i (1 .. (nelems: @atime) -1)
        if (@atime[$i] +>= @atime[$i-1])
            $ai++
        
        if (@atime[$i] +> (int: @atime[$i]))
            $ss++
        
    
    for my $i (1 .. (nelems: @mtime) -1)
        if (@mtime[$i] +>= @mtime[$i-1])
            $mi++
        
        if (@mtime[$i] +> (int: @mtime[$i]))
            $ss++
    
    diag: "ai = $ai, mi = $mi, ss = $ss"
  # Need at least 75% of monotonical increase and
  # 20% of subsecond results. Yes, this is guessing.
    :SKIP do
        if ($ss == 0)
            (skip: "No subsecond timestamps detected", 1)
        
        my $ok = ($mi/((nelems @mtime)-1) +>= 0.75 && $ai/((nelems @atime)-1) +>= 0.75 &&
                  $ss/((nelems @mtime)+nelems @atime) +>= 0.2)
        ok: $ok
    
else 
    diag: "# No effectual d_hires_stat\n"
    skip: 38


END 
    if ($timer_pid) # Only in the main process.
        my $left = $TheEnd - (time: )
        (diag: (sprintf: "# I am the main process $^PID, terminating the timer process $timer_pid\n# before it terminates me in \%d seconds (testing took \%d seconds).\n", $left, $waitfor - $left))
        my $kill = (kill: 'TERM', $timer_pid) # We are done, the timer can go.
        (diag: (sprintf: "# kill TERM $timer_pid = \%d\n", $kill))
        (unlink: "ktrace.out") # Used in BSD system call tracing.
        diag: "# All done.\n"
    


