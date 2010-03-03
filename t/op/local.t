#!./perl

BEGIN 
    require './test.pl'

plan: tests => 73

our (@c, @b, @a, $a, $b, $c, $d, $e, $x, $y, %d, %h, $m)

my $list_assignment_supported = 1

#mg.c says list assignment not supported on VMS, EPOC, and SYMBIAN.
$list_assignment_supported = 0 if ($^OS_NAME eq 'VMS')


sub foo
    local(@: $a, $b) =  @_
    local($c, $d)
    $c = "c 3"
    $d = "d 4"
    do { local (@: $a,$c) = (@: "a 9", "c 10"); (@: $x, $y) = (@: $a, $c); }
    is: $a, "a 1"
    is: $b, "b 2"
    return @: $c, $d


$a = "a 5"
$b = "b 6"
$c = "c 7"
$d = "d 8"

my @res
@res =  foo: "a 1","b 2"
is: @res[0], "c 3"
is: @res[1], "d 4"

is: $a, "a 5"
is: $b, "b 6"
is: $c, "c 7"
is: $d, "d 8"
is: $x, "a 9"
is: $y, "c 10"

# same thing, only with arrays and associative arrays

sub foo2
    local(@: $a, @b) = @: shift, @_
    local(@c, %d)
    @c = @:  "c 3" 
    %d{+''} = "d 4"
    do { local(@: $a, @c) = (@: "a 19", (@: "c 20")); (@: $x, $y) = (@: $a, < @c); }
    is: $a, "a 1"
    is: "$((join: ' ',@b))", "b 2"
    return @: @c[0], %d{?''}


$a = "a 5"
@b = @:  "b 6" 
@c = @:  "c 7" 
%d{+''} = "d 8"

@res = foo2: "a 1","b 2"
is: @res[0], "c 3"
is: @res[1], "d 4"

is: $a, "a 5"
is: "$((join: ' ',@b))", "b 6"
is: @c[0], "c 7"
is: %d{?''}, "d 8"
is: $x, "a 19"
is: $y, "c 20"


do
    local our $TODO = "fix localization through reference"
    eval 'local($$e)'
    like: $^EVAL_ERROR && $^EVAL_ERROR->{?description}, qr/Can't localize through a reference/

    eval '$e = \$@; local(@$e)'
    like: $^EVAL_ERROR && $^EVAL_ERROR->{?description}, qr/Can't localize through a reference/

    eval '$e = \$%; local(%$e)'
    like: $^EVAL_ERROR && $^EVAL_ERROR->{?description}, qr/Can't localize through a reference/


# Array and hash elements

@a = @: 'a', 'b', 'c'
do
    local(@a[1]) = 'foo'
    local(@a[2]) = @a[2]
    is: @a[1], 'foo'
    is: @a[2], 'c'
    undef @a

is: @a[1], 'b'
is: @a[2], 'c'
ok: !defined @a[0]

@a = @: 'a', 'b', 'c'
do
    local(@a[1]) = "X"
    shift @a

is: @a[0].@a[1], "Xb"
do
    my $d = "$((join: ' ',@a))"
    local @a = @a
    is: "$((join: ' ',@a))", $d


%h = %: 'a' => 1, 'b' => 2, 'c' => 3
do
    local(%h{+'a'}) = 'foo'
    local(%h{+'b'}) = %h{?'b'}
    is: %h{?'a'}, 'foo'
    is: %h{?'b'}, 2
    local(%h{'c'})
    delete %h{'c'}

is: %h{?'a'}, 1
is: %h{?'b'}, 2
do
    my $d = join: "\n", (map: { "$_=>%h{?$_}" }, (sort: keys %h))
    local %h = %:  < %h 
    is: (join: "\n", (map: { "$_=>%h{?$_}" }, (sort: keys %h))), $d

is: %h{?'c'}, 3

# check for scope leakage
$a = 'outer'
if (1) { local $a = 'inner' }
is: $a, 'outer'

