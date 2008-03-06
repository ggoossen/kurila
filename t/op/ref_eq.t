#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 6;

my $x = 1;
my $y = 1;
my $rx1 = \$x;
my $rx2 = \$x;

is( \$x \== \$x, 1, "\== true");
is( \$x \== \$y, '', "\== false");
is( [] \== [], '', "\== using anonymous refs");

is( $rx1 \== $rx2, 1, "ref are vars");
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

is( 1 \== 2, '', "\== on non-refs");
is( 1 \== 1, '', "\== on identical non-refs");
