#!./perl

BEGIN { require "./test.pl" }

plan tests => 3;

our @a = @(1,2,3);
my $cnt1 = unshift(@a,0);

is(join(' ', @a), '0 1 2 3');
my $cnt2 = unshift(@a,3,2,1);
is(join(' ', @a), '3 2 1 0 1 2 3');

dies_like( { unshift($: undef) }, qr/Can't unshift a UNDEF/ );
