#!./perl

sub foo1
    'true1'
    if (@_[0]) { 'true2'; }


sub foo2
    'true1'
    if (@_[0]) { return 'true2'; } else { return 'true3'; }
    'true0'


sub foo3
    'true1'
    unless (@_[0]) { 'true2'; }


sub foo4
    'true1'
    unless (@_[0]) { 'true2'; } else { 'true3'; }


sub foo5
    'true1'
    'true2' if @_[0]


sub foo6
    'true1'
    'true2' unless @_[0]


print: $^STDOUT, "1..28\n"

if ((foo1: 0) eq '0') {print: $^STDOUT, "ok 1\n";} else {print: $^STDOUT, "not ok 1\n";}
if ((foo1: 1) eq 'true2') {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2\n";}
if ((foo2: 0) eq 'true3') {print: $^STDOUT, "ok 3\n";} else {print: $^STDOUT, "not ok 3\n";}
if ((foo2: 1) eq 'true2') {print: $^STDOUT, "ok 4\n";} else {print: $^STDOUT, "not ok 4\n";}

if ((foo3: 0) eq 'true2') {print: $^STDOUT, "ok 5\n";} else {print: $^STDOUT, "not ok 5\n";}
if ((foo3: 1) eq '1') {print: $^STDOUT, "ok 6\n";} else {print: $^STDOUT, "not ok 6\n";}
if ((foo4: 0) eq 'true2') {print: $^STDOUT, "ok 7\n";} else {print: $^STDOUT, "not ok 7\n";}
if ((foo4: 1) eq 'true3') {print: $^STDOUT, "ok 8\n";} else {print: $^STDOUT, "not ok 8\n";}

if ((foo5: 0) eq '0') {print: $^STDOUT, "ok 9\n";} else {print: $^STDOUT, "not ok 9\n";}
if ((foo5: 1) eq 'true2') {print: $^STDOUT, "ok 10\n";} else {print: $^STDOUT, "not ok 10\n";}
if ((foo6: 0) eq 'true2') {print: $^STDOUT, "ok 11\n";} else {print: $^STDOUT, "not ok 11\n";}
if ((foo6: 1) eq '1') {print: $^STDOUT, "ok 12\n";} else {print: $^STDOUT, "not ok 12\n";}

# Now test to see that recursion works using a Fibonacci number generator

our $level

sub fib($arg)
    my($foo)
    $level++
    if ($arg +<= 2)
        $foo = 1
    else
        $foo = (fib: $arg-1) + fib: $arg-2
    
    $level--
    $foo


our @good = @: 0,1,1,2,3,5,8,13,21,34,55,89

our $foo

for my $i (1..10)
    $foo = $i + 12
    if ((fib: $i) == @good[$i])
        print: $^STDOUT, "ok $foo\n"
    else
        print: $^STDOUT, "not ok $foo\n"
    


sub ary1
    return @: 1,2,3


print: $^STDOUT, "ok 23\n"
print: $^STDOUT, (join: ':',(ary1:  < @_ )) eq '1:2:3' ?? "ok 24\n" !! "not ok 24\n"

sub ary2
    do
        return  @: 1,2,3
        (3,2,1)
    
    0


print: $^STDOUT, "ok 25\n"

our $x = join: ':',(ary2:  < @_ )
print: $^STDOUT, $x eq '1:2:3' ?? "ok 26\n" !! "not ok 26 $x\n"

sub somesub($num,$P,$F,$L)
    our (@: $p,$f,$l) =@:  caller
    print: $^STDOUT, "$p:$f:$l" eq "$P:$F:$L" ?? "ok $num\n" !! "not ok $num $p:$f:$l ne $P:$F:$L\n"


somesub: 27, 'main', __FILE__, __LINE__

package foo
main::somesub: 28, 'foo', __FILE__, __LINE__
