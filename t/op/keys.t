#!./perl -w

BEGIN {
    require "./test.pl";
}

plan 5;

my $x = %('aap', 'noot', 'mies', 'teun');
is join('*', sort keys($x)), 'aap*mies';
$x = %();
is join('*', keys($x)), '';
is join('*', keys(undef)), '';
sub foo { return %('aap', 'noot'); }
is join('*', keys(foo)), 'aap';

dies_like 
  sub { keys("teun") },
  qr/keys expected a hash but got PLAINVALUE/,
  'keys on plain value';

