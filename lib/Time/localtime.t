#!./perl

BEGIN {
    chdir 't' if -d 't';
    $^INCLUDE_PATH = @( '../lib' );
}

BEGIN {
    our $haslocal;
    try { my $n = localtime 0 };
    $haslocal = 1 unless $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/unimplemented/;
    unless ($haslocal) { print $^STDOUT, "1..0 # Skip: no localtime\n"; exit 0 }
}


our @localtime;
BEGIN {
    @localtime = @( localtime 0 ); # This is the function localtime.
    unless (nelems @localtime) { print $^STDOUT, "1..0 # Skip: localtime failed\n"; exit 0 }
}

print $^STDOUT, "1..10\n";

use Time::localtime;

print $^STDOUT, "ok 1\n";

my $localtime = localtime 0 ; # This is the OO localtime.

print $^STDOUT, "not " unless $localtime->sec   == @localtime[0];
print $^STDOUT, "ok 2\n";

print $^STDOUT, "not " unless $localtime->min   == @localtime[1];
print $^STDOUT, "ok 3\n";

print $^STDOUT, "not " unless $localtime->hour  == @localtime[2];
print $^STDOUT, "ok 4\n";

print $^STDOUT, "not " unless $localtime->mday  == @localtime[3];
print $^STDOUT, "ok 5\n";

print $^STDOUT, "not " unless $localtime->mon   == @localtime[4];
print $^STDOUT, "ok 6\n";

print $^STDOUT, "not " unless $localtime->year  == @localtime[5];
print $^STDOUT, "ok 7\n";

print $^STDOUT, "not " unless $localtime->wday  == @localtime[6];
print $^STDOUT, "ok 8\n";

print $^STDOUT, "not " unless $localtime->yday  == @localtime[7];
print $^STDOUT, "ok 9\n";

print $^STDOUT, "not " unless $localtime->isdst == @localtime[8];
print $^STDOUT, "ok 10\n";




