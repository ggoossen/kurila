#!./perl -w

my $child
my $can_fork
my $has_perlio

use Config
use Errno < qw|EPIPE ESHUTDOWN|
use signals

BEGIN 
    $can_fork = (config_value: 'd_fork') || config_value: 'd_pseudofork'


do
    # This was in the BEGIN block, but since Test::More 0.47 added support to
    # detect forking, we don't need to fork before Test::More initialises.

    # Too many things in this test will hang forever if something is wrong,
    # so we need a self destruct timer. And IO can hang despite an alarm.

    if( $can_fork)
        my $parent = $^PID
        $child = fork
        die: "Fork failed" unless defined $child
        if (!$child)
            (signals::handler: "INT") = sub (@< @_) {exit 0} # You have 60 seconds. Your time starts now.
            my $must_finish_by = time + 60
            my $remaining
            while (($remaining = $must_finish_by - time) +> 0)
                sleep $remaining
            
            warn: "Something unexpectedly hung during testing"
            kill: "INT", $parent or die: "Kill failed: $^OS_ERROR"
            exit 1
        
    
    unless ($has_perlio = (PerlIO::Layer->find:  'perlio'))
        print: $^STDOUT, <<EOF
# Since you don't have perlio you might get failures with UTF-8 locales.
EOF
    


use Socket
use Test::More

use warnings
use Errno

my $skip_reason

if( ! (config_value: 'd_alarm') )
    plan: skip_all => "alarm() not implemented on this platform"
elsif( !$can_fork )
    plan: skip_all => "fork() not implemented on this platform"
else
    # This should fail but not die if there is real socketpair
    try {(socketpair: my $left, my $right, -1, -1, -1)}
    if ($^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/^Unsupported socket function "socketpair" called/ ||
        $^OS_ERROR =~ m/^The operation requested is not supported./) # Stratus VOS
        plan: skip_all => 'No socketpair (real or emulated)'
    else
        try {AF_UNIX}
        if ($^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/^Your vendor has not defined Socket macro AF_UNIX/)
            plan: skip_all => 'No AF_UNIX'
        else
            plan: tests => 45
        
    


# But we'll install an alarm handler in case any of the races below fail.
(signals::handler: "ALRM") = sub (@< @_) {(die: "Unexpected alarm during testing")}

