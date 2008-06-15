#!./perl -Tw
# [perl #33173] shellwords.pl and tainting

BEGIN {
    require Config;
    if (%Config::Config{extensions} !~ m/\bList\/Util\b/) {
	print "1..0 # Skip: Scalar::Util was not built\n";
	exit 0;
    }
}

use Text::ParseWords qw(shellwords old_shellwords);
use Scalar::Util qw(tainted);

print "1..2\n";

print "not " if grep { not tainted($_) } shellwords("$0$^X");
print "ok 1\n";

print "not " if grep { not tainted($_) } old_shellwords("$0$^X");
print "ok 2\n";
