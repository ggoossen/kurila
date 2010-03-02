#!./perl

print: $^STDOUT, "1..36\n"


our (@x, $y, $c, @ary, $loop_count, @array, $r, $TODO)

for my $i (0..10)
    @x[+$i] = $i

$y = @x[10]
print: $^STDOUT, "#1	:$y: eq :10:\n"
$y = join: ' ', @x
print: $^STDOUT, "#1	:$y: eq :0 1 2 3 4 5 6 7 8 9 10:\n"
if ((join: ' ', @x) eq '0 1 2 3 4 5 6 7 8 9 10')
    print: $^STDOUT, "ok 1\n"
else
    print: $^STDOUT, "not ok 1\n"


@ary = @: 1, 2

for ( @ary)
    s/(.*)/ok $1\n/


print: $^STDOUT, @ary[1]

print: $^STDOUT, "ok 3\n"
print: $^STDOUT, "ok 4\n"

# test for internal scratch array generation
# this also tests that $foo was restored to 3210 after test 3
my $foo = "3210"
for ((split: ' ','a b c d e'))
    $foo .= $_

if ($foo eq '3210abcde') {print: $^STDOUT, "ok 5\n";} else {print: $^STDOUT, "not ok 5 $foo\n";}

foreach my $foo ((@: ("ok 6\n","ok 7\n")))
    print: $^STDOUT, $foo


sub foo
    for my $i (1..5)
        return $i if @_[0] == $i
    


print: $^STDOUT, (foo: 1) == 1 ?? "ok" !! "not ok", " 8\n"
print: $^STDOUT, (foo: 2) == 2 ?? "ok" !! "not ok", " 9\n"
print: $^STDOUT, (foo: 5) == 5 ?? "ok" !! "not ok", " 10\n"

sub bar
    return  @: 1, 2, 4


our $a = 0
foreach my $b ( (bar: ))
    $a += $b

print: $^STDOUT, $a == 7 ?? "ok" !! "not ok", " 11\n"

# loop over expand on empty list
sub baz { return () }
for ( (baz: ) )
    print: $^STDOUT, "not "

print: $^STDOUT, "ok 12\n"

$loop_count = 0
for ("-3" .. "0")
    $loop_count++

print: $^STDOUT, $loop_count == 4 ?? "ok" !! "not ok", " 13\n"

print: $^STDOUT, "ok 14\n"

# [perl #30061] double destory when same iterator variable (eg $_) used in
# DESTROY as used in for loop that triggered the destroy

do

    my $x = 0
    sub X::DESTROY
        my $o = shift
        $x++
        for (@: 1)
            1

    my %h
    %h{+foo} = bless: \$@, 'X'
    for (@: %h{?foo}, 1)
        delete %h{foo}
    print: $^STDOUT, $x == 1 ?? "ok" !! "not ok", " 15 - double destroy, x=$x\n"


# A lot of tests to check that reversed for works.
my $test = 15
sub is($got, $expected, $name)
    ++$test
    if ($got eq $expected)
        print: $^STDOUT, "ok $test # $name\n"
        return 1
    
    print: $^STDOUT, "not ok $test # $name\n"
    print: $^STDOUT, "# got '$got', expected '$expected'\n"
    return 0


@array = @: 'A', 'B', 'C'
for ( @array)
    $r .= $_

is: $r, 'ABC', 'Forwards for array'
$r = ''
for ((@: 1,2,3))
    $r .= $_

is: $r, '123', 'Forwards for list'
$r = ''
for ( (map: {$_}, @array))
    $r .= $_

is: $r, 'ABC', 'Forwards for array via map'
$r = ''
for ( (map: {$_}, (@:  1,2,3)))
    $r .= $_

is: $r, '123', 'Forwards for list via map'
$r = ''
for (1 .. 3)
    $r .= $_

is: $r, '123', 'Forwards for list via ..'
$r = ''
try { for ('A' .. 'C') { $r .= $_; } }
is: ($^EVAL_ERROR->message: ) =~ m/Range must be numeric/, 1, "for with non-numeric range"

$r = ''
for ((reverse: @array))
    $r .= $_

is: $r, 'CBA', 'Reverse for array'
$r = ''
for ((reverse: @: 1,2,3))
    $r .= $_

is: $r, '321', 'Reverse for list'
$r = ''
for ((reverse: (map: {$_}, @array)))
    $r .= $_

is: $r, 'CBA', 'Reverse for array via map'
$r = ''
for ((reverse: (map: {$_}, (@: 1,2,3))))
    $r .= $_

is: $r, '321', 'Reverse for list via map'
$r = ''
for ((reverse: 1 .. 3))
    $r .= $_

is: $r, '321', 'Reverse for list via ..'
$r = ''

try { for ((reverse: 'A' .. 'C')) { $r .= $_; } }
is: ($^EVAL_ERROR->message: ) =~ m/Range must be numeric/, 1, "for with non-numeric range"

$r = ''
for my $i ( @array)
    $r .= $i

is: $r, 'ABC', 'Forwards for array with var'
$r = ''
for my $i ((@: 1,2,3))
    $r .= $i

is: $r, '123', 'Forwards for list with var'
$r = ''
for my $i ( (map: {$_}, @array))
    $r .= $i

is: $r, 'ABC', 'Forwards for array via map with var'
$r = ''
for my $i ( (map: {$_}, (@:  1,2,3)))
    $r .= $i

is: $r, '123', 'Forwards for list via map with var'
$r = ''
for my $i (1 .. 3)
    $r .= $i

is: $r, '123', 'Forwards for list via .. with var'

$r = ''
for my $i ((reverse: @array))
    $r .= $i

is: $r, 'CBA', 'Reverse for array with var'
$r = ''
for my $i ((reverse: @: 1,2,3))
    $r .= $i

is: $r, '321', 'Reverse for list with var'

:TODO do
    $test++
    local $TODO = "RT #1085: what should be output of perl -we 'print do \{ foreach (1, 2) \{ 1; \} \}'"
    if (do {17; foreach ((@: 1, 2)) { 1; } } != 17)
        print: $^STDOUT, "not "
    
    print: $^STDOUT, "ok $test # TODO $TODO\n"


do
    $test++
    no warnings 'reserved';
    my %h
    foreach (%h{[(@: 'a', 'b')]}) {}
    if(%h)
        print: $^STDOUT, "not "
    
    print: $^STDOUT, "ok $test # TODO $TODO\n"

