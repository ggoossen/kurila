#!./perl

BEGIN { require "./test.pl"; }
plan:  tests => 25 

our ($foo, $Vec, $bar, $baz)
is: (vec: $foo,0,1), 0
is: (length: $foo), undef
vec: $foo,0,1,1
is: (length: $foo), 1
is: (unpack: 'C',$foo), 1
is: (vec: $foo,0,1), 1

is: (vec: $foo,20,1), 0
vec: $foo,20,1, 1
is: (vec: $foo,20,1), 1
is: (length: $foo), 3
is: (vec: $foo,1,8), 0
vec: $foo,1,8, 0xf1
is: (vec: $foo,1,8), 0xf1
is: ((unpack: 'C',(substr: $foo,1,1)) ^&^ 255), 0xf1
is: (vec: $foo,2,4), 1
is: (vec: $foo,3,4), 15
vec: $Vec, 0, 32, 0xbaddacab
is: $Vec, "\x[baddacab]"
is: (vec: $Vec, 0, 32), 3135089835

# ensure vec() handles numericalness correctly
$foo = $bar = $baz = 0
vec: ($foo = 0),0,1, 1
vec: ($bar = 0),1,1, 1
$baz = $foo ^|^ $bar
ok: $foo eq "1" && $foo == 1
ok: $bar eq "2" && $bar == 2
ok: "$foo $bar $baz" eq "1 2 3"

# error cases

dies_like:  sub (@< @_) { (vec: $foo, 0, 3) }, qr/^Illegal number of bits in vec/
dies_like:  sub (@< @_) { (vec: $foo, 0, 0) }, qr/^Illegal number of bits in vec/
dies_like:  sub (@< @_) { (vec: $foo, 0, -13) }, qr/^Illegal number of bits in vec/
dies_like:  sub (@< @_) { (vec: $foo, -1, 4, 2) }, qr/^Negative offset to vec in lvalue context/

ok: ! (vec: 'abcd', 7, 8)

# vec is independent of 'use utf8'
use utf8
our $x = "\x{263a}"  # == \xE2\x98\xBA
is: (vec: $x, 0, 8), 0xE2
no utf8

# A variation of [perl #20933]
do
    my $s = ""
    vec: $s, 0, 1, 0
    vec: $s, 1, 1, 1
    my @r
    for (@: 0, 1)
        @r[+$_] = \ vec: $s, $_, 1
    ok: !( @r[0]->$ != 0 ||  @r[1]->$ != 1)