do
    package TH
    sub TIEHASH { (bless: \$%, @_[0]) }
    sub STORE { (print: $^STDOUT, "# STORE [$((dump::view: \@_))]\n"); @_[0]->{+@_[1]} = @_[2] }
    sub FETCH { my $v = @_[0]->{?@_[1]}; (print: $^STDOUT, "# FETCH [$((dump::view: \@_))=$v]\n"); $v }
    sub EXISTS { (print: $^STDOUT, "# EXISTS [$((dump::view: \@_))]\n"); exists @_[0]->{@_[1]}; }
    sub DELETE { (print: $^STDOUT, "# DELETE [$((dump::view: \@_))]\n"); delete @_[0]->{@_[1]}; }
    sub CLEAR { (print: $^STDOUT, "# CLEAR [$((dump::view: < @_))]\n"); @_[0]->% = $%; }
    sub FIRSTKEY { (print: $^STDOUT, "# FIRSTKEY [$((join: ' ',@_))]\n"); keys @_[0]->%; each @_[0]->% }
    sub NEXTKEY { (print: $^STDOUT, "# NEXTKEY [$((join: ' ',@_))]\n"); each @_[0]->% }


@a = @: 'a', 'b', 'c'
do
    local(@a[1]) = "X"
    shift @a

is: @a[0].@a[1], "Xb"

# does implicit localization in foreach skip magic?

$_ = "o 0,o 1,"
my $iter = 0
while (m/(o.+?),/gc)
    is: $1, "o $iter"
    foreach (1..1) { $iter++ }
    if ($iter +> 2) { fail: "endless loop"; last; }


do
    # BUG 20001205.22
    my %x
    %x{+a} = 1
    do { local %x{+b} = 1; }
    ok: ! exists %x{b}
    do { local %x{[(@: 'c','d','e')]} =$@; }
    ok: ! exists %x{c}


# local() and readonly magic variables

try { local $1 = 1 }
like: $^EVAL_ERROR->{?description}, qr/Modification of a read-only value attempted/

# sub localisation
do
    package Other

    sub f1 { "f1" }
    sub f2 { "f2" }

    no warnings "redefine"
    do
        local *f1 = sub()  { "g1" }
        main::ok: (&f1->& <: ) eq "g1", "localised sub via glob"
    
    main::ok: (&f1->& <: ) eq "f1", "localised sub restored"
    do
        main::eval_dies_like:  'local %Other::{+"f1"} = sub { "h1" }'
                               qr/can't localize a glob/, "localised sub via stash" 
    
    main::ok: (f1: ) eq "f1", "localised sub restored"
    main::ok: (f2: ) eq "f2", "localised sub restored"


# Localising unicode keys (bug #38815)
do
    my %h
    %h{+"\243"} = "pound"
    %h{+"\302\240"} = "octects"
    is: (nelems:  keys %h), 2
    do
        use utf8
        my $unicode = chr 256
        my $ambigous = "\240" . $unicode
        chop $ambigous
        local %h{+$unicode} = 256
        local %h{+$ambigous} = 160

        is: (nelems: keys %h), 4
        is: %h{?"\243"}, "pound"
        is: %h{?$unicode}, 256
        is: %h{?$ambigous}, 160
        is: %h{?"\302\240"}, "octects"
    
    is: (nelems: keys %h), 2
    is: %h{?"\243"}, "pound"
    is: %h{?"\302\240"}, "octects"


# And with slices
do
    my %h
    %h{+"\243"} = "pound"
    %h{+"\302\240"} = "octects"
    is: (nelems: keys %h), 2
    do
        use utf8
        my $unicode = chr 256
        my $ambigous = "\240" . $unicode
        chop $ambigous
        local %h{[(@: $unicode, $ambigous)]} = @: 256, 160

        is: nkeys %h, 4
        is: %h{?"\243"}, "pound"
        is: %h{?$unicode}, 256
        is: %h{?$ambigous}, 160
        is: %h{?"\302\240"}, "octects"
    
    is: nkeys %h, 2
    is: %h{?"\243"}, "pound"
    is: %h{?"\302\240"}, "octects"


# [perl #39012] localizing @_ element then shifting frees element too # soon

do
    my $x
    my $y = bless: \$@, 'X39012'
    sub X39012::DESTROY { $x++ }
    sub (@< @_) { local @_[0]; shift }->& <: $y
    ok: !$x,  '[perl #39012]'



# when localising a hash element, the key should be copied, not referenced

do
    my %h=%: 'k1' => 111
    my $k='k1'
    do
        local %h{+$k}=222

        is: %h{?'k1'},222
        $k='k2'
    
    ok: ! (exists: %h{'k2'})
    is: %h{?'k1'},111

do
    my %h=%: 'k1' => 111
    our $k = 'k1'  # try dynamic too
    do
        local %h{+$k}=222
        is: %h{?'k1'},222
        $k='k2'
    
    ok: ! (exists: %h{'k2'})
    is: %h{?'k1'},111

