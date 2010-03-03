#!/usr/bin/perl -w


use Test::More
use ExtUtils::MakeMaker
use version

my %versions = %: q[$VERSION = '1.00']        => '1.00'
                  q[*VERSION = \'1.01']       => '1.01'
                  q[@: $VERSION = @: q$Revision: 32208 $ =~ m/(\d+)/g] => 32208
                  q[$FOO::VERSION = '1.10';]  => '1.10'
                  q[*FOO::VERSION = \'1.11';] => '1.11'
                  '$VERSION = 0.02'   => 0.02
                  '$VERSION = 0.0'    => 0.0
                  '$VERSION = -1.0'   => -1.0
                  '$VERSION = undef'  => 'undef'
                  '$wibble  = 1.0'    => 'undef'
                  q[my $VERSION = '1.01']         => 'undef'
                  q[local $VERISON = '1.02']      => 'undef'
                  q[local $FOO::VERSION = '1.30'] => 'undef'
                  q[our $VERSION = '1.23';]       => '1.23'
    

plan: tests => (2 * nkeys %versions) + 8

while( my(@: ?$code, ?$expect) =(@:  each %versions) )
    is:  (parse_version_string: $code), $expect, $code 


for my $v (@: @: q[use version; $VERSION = v1.2.3;], v1.2.3
              (@: q[$VERSION = v1.2.3], v1.2.3))
    is:  (parse_version_string: $v[0]), $v[1]->stringify, $v[0]


sub parse_version_string
    my $code = shift

    (open: my $fh, ">", "VERSION.tmp") || die: $^OS_ERROR
    print: $fh, "$code\n"
    close $fh

    $_ = 'foo'
    my $version = MM->parse_version: 'VERSION.tmp'
    is:  $_, 'foo', '$_ not leaked by parse_version' 

    unlink: "VERSION.tmp"

    return $version



# This is a specific test to see if a version subroutine in the $VERSION
# declaration confuses later calls to the version class.
# [rt.cpan.org 30747]
do
    is: (parse_version_string: q[ $VERSION = '1.00'; sub version { $VERSION } ])
        '1.00'
    is: (parse_version_string: q[ use version; $VERSION = version->new: "1.2.3" ])
        (qv: "1.2.3")->stringify

