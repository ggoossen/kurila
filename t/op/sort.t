#!./perl

BEGIN 
    require './test.pl'

use warnings
plan:  tests => 54 

our (@a, @b)

# these shouldn't hang
do
    no warnings
    sort: { while(1) {}            }, @a
    sort: { while(1) { last; }     }, @a
    sort: { while(0) { last; }     }, @a

    # Change 26011: Re: A surprising segfault
    map: { (scalar: (sort:  $@)) }, @:  ('')x68


sub Backwards { ($a cmp $b) +< 0 ?? 1 !! ($a cmp $b) +> 0 ?? -1 !! 0 }
sub Backwards_stacked($x, $y) { ($x cmp $y) +< 0 ?? 1 !! ($x cmp $y) +> 0 ?? -1 !! 0 }
sub Backwards_other { ($a cmp $b) +< 0 ?? 1 !! ($a cmp $b) +> 0 ?? -1 !! 0 }

my $upperfirst = ('A' cmp 'a') +< 0

# Beware: in future this may become hairier because of possible
# collation complications: qw(A a B b) can be sorted at least as
# any of the following
#
#	A a B b
#	A B a b
#	a b A B
#	a A b B
#
# All the above orders make sense.
#
# That said, EBCDIC sorts all small letters first, as opposed
# to ASCII which sorts all big letters first.

our @harry = @: 'dog','cat','x','Cain','Abel'
our @george = @: 'gone','chased','yz','punished','Axed'

our $x = join: '', (sort: @harry)
our $expected = $upperfirst ?? 'AbelCaincatdogx' !! 'catdogxAbelCain'

cmp_ok: $x,'eq',$expected,'upper first 1'

$x = join: '', (sort:  { (Backwards: )}, @harry)
$expected = $upperfirst ?? 'xdogcatCainAbel' !! 'CainAbelxdogcat'

cmp_ok: $x,'eq',$expected,'upper first 2'

$x = join: '', (sort:  { (Backwards_stacked: $a, $b) }, @harry)
$expected = $upperfirst ?? 'xdogcatCainAbel' !! 'CainAbelxdogcat'

cmp_ok: $x,'eq',$expected,'upper first 3'

$x = join: '', (sort: @:  < @george, 'to', < @harry)
$expected = $upperfirst ??
    'AbelAxedCaincatchaseddoggonepunishedtoxyz' !!
    'catchaseddoggonepunishedtoxyzAbelAxedCain' 

cmp_ok: $x,'eq',$expected,'upper first 4'
@a = $@
@b = reverse: @a
cmp_ok: "$((join: ' ',@b))",'eq',"",'reverse 1'

@a = @: 1
@b = reverse: @a
cmp_ok: "$((join: ' ',@b))",'eq',"1",'reverse 2'

@a = @: 1,2
@b = reverse: @a
cmp_ok: "$((join: ' ',@b))",'eq',"2 1",'reverse 3'

@a = @: 1,2,3
@b = reverse: @a
cmp_ok: "$((join: ' ',@b))",'eq',"3 2 1",'reverse 4'

@a = @: 1,2,3,4
@b = reverse: @a
cmp_ok: "$((join: ' ',@b))",'eq',"4 3 2 1",'reverse 5'

@a = @: 10,2,3,4
@b = sort: {$a <+> $b;}, @a
cmp_ok: "$((join: ' ',@b))",'eq',"2 3 4 10",'sort numeric'

# literals, combinations

@b = sort:  (@: 4,1,3,2)
cmp_ok: "$((join: ' ',@b))",'eq','1 2 3 4','just sort'


@b = sort: grep: { $_ }, @:  (4,1,3,2)
cmp_ok: "$((join: ' ',@b))",'eq','1 2 3 4','grep then sort'


@b = sort: map: { $_ }, @:  (4,1,3,2)
cmp_ok: "$((join: ' ',@b))",'eq','1 2 3 4','map then sort'


@b = sort: reverse:  (@: 4,1,3,2)
cmp_ok: "$((join: ' ',@b))",'eq','1 2 3 4','reverse then sort'



sub twoface { no warnings 'redefine'; *twoface = sub (@< @_) { $a <+> $b };( twoface:  < @_ ) }
try { @b = (sort: \&twoface, (@: 4,1,3,2)) }; die: if $^EVAL_ERROR
cmp_ok: "$((join: ' ',@b))",'eq','1 2 3 4','redefine sort sub inside the sort sub'

do
    my $sortsub = \&Backwards
    my $sortglobr = \*Backwards
    @b = sort: $sortsub, @: 4,1,3,2
    cmp_ok: "$((join: ' ',@b))",'eq','4 3 2 1','sortname 1'
    @b = sort: $sortglobr, @: 4,1,3,2
    cmp_ok: "$((join: ' ',@b))",'eq','4 3 2 1','sortname 4'


