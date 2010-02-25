#!./perl

use Config

BEGIN
    require "test.pl"

plan: tests => 66

use POSIX < qw(fcntl_h signal_h limits_h _exit getcwd open read strftime write
	     errno)


$^OUTPUT_AUTOFLUSH = 1

my $Is_W32     = $^OS_NAME eq 'MSWin32'
my $Is_Dos     = $^OS_NAME eq 'dos'
my $Is_MPE     = $^OS_NAME eq 'mpeix'
my $Is_MacOS   = $^OS_NAME eq 'MacOS'
my $Is_VMS     = $^OS_NAME eq 'VMS'
my $Is_OS2     = $^OS_NAME eq 'os2'
my $Is_UWin    = $^OS_NAME eq 'uwin'
my $Is_OS390   = $^OS_NAME eq 'os390'

ok:  (my $testfd = (open: "../../t/TEST", O_RDONLY, 0)),        'O_RDONLY with open' 
read: $testfd, my $buffer, 4 if $testfd +> 2
is:  $buffer, "#!./",                      '    with read' 

:TODO
    do
    local our $TODO = "read to array element not working"

    our @buffer
    read: $testfd, @buffer[+1], 5 if $testfd +> 2
    is:  @buffer[1], "perl\n",	               '    read to array element' 


write: 1,"ok 4\nnot ok 4\n", 5
(next_test: )

:SKIP do
    skip: "no pipe() support on DOS", 2 if $Is_Dos

    our @fds = (POSIX::pipe: )
    ok:  @fds[0] +> $testfd,      'POSIX::pipe' 

    CORE::open: (my $reader = \*READER), "<&=", @fds[0]
    CORE::open: (my $writer = \*WRITER), ">&=", @fds[1]
    print: $writer, "ok 6\n"
    close $writer
    print: $^STDOUT, ~< $reader
    close $reader
    (next_test: )


:SKIP do
    skip: "no sigaction support on win32/dos", 6 if $Is_W32 || $Is_Dos

    my $sigset = POSIX::SigSet->new:  1, 3
    $sigset->delset: 1
    ok: ! ($sigset->ismember: 1),  'POSIX::SigSet->delset' 
    ok:   ($sigset->ismember: 3),  'POSIX::SigSet->ismember' 

    :SKIP do
        skip: "no kill() support on Mac OS", 4 if $Is_MacOS

        my $sigint_called = 0

        my $mask   = POSIX::SigSet->new:  (SIGINT: ) 
        my $action = POSIX::SigAction->new:  &main::SigHUP, $mask, 0
        sigaction: (SIGHUP: ), $action
        (signals::handler: 'INT') = &SigINT

        # At least OpenBSD/i386 3.3 is okay, as is NetBSD 1.5.
        # But not NetBSD 1.6 & 1.6.1: the test makes perl crash.
        # So the kill() must not be done with this config in order to
        # finish the test.
        # For others (darwin & freebsd), let the test fail without crashing.
        my $todo = $^OS_NAME eq 'netbsd' && (config_value: 'osvers')=~m/^1\.6/
        my $why_todo = "# TODO $^OS_NAME config_value('osvers') seems to lose blocked signals"
        if (!$todo)
            kill: 'HUP', $^PID
        else
            print: $^STDOUT, "not ok 9 - sigaction SIGHUP ",$why_todo,"\n"
            print: $^STDOUT, "not ok 10 - sig mask delayed SIGINT ",$why_todo,"\n"
        
        sleep 1

        $todo = 1 if ($^OS_NAME eq 'freebsd')
          || ($^OS_NAME eq 'darwin' && (config_value: 'osvers') +<= v6.6)
        printf: $^STDOUT, "\%s 11 - masked SIGINT received \%s\n"
                $sigint_called ?? "ok" !! "not ok"
                $todo ?? $why_todo !! ''

        print: $^STDOUT, "ok 12 - signal masks successful\n"

        sub SigHUP
            print: $^STDOUT, "ok 9 - sigaction SIGHUP\n"
            kill: 'INT', $^PID
            sleep 2
            print: $^STDOUT, "ok 10 - sig mask delayed SIGINT\n"
        

        sub SigINT
            $sigint_called++

        # The order of the above tests is very important, so
        # we use literal prints and hard coded numbers.
        for (1..4)
            (next_test: )

