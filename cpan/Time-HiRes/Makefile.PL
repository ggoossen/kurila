#!/usr/bin/perl
#
# In general we trust %Config, but for nanosleep() this trust
# may be misplaced (it may be linkable but not really functional).
# Use $ENV{FORCE_NANOSLEEP_SCAN} to force rescanning whether there
# really is hope.


use Config
use ExtUtils::MakeMaker


my $VERBOSE = env::var: 'VERBOSE'
my $DEFINE
my $LIBS = $@
my $XSOPT = ''
my $SYSCALL_H

our ($self) # Used in 'sourcing' the hints.

# TBD: Can we just use $Config(exe_ext) here instead of this complex
#      expression?
my $ld_exeext = ($^OS_NAME eq 'cygwin' ||
                   $^OS_NAME eq 'os2' && (config_value: "ldflags") =~ m/-Zexe\b/) ?? '.exe' !!
    (($^OS_NAME eq 'vos') ?? (config_value: "exe_ext") !! '')

unless((env::var: 'PERL_CORE'))
    (env::var: 'PERL_CORE' ) = 1 if grep: { $_ eq 'PERL_CORE=1' }, @ARGV


use File::Spec

# if you have 5.004_03 (and some slightly older versions?), xsubpp
# tries to generate line numbers in the C code generated from the .xs.
# unfortunately, it is a little buggy around #ifdef'd code.
# my choice is leave it in and have people with old perls complain
# about the "Usage" bug, or leave it out and be unable to compile myself
# without changing it, and then I'd always forget to change it before a
# release. Sorry, Edward :)

sub try_compile_and_link($c, %< %args)

    my $ok = 0
    my $tmp = "tmp$^PID"

    my $obj_ext = (config_value: "obj_ext") || ".o"
    unlink: "$tmp.c", "$tmp$obj_ext"

    if ((open: my $tmpc, ">", "$tmp.c"))
        print: $tmpc, $c
        close: $tmpc

        my $cccmd = %args{?cccmd}

        my $errornull

        my $COREincdir

        if ((env::var: 'PERL_CORE'))
            my $updir = File::Spec->updir
            $COREincdir = File::Spec->catdir: < $: (@: $updir) x 2
        else
            $COREincdir = File::Spec->catdir: (config_value: 'archlibexp'), 'CORE'
        

        if ((env::var: 'PERL_CORE'))
            unless (-f (File::Spec->catfile: $COREincdir, "EXTERN.h"))
                die: <<__EOD__
Your environment variable PERL_CORE is '$((env::var: 'PERL_CORE'))' but there
is no EXTERN.h in $COREincdir.
Cannot continue, aborting.
__EOD__
            
        

        my $ccflags = (config_value: 'ccflags') . ' ' . "-I$COREincdir"

        if ($^OS_NAME eq 'VMS')
            if ((env::var: 'PERL_CORE'))
                # Fragile if the extensions change hierarchy within
                # the Perl core but this should do for now.
                $cccmd = "$((config_value: 'cc')) /include=([---]) $tmp.c"
            else
                my $perl_core = config_value: 'installarchlib'
                $perl_core =~ s/\]$/.CORE]/
                $cccmd = "$((config_value: 'cc')) /include=(perl_root:[000000],$perl_core) $tmp.c"
            
        

        if (%args{?silent} || !$VERBOSE)
            $errornull = "2>/dev/null" unless defined $errornull
        else
            $errornull = ''
        

        $cccmd = "$((config_value: 'cc')) -o $tmp $ccflags $tmp.c $((join: ' ',$LIBS)) $errornull"
            unless defined $cccmd

        if ($^OS_NAME eq 'VMS')
            open:  my $cmdfile, ">$tmp.com" 
            print: $cmdfile, "\$ SET MESSAGE/NOFACILITY/NOSEVERITY/NOIDENT/NOTEXT\n"
            print: $cmdfile, "\$ $cccmd\n"
            print: $cmdfile, "\$ IF \$SEVERITY .NE. 1 THEN EXIT 44\n" # escalate
            close $cmdfile
            system: "\@ $tmp.com"
            $ok = $^CHILD_ERROR==0
            for (@: "$tmp.c", "$tmp$obj_ext", "$tmp.com"
                    $tmp . (config_value: 'exe_ext'))
                1 while unlink: $_
            
        else
            my $tmp_exe = "$tmp$ld_exeext"
            printf: $^STDOUT, "cccmd = $cccmd\n" if $VERBOSE
            my $res = system: $cccmd
            $ok = (defined: $res) && $res == 0 && -s $tmp_exe && -x _

            if ( $ok && exists %args{run} && %args{?run})
                my $tmp_exe =
                    File::Spec->catfile:  File::Spec->curdir, $tmp_exe
                printf: $^STDOUT, "Running $tmp_exe..." if $VERBOSE
                if ((system: $tmp_exe) == 0)
                    $ok = 1
                else
                    $ok = 0
                    my $errno = $^CHILD_ERROR >> 8
                    local $^OS_ERROR = $errno
                    printf: $^STDOUT, <<EOF