our ($sortsub, $sortglob, $sortglobr)
do
    local $sortsub = \&Backwards
    local $sortglobr = \*Backwards
    @b = sort: $sortsub, @: 4,1,3,2
    cmp_ok: "$((join: ' ',@b))",'eq','4 3 2 1','sortname local 1'
    @b = sort: $sortglobr, @: 4,1,3,2
    cmp_ok: "$((join: ' ',@b))",'eq','4 3 2 1','sortname local 4'


## exercise sort builtins... ($a <=> $b already tested)
@a = @:  5, 19, 1996, 255, 90 
@b = sort: {
               my $dummy;		# force blockness
               return $b <+> $a
               }, @a
cmp_ok: "$((join: ' ',@b))",'eq','1996 255 90 19 5','force blockness'

$x = join: '', (sort: { $a cmp $b }, @harry)
$expected = $upperfirst ?? 'AbelCaincatdogx' !! 'catdogxAbelCain'
cmp_ok: $x,'eq',$expected,'a cmp b'

$x = join: '', (sort: { $b cmp $a }, @harry)
$expected = $upperfirst ?? 'xdogcatCainAbel' !! 'CainAbelxdogcat'
cmp_ok: $x,'eq',$expected,'b cmp a'

do
    use integer
    @b = sort: { $a <+> $b }, @a
    cmp_ok: "$((join: ' ',@b))",'eq','5 19 90 255 1996','integer a <=> b'

    @b = sort: { $b <+> $a }, @a
    cmp_ok: "$((join: ' ',@b))",'eq','1996 255 90 19 5','integer b <=> a'

    $x = join: '', (sort: { $a cmp $b }, @harry)
    $expected = $upperfirst ?? 'AbelCaincatdogx' !! 'catdogxAbelCain'
    cmp_ok: $x,'eq',$expected,'integer a cmp b'

    $x = join: '', (sort: { $b cmp $a }, @harry)
    $expected = $upperfirst ?? 'xdogcatCainAbel' !! 'CainAbelxdogcat'
    cmp_ok: $x,'eq',$expected,'integer b cmp a'





