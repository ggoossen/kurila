#!./perl

use TestInit;
use Config;

BEGIN {
    if (%Config{'extensions'} !~ m/\bSys\/Hostname\b/) {
      print "1..0 # Skip: Sys::Hostname was not built\n";
      exit 0;
    }
}

use Sys::Hostname;

my $host;
try {
    $host = hostname;
};

if ($@) {
    print "1..0\n" if $@->{description} =~ m/Cannot get host name/;
} else {
    print "1..1\n";
    print "# \$host = `$host'\n";
    print "ok 1\n";
}