ok: (socketpair: my $left, my $right, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    'socketpair ($left, $right, AF_UNIX, SOCK_STREAM, PF_UNSPEC)'
    or print: $^STDOUT, "# \$\! = $^OS_ERROR\n"

if ($has_perlio)
    binmode: $left,  ":bytes"
    binmode: $right, ":bytes"


my @left = @: "hello ", "world\n"
my @right = @: "perl ", "rules!" # Not like I'm trying to bias any survey here.

foreach ( @left)
    # is (syswrite ($left, $_), length $_, "write " . _qq ($_) . " to left");
    is: (syswrite: $left, $_), length $_, "syswrite to left"

foreach ( @right)
    # is (syswrite ($right, $_), length $_, "write " . _qq ($_) . " to right");
    is: (syswrite: $right, $_), length $_, "syswrite to right"


# stream socket, so our writes will become joined:
my ($buffer, $expect)
$expect = join: '', @right
undef $buffer
is: (read: $left, $buffer, length $expect), length $expect, "read on left"
is: $buffer, $expect, "content what we expected?"
$expect = join: '', @left
undef $buffer
is: (read: $right, $buffer, length $expect), length $expect, "read on right"
is: $buffer, $expect, "content what we expected?"

ok: (shutdown: $left, SHUT_WR), "shutdown left for writing"
# This will hang forever if eof is buggy, and alarm doesn't interrupt system
# Calls. Hence the child process minder.
:SKIP do
    skip: "SCO Unixware / OSR have a bug with shutdown",2 if $^OS_NAME =~ m/^(?:svr|sco)/
    local (signals::handler: "ALRM") = sub (@< @_) { (warn: "EOF on right took over 3 seconds") }
    local $TODO = "Known problems with unix sockets on $^OS_NAME"
        if $^OS_NAME eq 'hpux'   || $^OS_NAME eq 'super-ux'
    alarm 3
    $^OS_ERROR = 0
    ok: eof $right, "right is at EOF"
    local $TODO = "Known problems with unix sockets on $^OS_NAME"
        if $^OS_NAME eq 'unicos' || $^OS_NAME eq 'unicosmk'
    is: $^OS_ERROR, '', 'and $! should report no error'
    alarm 60


my $err = $^OS_ERROR
(signals::handler: "PIPE") = 'IGNORE'
do
    local signals::handler: "ALRM"
        = sub (@< @_) { (warn: "syswrite to left didn't fail within 3 seconds") }
    alarm 3
    # Split the system call from the is() - is() does IO so
    # (say) a flush may do a seek which on a pipe may disturb errno
    my $ans = syswrite: $left, "void"
    $err = $^OS_ERROR
    is: $ans, undef, "syswrite to shutdown left should fail"
    alarm 60

do
    # This may need skipping on some OSes - restoring value saved above
    # should help
    $^OS_ERROR = $err
    ok: ($^OS_ERROR == (EPIPE: )or $^OS_ERROR == (ESHUTDOWN: )), '$! should be EPIPE or ESHUTDOWN'
        or printf: $^STDOUT, "\$\!=\%d(\%s)\n", $err, $err

use bytes
my @gripping = @: chr 255, chr 127
foreach ( @gripping)
    is: (syswrite: $right, $_), length $_, "syswrite to right"

ok: !eof $left, "left is not at EOF"

$expect = join: '', @gripping
undef $buffer
is: (read: $left, $buffer, length $expect), length $expect, "read on left"
is: $buffer, $expect, "content what we expected?"

ok: close $left, "close left"
ok: close $right, "close right"


# And now datagrams
# I suspect we also need a self destruct time-bomb for these, as I don't see any
# guarantee that the stack won't drop a UDP packet, even if it is for localhost.

:SKIP do
    skip: "No usable SOCK_DGRAM for socketpair", 24 if ($^OS_NAME =~ m/^(MSWin32|os2)\z/)
    local $TODO = "socketpair not supported on $^OS_NAME" if $^OS_NAME eq 'nto'

    ok: (socketpair: $left, $right, AF_UNIX, SOCK_DGRAM, PF_UNSPEC)
        "socketpair (\$left, \$right, AF_UNIX, SOCK_DGRAM, PF_UNSPEC)"
        or print: $^STDOUT, "# \$\! = $^OS_ERROR\n"

    if ($has_perlio)
        binmode: $left,  ":bytes"
        binmode: $right, ":bytes"
    

    foreach ( @left)
        # is (syswrite ($left, $_), length $_, "write " . _qq ($_) . " to left");
        is: (syswrite: $left, $_), length $_, "syswrite to left"
    
    foreach ( @right)
        # is (syswrite ($right, $_), length $_, "write " . _qq ($_) . " to right");
        is: (syswrite: $right, $_), length $_, "syswrite to right"
    

    # stream socket, so our writes will become joined:
    my ($total)
    $total = join: '', @right
    foreach my $expect ( @right)
        undef $buffer
        is: (sysread: $left, $buffer, length $total), length $expect, "read on left"
        is: $buffer, $expect, "content what we expected?"
    
    $total = join: '', @left
    foreach my $expect ( @left)
        undef $buffer
        is: (sysread: $right, $buffer, length $total), length $expect, "read on right"
        is: $buffer, $expect, "content what we expected?"
    

    ok: (shutdown: $left, 1), "shutdown left for writing"

    # eof uses buffering. eof is indicated by a sysread of zero.
    # but for a datagram socket there's no way it can know nothing will ever be
    # sent
    :SKIP do
        skip: "$^OS_NAME does length 0 udp reads", 2 if ($^OS_NAME eq 'os390')

        my $alarmed = 0
        local (signals::handler: "ALRM") = sub (@< @_) { $alarmed = 1; }
        print: $^STDOUT, "# Approximate forever as 3 seconds. Wait 'forever'...\n"
        alarm 3
        undef $buffer
        is: (sysread: $right, $buffer, 1), undef
            "read on right should be interrupted"
        is: $alarmed, 1, "alarm should have fired"
    

    alarm 30

    #ok (eof $right, "right is at EOF");

    foreach ( @gripping)
        is: (syswrite: $right, $_), length $_, "syswrite to right"
    

    $total = join: '', @gripping
    foreach my $expect ( @gripping)
        undef $buffer
        is: (sysread: $left, $buffer, length $total), length $expect, "read on left"
        is: $buffer, $expect, "content what we expected?"
    

    ok: close $left, "close left"
    ok: close $right, "close right"

 # end of DGRAM SKIP

kill: "INT", $child or warn: "Failed to kill child process $child: $^OS_ERROR"
exit 0
