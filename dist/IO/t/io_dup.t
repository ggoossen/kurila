#!./perl

use Config

use IO::Handle
use IO::File

iohandle::output_autoflush: $^STDERR, 1
iohandle::output_autoflush: $^STDOUT, 1

print: $^STDOUT, "1..6\n"

print: $^STDOUT, "ok 1\n"

my $dupout = IO::Handle->new->fdopen:  $^STDOUT ,"w"
my $duperr = IO::Handle->new->fdopen:  $^STDERR ,"w"

my $stdout = $^STDOUT; bless: $stdout, "IO::File" # "IO::Handle";
my $stderr = $^STDERR; bless: $stderr, "IO::Handle"

($stdout->open:  "Io.dup","w") || die: "Can't open stdout"
$stderr->fdopen: $stdout,"w"

print: $stdout, "ok 2\n"
print: $stderr, "ok 3\n"

# Since some systems don't have echo, we use Perl.
my $echo = qq{$^EXECUTABLE_NAME -e "print \\\$^STDOUT, qq(ok \%d\n)"}

my $cmd = sprintf: $echo, 4
print: $^STDOUT, `$cmd`

$cmd = sprintf: "$echo 1>&2", 5
$cmd = (sprintf: $echo, 5) if $^OS_NAME eq 'MacOS'
print: $^STDOUT, `$cmd`

$stderr->close
$stdout->close

$stdout->fdopen: $dupout,"w"
$stderr->fdopen: $duperr,"w"

if ($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare' || $^OS_NAME eq 'VMS') { (print: $^STDOUT, `type Io.dup`) }
    elsif ($^OS_NAME eq 'MacOS') { (system: 'Catenate Io.dup') }
else                   { system: 'cat Io.dup' }
unlink: 'Io.dup'

print: $^STDOUT, "ok 6\n"