*** The test run of '$tmp_exe' failed: status $^CHILD_ERROR
*** (the status means: errno = $errno or '$^OS_ERROR')
*** DO NOT PANIC: this just means that *some* functionality will be missing.
EOF
                
            
            unlink: "$tmp.c", $tmp_exe
        
    

    return $ok


my $TIME_HEADERS = <<EOH
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef I_SYS_TYPES
#   include <sys/types.h>
#endif
#ifdef I_SYS_TIME
#   include <sys/time.h>
#endif
#ifdef I_SYS_SELECT
#   include <sys/select.h>	/* struct timeval might be hidden in here */
#endif
EOH

sub has_gettimeofday
    # confusing but true (if condition true ==> -DHAS_GETTIMEOFDAY already)
    return 0 if config_value: "d_gettimeod"
    return 1 if try_compile_and_link: <<EOM
$TIME_HEADERS
static int foo()
\{
    struct timeval tv;
    gettimeofday(&tv, 0);
\}
int main(int argc, char** argv)
\{
    foo();
\}
EOM
    return 0


sub has_x($x, %< %args)

    return 1 if
      try_compile_and_link: <<EOM, < %args
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef I_UNISTD
#   include <unistd.h>
#endif

#ifdef I_SYS_TYPES
#   include <sys/types.h>
#endif

#ifdef I_SYS_TIME
#   include <sys/time.h>
#endif

int main(int argc, char** argv)
\{
	$x;
\}
EOM
    return 0


sub has_nanosleep
    print: $^STDOUT, "testing... "
    return 1 if
      try_compile_and_link: <<EOM, run => 1
#include <time.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

/* int nanosleep(const struct timespec *rqtp, struct timespec *rmtp); */

int main(int argc, char** argv) \{
    struct timespec ts1, ts2;
    int ret;
    ts1.tv_sec  = 0;
    ts1.tv_nsec = 750000000;
    ts2.tv_sec  = 0;
    ts2.tv_nsec = 0;
    errno = 0;
    ret = nanosleep(&ts1, &ts2); /* E.g. in AIX nanosleep() fails and sets errno to ENOSYS. */
    ret == 0 ? exit(0) : exit(errno ? errno : -1);
\}
EOM


sub has_include($inc)
    return 1 if
      try_compile_and_link: <<EOM
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <$inc>
int main(int argc, char** argv)
\{
	return 0;
\}
EOM
    return 0


sub has_clock_xxx_syscall
    my $x = shift
    return 0 unless defined $SYSCALL_H
    return 1 if
      try_compile_and_link: <<EOM, run => 1
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <$SYSCALL_H>
int main(int argc, char** argv)
\{
    struct timespec ts;
    /* Many Linuxes get ENOSYS even though the syscall exists. */
    /* All implementations are supposed to support CLOCK_REALTIME. */
    int ret = syscall(SYS_clock_$x, CLOCK_REALTIME, &ts);
    ret == 0 ? exit(0) : exit(errno ? errno : -1);
\}
EOM


sub has_clock_xxx
    my $xxx = shift
    return 1 if
      try_compile_and_link: <<EOM, run => 1
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
int main(int argc, char** argv)
\{
    struct timespec ts;
    int ret = clock_$xxx(CLOCK_REALTIME, &ts); /* Many Linuxes get ENOSYS. */
    /* All implementations are supposed to support CLOCK_REALTIME. */
    ret == 0 ? exit(0) : exit(errno ? errno : -1);
\}
EOM


sub has_clock
    return 1 if
      try_compile_and_link: <<EOM, run => 1
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
int main(int argc, char** argv)
\{
    clock_t tictoc;
    clock_t ret = clock();
    ret == (clock_t)-1 ? exit(errno ? errno : -1) : exit(0);
\}
EOM


