#!./perl -i.inplace
# note the extra switch, for the test below

use Test::More tests => 1;

use English < qw( -no_match_vars ) ;
use Config;
use Errno;

ok 1;
