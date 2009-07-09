#!./perl

BEGIN 
    require './test.pl'

    plan tests => 18

our ($x, $y)

# using { }
$x = "old"
$y = "old"
do { local $y = "new"; $x = "new" }
is( $x, "new" )
is( $y, "old" )

# same using indenting
$x = "old"
$y = "old"
do
   local $y = "new"
    $x = "new"
    
is( $x, "new" )
is( $y, "old" )

# same using indenting terminated by end-of-string
$x = "old"
$y = "old"
eval q[do
   local $y = "new"
   $x = "new"]
die if $^EVAL_ERROR
is( $x, "new" )
is( $y, "old" )

# nesting
(@: $x, $y) = qw[old old]
do
    do
        local $x = "new"
    local $y = "new"
    
is($x, "old")
is($y, "old")

# ending multiple nested blocks at once
(@: $x, $y) = qw[old old]
do
    local $y = "new"
    do
        local $x = "new"
    
is($x, "old")
is($y, "old")

# @: with layout
$x = @: "aap"
        "noot"
            
is(join("*", $x), q[aap*noot])

# empty @:
$x = $@
is(join("*", $x), q[])

# @: terminated by an "and"
$x = $@or
    $y = 1

is(join("*", $x), q[])
is($y, 1)

# s/// seperared by statement end
eval_dies_like(<<'EOE', qr/statement end found where string delimeter expected/)
do
    s(foo)
    {bar}g
EOE

# block divided using pod
do
    my $tmpvar = "aap"
=head1 TEST
=cut
    is $tmpvar, "aap"
    
eval_dies_like(<<'EOE', qr/syntax error .* near "elsif/)
if ($a)
    1
    elsif { 2 }
EOE

eval_dies_like(<<'EOE', qr/wrong matching parens .* at end of line/)
if ($a)
    1
    $a[
EOE
