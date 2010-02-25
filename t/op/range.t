#!./perl

# Avoid using eq_array below as it uses .. internally.
require './test.pl'

use Config

plan: 101

our (@a, @foo, @bar, @bcd, $e, $x, @x, @b, @y)

is: (join: ':',1..5), '1:2:3:4:5'

@foo = @: 1,2,3,4,5,6,7,8,9
@foo[[2..4]] = @: 'c','d','e'

is: (join: ':', @foo[[@foo[0]..5]]), '2:c:d:e:6'

@bar[[2..4]] = @: 'c','d','e'
is: (join: ':', @bar[[1..5]]), ':c:d:e:'

:TODO do
    todo_skip: "slices in the middle of a list assignment", 1
    eval <<'TODO'; die: if $^EVAL_ERROR
   ($a, < @bcd[[0..2]],$e) = ('a','b','c','d','e');
   is(join(':', @($a, < @bcd[[0..2]],$e)), 'a:b:c:d:e');
TODO


$x = 0
for (1..100)
    $x += $_

is: $x, 5050

$x = 0
for ((@: (100, <2..99,1)))
    $x += $_

is: $x, 5050

eval_dies_like:  qq[ join('','a'..'z') ]
                 qr/Range must be numeric/ 

@x = '09' .. '08'
is: (join: ",", @x), ''

# same test with foreach (which is a separate implementation)
@y = $@
foreach ('09'..'08')
    push: @y, $_

is: (join: ",", @y), (join: ",", @x)

# check bounds
if ((config_value: 'ivsize') == 8)
    @a = eval "0x7ffffffffffffffe..0x7fffffffffffffff"
    $a = "9223372036854775806 9223372036854775807"
    @b = eval "-0x7fffffffffffffff..-0x7ffffffffffffffe"
    $b = "-9223372036854775807 -9223372036854775806"
else
    @a = eval "0x7ffffffe..0x7fffffff"
    $a = "2147483646 2147483647"
    @b = eval "-0x7fffffff..-0x7ffffffe"
    $b = "-2147483647 -2147483646"


is: "$((join: ' ',@a))", $a

is: "$((join: ' ',@b))", $b

# Should use magical autoinc only when both are strings
do
    my $scalar = "0"..-1
    is: (nelems: $scalar), 0

do
    my $fail = 0
    for my $x ("0"..-1)
        $fail++
    
    is: $fail, 0


# [#18165] Should allow "-4".."0", broken by #4730. (AMS 20021031)
is: (join: ":","-4".."0")     , "-4:-3:-2:-1:0"
is: (join: ":","-4".."-0")    , "-4:-3:-2:-1:0"
is: (join: ":","-4\n".."0\n") , "-4:-3:-2:-1:0"
is: (join: ":","-4\n".."-0\n"), "-4:-3:-2:-1:0"

# undef should be treated as 0 for numerical range
is: (join: ":",undef..2), '0:1:2'
is: (join: ":",-2..undef), '-2:-1:0'
is: (join: ":",undef..'2'), '0:1:2'
is: (join: ":",'-2'..undef), '-2:-1:0'

# undef..undef used to segfault
is: (join: ":", (map: { "[$_]" }, undef..undef)), '[0]'

# also test undef in foreach loops
@foo= $@
for (undef..2)
    push: @foo, $_
is: (join: ":", @foo), '0:1:2'

@foo= $@
for (-2..undef)
    push: @foo, $_
is: (join: ":", @foo), '-2:-1:0'

@foo= $@
for (undef..'2')
    push: @foo, $_
is: (join: ":", @foo), '0:1:2'

@foo= $@
for ('-2'..undef)
    push: @foo, $_
is: (join: ":", @foo), '-2:-1:0'

@foo= $@
for (undef..undef)
    push: @foo, $_
is: (join: ":", (map: { "[$_]" }, @foo)), '[0]'

# again with magic
do
    my @a =1..3
    @foo= $@
    for (undef..(nelems @a)-1)
        push: @foo, $_
    is: (join: ":", @foo), '0:1:2'

do
    my @a = $@
    @foo= $@
    for ((nelems @a)-1..undef)
        push: @foo, $_
    is: (join: ":", @foo), '-1:0'

do
    local $1
    "2" =~ m/(.+)/
    @foo= $@
    for (undef..$1)
        push: @foo, $_
    is: (join: ":", @foo), '0:1:2'

do
    local $1
    "-2" =~ m/(.+)/
    @foo= $@
    for ($1..undef)
        push: @foo, $_
    is: (join: ":", @foo), '-2:-1:0'


