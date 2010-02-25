#!./perl

use Config

use Test::More tests => 6

use List::Util < qw(shuffle)

my @r

@r = (shuffle: )
ok:  !nelems @r,	'no args'

@r = shuffle: 9
is:  0+nelems @r,	1,	'1 in 1 out'
is:  @r[0],	9,	'one arg'

my @in = 1..100
@r = shuffle: < @in
is:  0+nelems @r,	0+nelems @in,	'arg count'

isnt:  "$((join: ' ',@r))",	"$((join: ' ',@in))",	'result different to args'

my @s = sort: { $a <+> $b }, @r
is:  "$((join: ' ',@in))",	"$((join: ' ',@s))",	'values'