sub has_clock_nanosleep
    return 1 if
      try_compile_and_link: <<EOM, run => 1
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <time.h>
int main(int argc, char** argv)
\{
    int ret;
    struct timespec ts1;
    struct timespec ts2;
    ts1.tv_sec  = 0;
    ts1.tv_nsec = 750000000;;
    ret = clock_nanosleep(CLOCK_MONOTONIC, 0, &ts1, &ts2);
    ret == 0 ? exit(0) : exit(errno ? errno : -1);
\}
EOM


sub DEFINE($def, ?$val)
    my $define = defined $val ?? "$def=$val" !! $def 
    unless ($DEFINE =~ m/(?:^| )-D\Q$define\E(?: |$)/)
        $DEFINE .= " -D$define"
    


sub init
    my $hints = File::Spec->catfile: "hints", "$^OS_NAME.pl"
    if (-f $hints)
        print: $^STDOUT, "Using hints $hints...\n"
        local $self = \$%
        evalfile $hints
        if (exists $self->{LIBS})
            $LIBS = $self->{LIBS}
            print: $^STDOUT, "Extra libraries: $((join: ' ', $LIBS))...\n"
        
    

    $DEFINE = ''

    if ((config_value: "d_syscall"))
        print: $^STDOUT, "Have syscall()... looking for syscall.h... "
        if ((has_include: 'syscall.h'))
            $SYSCALL_H = 'syscall.h'
        elsif ((has_include: 'sys/syscall.h'))
            $SYSCALL_H = 'sys/syscall.h'
        
    else
        print: $^STDOUT, "No syscall()...\n"
    

    if ((config_value: "d_syscall"))
        if (defined $SYSCALL_H)
            print: $^STDOUT, "found <$SYSCALL_H>.\n"
        else
            print: $^STDOUT, "NOT found.\n"
        
    

    print: $^STDOUT, "Looking for gettimeofday()... "
    my $has_gettimeofday
    if (defined (config_value: "d_gettimeod"))
        $has_gettimeofday++ if config_value: "d_gettimeod"
    elsif ((has_gettimeofday: ))
        $DEFINE .= ' -DHAS_GETTIMEOFDAY'
        $has_gettimeofday++
    

    if ($has_gettimeofday)
        print: $^STDOUT, "found.\n"
    else
        die: <<EOD
Your operating system does not seem to have the gettimeofday() function.
(or, at least, I cannot find it)

There is no way Time::HiRes is going to work.

I am awfully sorry but I cannot go further.

Aborting configuration.

