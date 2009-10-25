#!./perl

BEGIN 
    # Can't chdir in BEGIN before FindBin runs, as it then can't find us.
    $^INCLUDE_PATH = (@:  -d 't' ?? 'lib' !! '../lib' )


print: $^STDOUT, "1..2\n"

use FindBin < qw($Bin);

print: $^STDOUT, "# $Bin\n"

if ($^OS_NAME eq 'MacOS')
    print: $^STDOUT, "not " unless $Bin =~ m,:lib:$,
else
    print: $^STDOUT, "not " unless $Bin =~ m,[/.]lib\]?$,

print: $^STDOUT, "ok 1\n"

$^PROGRAM_NAME = "-"
FindBin::again:

print: $^STDOUT, "not " if $FindBin::Script ne "-"
print: $^STDOUT, "ok 2\n"
