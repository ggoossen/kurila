#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = qw(. ../lib);
}

require "test.pl";
plan( tests => 25 );

is(vec($foo,0,1), 0);
is(length($foo), 0);
vec($foo,0,1) = 1;
is(length($foo), 1);
is(unpack('C',$foo), 1);
is(vec($foo,0,1), 1);

is(vec($foo,20,1), 0);
vec($foo,20,1) = 1;
is(vec($foo,20,1), 1);
is(length($foo), 3);
is(vec($foo,1,8), 0);
vec($foo,1,8) = 0xf1;
is(vec($foo,1,8), 0xf1);
is((unpack('C',substr($foo,1,1)) & 255), 0xf1);
is(vec($foo,2,4), 1);;
is(vec($foo,3,4), 15);
vec($Vec, 0, 32) = 0xbaddacab;
is($Vec, "\xba\xdd\xac\xab");
is(vec($Vec, 0, 32), 3135089835);

# ensure vec() handles numericalness correctly
$foo = $bar = $baz = 0;
vec($foo = 0,0,1) = 1;
vec($bar = 0,1,1) = 1;
$baz = $foo | $bar;
ok($foo eq "1" && $foo == 1);
ok($bar eq "2" && $bar == 2);
ok("$foo $bar $baz" eq "1 2 3");

# error cases

$x = eval { vec $foo, 0, 3 };
like($@, /^Illegal number of bits in vec/);
$@ = undef;
$x = eval { vec $foo, 0, 0 };
like($@, /^Illegal number of bits in vec/);
$@ = undef;
$x = eval { vec $foo, 0, -13 };
like($@, /^Illegal number of bits in vec/);
$@ = undef;
$x = eval { vec($foo, -1, 4) = 2 };
like($@, /^Illegal number of bits in vec/);
$@ = undef;
ok(! vec('abcd', 7, 8));

# vec is independent of 'use utf8'
use utf8;
$x = "\x{263a}";  # == \xE2\x98\xBA
is(vec($x, 0, 8), 0xE2);
no utf8;

# A variation of [perl #20933]
{
    my $s = "";
    vec($s, 0, 1) = 0;
    vec($s, 1, 1) = 1;
    my @r;
    $r[$_] = \ vec $s, $_, 1 for (0, 1);
    ok(!(${ $r[0] } != 0 || ${ $r[1] } != 1)); 
}
