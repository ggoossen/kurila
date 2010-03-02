#!./perl

BEGIN { require './test.pl'; }

plan: 36

sub foo($x)
    return $x


is:  (foo: 3), 3 

sub recur($x)
    if ($x eq 'depth2')
        return $x
    
    my $v = recur: 'depth2'
    return @: $x, $v


my (@: $r1, $r2) = recur: 'depth1'
is: $r1, 'depth1'
is: $r2, 'depth2'

sub emptyproto()
    return 'foo'


is:  (emptyproto: ), 'foo' 
is:  (emptyproto: ). 'bar', 'foobar' 

BEGIN 
    my $x = 11
    *baz = sub () { $x }


is:  (baz: )+ 1, 12 

my $sub = sub ($x) { ++$x }
is: ($sub->& <: 4), 5

sub threeargs($x, $y, $z)
    return 1

dies_like:  {( &threeargs->& < 1, 2)}
            qr/Not enough arguments for main::threeargs/
            "runtime min argument check" 
dies_like:  {( &threeargs->& < 1, 2, 3, 4)}
            qr/Too many arguments for main::threeargs/
            "runtime max argument check" 
eval_dies_like:  'sub { main::threeargs(1, 2) }'
                 qr/Not enough arguments for main::threeargs/
                 "compile-time min argument check" 
eval_dies_like:  'sub { threeargs(1, 2, 3, 4) }'
                 qr/Too many arguments for main::threeargs/
                 "compile-time min argument check" 

my $args
sub assign($x, $y = $z)
    $args = "$x,$y=$z"
    return $args


is:  ((assign: "aap", "noot") = "mies"), "aap,noot=mies" 
is:  $args, "aap,noot=mies" 

do
    # assignment inside another assignment
    $args = undef
    (@: my $before, (assign: "aap", "noot"), my $after) = qw[before mies after]
    is:  $args, "aap,noot=mies" 
    is:  $before, "before" 
    is:  $after, "after" 


do
    # assignee prototype checking
    dies_like:  { (assign: "aap", "noot") }
                qr/main::assign must be an assignee/ 
    dies_like:  { (threeargs: "aap", "noot", "mies") = "wim" }
                qr/main::threeargs can not be an assignee/ 


sub opt_assign($x, $y ?= $z)
    $args = "$x,$y=$((dump::view: $z))"
    return $args


is:  ((opt_assign: "aap", "noot") = "mies"), "aap,noot='mies'" 
is:  (opt_assign: "aap", "noot"), 'aap,noot=undef' 

is:  ((opt_assign: "aap", "noot") .= "mies"), "aap,noot='aap,noot=undefmies'" 
is:  $args, "aap,noot='aap,noot=undefmies'" 

my $var

sub varsub(?= $x)
    if ($^is_assignment)
        $var = $x
    
    return $var


is:  (join: "*", ((varsub: )= qw(aap noot mies))), "aap*noot*mies" 
is:  (join: "*", $var), "aap*noot*mies" 
is:  (push: (varsub: ), "wim"), 4 
is:  (join: "*", $var), "aap*noot*mies*wim" 

(varsub: )= "aap"
do
    local (varsub: )
    (varsub: )= "noot"
    is: (varsub: ), "noot"

is: (varsub: ), "aap"
do
    local (varsub: ).= "mies"
    is: (varsub: ), "aapmies"

is: (varsub: ), "aap"

do
    local (varsub: )= "mies"
    is: (varsub: ), "mies"

is: (varsub: ), "aap"

my $varassign
sub varargsassign(@< $x ?= $y)
    return $varassign = (join: "*", $x) . "=$y"


is:  ((varargsassign: "aap", "noot") = "mies")
     "aap*noot=mies" 

(@: my $before, (varargsassign: "wim", "zus"), my $after) = @: "before", "jet", "after"
is:  $varassign, "wim*zus=jet" 
is:  $before, "before" 
is:  $after, "after" 
