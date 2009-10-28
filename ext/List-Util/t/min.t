#!./perl


use Test::More tests => 5
use List::Util < qw(min)

my $v

ok: exists &min, 'defined'

$v = min: 9
is: $v, 9, 'single arg'

$v = min: 1,2
is: $v, 1, '2-arg ordered'

$v = min: 2,1
is: $v, 1, '2-arg reverse ordered'

my @a = map: { (rand: ) }, 1 .. 20
my @b = sort: { $a <+> $b }, @a
$v = min: < @a
is: $v, @b[0], '20-arg random order'
