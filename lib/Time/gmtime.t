#!./perl

BEGIN {
    chdir 't' if -d 't';
    $^INCLUDE_PATH = @( '../lib' );
}

BEGIN {
    our $hasgm;
    try { my $n = gmtime 0 };
    $hasgm = 1 unless $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/unimplemented/;
    unless ($hasgm) { print $^STDOUT, "1..0 # Skip: no gmtime\n"; exit 0 }
}


our @gmtime;

BEGIN {
    @gmtime = @( gmtime 0 ); # This is the function gmtime.
    unless (nelems @gmtime) { print $^STDOUT, "1..0 # Skip: gmtime failed\n"; exit 0 }
}

print $^STDOUT, "1..10\n";

use Time::gmtime;

print $^STDOUT, "ok 1\n";

my $gmtime = gmtime 0 ; # This is the OO gmtime.

print $^STDOUT, "not " unless $gmtime->sec   == @gmtime[0];
print $^STDOUT, "ok 2\n";

print $^STDOUT, "not " unless $gmtime->min   == @gmtime[1];
print $^STDOUT, "ok 3\n";

print $^STDOUT, "not " unless $gmtime->hour  == @gmtime[2];
print $^STDOUT, "ok 4\n";

print $^STDOUT, "not " unless $gmtime->mday  == @gmtime[3];
print $^STDOUT, "ok 5\n";

print $^STDOUT, "not " unless $gmtime->mon   == @gmtime[4];
print $^STDOUT, "ok 6\n";

print $^STDOUT, "not " unless $gmtime->year  == @gmtime[5];
print $^STDOUT, "ok 7\n";

print $^STDOUT, "not " unless $gmtime->wday  == @gmtime[6];
print $^STDOUT, "ok 8\n";

print $^STDOUT, "not " unless $gmtime->yday  == @gmtime[7];
print $^STDOUT, "ok 9\n";

print $^STDOUT, "not " unless $gmtime->isdst == @gmtime[8];
print $^STDOUT, "ok 10\n";




