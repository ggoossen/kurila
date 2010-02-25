#!./perl

BEGIN 
    require './test.pl'


our $TODO

my $vms_exit_mode = 0

if ($^OS_NAME eq 'VMS')
    if (eval 'require VMS::Feature')
        $vms_exit_mode = !((VMS::Feature::current: "posix_exit"))
    else
        my $env_unix_rpt = (env::var: 'DECC$FILENAME_UNIX_REPORT') || ''
        my $env_posix_ex = (env::var: 'PERL_VMS_POSIX_EXIT') || ''
        my $unix_rpt = $env_unix_rpt =~ m/^[ET1]/i;
        my $posix_ex = $env_posix_ex =~ m/^[ET1]/i
        if (($unix_rpt || $posix_ex) )
            $vms_exit_mode = 0
        else
            $vms_exit_mode = 1


# supress VMS whinging about bad execs.
use vmsish qw(hushed)

$^OUTPUT_AUTOFLUSH = 1				# flush stdout

(env::var: 'LC_ALL'   ) = 'C'		# Forge English error messages.
(env::var: 'LANGUAGE' ) = 'C'		# Ditto in GNU.

my $Is_VMS   = $^OS_NAME eq 'VMS'
my $Is_Win32 = $^OS_NAME eq 'MSWin32'

skip_all: "Tests mostly usesless on MacOS" if $^OS_NAME eq 'MacOS'

plan: tests => 20

my $Perl = (which_perl: )

my $exit
:SKIP do
    skip: "bug/feature of pdksh", 2 if $^OS_NAME eq 'os2'

    my $tnum = (curr_test: )
    $exit = system: qq{$Perl -e "print: \\\$^STDOUT, q\{ok $tnum - interp system(EXPR)\n"\}}
    (next_test: )
    is:  $exit, 0, '  exited 0' 


my $tnum = (curr_test: )
$exit = system: qq{$Perl -e "print: \\\$^STDOUT, q\{ok $tnum - split & direct system(EXPR)\n"\}}
(next_test: )
is:  $exit, 0, '  exited 0' 

# On VMS and Win32 you need the quotes around the program or it won't work.
# On Unix its the opposite.
my $quote = $Is_VMS || $Is_Win32 ?? '"' !! ''
$tnum = (curr_test: )
$exit = system: $Perl, '-e'
                "$($quote)print: \$^STDOUT, q<ok $tnum - system(PROG, LIST)\n>$($quote)"
(next_test: )
is:  $exit, 0, '  exited 0' 


# Some basic piped commands.  Some OS's have trouble with "helpfully"
# putting newlines on the end of piped output.  So we split this into
# newline insensitive and newline sensitive tests.
my $echo_out = `$Perl -e "print: \\\$^STDOUT, 'ok'" | $Perl -e "print: \\\$^STDOUT, ~< \\\$^STDIN, qq[\n]"`
$echo_out =~ s/\n\n/\n/g
is:  $echo_out, "ok\n", 'piped echo emulation'

do
    # here we check if extra newlines are going to be slapped on
    # piped output.
    local $TODO = 'VMS sticks newlines on everything' if $Is_VMS

    is:  scalar `$Perl -e "print: \\\$^STDOUT, 'ok'"`
         "ok", 'no extra newlines on ``' 

    is:  scalar `$Perl -e "print: \\\$^STDOUT, 'ok'" | $Perl -e "print: \\\$^STDOUT, ~< \\\$^STDIN"`
         "ok", 'no extra newlines on pipes'

    is:  scalar `$Perl -e "print: \\\$^STDOUT, 'ok', qq[\n]" | $Perl -e "print: \\\$^STDOUT, ~< \\\$^STDIN, qq[\n]"`
         "ok\n\n", 'doubled up newlines'

    is:  scalar `$Perl -e "print: \\\$^STDOUT, 'ok'" | $Perl -e "print: \\\$^STDOUT, ~< \\\$^STDIN, qq[\n]"`
         "ok\n", 'extra newlines on inside pipes'

    is:  scalar `$Perl -e "print: \\\$^STDOUT, 'ok', qq[\n]" | $Perl -e "print: \\\$^STDOUT, ~< \\\$^STDIN"`
         "ok\n", 'extra newlines on outgoing pipes'

    do
        local($^INPUT_RECORD_SEPARATOR) = \2
        my $out = runperl: prog => 'print: $^STDOUT, q{1234}'
        is: $out, "1234", 'ignore $/ when capturing output in scalar context'
    



is:  (system: qq{$Perl -e "exit 0"}), 0,     'Explicit exit of 0' 

my $exit_one = $vms_exit_mode ?? 4 << 8 !! 1 << 8
is:  (system: qq{$Perl "-I../lib" -e "use vmsish qw(hushed); exit 1"}), $exit_one
     'Explicit exit of 1' 

is:  `$Perl -e "print: \\\$^STDOUT, 'ok', qq[\n]"`,   "ok\n",     'basic ``' 
is:  <<`END`,                    "ok\n",     '<<`HEREDOC`' 
$Perl -e "print: \\\$^STDOUT, 'ok', qq[\n]"
END

do
    my $_ = qq($Perl -e "print: \\\$^STDOUT, 'ok', qq[\n]")
    is:  readpipe, "ok\n", 'readpipe default argument' 


:TODO do
    my $tnum = (curr_test: )
    if( $^OS_NAME =~ m/Win32/ )
        print: $^STDOUT, "not ok $tnum - exec failure doesn't terminate process " .
                   "# TODO Win32 exec failure waits for user input\n"
        (next_test: )
        last TODO
    

    ok:  !(exec: "lskdjfalksdjfdjfkls")
         "exec failure doesn't terminate process"


my $test = (curr_test: )
exec: $Perl, '-e', qq{$($quote)print: \$^STDOUT, 'ok $test - exec PROG, LIST', qq[\n]$($quote)}
fail: "This should never be reached if the exec() worked"