# Test upper range limit
my $MAX_INT = ^~^0>>1

foreach my $ii (-3 .. 3)
    my ($first, $last)
    try {
        my $lim=0;
        for ($MAX_INT-10 .. $MAX_INT+$ii)
            if (! (defined: $first))
                $first = $_
            
            $last = $_
            last if ($lim++ +> 100)   # Protect against integer wrap
        
    }
    if ($ii +<= 0)
        ok: ! $^EVAL_ERROR, 'Upper bound accepted: ' . ($MAX_INT+$ii)
        is: $first, $MAX_INT-10, 'Lower bound okay'
        is: $last, $MAX_INT+$ii, 'Upper bound okay'
    else
        ok: $^EVAL_ERROR, 'Upper bound rejected: ' . ($MAX_INT+$ii)
    


foreach my $ii (-3 .. 3)
    my ($first, $last)
    try {
        my $lim=0;
        for ($MAX_INT+$ii .. $MAX_INT)
            if (! (defined: $first))
                $first = $_
            
            $last = $_
            last if ($lim++ +> 100)
        
    }
    if ($ii +<= 0)
        ok: ! $^EVAL_ERROR, 'Lower bound accepted: ' . ($MAX_INT+$ii)
        is: $first, $MAX_INT+$ii, 'Lower bound okay'
        is: $last, $MAX_INT, 'Upper bound okay'
    else
        ok: $^EVAL_ERROR, 'Lower bound rejected: ' . ($MAX_INT+$ii)
    


do
    my $first
    try {
        my $lim=0;
        for ($MAX_INT .. $MAX_INT-1)
            if (! (defined: $first))
                $first = $_
            
            last if ($lim++ +> 100)
        
    }
    ok: ! $^EVAL_ERROR, 'Range accepted'
    ok: ! (defined: $first), 'Range ineffectual'


foreach my $ii ((@: ^~^0, ^~^0+1, ^~^0+(^~^0>>4)))
    try {
        my $lim=0;
        for ($MAX_INT-10 .. $ii)
            last if ($lim++ +> 100)
        
    }
    ok: $^EVAL_ERROR, 'Upper bound rejected: ' . $ii


# Test lower range limit
my $MIN_INT = -1-$MAX_INT

if (! (config_value: 'd_nv_preserves_uv'))
    # $MIN_INT needs adjustment when IV won't fit into an NV
    my $NV = $MIN_INT - 1
    my $OFFSET = 1
    while (($NV + $OFFSET) == $MIN_INT)
        $OFFSET++
    
    $MIN_INT += $OFFSET


foreach my $ii (-3 .. 3)
    my ($first, $last)
    try {
        my $lim=0;
        for ($MIN_INT+$ii .. $MIN_INT+10)
            if (! (defined: $first))
                $first = $_
            
            $last = $_
            last if ($lim++ +> 100)
        
    }
    if ($ii +>= 0)
        ok: ! $^EVAL_ERROR, 'Lower bound accepted: ' . ($MIN_INT+$ii)
        is: $first, $MIN_INT+$ii, 'Lower bound okay'
        is: $last, $MIN_INT+10, 'Upper bound okay'
    else
        ok: $^EVAL_ERROR, 'Lower bound rejected: ' . ($MIN_INT+$ii)
    


foreach my $ii (-3 .. 3)
    my ($first, $last)
    try {
        my $lim=0;
        for ($MIN_INT .. $MIN_INT+$ii)
            if (! (defined: $first))
                $first = $_
            
            $last = $_
            last if ($lim++ +> 100)
        
    }
    if ($ii +>= 0)
        ok: ! $^EVAL_ERROR, 'Upper bound accepted: ' . ($MIN_INT+$ii)
        is: $first, $MIN_INT, 'Lower bound okay'
        is: $last, $MIN_INT+$ii, 'Upper bound okay'
    else
        ok: $^EVAL_ERROR, 'Upper bound rejected: ' . ($MIN_INT+$ii)
    


do
    my $first
    try {
        my $lim=0;
        for ($MIN_INT+1 .. $MIN_INT)
            if (! (defined: $first))
                $first = $_
            last if ($lim++ +> 100)
    }
    ok: ! $^EVAL_ERROR, 'Range accepted'
    ok: ! (defined: $first), 'Range ineffectual'


foreach my $ii ((@: ^~^0, ^~^0+1, ^~^0+(^~^0>>4)))
    try {
        my $lim=0;
        for (-$ii .. $MIN_INT+10)
            last if ($lim++ +> 100)
    }
    ok: $^EVAL_ERROR, 'Lower bound rejected: ' . -$ii

# EOF
