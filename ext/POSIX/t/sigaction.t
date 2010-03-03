#!./perl

BEGIN
    # Don't do anything if POSIX is missing, or sigaction missing.
    use Config
    eval 'use POSIX'
    if($^EVAL_ERROR || $^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare' || $^OS_NAME eq 'dos' ||
        $^OS_NAME eq 'MacOS' || ($^OS_NAME eq 'VMS' && ! (config_value: 'd_sigaction')))
        print: $^STDOUT, "1..0\n"
        exit 0
    


use Test::More tests => 27

our ($bad, $bad7, $ok10, $bad18, $ok)

$^WARNING=1

sub IGNORE
    $bad7=1


sub DEFAULT
    $bad18=1


sub foo
    $ok=1


sub bar { }

my $newaction=POSIX::SigAction->new: &foo, (POSIX::SigSet->new: SIGUSR1), 0
my $oldaction=POSIX::SigAction->new: &bar, POSIX::SigSet->new, 0

do
    my $bad
    local($^WARN_HOOK)=sub (@< @_) { $bad=1; }
    sigaction: SIGHUP, $newaction, $oldaction
    ok: !$bad, "no warnings"


ok: $oldaction->{HANDLER} eq 'DEFAULT' ||
       $oldaction->{HANDLER} eq 'IGNORE', $oldaction->{HANDLER}

is: (signals::handler: "HUP"), &foo

sigaction: SIGHUP, $newaction, $oldaction
is: $oldaction->{?HANDLER}, &foo

ok: ($oldaction->{?MASK}->ismember: SIGUSR1), "SIGUSR1 ismember MASK"

:SKIP do
    skip: "sigaction() thinks different in $^OS_NAME", 1
        if $^OS_NAME eq 'linux' || $^OS_NAME eq 'unicos'
    is: $oldaction->{?FLAGS}, 0


$newaction=POSIX::SigAction->new: 'IGNORE'
sigaction: SIGHUP, $newaction
kill: 'HUP', $^PID
ok: !$bad, "SIGHUP ignored"

is: (signals::handler: "HUP"), 'IGNORE'
sigaction: SIGHUP, (POSIX::SigAction->new: 'DEFAULT')
is: (signals::handler: "HUP"), undef

$newaction=POSIX::SigAction->new: sub (@< @_) { $ok10=1; }
sigaction: SIGHUP, $newaction
do
    local($^WARNING)=0
    kill: 'HUP', $^PID

ok: $ok10, "SIGHUP handler called"

is: (ref::svtype: (signals::handler: "HUP")), 'CODE'

sigaction: SIGHUP, (POSIX::SigAction->new: &main::foo)
# Make sure the signal mask gets restored after sigaction croak()s.
try {
    my $act=(POSIX::SigAction->new: &main::foo);
    delete $act->{HANDLER};
    (sigaction: SIGINT, $act);
}
kill: 'HUP', $^PID
ok: $ok, "signal mask gets restored after croak"

undef $ok
# Make sure the signal mask gets restored after sigaction returns early.
my $x=defined sigaction: SIGKILL, $newaction, $oldaction
kill: 'HUP', $^PID
ok: !$x && $ok, "signal mask gets restored after early return"

(signals::handler: "HUP") = sub {}
sigaction: SIGHUP, $newaction, $oldaction
is: (ref::svtype: $oldaction->{?HANDLER}), 'CODE'

try {
    (sigaction: SIGHUP, undef, $oldaction);
}
ok: !$^EVAL_ERROR, "undef for new action"

try {
    (sigaction: SIGHUP, 0, $oldaction);
}
ok: !$^EVAL_ERROR, "zero for new action"

try {
    (sigaction: SIGHUP, (bless: \$%,'Class'), $oldaction);
}
ok: $^EVAL_ERROR, "any object not good as new action"

:SKIP do
    skip: "SIGCONT not trappable in $^OS_NAME", 1
        if ($^OS_NAME eq 'VMS')
    $newaction=POSIX::SigAction->new: sub (@< @_) { $ok10=1; }
    if (try { SIGCONT; 1 })
        sigaction: SIGCONT, (POSIX::SigAction->new: 'DEFAULT')
        do
            local($^WARNING)=0
            kill: 'CONT', $^PID
        
    
    ok: !$bad18, "SIGCONT trappable"


do
    local $^WARN_HOOK = sub { } # Just suffer silently.

    my $hup20
    my $hup21

    sub hup20 { $hup20++ }
    sub hup21 { $hup21++ }

    sigaction: "FOOBAR", $newaction
    ok: 1, "no coredump, still alive"

    $newaction = POSIX::SigAction->new: &hup20
    sigaction: "SIGHUP", $newaction
    kill: "HUP", $^PID
    is: $hup20, 1

    $newaction = POSIX::SigAction->new: &hup21
    sigaction: "HUP", $newaction
    kill: "HUP", $^PID
    is: $hup21, 1


# "safe" attribute.
# for this one, use the accessor instead of the attribute

# standard signal handling via %SIG is safe
(signals::handler: "HUP") = &foo 
$oldaction = POSIX::SigAction->new
sigaction: SIGHUP, undef, $oldaction
ok: $oldaction->safe, "SIGHUP is safe"

# SigAction handling is not safe ...
sigaction: SIGHUP, (POSIX::SigAction->new: &foo)
sigaction: SIGHUP, undef, $oldaction
ok: !$oldaction->safe, "SigAction not safe by default"

# ... unless we say so!
$newaction = POSIX::SigAction->new: &foo
$newaction->safe: 1
sigaction: SIGHUP, $newaction
sigaction: SIGHUP, undef, $oldaction
ok: $oldaction->safe, "SigAction can be safe"

# And safe signal delivery must work
$ok = 0
kill: 'HUP', $^PID
ok: $ok, "safe signal delivery must work"

:SKIP do
    eval 'use POSIX qw(SA_SIGINFO); SA_SIGINFO'
    skip: "no SA_SIGINFO", 1 if $^EVAL_ERROR
    sub hiphup
        is: @_[1]->{?signo}, SIGHUP, "SA_SIGINFO got right signal"
    
    my $act = POSIX::SigAction->new: \&hiphup, 0, SA_SIGINFO
    sigaction: SIGHUP, $act
    kill: 'HUP', $^PID


try { (sigaction: -999, "foo"); }
like: $^EVAL_ERROR->{?description}, qr/Negative signals/
      "Prevent negative signals instead of core dumping"
