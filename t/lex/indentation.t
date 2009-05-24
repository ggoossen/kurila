#!./perl

BEGIN 
    require './test.pl'


plan tests => 10

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
@: $x, $y = qw[old old]
do
do
    local $x = "new"
 local $y = "new"

is($x, "old")
is($y, "old")

# ending multiple nested blocks at once
@: $x, $y = qw[old old]
do
local $y = "new"
 do
    local $x = "new"

is($x, "old")
is($y, "old")