EOD
    

    print: $^STDOUT, "Looking for setitimer()... "
    my $has_setitimer
    if (defined (config_value: "d_setitimer"))
        $has_setitimer++ if config_value: "d_setitimer"
    elsif ((has_x: "setitimer(ITIMER_REAL, 0, 0)"))
        $has_setitimer++
        $DEFINE .= ' -DHAS_SETITIMER'
    

    if ($has_setitimer)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
    

    print: $^STDOUT, "Looking for getitimer()... "
    my $has_getitimer
    if (defined (config_value: 'd_getitimer'))
        $has_getitimer++ if config_value: 'd_getitimer'
    elsif ((has_x: "getitimer(ITIMER_REAL, 0)"))
        $has_getitimer++
        $DEFINE .= ' -DHAS_GETITIMER'
    

    if ($has_getitimer)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
    

    if ($has_setitimer && $has_getitimer)
        print: $^STDOUT, "You have interval timers (both setitimer and getitimer).\n"
    else
        print: $^STDOUT, "You do not have interval timers.\n"
    

    print: $^STDOUT, "Looking for ualarm()... "
    my $has_ualarm
    if (defined (config_value: "d_ualarm"))
        $has_ualarm++ if config_value: "d_ualarm"
    elsif ((has_x: "ualarm (0, 0)"))
        $has_ualarm++
        $DEFINE .= ' -DHAS_UALARM'
    

    if ($has_ualarm)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
        if ($has_setitimer)
            print: $^STDOUT, "But you have setitimer().\n"
            print: $^STDOUT, "We can make a Time::HiRes::ualarm().\n"
        
    

    print: $^STDOUT, "Looking for usleep()... "
    my $has_usleep
    if (defined (config_value: "d_usleep"))
        $has_usleep++ if config_value: "d_usleep"
    elsif ((has_x: "usleep (0)"))
        $has_usleep++
        $DEFINE .= ' -DHAS_USLEEP'
    

    if ($has_usleep)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
        print: $^STDOUT, "Let's see if you have select()... "
        if ((config_value: 'd_select'))
            print: $^STDOUT, "found.\n"
            print: $^STDOUT, "We can make a Time::HiRes::usleep().\n"
        else
            print: $^STDOUT, "NOT found.\n"
            print: $^STDOUT, "You won't have a Time::HiRes::usleep().\n"
        
    

    print: $^STDOUT, "Looking for nanosleep()... "
    my $has_nanosleep
    if ((env::var: 'FORCE_NANOSLEEP_SCAN'))
        print: $^STDOUT, "forced scan... "
        if ((has_nanosleep: ))
            $has_nanosleep++
            $DEFINE .= ' -DTIME_HIRES_NANOSLEEP'
        
    elsif (defined (config_value: "d_nanosleep"))
        print: $^STDOUT, "believing \$Config\{d_nanosleep\}... "
        if ((config_value: "d_nanosleep"))
            $has_nanosleep++
            $DEFINE .= ' -DTIME_HIRES_NANOSLEEP'
        
    elsif ($^OS_NAME =~ m/^(mpeix)$/)
        # MPE/iX falsely finds nanosleep from its libc equivalent.
        print: $^STDOUT, "skipping because in $^OS_NAME... "
    else
        if ((has_nanosleep: ))
            $has_nanosleep++
            $DEFINE .= ' -DTIME_HIRES_NANOSLEEP'
        
    

    if ($has_nanosleep)
        print: $^STDOUT, "found.\n"
        print: $^STDOUT, "You can mix subsecond sleeps with signals, if you want to.\n"
        print: $^STDOUT, "(It's still not portable, though.)\n"
    else
        print: $^STDOUT, "NOT found.\n"
        my $nt = ($^OS_NAME eq 'os2' ?? '' !! 'not')
        print: $^STDOUT, "You can$nt mix subsecond sleeps with signals.\n"
        print: $^STDOUT, "(It would not be portable anyway.)\n"
    

    print: $^STDOUT, "Looking for clock_gettime()... "
    my $has_clock_gettime
    if (defined (config_value: "d_clock_gettime"))
        $has_clock_gettime++ if config_value: "d_clock_gettime" # Unlikely...
    elsif ((has_clock_xxx: 'gettime'))
        $has_clock_gettime++
        $DEFINE .= ' -DTIME_HIRES_CLOCK_GETTIME'
    elsif (defined $SYSCALL_H && (has_clock_xxx_syscall: 'gettime'))
        $has_clock_gettime++
        $DEFINE .= ' -DTIME_HIRES_CLOCK_GETTIME -DTIME_HIRES_CLOCK_GETTIME_SYSCALL'
    

    if ($has_clock_gettime)
        if ($DEFINE =~ m/-DTIME_HIRES_CLOCK_GETTIME_SYSCALL/)
            print: $^STDOUT, "found (via syscall).\n"
        else
            print: $^STDOUT, "found.\n"
        
    else
        print: $^STDOUT, "NOT found.\n"
    

    print: $^STDOUT, "Looking for clock_getres()... "
    my $has_clock_getres
    if (defined (config_value: "d_clock_getres"))
        $has_clock_getres++ if config_value: "d_clock_getres" # Unlikely...
    elsif ((has_clock_xxx: 'getres'))
        $has_clock_getres++
        $DEFINE .= ' -DTIME_HIRES_CLOCK_GETRES'
    elsif (defined $SYSCALL_H && (has_clock_xxx_syscall: 'getres'))
        $has_clock_getres++
        $DEFINE .= ' -DTIME_HIRES_CLOCK_GETRES -DTIME_HIRES_CLOCK_GETRES_SYSCALL'
    

    if ($has_clock_getres)
        if ($DEFINE =~ m/-DTIME_HIRES_CLOCK_GETRES_SYSCALL/)
            print: $^STDOUT, "found (via syscall).\n"
        else
            print: $^STDOUT, "found.\n"
        
    else
        print: $^STDOUT, "NOT found.\n"
    

    print: $^STDOUT, "Looking for clock_nanosleep()... "
    my $has_clock_nanosleep
    if (defined (config_value: "d_clock_nanosleep"))
        $has_clock_nanosleep++ if config_value: "d_clock_nanosleep" # Unlikely...
    elsif ((has_clock_nanosleep: ))
        $has_clock_nanosleep++
        $DEFINE .= ' -DTIME_HIRES_CLOCK_NANOSLEEP'
    

    if ($has_clock_nanosleep)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
    

    print: $^STDOUT, "Looking for clock()... "
    my $has_clock
    if (defined (config_value: "d_clock"))
        $has_clock++ if config_value: "d_clock" # Unlikely...
    elsif ((has_clock: ))
        $has_clock++
        $DEFINE .= ' -DTIME_HIRES_CLOCK'
    

    if ($has_clock)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
    

    print: $^STDOUT, "Looking for stat() subsecond timestamps...\n"

    print: $^STDOUT, "Trying struct stat st_atimespec.tv_nsec..."
    my $has_stat_st_xtimespec
    if ((try_compile_and_link: <<EOM))
