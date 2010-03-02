#!./perl

use Config

use Test::More tests => 20

use Scalar::Util < qw(reftype)
our ($t, $y, $x)
use Symbol < qw(gensym)

my @test = @:
 \(@:  undef, 1,		'number'	)
 \(@:  undef, 'A',		'string'	)
 \(@:  HASH   => \$%,	'HASH ref'	)
 \(@:  ARRAY  => \$@,	'ARRAY ref'	)
 \(@:  SCALAR => \$t,	'SCALAR ref'	)
 \(@:  REF    => \(\$t),	'REF ref'	)
 \(@:  GLOB   => (gensym: ),	'GLOB ref'	)
 \(@:  CODE   => \ sub {},	'CODE ref'	)
    # \@( IO => *STDIN{IO} ) the internal sv_reftype returns UNKNOWN
    

foreach my $test (@test)
    my(@: $type,$what, $n) =  $test->@

    is:  (reftype: $what), $type, $n
    next unless ref: $what

    bless: $what, "ABC"
    is:  (reftype: $what), $type, $n

    bless: $what, "0"
    is:  (reftype: $what), $type, $n


package MyTie

sub TIEHANDLE { (bless: \$%) }
sub DESTROY {}

