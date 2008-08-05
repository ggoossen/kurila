#!perl -w

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't';
        @INC = @('../lib', 'lib');
    }
}

use lib 't/lib';
use Test::More tests => 1;
use Dev::Null;

my $str = "";
open my $dummy_fh, '>>', \$str or die;
*STDOUT = *$dummy_fh{IO};

print "not ok 1\n";     # this should not print.
pass 'STDOUT can be mucked with';

