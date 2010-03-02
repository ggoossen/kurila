#!./perl -w

BEGIN 
    require './test.pl'


plan:  tests => 1 

$_ = "foo"
for (qw[a]) { }
$_ = "bar"
is:  $_, "bar" 
