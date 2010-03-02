#!./perl

print: $^STDOUT, "1..34\n"

our ($a, $b, $c, $d, $x, $y, @b, @c, %d, $k)

sub foo($a, $b)
    my $c
    my $d
    $c = "ok 3\n"
    $d = "ok 4\n"
    do { my(@: $a, _, $c) = (@: "ok 9\n", "not ok 10\n", "ok 10\n");
        (@: $x, $y) = (@: $a, $c); }
    print: $^STDOUT, $a, $b
    $c . $d


$a = "ok 5\n"
$b = "ok 6\n"
$c = "ok 7\n"
$d = "ok 8\n"

print: $^STDOUT, foo: "ok 1\n","ok 2\n"

print: $^STDOUT, $a,$b,$c,$d,$x,$y

# same thing, only with arrays and associative arrays

sub foo2($a, @< @b)
    my(@c, %d)
    @c = @:  "ok 13\n" 
    %d{+''} = "ok 14\n"
    do { my(@: $a,@< @c) = (@: "ok 19\n", "ok 20\n"); (@: $x, $y) = (@: $a, < @c); }
    print: $^STDOUT, $a, < @b
    @c[0] . %d{?''}


$a = "ok 15\n"
@b = @:  "ok 16\n" 
@c = @:  "ok 17\n" 
%d{+''} = "ok 18\n"

print: $^STDOUT, foo2: "ok 11\n","ok 12\n"

print: $^STDOUT, $a,< @b,< @c,< %d,$x,$y

my $i = "outer"

if (my $i = "inner")
    print: $^STDOUT, "not " if $i ne "inner"

print: $^STDOUT, "ok 21\n"

if ((my $i = 1) == 0)
    print: $^STDOUT, "not "
else
    print: $^STDOUT, "not" if $i != 1

print: $^STDOUT, "ok 22\n"

my $j = 5
while (my $i = --$j)
    (print: $^STDOUT, "not "), last unless $i +> 0
continue
    (print: $^STDOUT, "not "), last unless $i +> 0

print: $^STDOUT, "ok 23\n"
print: $^STDOUT, "ok 24\n"
print: $^STDOUT, "ok 25\n"

foreach my $i ((@: 26, 27))
    print: $^STDOUT, "ok $i\n"


print: $^STDOUT, "not " if $i ne "outer"
print: $^STDOUT, "ok 28\n"

print: $^STDOUT, "ok 29\n"
print: $^STDOUT, "ok 30\n"

# Found in HTML::FormatPS
my %fonts = %:  < qw(nok 31) 
for my $full (keys %fonts)
    $full =~ s/^n//
    # Supposed to be copy-on-write via force_normal after a THINKFIRST check.
    print: $^STDOUT, "$full %fonts{?nok}\n"


#  [perl #29340] optimising away the = () left the padav returning the
# array rather than the contents, leading to 'Bizarre copy of array' error

sub opta { my @a= $@ }
sub opth { my %h= $% }
try { my $x = (opta: )}
print: $^STDOUT, "not " if $^EVAL_ERROR
print: $^STDOUT, "ok 32\n"
try { my $x = (opth: )}
print: $^STDOUT, "not " if $^EVAL_ERROR
print: $^STDOUT, "ok 33\n"


sub foo3
    ++my $x{+foo}
    print: $^STDOUT, "not " if defined $x{?bar}
    ++$x{+bar}

try { (foo3: ); (foo3: ); }
die: if $^EVAL_ERROR
print: $^STDOUT, "ok 34\n"
