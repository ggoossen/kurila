#!./perl

require './test.pl'
plan:  tests => 10 

# test various operations on @_

sub new1 { (bless: \@_) }
do
    my $x = new1: "x"
    my $y = new1: "y"
    is: (join: ' ', $y->@),"y"
    is: (join: ' ', $x->@),"x"


sub new2 { (splice: @_, 0, 0, "a", "b", "c"); return \@_ }
do
    my $x = new2: "x"
    my $y = new2: "y"
    is: ((join: ' ',$x->@)),"a b c x"
    is: ((join: ' ',$y->@)),"a b c y"


# see if POPSUB gets to see the right pad across a dounwind() with
# a reified @_

sub methimpl
    my $refarg = \@_
    die:  "got: $((join: ' ',@_))\n" 


sub method
    methimpl:  < @_ 


sub trymethod
    try { (method: 'foo', 'bar'); }
    print: $^STDOUT, "# $^EVAL_ERROR->{?description}" if $^EVAL_ERROR


for (1..5) { (trymethod: ) }
(pass: )

# bug #21542 local @_[0] causes reify problems and coredumps

sub local1 { local @_[0] }
my $foo = 'foo'; (local1: $foo); local1: $foo
print: $^STDOUT, "got [$foo], expected [foo]\nnot " if $foo ne 'foo'
(pass: )

sub local2 { local @_[?0]; last L }
:L do { (local2: )}
(pass: )

# [perl #28032] delete $_[0] was freeing things too early

do
    my $flag = 0
    sub X::DESTROY { $flag = 1 }
    sub f
        delete @_[0]
        ok: !$flag, 'delete $_[0] : in f'
    
    do
        my $x = bless: \$@, 'X'
        f: $x
        ok: !$flag, 'delete $_[0] : after f'
    
    ok: $flag, 'delete $_[0] : outside block'