:SKIP do
    skip: "_POSIX_OPEN_MAX is inaccurate on MPE", 1 if $Is_MPE
    skip: '_POSIX_OPEN_MAX undefined (@fds[1])',  1 unless _POSIX_OPEN_MAX:  < @_ 

    ok:  (_POSIX_OPEN_MAX:  < @_ ) +>= 16, "The minimum allowed values according to susv2" 



my $pat = qr#[\\/]POSIX$#i

like:  (getcwd: ), qr/$pat/, 'getcwd' 

# Check string conversion functions.

:SKIP do
    skip: "strtod() not present", 1 unless config_value: 'd_strtod'

    my $lc = (POSIX::setlocale: (POSIX::LC_NUMERIC:  < @_ ), 'C') if config_value: 'd_setlocale'

    # we're just checking that strtod works, not how accurate it is
    my (@: $n, $x) =  POSIX::strtod: '3.14159_OR_SO'
    ok: ((abs: "3.14159" - $n) +< 1e-6) && ($x == 6), 'strtod works'

    POSIX::setlocale: (POSIX::LC_NUMERIC:  < @_ ), $lc if config_value: 'd_setlocale'


:SKIP do
    skip: "strtol() not present", 2 unless config_value: 'd_strtol'

    my (@: $n, $x) =  POSIX::strtol: '21_PENGUINS'
    is: $n, 21, 'strtol() number'
    is: $x, 9,  '         unparsed chars'


:SKIP do
    skip: "strtoul() not present", 2 unless config_value: 'd_strtoul'

    my (@: $n, $x) =  POSIX::strtoul: '88_TEARS'
    is: $n, 88, 'strtoul() number'
    is: $x, 6,  '          unparsed chars'


# Pick up whether we're really able to dynamically load everything.
ok:  (POSIX::acos: 1.0) == 0.0,   'dynamic loading' 

# This can coredump if struct tm has a timezone field and we
# didn't detect it.  If this fails, try adding
# -DSTRUCT_TM_HASZONE to your cflags when compiling ext/POSIX/POSIX.c.
# See ext/POSIX/hints/sunos_4.pl and ext/POSIX/hints/linux.pl
print: $^STDOUT, POSIX::strftime: 'ok 21 # %H:%M, on %m/%d/%y' . "\n", (localtime: )
(next_test: )

# If that worked, validate the mini_mktime() routine's normalisation of
# input fields to strftime().
sub try_strftime
    my $expect = shift
    my $got = POSIX::strftime: '%a %b %d %H:%M:%S %Y %j', < @_
    is: $got, $expect, "validating mini_mktime() and strftime(): $expect"


my $lc = (POSIX::setlocale: (POSIX::LC_TIME:  < @_ ), 'C') if config_value: 'd_setlocale'
try_strftime: "Wed Feb 28 00:00:00 1996 059", 0,0,0, 28,1,96
:SKIP do
    skip: "VC++ 8 and Vista's CRTs regard 60 seconds as an invalid parameter", 1
        if ($Is_W32 and (((config_value: "cc") eq 'cl' and
                          (config_value: "ccversion") =~ m/^(\d+)/ and $1 +>= 14) or
                         ((Win32::GetOSVersion: ))[1] +>= 6))

    try_strftime: "Thu Feb 29 00:00:60 1996 060", 60,0,-24, 30,1,96

try_strftime: "Fri Mar 01 00:00:00 1996 061", 0,0,-24, 31,1,96
try_strftime: "Sun Feb 28 00:00:00 1999 059", 0,0,0, 28,1,99
try_strftime: "Mon Mar 01 00:00:00 1999 060", 0,0,24, 28,1,99
try_strftime: "Mon Feb 28 00:00:00 2000 059", 0,0,0, 28,1,100
try_strftime: "Tue Feb 29 00:00:00 2000 060", 0,0,0, 0,2,100
try_strftime: "Wed Mar 01 00:00:00 2000 061", 0,0,0, 1,2,100
try_strftime: "Fri Mar 31 00:00:00 2000 091", 0,0,0, 31,2,100
POSIX::setlocale: (POSIX::LC_TIME:  < @_ ), $lc if config_value: "d_setlocale"

do
    for my $test ((@: 0, 1))
        $^OS_ERROR = 0
        # POSIX::errno is autoloaded.
        # Autoloading requires many system calls.
        # errno() looks at $! to generate its result.
        # Autoloading should not munge the value.
        my $foo  = $^OS_ERROR
        my $errno = (POSIX::errno: )

        # Force numeric context.
        is:  $errno + 0, $foo + 0,     'autoloading and errno() mix' 
    


