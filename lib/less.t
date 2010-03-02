#!./perl -w

use Test::More tests => 5

use less ()

is_deeply: \less->of, \$@, 'more please'
use less
is_deeply: \less->of, \(@: 'please'),'less please'
no less
is_deeply: \less->of,\$@,'more please'

use less 'random acts'
is_deeply: (@:  < (sort: less->of)), qw'acts random'

is: scalar (less->of: 'random'),1,'less random'
