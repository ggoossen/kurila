#!./perl

our $tell_file

BEGIN 
    $tell_file = "Makefile"


use Config

print: $^STDOUT, "1..13\n"

use IO::File

my $tst = (IO::File->new: "$tell_file","r") || die: "Can't open $tell_file"
binmode: $tst # its a nop unless it matters. Was only if ($^O eq 'MSWin32' or $^O eq 'dos');
if (($tst->eof: )) { print: $^STDOUT, "not ok 1\n"; } else { print: $^STDOUT, "ok 1\n"; }

my $firstline = ~< $tst
my $secondpos = tell $tst

my $x = 0
while ( ~< $tst)
    if (eof $tst) {$x++;}

if ($x == 1) { print: $^STDOUT, "ok 2\n"; } else { print: $^STDOUT, "not ok 2\n"; }

my $lastpos = tell $tst

unless (eof $tst) { print: $^STDOUT, "not ok 3\n"; } else { print: $^STDOUT, "ok 3\n"; }

if (($tst->seek: 0,0)) { print: $^STDOUT, "ok 4\n"; } else { print: $^STDOUT, "not ok 4\n"; }

if (eof $tst) { print: $^STDOUT, "not ok 5\n"; } else { print: $^STDOUT, "ok 5\n"; }

if ($firstline eq ~< $tst) { print: $^STDOUT, "ok 6\n"; } else { print: $^STDOUT, "not ok 6\n"; }

if ($secondpos == tell $tst) { print: $^STDOUT, "ok 7\n"; } else { print: $^STDOUT, "not ok 7\n"; }

if (($tst->seek: 0,1)) { print: $^STDOUT, "ok 8\n"; } else { print: $^STDOUT, "not ok 8\n"; }

if (($tst->eof: )) { print: $^STDOUT, "not ok 9\n"; } else { print: $^STDOUT, "ok 9\n"; }

if ($secondpos == tell $tst) { print: $^STDOUT, "ok 10\n"; } else { print: $^STDOUT, "not ok 10\n"; }

if (($tst->seek: 0,2)) { print: $^STDOUT, "ok 11\n"; } else { print: $^STDOUT, "not ok 11\n"; }

if ($lastpos == ($tst->tell: )) { print: $^STDOUT, "ok 12\n"; } else { print: $^STDOUT, "not ok 12\n"; }

unless (eof $tst) { print: $^STDOUT, "not ok 13\n"; } else { print: $^STDOUT, "ok 13\n"; }
