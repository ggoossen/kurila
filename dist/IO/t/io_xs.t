#!./perl

use Config

BEGIN 
    if( $^OS_NAME eq 'VMS' && (config_value: 'vms_cc_type') ne 'decc' )
        print: $^STDOUT, "1..0 # Skip: not compatible with the VAXCRTL\n"
        exit 0
    


use IO::File
use IO::Seekable

print: $^STDOUT, "1..4\n"

my $x = IO::File->new_tmpfile or print: $^STDOUT, "not "
print: $^STDOUT, "ok 1\n"
print: $x, "ok 2\n"
$x->seek: 0,SEEK_SET
print: $^STDOUT, ~< $x

$x->seek: 0,SEEK_SET
print: $x, "not ok 3\n"
my $p = $x->getpos
print: $x, "ok 3\n"
$x->flush
$x->setpos: $p
print: $^STDOUT, scalar ~< $x

$^OS_ERROR = 0
$x->setpos: undef
print: $^STDOUT, $^OS_ERROR ?? "ok 4 # $^OS_ERROR\n" !! "not ok 4\n"

