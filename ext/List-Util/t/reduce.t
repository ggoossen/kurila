#!./perl

use Config

use List::Util < qw(reduce min)
use Test::More
plan: tests => 19

my $v = reduce: {}

is:  $v,	undef,	'no args'

$v = reduce: { $a / $b }, 756,3,7,4
is:  $v,	9,	'4-arg divide'

$v = reduce: { $a / $b }, 6
is:  $v,	6,	'one arg'

my @a = map: { rand }, 0 .. 20
$v = reduce: { $a +< $b ?? $a !! $b }, < @a
is:  $v,	(min: < @a),	'min'

@a = map: { (pack: "C", (int: (rand: 256))) }, 0 .. 20
$v = reduce: { $a . $b }, < @a
is:  $v,	(join: "", @a),	'concat'

sub add($aa, $bb)
    return $aa + $bb


$v = reduce: { my $t="$a $b\n"; 0+(add: $a, $b) }, 3, 2, 1
is:  $v,	6,	'call sub'

# Check that try{} inside the block works correctly
$v = reduce: { try { (die: )}; $a + $b }, 0,1,2,3,4
is:  $v,	10,	'use eval{}'

$v = !defined try { (reduce: { die: if $b +> 2; $a + $b }, 0,1,2,3,4) }
ok: $v, 'die'

sub add2 { $a + $b }

$v = reduce: \&add2, 1,2,3
is:  $v,	6,	'sub reference'

$v = reduce: { (add2: ) }, 3,4,5
is:  $v, 12,	'call sub'


$v = reduce: { eval "$a + $b" }, 1,2,3
is:  $v, 6, 'eval string'

$a = 8; $b = 9
$v = reduce: { $a * $b }, 1,2,3
is:  $a, 8, 'restore $a'
is:  $b, 9, 'restore $b'

# Can we leave the sub with 'return'?
$v = reduce: {return $a+$b}, 2,4,6
is: $v, 12, 'return'

# ... even in a loop?
$v = reduce: {while(1) {return $a+$b} }, 2,4,6
is: $v, 12, 'return from loop'

# Does it work from another package?
do { package Foo;
    $a = $b;
    main::is: ((List::Util::reduce:  {$a*$b}, ( <1..4))), 24, 'other package';
}

# Redefining an active sub should not fail, but whether the
# redefinition takes effect immediately depends on whether we're
# running the Perl or XS implementation.

sub self_updating { local $^WARNING = undef; *self_updating = sub (@< @_){1} ;1 }
try { $v = (reduce: \&self_updating, 1,2); }
is: $^EVAL_ERROR, '', 'redefine self'

do { my $failed = 0;

    sub rec { my $n = shift;
        if (!(defined: $n))  # No arg means we're being called by reduce()
            return 1 
        if ($n+<5) { rec: $n+1; }
        else { $v = (reduce: \&rec, 1,2); }
        $failed = 1 if !defined $n;
    }

    rec: 1;
    ok: !$failed, 'from active sub';
}

# Calling a sub from reduce should leave its refcount unchanged.
:SKIP do
    skip: "No Internals::SvREFCNT", 1 if !exists &Internals::SvREFCNT
    sub mult {$a*$b}
    my $refcnt = Internals::SvREFCNT: \&mult
    $v = reduce: \&mult, < 1..6
    is: (Internals::SvREFCNT: \&mult), $refcnt, "Refcount unchanged"

