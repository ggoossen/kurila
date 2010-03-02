#!/usr/bin/perl -w



use Test::More tests => 14
use Scalar::Util < qw(looks_like_number)

foreach my $num (qw(1 -1 +1 1.0 +1.0 -1.0 -1.0e-12))
    ok: (looks_like_number: $num), "'$num'"


is: ! !(looks_like_number: "Inf"),	    1,	'Inf'
is: ! !(looks_like_number: "Infinity"), 1,	'Infinity'
is: ! !(looks_like_number: "NaN"),	    1,	'NaN'
is: ! !(looks_like_number: "foo"),	    '',			'foo'
is: ! !(looks_like_number: undef),	    '',           	'undef'
is: ! !(looks_like_number: \$%),	    '',			'HASH Ref'
is: ! !(looks_like_number: \$@),	    '',			'ARRAY Ref'

# We should copy some of perl core tests like t/base/num.t here
