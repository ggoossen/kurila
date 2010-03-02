#!./perl

BEGIN 
    require './test.pl'


plan: tests => 21

ok: (length: "")    == 0

ok: (length: "abc") == 3

$_ = "foobar"
ok: (length: )      == 6

# Okay, so that wasn't very challenging.  Let's go Unicode.

do
    my $a = "\x{41}"

    ok: (length: $a) == 1

    use bytes;
    ok: $a eq "\x[41]" && (length: $a) == 1


do
    my $a = pack: "U", 0xFF

    use utf8;
    ok: (length: $a) == 1

    no utf8;
    ok: $a eq "\x[c3bf]" && (length: $a) == 2


do
    use utf8
    my $a = "\x{100}"
    ok: (length: $a) == 1

    use bytes;
    ok:  $a eq "\x[c480]" && (length: $a) == 2 


do
    use utf8
    my $a = "\x{100}\x{80}"

    ok: (length: $a) == 2

    use bytes;
    ok:  $a eq "\x[c480c280]" && (length: $a) == 4


do
    use utf8
    my $a = "\x{80}\x{100}"
    ok: (length: $a) == 2

    use bytes;
    ok:  $a eq "\x[c280c480]" && (length: $a) == 4 


do
    # Play around with Unicode strings,
    # give a little workout to the UTF-8 length cache.
    use utf8
    my $a = (chr: 256) x 100
    ok: length $a == 100
    chop $a
    ok: length $a ==  99
    $a .= $a
    ok: length $a == 198
    $a = (chr: 256) x 999
    ok: length $a == 999
    substr: $a, 0, 1, ''
    ok: length $a == 998


$^WARNING = 1

my $warnings = 0

$^WARN_HOOK = sub (@< @_)
    $warnings++
    print: $^STDERR, shift->message


is: (length: undef), undef, "Length of literal undef"

my $u

is: (length: $u), undef, "Length of regular scalar"

$u = "Gotcha!"

is: $warnings, 0, "There were no warnings"
