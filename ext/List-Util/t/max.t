#!./perl


use Test::More tests => 5
use List::Util < qw(max)

my $v

ok: exists &max, 'defined'

$v = max: 1
is: $v, 1, 'single arg'

$v = max: 1,2
is: $v, 2, '2-arg ordered'

$v = max: 2,1
is: $v, 2, '2-arg reverse ordered'

my @a = map: { (rand: ) }, 1 .. 20
my @b = sort: { $a <+> $b }, @a
$v = max: < @a
is: $v, @b[-1], '20-arg random order'
