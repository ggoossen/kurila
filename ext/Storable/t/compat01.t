#!perl -w

use Config;

BEGIN {
    if (env::var('PERL_CORE')){
        chdir('t') if -d 't';
        $^INCLUDE_PATH = @('.', '../lib', '../ext/Storable/t');
    } else {
        unshift $^INCLUDE_PATH, 't';
    }

    if (config_value('byteorder') ne "1234") {
	print $^STDOUT, "1..0 # Skip: Test only works for 32 bit little-ending machines\n";
	exit 0;
    }
}

use Storable < qw(retrieve);

my $file = "xx-$^PID.pst";
my @dumps = @(
    # some sample dumps of the hash { one => 1 }
    "perl-store\x[04]1234\4\4\4\x[94]y\22\b\3\1\0\0\0vxz\22\b\1\1\0\0\x[00]1Xk\3\0\0\0oneX", # 0.1
    "perl-store\0\x[04]1234\4\4\4\x[94]y\22\b\3\1\0\0\0vxz\22\b\b\x[81]Xk\3\0\0\0oneX",      # 0.4@7
);

use Test::More;
plan tests => (nelems @dumps);

my $testno;
for my $dump (@dumps) {
    $testno++;

    open(my $fh, ">", "$file") || die "Can't create $file: $^OS_ERROR";
    binmode($fh);
    print $fh, $dump;
    close($fh) || die "Can't write $file: $^OS_ERROR";

    my $data = retrieve($file);
    ok(ref($data) eq "HASH" && $data->{one} eq "1");

    unlink($file);
}
