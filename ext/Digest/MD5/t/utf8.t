#!perl -w

BEGIN {
    if ($] < 5.006) {
	print "1..0 # Skipped: your perl don't know unicode\n";
	exit;
    }
}

print "1..3\n";

use strict;
use Digest::MD5 qw(md5_hex);

use utf8;

my $str;
$str = "foo\xFF\x{100}";

eval { md5_hex($str); };
print "not " if $@;
print "ok 1\n";

my $exp = "503debffe559537231ed24f25651ec20";

chop($str);  # only bytes left
print "not " unless md5_hex($str) eq $exp;
print "ok 2\n";

# reference
print "not " unless md5_hex("foo\xFF") eq $exp;
print "ok 3\n";
