#!./perl

use Config;

BEGIN {
    unless (-d 'blib') {
	if (%Config{extensions} !~ m/\bList\/Util\b/) {
	    print "1..0 # Skip: List::Util was not built\n";
	    exit 0;
	}
    }
}

use strict;
use vars qw(*CLOSED);
use Test::More tests => 4;
use Scalar::Util qw(openhandle);

ok(defined &openhandle, 'defined');

my $fh = \*STDERR;
is(openhandle($fh), $fh, 'STDERR');

is(fileno(openhandle(*STDERR)), fileno(STDERR), 'fileno(STDERR)');

is(openhandle(*CLOSED), undef, 'closed');

