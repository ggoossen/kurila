#!./perl

if ($^OS_NAME eq 'mpeix')
    print: $^STDOUT, "1..0 # Skip: broken on MPE/iX\n"
    exit 0


iohandle::output_autoflush: $^STDERR, 1
iohandle::output_autoflush: $^STDOUT, 1

print: $^STDOUT, "1..10\n"

use IO::Handle
use IO::Poll < qw(/POLL/)

my $poll = IO::Poll->new: 

my $stdout = $^STDOUT
my $dupout = IO::Handle->new_from_fd: (fileno: $stdout),"w"

$poll->mask: $stdout => POLLOUT

print: $^STDOUT, "not "
    unless ($poll->mask: $stdout) == POLLOUT
print: $^STDOUT, "ok 1\n"

$poll->mask: $dupout => POLLPRI

print: $^STDOUT, "not "
    unless ($poll->mask: $dupout) == POLLPRI
print: $^STDOUT, "ok 2\n"

$poll->poll: 0.1

if ($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare' || $^OS_NAME eq 'VMS' || $^OS_NAME eq 'beos')
    print: $^STDOUT, "ok 3 # skipped, doesn't work on non-socket fds\n"
    print: $^STDOUT, "ok 4 # skipped, doesn't work on non-socket fds\n"
else
    print: $^STDOUT, "not "
        unless ($poll->events: $stdout) == POLLOUT
    print: $^STDOUT, "ok 3\n"

    print: $^STDOUT, "not "
        if $poll->events: $dupout
    print: $^STDOUT, "ok 4\n"


my @h = $poll->handles: 
print: $^STDOUT, "not "
    unless (nelems @h) == 2
print: $^STDOUT, "ok 5\n"

$poll->remove: $stdout

@h = $poll->handles: 

print: $^STDOUT, "not "
    unless (nelems @h) == 1
print: $^STDOUT, "ok 6\n"

print: $^STDOUT, "not "
    if $poll->mask: $stdout
print: $^STDOUT, "ok 7\n"

$poll->poll: 0.1

print: $^STDOUT, "not "
    if $poll->events: $stdout
print: $^STDOUT, "ok 8\n"

$poll->remove: $dupout
print: $^STDOUT, "not "
    if $poll->handles: 
print: $^STDOUT, "ok 9\n"

my $stdin = $^STDIN
$poll->mask: $stdin => POLLIN
$poll->remove: $stdin
close $^STDIN
print: $^STDOUT, "not "
    if $poll->poll: 0.1
print: $^STDOUT, "ok 10\n"
