#!./perl

use Config

use Scalar::Util < qw(readonly)
use Test::More tests => 10

ok:  (readonly: 1),	'number constant'

my $var = 2

ok:  !(readonly: $var),	'number variable'
is:  $var,	2,	'no change to number variable'

ok:  (readonly: "fred"),	'string constant'

$var = "fred"

ok:  !(readonly: $var),	'string variable'
is:  $var,	'fred',	'no change to string variable'

$var = \2

ok:  !(readonly: $var),	'reference to constant'
ok:  (readonly: $var->$),	'de-reference to constant'

sub tryreadonly($v)
    return readonly: $v->$


$var = 123
ok:  (tryreadonly: \"abc"), 'reference a constant in a sub'
ok:  !(tryreadonly: \$var), 'reference a non-constant in a sub'
