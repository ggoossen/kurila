#!./perl

use TestInit
use Config

use Sys::Hostname

my $host
try {
    $host = (hostname: );
}

if ($^EVAL_ERROR)
    print: $^STDOUT, "1..0\n" if $^EVAL_ERROR->{?description} =~ m/Cannot get host name/
else
    print: $^STDOUT, "1..1\n"
    print: $^STDOUT, "# \$host = `$host'\n"
    print: $^STDOUT, "ok 1\n"