$TIME_HEADERS
#include <sys/stat.h>
int main(int argc, char** argv) \{
    struct stat st;
    st.st_atimespec.tv_nsec = 0;
\}
EOM
        $has_stat_st_xtimespec++
        DEFINE: 'TIME_HIRES_STAT', 1
    

    if ($has_stat_st_xtimespec)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
    

    print: $^STDOUT, "Trying struct stat st_atimensec..."
    my $has_stat_st_xtimensec
    if ((try_compile_and_link: <<EOM))
$TIME_HEADERS
#include <sys/stat.h>
int main(int argc, char** argv) \{
    struct stat st;
    st.st_atimensec = 0;
\}
EOM
        $has_stat_st_xtimensec++
        DEFINE: 'TIME_HIRES_STAT', 2
    

    if ($has_stat_st_xtimensec)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
    

    print: $^STDOUT, "Trying struct stat st_atime_n..."
    my $has_stat_st_xtime_n
    if ((try_compile_and_link: <<EOM))
$TIME_HEADERS
#include <sys/stat.h>
int main(int argc, char** argv) \{
    struct stat st;
    st.st_atime_n = 0;
\}
EOM
        $has_stat_st_xtime_n++
        DEFINE: 'TIME_HIRES_STAT', 3
    

    if ($has_stat_st_xtime_n)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
    

    print: $^STDOUT, "Trying struct stat st_atim.tv_nsec..."
    my $has_stat_st_xtim
    if ((try_compile_and_link: <<EOM))
$TIME_HEADERS
#include <sys/stat.h>
int main(int argc, char** argv) \{
    struct stat st;
    st.st_atim.tv_nsec = 0;
\}
EOM
        $has_stat_st_xtim++
        DEFINE: 'TIME_HIRES_STAT', 4
    

    if ($has_stat_st_xtim)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
    

    print: $^STDOUT, "Trying struct stat st_uatime..."
    my $has_stat_st_uxtime
    if ((try_compile_and_link: <<EOM))
$TIME_HEADERS
#include <sys/stat.h>
int main(int argc, char** argv) \{
    struct stat st;
    st.st_uatime = 0;
\}
EOM
        $has_stat_st_uxtime++
        DEFINE: 'TIME_HIRES_STAT', 5
    

    if ($has_stat_st_uxtime)
        print: $^STDOUT, "found.\n"
    else
        print: $^STDOUT, "NOT found.\n"
    

    if ($DEFINE =~ m/-DTIME_HIRES_STAT=\d+/)
        print: $^STDOUT, "You seem to have stat() subsecond timestamps.\n"
        print: $^STDOUT, "(Your struct stat has them, but the filesystems must help.)\n"
    else
        print: $^STDOUT, "You do not seem to have stat subsecond timestamps.\n"
    

    my $has_w32api_windows_h

    if ($^OS_NAME eq 'cygwin')
        print: $^STDOUT, "Looking for <w32api/windows.h>... "
        if ((has_include: 'w32api/windows.h'))
            $has_w32api_windows_h++
            DEFINE: 'HAS_W32API_WINDOWS_H'
        
        if ($has_w32api_windows_h)
            print: $^STDOUT, "found.\n"
        else
            print: $^STDOUT, "NOT found.\n"
        
    

    if ($DEFINE)
        $DEFINE =~ s/^\s+//
        if ((open: my $xdefine, ">", "xdefine"))
            print: $xdefine, $DEFINE, "\n"
            close: $xdefine
        
    


