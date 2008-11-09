#!./perl

use TestInit;
use Config;

use Sys::Hostname;

my $host;
try {
    $host = hostname;
};

if ($@) {
    print "1..0\n" if $@->{?description} =~ m/Cannot get host name/;
} else {
    print "1..1\n";
    print "# \$host = `$host'\n";
    print "ok 1\n";
}
