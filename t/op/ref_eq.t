#!./perl

BEGIN 
    require './test.pl'


plan: tests => 14

my $x = 1
my $y = 1
my $rx1 = \$x
my $rx2 = \$x

is:  \$x \== \$x, 1, "\== true"
is:  \$x \== \$y, '', "\== false"
is:  \$@ \== \$@, '', "\== using anonymous refs"

is:  $rx1 \== $rx2, 1, "ref are vars"
# is( $rx1 \==\ $rx2, 1, "ref are vars");
# is( $rx1 ref_eq $rx2, 1, "ref are vars");
# is( $rx1 req $rx2, 1, "ref are vars");
# is( $rx1 =\= $rx2, 1, "ref are vars");
# is( $rx1 *== $rx2, 1, "ref are vars");
# is( $rx1 *==* $rx2, 1, "ref are vars");
# is( $rx1 ==\ $rx2, 1, "ref are vars");
# is( $rx1 |==| $rx2, 1, "ref are vars");
# is( $rx1 |== $rx2, 1, "ref are vars");
# is( $rx1 +==+ $rx2, 1, "ref are vars");
# is( $rx1 +== $rx2, 1, "ref are vars");

dies_like:  sub (@< @_) { $x \== \$y }, qr/Not a reference/ 
dies_like:  sub (@< @_) { \$x \== $y }, qr/Not a reference/ 
dies_like:  sub (@< @_) { $x \== $y }, qr/Not a reference/ 


## ref_ne

is:  \$x \!= \$x, '', "\!= true"
is:  \$x \!= \$y, 1, "\!= false"
is:  \$@ \!= \$@, 1, "\!= using anonymous refs"

is:  $rx1 \!= $rx2, '', "ref are vars"
# is( $rx1 \==\ $rx2, 1, "ref are vars");
# is( $rx1 ref_eq $rx2, 1, "ref are vars");
# is( $rx1 req $rx2, 1, "ref are vars");
# is( $rx1 =\= $rx2, 1, "ref are vars");
# is( $rx1 *== $rx2, 1, "ref are vars");
# is( $rx1 *==* $rx2, 1, "ref are vars");
# is( $rx1 ==\ $rx2, 1, "ref are vars");
# is( $rx1 |==| $rx2, 1, "ref are vars");
# is( $rx1 |== $rx2, 1, "ref are vars");
# is( $rx1 +==+ $rx2, 1, "ref are vars");
# is( $rx1 +== $rx2, 1, "ref are vars");

dies_like:  sub (@< @_) { $x \!= \$y }, qr/Not a reference/ 
dies_like:  sub (@< @_) { \$x \!= $y }, qr/Not a reference/ 
dies_like:  sub (@< @_) { $x \!= $y }, qr/Not a reference/ 
