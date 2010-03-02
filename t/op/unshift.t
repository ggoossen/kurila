#!./perl

BEGIN { require "./test.pl" }

plan: tests => 5

our @a = @: 1,2,3
my $cnt1 = unshift: @a,0

is: (join: ' ', @a), '0 1 2 3'
my $cnt2 = unshift: @a,3,2,1
is: (join: ' ', @a), '3 2 1 0 1 2 3'

@a = undef
unshift: @a, 0
is: (join: ' ', @a), '0', "unshift on UNDEF"
dies_like:  { (unshift: %: aap => "noot") }, qr/Can't unshift a HASH/ 
dies_like:  { (unshift: undef, 0) }, qr/Modification of a read-only value attempted/ 
