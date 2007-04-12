#!./perl

BEGIN {
    chdir 't' if -d 't';
    unshift @INC, "../lib";
}

print "1..14\n";

my $test = 1;

use v5.5.640;
require v5.5.640;
print "ok $test\n";  ++$test;

print "not " unless v1.20.300.4000 eq "\x{1}\x{14}\x{12c}\x{fa0}";
print "ok $test\n";  ++$test;

print "not " unless sprintf("%vd", "Perl") eq '80.101.114.108';
print "ok $test\n";  ++$test;

print "not " unless sprintf("%vd", v1.22.333.4444) eq '1.22.333.4444';
print "ok $test\n";  ++$test;

print "not " unless sprintf("%vx", "Perl") eq '50.65.72.6c';
print "ok $test\n";  ++$test;

print "not " unless sprintf("%vX", v1.22.333.4444) eq '1.16.14D.115C';
print "ok $test\n";  ++$test;

print "not " unless sprintf("%*v#o", ":", "Perl") eq '0120:0145:0162:0154';
print "ok $test\n";  ++$test;

print "not " unless sprintf("%*vb", "##", v1.22.333.4444)
    eq '1##10110##101001101##1000101011100';
print "ok $test\n";  ++$test;

{
    use bytes;
    print "not " unless sprintf("%vd", "Perl") eq '80.101.114.108';
    print "ok $test\n";  ++$test;

    print "not " unless
        sprintf("%vd", v1.22.333.4444) eq '1.22.197.141.225.133.156';
    print "ok $test\n";  ++$test;

    print "not " unless sprintf("%vx", "Perl") eq '50.65.72.6c';
    print "ok $test\n";  ++$test;

    print "not " unless sprintf("%vX", v1.22.333.4444) eq '1.16.C5.8D.E1.85.9C';
    print "ok $test\n";  ++$test;

    print "not " unless sprintf("%*v#o", ":", "Perl") eq '0120:0145:0162:0154';
    print "ok $test\n";  ++$test;

    print "not " unless sprintf("%*vb", "##", v1.22.333.4444)
	eq '1##10110##11000101##10001101##11100001##10000101##10011100';
    print "ok $test\n";  ++$test;
}
