BEGIN {
	chdir 't' if -d 't';
	@INC = '../lib';
	require Config; import Config;
	if ($Config{extensions} !~ /\bList\/Util\b/) {
	    print "1..0 # Skip: List::Util was not built\n";
	    exit 0;
	}
}

use List::Util qw(first);

print "1..4\n";

print "not " unless defined &first;
print "ok 1\n";

print "not " unless 9 == first { 8 == ($_ - 1) } 9,4,5,6;
print "ok 2\n";

print "not " if defined(first { 0 } 1,2,3,4);
print "ok 3\n";

print "not " if defined(first { 0 });
print "ok 4\n";
