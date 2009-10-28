#!perl

BEGIN 
    use Config
    use Test::More


use File::Spec
use POSIX
use Scalar::Util < qw(looks_like_number)

sub check { grep: { eval "&$_;1" or $^EVAL_ERROR->{?description}!~m/vendor has not defined POSIX macro/ }, @_
}

my @path_consts = check: < qw(
    _PC_CHOWN_RESTRICTED _PC_LINK_MAX _PC_NAME_MAX
    _PC_NO_TRUNC _PC_PATH_MAX
)

my @path_consts_terminal = check: < qw(
    _PC_MAX_CANON _PC_MAX_INPUT _PC_VDISABLE
)

my @path_consts_fifo = check: < qw(
    _PC_PIPE_BUF
)

my @sys_consts = check: < qw(
    _SC_ARG_MAX _SC_CHILD_MAX _SC_CLK_TCK _SC_JOB_CONTROL
    _SC_NGROUPS_MAX _SC_OPEN_MAX _SC_PAGESIZE _SC_SAVED_IDS
    _SC_STREAM_MAX _SC_VERSION _SC_TZNAME_MAX
)

my $tests = 2 * 3 * (nelems @path_consts) +
    2 * 3 * (nelems @path_consts_terminal) +
    2 * 3 * (nelems @path_consts_fifo) +
    3 * (nelems @sys_consts)
plan: $tests
           ?? (tests => $tests)
           !! (skip_all => "No tests to run on this OS")


# Don't test on "." as it can be networked storage which returns EINVAL
# Testing on "/" may not be portable to non-Unix as it may not be readable
# "/tmp" should be readable and likely also local.
my $testdir = File::Spec->tmpdir: 
$testdir = (VMS::Filespec::fileify: $testdir) if $^OS_NAME eq 'VMS'

my $r

my $TTY = "/dev/tty"

sub _check_and_report($eval_status, $return_val, $description)
    my $success = (defined: $return_val) || $^OS_ERROR == 0
    is:  $eval_status, '', $description 
    :SKIP do
        skip: "terminal constants set errno on QNX", 1
            if $^OS_NAME eq 'nto' and $description =~ $TTY
        ok:  $success, "\tchecking that the returned value is defined ("
                 . ((defined: $return_val) ?? "yes, it's $return_val)" !! "it isn't)"
               . " or that errno is clear ("
               . (!($^OS_ERROR+0) ?? "it is)" !! "it isn't, it's $^OS_ERROR)"))
            
    
    :SKIP do
        skip: "constant not implemented on $^OS_NAME or no limit in effect", 1
            if !defined: $return_val
        ok:  (looks_like_number: $return_val), "\tchecking that the returned value looks like a number" 
    


# testing fpathconf() on a non-terminal file
:SKIP do
    my $fd = POSIX::open: $testdir, O_RDONLY
        or skip: "could not open test directory '$testdir' ($^OS_ERROR)"
                 3 * nelems @path_consts

    for my $constant ( @path_consts)
        $^OS_ERROR = 0
        $r = try { (fpathconf:  $fd, eval "$constant()" ) }
        _check_and_report:  $^EVAL_ERROR, $r, "calling fpathconf($fd, $constant) " 
    

    POSIX::close: $fd


# testing pathconf() on a non-terminal file
for my $constant ( @path_consts)
    $^OS_ERROR = 0
    $r = try { (pathconf:  $testdir, eval "$constant()" ) }
    _check_and_report:  $^EVAL_ERROR, $r, qq[calling pathconf("$testdir", $constant)] 


:SKIP do
    my $n = 2 * 3 * nelems @path_consts_terminal

    -c $TTY
        or skip: "$TTY not a character file", $n
    open: my $ttyfh, "<", $TTY
        or skip: "failed to open $TTY: $^OS_ERROR", $n
    -t $ttyfh->*
        or skip: "TTY ($TTY) not a terminal file", $n

    my $fd = fileno: $ttyfh

    # testing fpathconf() on a terminal file
    for my $constant ( @path_consts_terminal)
        $^OS_ERROR = 0
        $r = try { (fpathconf:  $fd, eval "$constant()" ) }
        _check_and_report:  $^EVAL_ERROR, $r, qq[calling fpathconf($fd, $constant) ($TTY)] 
    

    close: $ttyfh
    # testing pathconf() on a terminal file
    for my $constant ( @path_consts_terminal)
        $^OS_ERROR = 0
        $r = try { (pathconf:  $TTY, eval "$constant()" ) }
        _check_and_report:  $^EVAL_ERROR, $r, qq[calling pathconf($TTY, $constant)] 
    


my $fifo = "fifo$^PID"

:SKIP do
    try { (mkfifo: $fifo, 0666) }
        or skip: "could not create fifo $fifo ($^OS_ERROR)", 2 * 3 * nelems @path_consts_fifo

    :SKIP do
        my $fd = POSIX::open: $fifo, O_RDWR
            or skip: "could not open $fifo ($^OS_ERROR)", 3 * nelems @path_consts_fifo

        for my $constant ( @path_consts_fifo)
            $^OS_ERROR = 0
            $r = try { (fpathconf:  $fd, eval "$constant()" ) }
            _check_and_report:  $^EVAL_ERROR, $r, "calling fpathconf($fd, $constant) ($fifo)" 
        

        POSIX::close: $fd
    

    # testing pathconf() on a fifo file
    for my $constant ( @path_consts_fifo)
        $^OS_ERROR = 0
        $r = try { (pathconf:  $fifo, eval "$constant()" ) }
        _check_and_report:  $^EVAL_ERROR, $r, qq[calling pathconf($fifo, $constant)] 
    


END 
    1 while unlink: $fifo


:SKIP do
    if($^OS_NAME eq 'cygwin')
        pop @sys_consts
        skip: "No _SC_TZNAME_MAX on Cygwin", 3
    


# testing sysconf()
for my $constant ( @sys_consts)
    $^OS_ERROR = 0
    $r = try { (sysconf:  eval "$constant()" ) }
    _check_and_report:  $^EVAL_ERROR, $r, "calling sysconf($constant)" 


