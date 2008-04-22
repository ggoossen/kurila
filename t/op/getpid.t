#!perl -w

# Tests if $$ and getppid return consistent values across threads

BEGIN {
    require './test.pl';
}

use strict;
use Config;

BEGIN {
    if (!%Config{useithreads}) {
	print "1..0 # Skip: no ithreads\n";
	exit;
    }
    if (!%Config{d_getppid}) {
	print "1..0 # Skip: no getppid\n";
	exit;
    }
    if (%ENV{PERL_CORE_MINITEST}) {
        print "1..0 # Skip: no dynamic loading on miniperl, no threads\n";
        exit 0;
    }
}
use threads;
use threads::shared;

plan tests => 2;

my ($pid, $ppid) = ($$, getppid());
my $pid2 : shared = 0;
my $ppid2 : shared = 0;

threads->new( sub { ($pid2, $ppid2) = ($$, getppid()); }) -> join();

is($pid,  $pid2,  'pids');
is($ppid, $ppid2, 'ppids');
