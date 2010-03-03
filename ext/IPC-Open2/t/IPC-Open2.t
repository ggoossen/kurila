#!./perl -w

use Config

BEGIN 
    if (!config_value: 'd_fork'
          # open2/3 supported on win32 (but not Borland due to CRT bugs)
          && (($^OS_NAME ne 'MSWin32' && $^OS_NAME ne 'NetWare') || (config_value: 'cc') =~ m/^bcc/i))
        print: $^STDOUT, "1..0\n"
        exit 0
    
    # make warnings fatal
    $^WARN_HOOK = sub (@< @_) { (die: < @_) }


use IO::Handle
use IPC::Open2

my $perl = '../../t/perl'

sub ok($n, $result, ?$info)
    if ($result)
        print: $^STDOUT, "ok $n\n"
    else
        print: $^STDOUT, "not ok $n\n"
        print: $^STDOUT, "# $info\n" if $info
    


sub cmd_line
    if ($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare')
        return qq/"@_[0]"/
    else
        return @_[0]


my ($pid, $reaped_pid)
($^STDOUT)->autoflush
($^STDERR)->autoflush

print: $^STDOUT, "1..7\n"

ok: 1, ($pid = (open2: \*READ, \*WRITE, $perl, '-e'
                       (cmd_line: 'print: $^STDOUT, scalar ~< $^STDIN')))
ok: 2, print: \*WRITE, "hi kid\n"
ok: 3, (~< *READ) =~ m/^hi kid\r?\n$/
ok: 4, (close: \*WRITE), $^OS_ERROR
ok: 5, (close: \*READ), $^OS_ERROR
$reaped_pid = waitpid: $pid, 0
ok: 6, $reaped_pid == $pid, $reaped_pid
ok: 7, $^CHILD_ERROR == 0, $^CHILD_ERROR
