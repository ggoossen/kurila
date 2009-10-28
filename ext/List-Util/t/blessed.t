#!./perl


use Test::More tests => 8
use Scalar::Util < qw(blessed)
our ($t, $x)

ok: !(blessed: undef),	'undef is not blessed'
ok: !(blessed: 1),		'Numbers are not blessed'
ok: !(blessed: 'A'),	'Strings are not blessed'
ok: !(blessed: \$%),	'Unblessed HASH-ref'
ok: !(blessed: \$@),	'Unblessed ARRAY-ref'
ok: !(blessed: \$t),	'Unblessed SCALAR-ref'

$x = bless: \$@, "ABC"
is: (blessed: $x), "ABC",	'blessed ARRAY-ref'

$x = bless: \$%, "DEF"
is: (blessed: $x), "DEF",	'blessed HASH-ref'
