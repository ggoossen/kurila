#!perl -w

use Config;

BEGIN {
    if (%ENV{PERL_CORE}){
        chdir('t') if -d 't';
        @INC = @('.', '../lib', '../ext/Storable/t');
    } else {
        unshift @INC, 't';
    }

    if (%Config{byteorder} ne "1234") {
	print "1..0 # Skip: Test only works for 32 bit little-ending machines\n";
	exit 0;
    }
}

use strict;
use Storable qw(retrieve);

my $file = "xx-$$.pst";
my @dumps = @(
    # some sample dumps of the hash { one => 1 }
    "perl-store\x[04]1234\4\4\4\x[94]y\22\b\3\1\0\0\0vxz\22\b\1\1\0\0\x[00]1Xk\3\0\0\0oneX", # 0.1
    "perl-store\0\x[04]1234\4\4\4\x[94]y\22\b\3\1\0\0\0vxz\22\b\b\x[81]Xk\3\0\0\0oneX",      # 0.4@7
);

print "1.." . (nelems @dumps) . "\n";

my $testno;
for my $dump (< @dumps) {
    $testno++;

    open(FH, ">", "$file") || die "Can't create $file: $!";
    binmode(FH);
    print FH $dump;
    close(FH) || die "Can't write $file: $!";

    try {
	my $data = retrieve($file);
	if (ref($data) eq "HASH" && $data->{one} eq "1") {
	    print "ok $testno\n";
	}
	else {
	    print "not ok $testno\n";
	}
    };
    warn $@ if $@;

    unlink($file);
}
