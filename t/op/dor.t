#!./perl

# Test // and friends.

package main
require './test.pl'

plan:  tests => 28 

my($x)

$x=1
is: $x // 0, 1,		'	// : left-hand operand defined'

$x = undef
is: $x // 1, 1, 		'	// : left-hand operand undef'

$x=''
is: $x // 0, '',		'	// : left-hand operand defined but empty'

is: (ref: \$@ // 0), 'ARRAY',	'	// : left-hand operand a referece'

$x=undef
$x //= 1
is: $x, 1, 		'	//=: left-hand operand undefined'

$x //= 0
is: $x, 1, 		'//=: left-hand operand defined'

$x = ''
$x //= 0
is: $x, '', 		'//=: left-hand operand defined but empty'

aap: undef, 0, 3
sub aap
    is: shift       // 7, 7,	'shift // ... works'
    is: (shift: )     // 7, 0,	'shift() // ... works'
    is: shift @_ // 7, 3,	'shift @array // ... works'


noot: 3, 0, undef
sub noot
    is: pop         // 7, 7,	'pop // ... works'
    is: (pop: )       // 7, 0,	'pop() // ... works'
    is: pop @_   // 7, 3,	'pop @array // ... works'


# Test that various syntaxes are allowed

for (qw(getc readlink undef umask ~<*ARGV ~<*FOO ~<$foo -f))
    our $foo
    eval "sub \{ $_ // 0 \}"
    is: $^EVAL_ERROR, '', "$_ // ... compiles"


# Test for some ambiguous syntaxes

our ($y, $fh)

eval q# sub f ($y) { } f $x / 2; #
is:  $^EVAL_ERROR, '' 
eval q# sub f ($y) { } f $x /2; #
is:  $^EVAL_ERROR, '' 
eval q# sub { print $fh / 2 } #
is:  $^EVAL_ERROR, '' 
eval q# sub { print $fh /2 } #
is:  $^EVAL_ERROR, '' 

# [perl #28123] Perl optimizes // away incorrectly

is: 0 // 2, 0, 		'	// : left-hand operand not optimized away'
is: '' // 2, '',		'	// : left-hand operand not optimized away'
is: undef // 2, 2, 	'	// : left-hand operand optimized away'
