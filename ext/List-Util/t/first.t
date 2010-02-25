#!./perl

use List::Util < qw(first)
use Test::More
plan: tests => 12
my $v

ok: exists &first,	'defined'

$v = first: { 8 == ($_ - 1) }, 9,4,5,6
is: $v, 9, 'one more than 8'

$v = first: { 0 }, 1,2,3,4
is: $v, undef, 'none match'

$v = first: { 0 }
is: $v, undef, 'no args'

$v = first: { ($_->[1] cmp "e") +<= 0 and ("e" cmp $_->[2]) +<= 0 }
            \qw(a b c), \qw(d e f), \qw(g h i)
is_deeply: $v, \qw(d e f), 'reference args'

# Check that try{} inside the block works correctly
my $i = 0
$v = first: { try { (die: )}; (@: ($i == 5), ($i = $_))[0] }, 0,1,2,3,4,5,5
is: $v, 5, 'use of eval'

$v = try { (first: { die: if $_ }, 0,0,1) }
is: $v, undef, 'use of die'

# Can we leave the sub with 'return'?
$v = first: {return ($_+>6)}, 2,4,6,12
is: $v, 12, 'return'

# ... even in a loop?
$v = first: {while(1) {return  ($_+>6)} }, 2,4,6,12
is: $v, 12, 'return from loop'

# Does it work from another package?
do { package Foo;
    main::is: (List::Util::first: {$_+>4},( <1..4,24)), 24, 'other package';
}

# Redefining an active sub should not fail, but whether the
# redefinition takes effect immediately depends on whether we're
# running the Perl or XS implementation.

sub self_updating { local $^WARNING = undef; *self_updating = sub (@< @_){1} ;1}
try { $v = (first: \&self_updating, 1,2); }
is: $^EVAL_ERROR, '', 'redefine self'

# Calling a sub from first should leave its refcount unchanged.
:SKIP do
    skip: "No Internals::SvREFCNT", 1 if !exists &Internals::SvREFCNT
    sub huge {$_+>1E6}
    my $refcnt = Internals::SvREFCNT: \&huge
    $v = first: \&huge, < 1..6
    is: (Internals::SvREFCNT: \&huge), $refcnt, "Refcount unchanged"

