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
use IPC::Open3

my $perl = $^EXECUTABLE_NAME

sub ok($n, $result, ?$info)
    if ($result)
        print: $^STDOUT, "ok $n\n"
    else
        print: $^STDOUT, "not ok $n\n"
        print: $^STDOUT, "# $info\n" if $info


sub cmd_line
    if ($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare')
        my $cmd = shift
        $cmd =~ s/[\r\n]//g
        $cmd =~ s/"/\\"/g
        return qq/"$cmd"/
    else
        return @_[0]


my ($pid, $reaped_pid)
($^STDOUT)->autoflush: 
($^STDERR)->autoflush: 

print: $^STDOUT, "1..23\n"

# basic
ok: 1, ($pid = (open3: \*WRITE, \*READ, \*ERROR, $perl, '-e', (cmd_line: <<'EOF')))
    $^OUTPUT_AUTOFLUSH = 1;
    print: $^STDOUT, scalar ~< $^STDIN;
    print: $^STDERR, "hi error\n";
EOF
ok: 2, print: \*WRITE, "hi kid\n"
ok: 3, $: (~< *READ) =~ m/^hi kid\r?\n$/
ok: 4, $: (~< *ERROR) =~ m/^hi error\r?\n$/
ok: 5, (close: *WRITE), $^OS_ERROR
ok: 6, (close: *READ), $^OS_ERROR
ok: 7, (close: *ERROR), $^OS_ERROR
$reaped_pid = waitpid: $pid, 0
ok: 8, $reaped_pid == $pid, $reaped_pid
ok: 9, $^CHILD_ERROR == 0, $^CHILD_ERROR

# read and error together, both named
$pid = open3: \*WRITE, \*READ, \*READ, $perl, '-e', cmd_line: <<'EOF'
    $^OUTPUT_AUTOFLUSH = 1;
    print: $^STDOUT, scalar ~< $^STDIN;
    print: $^STDERR, scalar ~< $^STDIN;
EOF
print: \*WRITE, "ok 10\n"
print: $^STDOUT, scalar ~< *READ
print: \*WRITE, "ok 11\n"
print: $^STDOUT, scalar ~< *READ
waitpid: $pid, 0

# read and error together, error empty
$pid = open3: \*WRITE, \*READ, '', $perl, '-e', cmd_line: <<'EOF'
    $^OUTPUT_AUTOFLUSH = 1;
    print: $^STDOUT, scalar ~< $^STDIN;
    print: $^STDERR, scalar ~< $^STDIN;
EOF
print: \*WRITE, "ok 12\n"
print: $^STDOUT, scalar ~< *READ
print: \*WRITE, "ok 13\n"
print: $^STDOUT, scalar ~< *READ
waitpid: $pid, 0

# dup writer
ok: 14, pipe: *PIPE_READ, *PIPE_WRITE
$pid = open3: (@: '<&', \*PIPE_READ), \*READ, undef
              $perl, '-e', (cmd_line: 'print: $^STDOUT, scalar ~< $^STDIN')
close \*PIPE_READ
print: \*PIPE_WRITE ,"ok 15\n"
close \*PIPE_WRITE
print: $^STDOUT, scalar ~< *READ
waitpid: $pid, 0

# dup reader
$pid = open3: \*WRITE, (@: '>&', $^STDOUT), \*ERROR
              $perl, '-e', cmd_line: 'print: $^STDOUT, scalar ~< $^STDIN'
print: \*WRITE, "ok 16\n"
waitpid: $pid, 0

# dup error:  This particular case, duping stderr onto the existing
# stdout but putting stdout somewhere else, is a good case because it
# used not to work.
$pid = open3: \*WRITE, \*READ, (@: '>&', $^STDOUT)
              $perl, '-e', cmd_line: 'print: $^STDERR, scalar ~< $^STDIN'
print: \*WRITE, "ok 17\n"
waitpid: $pid, 0

# dup reader and error together, both named
$pid = open3: \*WRITE, (@: '>&', $^STDOUT), (@: '>&', $^STDOUT), $perl, '-e', cmd_line: <<'EOF'
    $^OUTPUT_AUTOFLUSH = 1;
    print: $^STDOUT, scalar ~< $^STDIN;
    print: $^STDERR, scalar ~< $^STDIN;
EOF
print: \*WRITE, "ok 18\n"
print: \*WRITE, "ok 19\n"
waitpid: $pid, 0

# dup reader and error together, error empty
$pid = open3: \*WRITE, (@: '>&', $^STDOUT), '', $perl, '-e', cmd_line: <<'EOF'
    $^OUTPUT_AUTOFLUSH = 1;
    print: $^STDOUT, scalar ~< $^STDIN;
    print: $^STDERR, scalar ~< $^STDIN;
EOF
print: \*WRITE, "ok 20\n"
print: \*WRITE, "ok 21\n"
waitpid: $pid, 0

# command line in single parameter variant of open3
# for understanding of Config{'sh'} test see exec description in camel book
my $cmd = 'print: $^STDOUT, scalar(~< $^STDIN)'
$cmd = (config_value: 'sh') =~ m/sh/ ?? "'$cmd'" !! cmd_line: $cmd
try{$pid = (open3: \*WRITE, (@: '>&', $^STDOUT), \*ERROR, "$perl -e " . $cmd); }
if ($^EVAL_ERROR)
    print: $^STDOUT, "error $($^EVAL_ERROR->message)\n"
    print: $^STDOUT, "not ok 22\n"
else
    print: \*WRITE, "ok 22\n"
    waitpid: $pid, 0


try { (open3: 'WRITE', 'READ', 'ERROR', "$perl -e 1") }
ok:  23, ($: $^EVAL_ERROR->{description} =~ m/PLAINVALUE can not be used as a filehandle/)
     "PLAINVALUE can not be used as a filehandle"  