$x = join: '', (sort: { $a <+> $b }, (@:  3, 1, 2))
cmp_ok: $x,'eq','123',q(optimized-away comparison block doesn't take any other arguments away with it)

# test sorting in non-main package
package Foo
@a = @:  5, 19, 1996, 255, 90 
@b = sort: { $b <+> $a }, @a
main::cmp_ok: "$((join: ' ',@b))",'eq','1996 255 90 19 5','not in main:: 1'

# check if context for sort arguments is handled right


# test against a reentrancy bug
do
    package Bar
    sub compare { $a cmp $b }
    sub reenter { my @force = (sort: \&compare, qw/a b/) }

do
    my(@: $def, $init) = @: 0, 0
    @b = sort: {
                   $def = 1 if defined $Bar::a;
                   Bar::reenter:  unless $init++;
                   $a <+> $b
                   }, qw/4 3 1 2/
    main::cmp_ok: "$((join: ' ',@b))",'eq','1 2 3 4','reenter 1'

    main::ok: !$def,'reenter 2'



do
    sub routine { (@: "one", "two") };
    @a = sort: (routine: 1)
    main::cmp_ok: "$((join: ' ',@a))",'eq',"one two",'bug id 19991001.003'


package main

# check for in-place optimisation of @a = sort @a
do
    my ($r1,$r2,@a)
    our @g
    @g = (@: 3,2,1); $r1 = \@g[2]; @g = (sort: @g); $r2 = \@g[0]
    is: "$((join: ' ',@g))", "1 2 3", "inplace sort of global"

    @a = qw(b a c); $r1 = \@a[1]; @a =(sort: @a); $r2 = \@a[0]
    is: "$((join: ' ',@a))", "a b c", "inplace sort of lexical"

    @g = (@: 2,3,1); $r1 = \@g[1]; @g =(sort: { $b <+> $a }, @g); $r2 = \@g[0]
    is: "$((join: ' ',@g))", "3 2 1", "inplace reversed sort of global"

    @g = @: 2,3,1
    $r1 = \@g[1]; @g =(sort: { $a+<$b??1!!$a+>$b??-1!!0 }, @g); $r2 = \@g[0]
    is: "$((join: ' ',@g))", "3 2 1", "inplace custom sort of global"

    #  [perl #29790] don't optimise @a = ('a', sort @a) !

    @g = (@: 3,2,1); @g = @: '0', < sort: @g
    is: "$((join: ' ',@g))", "0 1 2 3", "un-inplace sort of global"
    @g = (@: 3,2,1); @g = @:  <(sort:  @g),'4'
    is: "$((join: ' ',@g))", "1 2 3 4", "un-inplace sort of global 2"

    @a = qw(b a c); @a = @: 'x', < sort: @a
    is: "$((join: ' ',@a))", "x a b c", "un-inplace sort of lexical"
    @a = qw(b a c); @a = @: ( <(sort: @a)), 'x'
    is: "$((join: ' ',@a))", "a b c x", "un-inplace sort of lexical 2"

    @g = (@: 2,3,1); @g = @: '0', < sort: { $b <+> $a }, @g
    is: "$((join: ' ',@g))", "0 3 2 1", "un-inplace reversed sort of global"
    @g = (@: 2,3,1); @g = @: ( <(sort: { $b <+> $a }, @g)),'4'
    is: "$((join: ' ',@g))", "3 2 1 4", "un-inplace reversed sort of global 2"

    @g = (@: 2,3,1); @g = @: '0', < sort: { $a+<$b??1!!$a+>$b??-1!!0 }, @g
    is: "$((join: ' ',@g))", "0 3 2 1", "un-inplace custom sort of global"
    @g = (@: 2,3,1); @g = @: ( <(sort: { $a+<$b??1!!$a+>$b??-1!!0 }, @g)),'4'
    is: "$((join: ' ',@g))", "3 2 1 4", "un-inplace custom sort of global 2"


# test that optimized {$b cmp $a} and {$b <=> $a} remain stable
# (new in 5.9) without overloading
do { no warnings;
    my @input = qw/5first 6first 5second 6second/;
    @b = (sort: { $b <+> $a }, @input);
    is: "$((join: ' ',@b))" , "6first 6second 5first 5second", "optimized \{$b <=> $a\} without overloading" ;
    @input =(sort: {$b <+> $a}, @input);
    is: "$((join: ' ',@input))" , "6first 6second 5first 5second","inline optimized \{$b <=> $a\} without overloading" ;
}

my @output

do
    my $failed = 0

    sub rec
        my $n = shift
        if (!(defined: $n))  # No arg means we're being called by sort()
            return 1
        
        if ($n+<5) { rec: $n+1; }
        else { (@: ...) =  (sort: \&rec, (@: 1,2)); }

        $failed = 1 if !defined $n
    

    rec: 1
    main::ok: !$failed, "sort from active sub"


# $a and $b are set in the package the sort() is called from,
# *not* the package the sort sub is in. This is longstanding
# de facto behaviour that shouldn't be broken.
package main
my $answer = "good"
(@: ...) =  sort: \&OtherPack::foo, @: 1,2,3,4

do
    package OtherPack
    no warnings 'once'
    sub foo
        $answer = "something was unexpectedly defined or undefined" if
          (defined: $a) || (defined: $b) || !(defined: $main::a) || !defined: $main::b
        $main::a <+> $main::b
    


main::cmp_ok: $answer,'eq','good','sort subr called from other package'


# Bug 36430 - sort called in package2 while a
# sort in package1 is active should set $package2::a/b.

$answer = "good"
my @list = sort: { (A::min: < $a->@) <+> (A::min: < $b->@) }
                 @:   \(@: 3, 1, 5), \(@: 2, 4), \(@: 0)

main::cmp_ok: $answer,'eq','good','bug 36430'

package A
sub min
    my @list = sort: {
                         $answer = '$a and/or $b are not defined ' if !(defined: $a) || !(defined: $b);
                         $a <+> $b;
                         }, @_
    @list[0]


# Sorting shouldn't increase the refcount of a sub
sub foo {(1+$a) <+> (1+$b)}
my $refcnt = Internals::SvREFCNT: \&foo
@output = sort: @:  foo: 3,7,9
main::is: $refcnt, (Internals::SvREFCNT: \&foo), "sort sub refcnt"
my $fail_msg = q(Modification of a read-only value attempted)
# Sorting a read-only array in-place shouldn't be allowed
my @readonly =1..10
Internals::SvREADONLY: \@readonly, 1
try { @readonly = (sort: @readonly); }
main::cmp_ok: (substr: $^EVAL_ERROR->{?description},0,(length: $fail_msg)),'eq',$fail_msg,'in-place sort of read-only array'




# Using return() should be okay even in a deeper context
@b = sort: {while (1) {return  $a <+> $b} }, 1..10
main::is: "$((join: ' ',@b))", "1 2 3 4 5 6 7 8 9 10", "return within loop"

# Using return() should be okay even if there are other items
# on the stack at the time.
@b = sort: {$_ = ($a<+>$b) + do{return $b<+> $a}}, 1..10
main::is: "$((join: ' ',@b))", "10 9 8 7 6 5 4 3 2 1", "return with SVs on stack"

# As above, but with a sort sub rather than a sort block.
sub ret_with_stacked { $_ = ($a<+>$b) + do {return $b <+> $a} }
@b = sort: &ret_with_stacked, 1..10
main::is: ((join: ' ', @b)), "10 9 8 7 6 5 4 3 2 1", "return with SVs on stack"

# Comparison code should be able to give result in non-integer representation.
sub cmp_as_string { @_[0] +< @_[1] ?? "-1" !! @_[0] == @_[1] ?? "0" !! "+1" }
@b = sort: { (cmp_as_string: $a, $b) }, @: 1,5,4,7,3,2,3
main::is: ((join: ' ', @b)), "1 2 3 3 4 5 7", "comparison result as string"
