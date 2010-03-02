#!./perl

BEGIN
    require './test.pl'

plan: tests => 22

our ($x, $y)

# using { }
$x = "old"
$y = "old"
do { local $y = "new"; $x = "new" }
is:  $x, "new" 
is:  $y, "old" 

# same using indenting
$x = "old"
$y = "old"
do
   local $y = "new"
   $x = "new"

is:  $x, "new" 
is:  $y, "old" 

# same using indenting terminated by end-of-string
$x = "old"
$y = "old"
eval q[do
   local $y = "new"
   $x = "new"]
die: if $^EVAL_ERROR
is:  $x, "new" 
is:  $y, "old" 

# nesting
(@: $x, $y) = qw[old old]
do
    do
        local $x = "new"
    local $y = "new"
    
is: $x, "old"
is: $y, "old"

# ending multiple nested blocks at once
(@: $x, $y) = qw[old old]
do
    local $y = "new"
    do
        local $x = "new"
    
is: $x, "old"
is: $y, "old"

# @: with layout
$x = @: "aap"
        "noot"

is: (join: "*", $x), q[aap*noot]

# empty @:
$x = @:
is: (join: "*", $x), q[]

# empty @: with pod
$x = @:
=pod
=cut
is: (join: "*", $x), q[]

# @: terminated by an "and"
$x = @: 'aap' and
    $y = 1

is: (join: "*", $x), q[aap]
is: $y, 1

# @(:
$x = @(: 'aap',
         'noot' )
is:  (join: "*", $x), "aap*noot"

# s/// seperared by statement end
eval_dies_like: <<'EOE', qr/statement end found where string delimeter expected/
do
    s(foo)
    {bar}g
EOE

# block divided using pod
do
    my $tmpvar = "aap"
=head1 TEST
=cut
    is: $tmpvar, "aap"

eval_dies_like: <<'EOE', qr/syntax error .* near "elsif/
if ($a)
    1
    elsif { 2 }
EOE

eval_dies_like: <<'EOE', qr/wrong matching parens .* at end of line/
if ($a)
    1
    $a[
EOE


# detection of newlines with something that has lookahead

do
    local our $TODO = "Proper error message"
    eval_dies_like: <<'EOE', qr/Not enough arguments for bless/
bless
(1, 2)
EOE

do
    local our $TODO = "Gracefull recovery after missing ("
    eval_dies_like: <<'EOE', qr/XXXX/
do
    (defined: $a

=pod

=cut

1
EOE
