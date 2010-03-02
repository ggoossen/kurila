#!./perl -w

BEGIN 
    require "./test.pl"


plan: 5

my $x = %: 'aap', 'noot', 'mies', 'teun'
is: (join: '*', (sort: (keys: $x))), 'aap*mies'
$x = $%
is: (join: '*', (keys: $x)), ''
is: (keys: undef), undef
sub foo { return (%: 'aap', 'noot'); }
is: (join: '*', (keys: (foo: ))), 'aap'

dies_like: 
  sub (@< @_) { (keys: "teun") }
  qr/keys expected a hash but got PLAINVALUE/
  'keys on plain value'

