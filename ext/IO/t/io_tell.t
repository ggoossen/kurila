#!./perl

our $tell_file;

BEGIN {
    unless(grep m/blib/, @INC) {
	$tell_file = "TEST";
    }
    else {
	$tell_file = "Makefile";
    }
}

use Config;

BEGIN {
    if (%ENV{PERL_CORE} and %Config{'extensions'} !~ m/\bIO\b/ && $^O ne 'VMS') {
	print "1..0\n";
	exit 0;
    }
}

print "1..13\n";

use IO::File;

my $tst = IO::File->new("$tell_file","r") || die("Can't open $tell_file");
binmode $tst; # its a nop unless it matters. Was only if ($^O eq 'MSWin32' or $^O eq 'dos');
if ($tst->eof) { print "not ok 1\n"; } else { print "ok 1\n"; }

my $firstline = ~< $tst;
my $secondpos = tell $tst;

my $x = 0;
while ( ~< $tst) {
    if (eof $tst) {$x++;}
}
if ($x == 1) { print "ok 2\n"; } else { print "not ok 2\n"; }

my $lastpos = tell $tst;

unless (eof $tst) { print "not ok 3\n"; } else { print "ok 3\n"; }

if ($tst->seek(0,0)) { print "ok 4\n"; } else { print "not ok 4\n"; }

if (eof $tst) { print "not ok 5\n"; } else { print "ok 5\n"; }

if ($firstline eq ~< $tst) { print "ok 6\n"; } else { print "not ok 6\n"; }

if ($secondpos == tell $tst) { print "ok 7\n"; } else { print "not ok 7\n"; }

if ($tst->seek(0,1)) { print "ok 8\n"; } else { print "not ok 8\n"; }

if ($tst->eof) { print "not ok 9\n"; } else { print "ok 9\n"; }

if ($secondpos == tell $tst) { print "ok 10\n"; } else { print "not ok 10\n"; }

if ($tst->seek(0,2)) { print "ok 11\n"; } else { print "not ok 11\n"; }

if ($lastpos == $tst->tell) { print "ok 12\n"; } else { print "not ok 12\n"; }

unless (eof $tst) { print "not ok 13\n"; } else { print "ok 13\n"; }
