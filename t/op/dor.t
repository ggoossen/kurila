#!./perl

# Test // and friends.

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
}

package main;
require './test.pl';

plan( tests => 25 );

my($x);

$x=1;
is($x // 0, 1,		'	// : left-hand operand defined');

$x = undef;
is($x // 1, 1, 		'	// : left-hand operand undef');

$x='';
is($x // 0, '',		'	// : left-hand operand defined but empty');

$x=1;
is(($x err 0), 1,	'	err: left-hand operand defined');

$x = undef;
is(($x err 1), 1, 	'	err: left-hand operand undef');

$x='';
is(($x err 0), '',	'	err: left-hand operand defined but empty');

$x=undef;
$x //= 1;
is($x, 1, 		'	//=: left-hand operand undefined');

$x //= 0;
is($x, 1, 		'	//=: left-hand operand defined');

$x = '';
$x //= 0;
is($x, '', 		'	//=: left-hand operand defined but empty');

@ARGV = (undef, 0, 3);
is(shift       // 7, 7,	'shift // ... works');
is(shift()     // 7, 0,	'shift() // ... works');
is(shift @ARGV // 7, 3,	'shift @array // ... works');

@ARGV = (3, 0, undef);
is(pop         // 7, 7,	'pop // ... works');
is(pop()       // 7, 0,	'pop() // ... works');
is(pop @ARGV   // 7, 3,	'pop @array // ... works');

# Test that various syntaxes are allowed

for (qw(getc pos readline readlink undef umask <> <FOO> <$foo> -f)) {
    eval "sub { $_ // 0 }";
    is($@, '', "$_ // ... compiles");
}