sub doMakefile
    my @makefileopts = $@

    DEFINE: 'ATLEASTFIVEOHOHFIVE'

    push: @makefileopts
          'NAME'	=> 'Time::HiRes'
          'AUTHOR'    => 'Jarkko Hietaniemi <jhi@iki.fi>'
          'ABSTRACT_FROM' => 'HiRes.pm'
          'VERSION_FROM' => 'HiRes.pm' # finds $VERSION
          'LIBS'	=> $LIBS   # e.g., '-lm'
          'DEFINE'	=> $DEFINE     # e.g., '-DHAS_SOMETHING'
          'XSOPT'	=> $XSOPT
        # Do not even think about 'INC' => '-I/usr/ucbinclude',
        # Solaris will avenge.
          'INC'	=> ''     # e.g., '-I/usr/include/other'
          'INSTALLDIRS' => 'perl'
          clean => (%:  FILES => "xdefine" )
          realclean => (%:  FILES=> 'const-c.inc const-xs.inc' )
        

    WriteMakefile: < @makefileopts


sub doConstants
    if (try {require ExtUtils::Constant; 1})
        my @names = qw(CLOCK_HIGHRES CLOCK_MONOTONIC
		       CLOCK_PROCESS_CPUTIME_ID
		       CLOCK_REALTIME
		       CLOCK_SOFTTIME
		       CLOCK_THREAD_CPUTIME_ID
		       CLOCK_TIMEOFDAY
		       CLOCKS_PER_SEC
		       ITIMER_REAL ITIMER_VIRTUAL ITIMER_PROF
		       ITIMER_REALPROF
		       TIMER_ABSTIME)
        foreach (qw (d_usleep d_ualarm d_gettimeofday d_getitimer d_setitimer
		     d_nanosleep d_clock_gettime d_clock_getres
		     d_clock d_clock_nanosleep d_hires_stat))
            my $macro = $_
            if ($macro =~ m/^(d_nanosleep|d_clock_gettime|d_clock_getres|d_clock|d_clock_nanosleep)$/)
                $macro =~ s/^d_(.+)/TIME_HIRES_\U$1/
            elsif ($macro =~ m/^(d_hires_stat)$/)
                my $d_hires_stat = 0
                $d_hires_stat = $1 if ($DEFINE =~ m/-DTIME_HIRES_STAT=(\d+)/)
                push: @names, \%: name => $_, macro => "TIME_HIRES_STAT", value => $d_hires_stat
                                  default => \ @: "IV", "0"
                next
            else
                $macro =~ s/^d_(.+)/HAS_\U$1/
            
            push: @names, \%: name => $_, macro => $macro, value => 1
                              default => \ @: "IV", "0"

        ExtUtils::Constant::WriteConstants: 
            NAME => 'Time::HiRes'
            NAMES => \@names
            PROXYSUBS => 1

    else
        foreach my $file ((@: 'const-c.inc', 'const-xs.inc'))
            my $fallback = File::Spec->catfile: 'fallback', $file
            local $^INPUT_RECORD_SEPARATOR = undef
            open: my $in, "<", "$fallback" or die: "Can't open $fallback: $^OS_ERROR"
            open: my $out, ">", "$file" or die: "Can't open $file: $^OS_ERROR"
            print: $out, ~< $in or die: $^OS_ERROR
            close $out or die: "Can't close $file: $^OS_ERROR"
            close $in or die: "Can't close $fallback: $^OS_ERROR"
        
    


sub main
    print: $^STDOUT, "Configuring Time::HiRes...\n"

    if ($^OS_NAME =~ m/Win32/i)
        DEFINE: 'SELECT_IS_BROKEN'
        $LIBS = $@
        print: $^STDOUT, "System is $^OS_NAME, skipping full configure...\n"
    else
        (init: )
    
    (doMakefile: )
    (doConstants: )
    my $make = (config_value: 'make') || "make"
    unless ((env::var: 'PERL_CORE'))
        print: $^STDOUT,  <<EOM
Now you may issue '$make'.  Do not forget also '$make test'.
EOM
        if ((defined (env::var: 'LC_ALL')   && (env::var: 'LC_ALL')   =~ m/utf-?8/i) ||
            (defined (env::var: 'LC_CTYPE') && (env::var: 'LC_CTYPE') =~ m/utf-?8/i) ||
            (defined (env::var: 'LANG')     && (env::var: 'LANG')     =~ m/utf-?8/i))
            print: $^STDOUT, <<EOM

NOTE: if you get an error like this (the Makefile line number may vary):
Makefile:91: *** missing separator
then set the environment variable LC_ALL to "C" and retry
from scratch (re-run perl "Makefile.PL").
(And consider upgrading your Perl to, say, at least Perl 5.8.8.)
(You got this message because you seem to have
 an UTF-8 locale active in your shell environment, this used
 to cause broken Makefiles to be created from Makefile.PLs)
EOM
        
    


main:  < @_ 

# EOF
