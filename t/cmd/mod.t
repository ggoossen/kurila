#!./perl

print: $^STDOUT, "1..13\n"

(print: $^STDOUT, "ok 1\n") if 1
(print: $^STDOUT, "not ok 1\n") unless 1

(print: $^STDOUT, "ok 2\n") unless 0
(print: $^STDOUT, "not ok 2\n") if 0

1 &&  (@: (print: $^STDOUT, "not ok 3\n")) if 0
1 && ((print: $^STDOUT, "ok 3\n")) if 1
0 ||  (@: (print: $^STDOUT, "not ok 4\n")) if 0
0 || ((print: $^STDOUT, "ok 4\n")) if 1

our ($x, @x, @y)

$x = 0
loop {@x[+$x] = $x;} while ($x++) +< 10
if ((join: ' ', @x) eq '0 1 2 3 4 5 6 7 8 9 10')
    print: $^STDOUT, "ok 5\n"
else
    print: $^STDOUT, "not ok 5 $((join: ' ',@x))\n"


$x = 15
$x = 10 while $x +< 10
if ($x == 15) {print: $^STDOUT, "ok 6\n";} else {print: $^STDOUT, "not ok 6\n";}

foreach (@x)
    @y[+$_] = $_ * 2
if ((join: ' ', @y) eq '0 2 4 6 8 10 12 14 16 18 20')
    print: $^STDOUT, "ok 7\n"
else
    print: $^STDOUT, "not ok 7 $((join: ' ',@y))\n"


my $foo
(open: $foo, "<",'./TEST') || (open: $foo, "<",'TEST') || open: $foo, "<",'t/TEST'
$x = 0
$x++ while ~< $foo->*
print: $^STDOUT, $x +> 50 && $x +< 1000 ?? "ok 8\n" !! "not ok 8\n"

$x = -0.5
print: $^STDOUT, "not " if (scalar: $x) +< 0 and $x +>= 0
print: $^STDOUT, "ok 9\n"

print: $^STDOUT, "not " unless (-(-$x) +< 0) == ($x +< 0)
print: $^STDOUT, "ok 10\n"

print: $^STDOUT, "ok 11\n" if $x +< 0
print: $^STDOUT, "not ok 11\n" unless $x +< 0

print: $^STDOUT, "ok 12\n" unless $x +> 0
print: $^STDOUT, "not ok 12\n" if $x +> 0

# This used to cause a segfault
$x = "".("".do { for (@: 1) { "foo" } })
print: $^STDOUT, "ok 13\n"
