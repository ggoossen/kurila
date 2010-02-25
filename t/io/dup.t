#!./perl

BEGIN 
    require "./test.pl"


use Config
no warnings 'once'

my $test = 1
print: $^STDOUT, "1..29\n"
print: $^STDOUT, "ok 1\n"

open: my $dupout, ">&", $^STDOUT
open: my $duperr, ">&", $^STDERR

(open: $^STDOUT, ">","Io.dup")  || die: "Can't open stdout"
(open: $^STDERR, ">&", $^STDOUT) || die: "Can't open stderr"

iohandle::output_autoflush: $^STDERR, 1
iohandle::output_autoflush: $^STDOUT, 1

print: $^STDOUT, "ok 2\n"
print: $^STDERR, "ok 3\n"

# Since some systems don't have echo, we use Perl.
my $echo = qq{$^EXECUTABLE_NAME -e "print: \\\$^STDOUT, qq(ok \%d\n)"}

my $cmd = sprintf: $echo, 4
print: $^STDOUT, `$cmd`

$cmd = sprintf: "$echo 1>&2", 5
$cmd = (sprintf: $echo, 5) if $^OS_NAME eq 'MacOS'  # don't know if we can do this ...
print: $^STDOUT, `$cmd`

# KNOWN BUG system() does not honor STDOUT redirections on VMS.
if( $^OS_NAME eq 'VMS' )
    for (6..7)
        print: $^STDOUT, "not ok $_ # TODO system() not honoring STDOUT redirect on VMS\n"
else
    system: sprintf: $echo, 6
    if ($^OS_NAME eq 'MacOS')
        system: sprintf: $echo, 7
    else
        system: sprintf: "$echo 1>&2", 7
    


close: $^STDOUT or die: "Could not close: $^OS_ERROR"
close: $^STDERR or die: "Could not close: $^OS_ERROR"

open: $^STDOUT, ">&", $dupout or die: "Could not open: $^OS_ERROR"
open: $^STDERR, ">&", $duperr or die: "Could not open: $^OS_ERROR"

if (($^OS_NAME eq 'MSWin32') || ($^OS_NAME eq 'NetWare') || ($^OS_NAME eq 'VMS')) { (print: $^STDOUT, `type Io.dup`) }
    elsif ($^OS_NAME eq 'MacOS') { (system: 'catenate Io.dup') }
else                   { system: 'cat Io.dup' }
unlink: 'Io.dup'

print: $^STDOUT, "ok 8\n"

open: my $f,">&",1 or die: "Cannot dup to numeric 1: $^OS_ERROR"
print: $f, "ok 9\n"
close: $f

open: $f,">&",'1' or die: "Cannot dup to string '1': $^OS_ERROR"
print: $f, "ok 10\n"
close: $f

open: $f,">&=",1 or die: "Cannot dup to numeric 1: $^OS_ERROR"
print: $f, "ok 11\n"
close: $f

if ((config_value: "useperlio"))
    open: $f,">&=",'1' or die: "Cannot dup to string '1': $^OS_ERROR"
    print: $f, "ok 12\n"
    close: $f
else
    open: $f, ">&", $dupout or die: "Cannot dup stdout back: $^OS_ERROR"
    print: $f, "ok 12\n"
    close: $f


# To get STDOUT back.
open: $f, ">&", $dupout or die: "Cannot dup stdout back: $^OS_ERROR"

curr_test: 13

:SKIP do
    skip: "need perlio", 14 unless config_value: "useperlio"

    ok: (open: $f, ">&", $^STDOUT)
    isnt: (fileno: $f), (fileno: $^STDOUT)
    close $f

    ok: (open: $f, "<&=", $^STDIN) or _diag: $^OS_ERROR
    is: (fileno: $f), (fileno: $^STDIN)
    close $f

    ok: (open: $f, ">&=", $^STDOUT)
    is: (fileno: $f), (fileno: $^STDOUT)
    close $f

    ok: (open: $f, ">&=", $^STDERR)
    is: (fileno: $f), (fileno: $^STDERR)
    close $f

    open: my $gfh, ">", "dup$^PID" or die: 
    my $g = fileno: $gfh

    ok: (open: $f, ">&=", "$g")
    is: (fileno: $f), $g
    close $f

    ok: (open: $f, ">&=", $gfh)
    is: (fileno: $f), $g

    print: $gfh, "ggg\n"
    print: $f, "fff\n"

    close $gfh # flush first
    close $f # flush second

    open: $gfh, "<", "dup$^PID" or die: 
    do
        my $line
        $line = ~< $gfh->*; chomp $line; is: $line, "ggg"
        $line = ~< $gfh->*; chomp $line; is: $line, "fff"
    
    close $gfh

    open: my $utfout, '>:utf8', "dup$^PID" or die: $^OS_ERROR
    open: my $utfdup, ">&", \$utfout->* or die: $^OS_ERROR
    # some old greek saying.
    my $message = "\x{03A0}\x{0391}\x{039D}\x{03A4}\x{0391} \x{03A1}\x{0395}\x{0399}\n"
    print: $utfout, $message
    print: $utfdup, $message
    binmode: $utfdup, ':utf8'
    print: $utfdup, $message
    close $utfout
    close $utfdup
    open: my $utfin, "<:utf8", "dup$^PID" or die: $^OS_ERROR
    do
        my $line
        $line = ~< $utfin->*; is: $line, $message
        $line = ~< $utfin->*; is: $line, $message
        $line = ~< $utfin->*; is: $line, $message
    
    close $utfin

    END { 1 while (unlink: "dup$^PID") }
