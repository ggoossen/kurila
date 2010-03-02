#!./perl

print: $^STDOUT, "1..14\n"

our ($x, $y, @x)

# compile time evaluation

if ((int: 1.234) == 1) {print: $^STDOUT, "ok 1\n";} else {print: $^STDOUT, "not ok 1\n";}

if ((int: -1.234) == -1) {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2\n";}

# run time evaluation

$x = 1.234
if ((int: $x) == 1) {print: $^STDOUT, "ok 3\n";} else {print: $^STDOUT, "not ok 3\n";}
if ((int: -$x) == -1) {print: $^STDOUT, "ok 4\n";} else {print: $^STDOUT, "not ok 4\n";}

$x = (length: "abc") % -10
print: $^STDOUT, $x == -7 ?? "ok 5\n" !! "# expected -7, got $x\nnot ok 5\n"

do
    use integer
    $x = (length: "abc") % -10
    $y = (3/-10)*-10
    print: $^STDOUT, $x+$y == 3 && (abs: $x) +< 10 ?? "ok 6\n" !! "not ok 6\n"


# check bad strings still get converted

@x = @:  6, 8, 10
print: $^STDOUT, "not " if @x["1foo"] != 8
print: $^STDOUT, "ok 7\n"

# check values > 32 bits work.

$x = 4294967303.15
$y = int: $x

if ($y eq "4294967303")
    print: $^STDOUT, "ok 8\n"
else
    print: $^STDOUT, "not ok 8 # int($x) is $y, not 4294967303\n"


$y = int: -$x

if ($y eq "-4294967303")
    print: $^STDOUT, "ok 9\n"
else
    print: $^STDOUT, "not ok 9 # int($x) is $y, not -4294967303\n"


$x = 4294967294.2
$y = int: $x

if ($y eq "4294967294")
    print: $^STDOUT, "ok 10\n"
else
    print: $^STDOUT, "not ok 10 # int($x) is $y, not 4294967294\n"


$x = 4294967295.7
$y = int: $x

if ($y eq "4294967295")
    print: $^STDOUT, "ok 11\n"
else
    print: $^STDOUT, "not ok 11 # int($x) is $y, not 4294967295\n"


$x = 4294967296.11312
$y = int: $x

if ($y eq "4294967296")
    print: $^STDOUT, "ok 12\n"
else
    print: $^STDOUT, "not ok 12 # int($x) is $y, not 4294967296\n"


$y = int: 279964589018079/59
if ($y == 4745162525730)
    print: $^STDOUT, "ok 13\n"
else
    print: $^STDOUT, "not ok 13 # int(279964589018079/59) is $y, not 4745162525730\n"


$y = 279964589018079
$y = int: $y/59
if ($y == 4745162525730)
    print: $^STDOUT, "ok 14\n"
else
    print: $^STDOUT, "not ok 14 # int(279964589018079/59) is $y, not 4745162525730\n"


