#!./perl -w

BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = qw(../lib .)
    require "test.pl"


plan: tests => 52

use utf8

$a = "B\x{fc}f"
$b = "G\x{100}r"
my $c = 0x200

do
    my $s = sprintf: "\%s", $a
    is: $s, $a, "\%s a"


do
    my $s = sprintf: "\%s", $b
    is: $s, $b, "\%s b"


do
    my $s = sprintf: "\%s\%s", $a, $b
    is: $s, $a.$b, "\%s\%s a b"


do
    my $s = sprintf: "\%s\%s", $b, $a
    is: $s, $b.$a, "\%s\%s b a"


do
    my $s = sprintf: "\%s\%s", $b, $b
    is: $s, $b.$b, "\%s\%s b b"


do
    my $s = sprintf: "\%s$b", $a
    is: $s, $a.$b, "\%sb a"


do
    my $s = sprintf: "$b\%s", $a
    is: $s, $b.$a, "b\%s a"


do
    my $s = sprintf: "\%s$a", $b
    is: $s, $b.$a, "\%sa b"


do
    my $s = sprintf: "$a\%s", $b
    is: $s, $a.$b, "a\%s b"


do
    my $s = sprintf: "$a\%s", $a
    is: $s, $a.$a, "a\%s a"


do
    my $s = sprintf: "$b\%s", $b
    is: $s, $b.$b, "a\%s b"


do
    my $s = sprintf: "\%c", $c
    is: $s, (chr: $c), "\%c c"


do
    my $s = sprintf: "\%s\%c", $a, $c
    is: $s, $a.(chr: $c), "\%s\%c a c"


do
    my $s = sprintf: "\%c\%s", $c, $a
    is: $s, (chr: $c).$a, "\%c\%s c a"


do
    my $s = sprintf: "\%c$b", $c
    is: $s, (chr: $c).$b, "\%cb c"


do
    my $s = sprintf: "\%s\%c$b", $a, $c
    is: $s, $a.(chr: $c).$b, "\%s\%cb a c"


do
    my $s = sprintf: "\%c\%s$b", $c, $a
    is: $s, (chr: $c).$a.$b, "\%c\%sb c a"


do
    my $s = sprintf: "$b\%c", $c
    is: $s, $b.(chr: $c), "b\%c c"


do
    my $s = sprintf: "$b\%s\%c", $a, $c
    is: $s, $b.$a.(chr: $c), "b\%s\%c a c"


do
    my $s = sprintf: "$b\%c\%s", $c, $a
    is: $s, $b.(chr: $c).$a, "b\%c\%s c a"


do
    # 20010407.008 sprintf removes utf8-ness
    $a = sprintf: "\x{1234}"
    is: ((sprintf: "\%x \%d", (unpack: "U*", $a), (length: $a))),    "1234 1"
        '\x{1234}'
    $a = sprintf: "\%s", "\x{5678}"
    is: ((sprintf: "\%x \%d", (unpack: "U*", $a), (length: $a))),    "5678 1"
        '%s \x{5678}'
    $a = sprintf: "\x{1234}\%s", "\x{5678}"
    is: ((sprintf: "\%x \%x \%d", (unpack: "U*", $a), (length: $a))), "1234 5678 2"
        '\x{1234}%s \x{5678}'


do
    # check that utf8ness doesn't "accumulate"

    my $w = "w\x{fc}"
    my $sprintf

    $sprintf = sprintf: "\%s\%s", $w, "$w\x{100}"
    is: (substr: $sprintf,0,2), $w, "utf8 echo"

    $sprintf = sprintf: "\%s\%s", $w, "$w\x{100}"
    is: (substr: $sprintf,0,2), $w, "utf8 echo echo"


my @values =@: chr 110, chr 255, chr 256

foreach my $prefix ( @values)
    foreach my $vector ( (map: {$_ . $_}, @values))

        my $format = "$prefix\%*vd"

        foreach my $dot ( @values)
            my $result = sprintf: $format, $dot, $vector
            is: length $result, 8
                or print: $^STDOUT, "# ", (join: ',', (map: {ord $_}, (@:  $prefix, $dot, $vector)))
                          "\n"
        
    

