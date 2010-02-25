#!./perl

#####################################################################
#
# Test for process id return value from open
# Ronald Schmidt (The Software Path) RonaldWS@software-path.com
#
#####################################################################

BEGIN 
    require './test.pl'


if ($^OS_NAME eq 'dos' || $^OS_NAME eq 'MacOS')
    skip_all: "no multitasking"

plan: tests => 10

watchdog: 15

use Config
use signals
$^OUTPUT_AUTOFLUSH = 1
(signals::handler: "PIPE") = 'IGNORE'
(signals::handler: "HUP") = 'IGNORE' if $^OS_NAME eq 'interix'

my $perl = (which_perl: )
$perl .= qq[ "-I../lib"]

#
# commands run 4 perl programs.  Two of these programs write a
# short message to STDOUT and exit.  Two of these programs
# read from STDIN.  One reader never exits and must be killed.
# the other reader reads one line, waits a few seconds and then
# exits to test the waitpid function.
#
my $cmd1 = qq/$perl -e "\$^OUTPUT_AUTOFLUSH=1; print: \\\$^STDOUT, qq[first process\\n]; sleep 30;"/
my $cmd2 = qq/$perl -e "\$^OUTPUT_AUTOFLUSH=1; print: \\\$^STDOUT, qq[second process\\n]; sleep 30;"/
my $cmd3 = qq/$perl -e "print: \\\$^STDOUT, ~< *ARGV;"/ # hangs waiting for end of STDIN
my $cmd4 = qq/$perl -e "print: \\\$^STDOUT, scalar ~< *ARGV;"/

#warn "#$cmd1\n#$cmd2\n#$cmd3\n#$cmd4\n";

our ($pid3, $pid4)
our ($from_pid1, $from_pid2, $kill_cnt)

# start the processes
ok:  (my $pid1 = (open: my $fh1, "-|", "$cmd1")), 'first process started'
ok:  (my $pid2 = (open: my $fh2, "-|", "$cmd2")), '    second' 
my $fh3
do
    no warnings 'once'
    ok:  ($pid3 = (open: $fh3, "|-", "$cmd3")), '    third'  

ok:  ($pid4 = (open: my $fh4, "|-", "$cmd4")), '    fourth' 

print: $^STDOUT, "# pids were $pid1, $pid2, $pid3, $pid4\n"

my $killsig = 'HUP'
$killsig = 1 unless (config_value: "sig_name") =~ m/\bHUP\b/

# get message from first process and kill it
chomp: ($from_pid1 = (scalar:  ~< $fh1))
is:  $from_pid1, 'first process',    'message from first process' 

$kill_cnt = kill: $killsig, $pid1
(is:  $kill_cnt, 1,   'first process killed' ) ||
    print: $^STDOUT, "# errno == $^OS_ERROR\n"

# get message from second process and kill second process and reader process
chomp: ($from_pid2 = (scalar:  ~< $fh2))
is:  $from_pid2, 'second process',   'message from second process' 

$kill_cnt = kill: $killsig, $pid2, $pid3
(is:  $kill_cnt, 2,   'killing procs 2 & 3' ) ||
    print: $^STDOUT, "# errno == $^OS_ERROR\n"


# send one expected line of text to child process and then wait for it
iohandle::output_autoflush: $fh4, 1
printf: $fh4, "ok \%d - text sent to fourth process\n", (curr_test: )
(next_test: )
print: $^STDOUT, "# waiting for process $pid4 to exit\n"
my $reap_pid = waitpid: $pid4, 0
is:  $reap_pid, $pid4, 'fourth process reaped' 