:SKIP do
    skip: "no kill() support on Mac OS", 1 if $Is_MacOS
    is: eval "kill: 0", 0, "check we have CORE::kill"
        or print: $^STDOUT, "\$\@ is " . (_qq: $^EVAL_ERROR) . "\n"


# Check that we can import the POSIX kill routine
POSIX->import : 'kill'
my $result = eval "kill 0"
is: $result, undef, "we should now have POSIX::kill"
# Check usage.
like: $^EVAL_ERROR->{?description}, qr/^Usage: POSIX::kill\(pid, sig\)/, "check its usage message"

# Check unimplemented.
$result = try {(POSIX::offsetof: )}
is: $result, undef, "offsetof should fail"
like: $^EVAL_ERROR->{?description}, qr/^Unimplemented: POSIX::offsetof\(\) is C-specific/
      "check its unimplemented message"

# Check reimplemented.
$result = try {(POSIX::fgets: )}
is: $result, undef, "fgets should fail"
like: $^EVAL_ERROR->{?description}, qr/^Use method IO::Handle::gets\(\) instead/
      "check its redef message"

# Simplistic tests for the isXXX() functions (bug #16799)
ok:  (POSIX::isalnum: '1'),  'isalnum' 
ok: !(POSIX::isalnum: '*'),  'isalnum' 
ok:  (POSIX::isalpha: 'f'),  'isalpha' 
ok: !(POSIX::isalpha: '7'),  'isalpha' 
ok:  (POSIX::iscntrl: "\cA"),'iscntrl' 
ok: !(POSIX::iscntrl: "A"),  'iscntrl' 
ok:  (POSIX::isdigit: '1'),  'isdigit' 
ok: !(POSIX::isdigit: 'z'),  'isdigit' 
ok:  (POSIX::isgraph: '@'),  'isgraph' 
ok: !(POSIX::isgraph: ' '),  'isgraph' 
ok:  (POSIX::islower: 'l'),  'islower' 
ok: !(POSIX::islower: 'L'),  'islower' 
ok:  (POSIX::isupper: 'U'),  'isupper' 
ok: !(POSIX::isupper: 'u'),  'isupper' 
ok:  (POSIX::isprint: '$'),  'isprint' 
ok: !(POSIX::isprint: "\n"), 'isprint' 
ok:  (POSIX::ispunct: '%'),  'ispunct' 
ok: !(POSIX::ispunct: 'u'),  'ispunct' 
ok:  (POSIX::isspace: "\t"), 'isspace' 
ok: !(POSIX::isspace: '_'),  'isspace' 
ok:  (POSIX::isxdigit: 'f'), 'isxdigit' 
ok: !(POSIX::isxdigit: 'g'), 'isxdigit' 
# metaphysical question : what should be returned for an empty string ?
# anyway this shouldn't segfault (bug #24554)
ok:  (POSIX::isalnum: ''),   'isalnum empty string' 
ok:  (POSIX::isalnum: undef),'isalnum undef' 
# those functions should stringify their arguments
dies_like:  sub (@< @_) { (POSIX::isalpha: \$@) }, qr/reference as string/,   'isalpha []' 
dies_like:  sub (@< @_) { (POSIX::isprint: \$@) }, qr/reference as string/,   'isalpha []' 

do
    POSIX->import: "S_ISBLK"
    my $x = &S_ISBLK
    ok: 1, "Can import autoloaded constants" 

# Check that output is not flushed by _exit. This test should be last
# in the file, and is not counted in the total number of tests.
if ($^OS_NAME eq 'vos')
    print: $^STDOUT, "# TODO - hit VOS bug posix-885 - _exit flushes output buffers.\n"
else
    $^OUTPUT_AUTOFLUSH = 0
    # The following line assumes buffered output, which may be not true:
    print: $^STDOUT, '@#!*$@(!@#$' unless ($Is_MacOS || $Is_OS2 || $Is_UWin || $Is_OS390 ||
                                          $Is_VMS ||
                                          (defined (env::var: 'PERLIO') &&
                                        (env::var: 'PERLIO') eq 'unix' &&
                                        (Config::config_value: "useperlio")))
    _exit: 0

