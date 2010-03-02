#!./perl

use Config

use Test::More tests => 6

use List::Util < qw(sum)

my $v = (sum: )
is:  $v,	undef,	'no args'

$v = sum: 9
is:  $v, 9, 'one arg'

$v = sum: 1,2,3,4
is:  $v, 10, '4 args'

$v = sum: -1
is:  $v, -1, 'one -1'

my $x = -3

$v = sum: $x, 3
is:  $v, 0, 'variable arg'

$v = sum: -3.5,3
is:  $v, -0.5, 'real numbers'

