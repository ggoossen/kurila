#!/usr/local/bin/perl -w
# Test for File::Temp - POSIX functions


use Test::More
BEGIN { (plan: tests => 6)}

use File::Temp < qw/ :POSIX unlink0 /
use IO::File
ok: 1

# TMPNAM list context
# Not strict posix behaviour
my(@: $fh, $tmpnam) =  (tmpnam: )

print: $^STDOUT, "# TMPNAM: in list context: $((dump::view: $fh)) $tmpnam\n"

# File is opened - make sure it exists
ok:  (-e $tmpnam )

# Unlink it - a possible NFS issue again if TMPDIR is not a local disk
my $status = unlink0: $fh, $tmpnam
if ($status)
    ok:  $status 
else
    skip: "Skip test failed probably due to \$TMPDIR being on NFS",1


# TMPFILE

$fh = (tmpfile: )

if (defined $fh)
    ok:  $fh 
    print: $^STDOUT, "# TMPFILE: tmpfile got FH $((dump::view: $fh))\n"

    $fh->autoflush: 1

    # print something to it
    my $original = "Hello a test\n"
    print: $^STDOUT, "# TMPFILE: Wrote line: $original"
    print: $fh, $original
        or die: "Error printing to tempfile\n"

    # rewind it
    ok:  (seek: $fh,0,0) 

    # Read from it
    my $line = ~< $fh

    print: $^STDOUT, "# TMPFILE: Read line: $line"
    is:  $original, $line

    close: $fh

else
    # Skip all the remaining tests
    foreach (1..3)
        skip: "Skip test failed probably due to \$TMPDIR being on NFS",1
    





