#!./perl

print "1..43\n";

use strict;

our ($i, @x, $y, $c, $foo, @ary, $loop_count, @array, $r, $TODO);

for ($i = 0; $i +<= 10; $i++) {
    @x[$i] = $i;
}
$y = @x[10];
print "#1	:$y: eq :10:\n";
$y = join(' ', @( < @x));
print "#1	:$y: eq :0 1 2 3 4 5 6 7 8 9 10:\n";
if (join(' ', @( < @x)) eq '0 1 2 3 4 5 6 7 8 9 10') {
	print "ok 1\n";
} else {
	print "not ok 1\n";
}

$i = $c = 0;
for (;;) {
	$c++;
	last if $i++ +> 10;
}
if ($c == 12) {print "ok 2\n";} else {print "not ok 2\n";}

$foo = 3210;
@ary = @(1,2,3,4,5);
foreach $foo ( @ary) {
	$foo *= 2;
}
if (join('', @(< @ary)) eq '246810') {print "ok 3\n";} else {print "not ok 3\n";}

for ( @ary) {
    s/(.*)/ok $1\n/;
}

print @ary[1];

# test for internal scratch array generation
# this also tests that $foo was restored to 3210 after test 3
for (@( <split(' ','a b c d e'))) {
	$foo .= $_;
}
if ($foo eq '3210abcde') {print "ok 5\n";} else {print "not ok 5 $foo\n";}

foreach $foo (@(("ok 6\n","ok 7\n"))) {
	print $foo;
}

sub foo {
    for $i (1..5) {
	return $i if @_[0] == $i;
    }
}

print foo(1) == 1 ? "ok" : "not ok", " 8\n";
print foo(2) == 2 ? "ok" : "not ok", " 9\n";
print foo(5) == 5 ? "ok" : "not ok", " 10\n";

sub bar {
    return  @(1, 2, 4);
}

our $a = 0;
foreach $b ( bar()) {
    $a += $b;
}
print $a == 7 ? "ok" : "not ok", " 11\n";

# loop over expand on empty list
sub baz { return () }
for ( baz() ) {
    print "not ";
}
print "ok 12\n";

$loop_count = 0;
for ("-3" .. "0") {
    $loop_count++;
}
print $loop_count == 4 ? "ok" : "not ok", " 13\n";

print "ok 14\n";

# [perl #30061] double destory when same iterator variable (eg $_) used in
# DESTROY as used in for loop that triggered the destroy

{

    my $x = 0;
    sub X::DESTROY {
	my $o = shift;
	$x++;
	1 for @( (1));
    }

    my %h;
    %h{foo} = bless \@(), 'X';
    delete %h{foo} for @( %h{foo}, 1);
    print $x == 1 ? "ok" : "not ok", " 15 - double destroy, x=$x\n";
}

# A lot of tests to check that reversed for works.
my $test = 15;
sub is {
    my ($got, $expected, $name) = < @_;
    ++$test;
    if ($got eq $expected) {
	print "ok $test # $name\n";
	return 1;
    }
    print "not ok $test # $name\n";
    print "# got '$got', expected '$expected'\n";
    return 0;
}

@array = @('A', 'B', 'C');
for ( @array) {
    $r .= $_;
}
is ($r, 'ABC', 'Forwards for array');
$r = '';
for (@(1,2,3)) {
    $r .= $_;
}
is ($r, '123', 'Forwards for list');
$r = '';
for (@(< map {$_} @( < @array))) {
    $r .= $_;
}
is ($r, 'ABC', 'Forwards for array via map');
$r = '';
for (@(< map {$_} @( 1,2,3))) {
    $r .= $_;
}
is ($r, '123', 'Forwards for list via map');
$r = '';
for (1 .. 3) {
    $r .= $_;
}
is ($r, '123', 'Forwards for list via ..');
$r = '';
for ('A' .. 'C') {
    $r .= $_;
}
is ($r, 'ABC', 'Forwards for list via ..');

$r = '';
for (reverse @array) {
    $r .= $_;
}
is ($r, 'CBA', 'Reverse for array');
$r = '';
for (reverse @(1,2,3)) {
    $r .= $_;
}
is ($r, '321', 'Reverse for list');
$r = '';
for (reverse map {$_} @array) {
    $r .= $_;
}
is ($r, 'CBA', 'Reverse for array via map');
$r = '';
for (reverse map {$_} @(1,2,3)) {
    $r .= $_;
}
is ($r, '321', 'Reverse for list via map');
$r = '';
for (reverse 1 .. 3) {
    $r .= $_;
}
is ($r, '321', 'Reverse for list via ..');
$r = '';
for (reverse 'A' .. 'C') {
    $r .= $_;
}
is ($r, 'CBA', 'Reverse for list via ..');

$r = '';
for my $i ( @array) {
    $r .= $i;
}
is ($r, 'ABC', 'Forwards for array with var');
$r = '';
for my $i (@(1,2,3)) {
    $r .= $i;
}
is ($r, '123', 'Forwards for list with var');
$r = '';
for my $i (@(< map {$_} @( < @array))) {
    $r .= $i;
}
is ($r, 'ABC', 'Forwards for array via map with var');
$r = '';
for my $i (@(< map {$_} @( 1,2,3))) {
    $r .= $i;
}
is ($r, '123', 'Forwards for list via map with var');
$r = '';
for my $i (1 .. 3) {
    $r .= $i;
}
is ($r, '123', 'Forwards for list via .. with var');
$r = '';
for my $i ('A' .. 'C') {
    $r .= $i;
}
is ($r, 'ABC', 'Forwards for list via .. with var');

$r = '';
for my $i (reverse @array) {
    $r .= $i;
}
is ($r, 'CBA', 'Reverse for array with var');
$r = '';
for my $i (reverse @(1,2,3)) {
    $r .= $i;
}
is ($r, '321', 'Reverse for list with var');

# For some reason the generate optree is different when $_ is implicit.
$r = '';
for $_ ( @array) {
    $r .= $_;
}
is ($r, 'ABC', 'Forwards for array with explicit $_');
$r = '';
for $_ (@(1,2,3)) {
    $r .= $_;
}
is ($r, '123', 'Forwards for list with explicit $_');
$r = '';
for $_ (@(< map {$_} @( < @array))) {
    $r .= $_;
}
is ($r, 'ABC', 'Forwards for array via map with explicit $_');
$r = '';
for $_ (@(< map {$_} @( 1,2,3))) {
    $r .= $_;
}
is ($r, '123', 'Forwards for list via map with explicit $_');
$r = '';
for $_ (1 .. 3) {
    $r .= $_;
}
is ($r, '123', 'Forwards for list via .. with var with explicit $_');
$r = '';
for $_ ('A' .. 'C') {
    $r .= $_;
}
is ($r, 'ABC', 'Forwards for list via .. with var with explicit $_');

TODO: {
    $test++;
    local $TODO = "RT #1085: what should be output of perl -we 'print do \{ foreach (1, 2) \{ 1; \} \}'";
    if (do {17; foreach (@(1, 2)) { 1; } } != 17) {
        print "not ";
    }
    print "ok $test # TODO $TODO\n";
}

{
    $test++;
    no warnings 'reserved';
    my %h;
    foreach (@(%h{['a', 'b']})) {}
    if(%h) {
        print "not ";
    }
    print "ok $test # TODO $TODO\n";
}
