#!./perl -w

BEGIN 
    require "./test.pl"


plan: 9

my $x = @: 'a', 'b', 'c'
is: (nelems: $x), 3
$x = $@
is: (nelems: $x), 0
$x = undef
is: (nelems: $x), 0, '$x=undef; nelems($x) == 0'
is: (nelems: undef), 0, 'nelems(undef) == 0'
is: (nelems: (@: 'aap', 'noot', 'mies')), 3, 'nelems(@(...))'

dies_like: 
  sub (@< @_) { (nelems: "teun") }
  qr/nelems expected an array or hash but got PLAINVALUE/
  'nelems on plain value'

$x = %:  'aap', 'noot', 'mies', 'teun' 
is: (nelems: $x), 4
$x = $%
is: (nelems: $x), 0
is: (nelems: (%:  'aap', 'noot' )), 2
