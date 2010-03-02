#!./perl

# This ok() function is specially written to avoid any concatenation.
my $test = 1
sub ok($ok, ?$name)

    printf: $^STDOUT, "\%sok \%d - \%s\n", ($ok ?? "" !! "not "), $test, $name

    printf: $^STDOUT, "# Failed test at line \%d\n", (caller)[[2]] unless $ok

    $test++
    return $ok


print: $^STDOUT, q(1..22
)

do
    our ($a, $b, $c)

    $a = 'ab' . 'c'	# compile time
    $b = 'def'

    $c = $a . $b
    ok: $c eq 'abcdef'

    $c .= 'xyz'
    ok: $c eq 'abcdefxyz'

    $_ = $a
    $_ .= $b
    ok: $_ eq 'abcdef'


# test that when right argument of concat is UTF8, and is the same
# variable as the target, and the left argument is not UTF8, it no
# longer frees the wrong string.
do
    sub r2
        my $string = ''
        $string .= pack: "U0a*", 'mnopqrstuvwx'
        $string = "abcdefghijkl$string"

    for (qw/ 4 5 /)
        r2:  and ok: 1


# test that nul bytes get copied
do
    my (@: $a, $ab)   = @: "a", "a\0b"
    my (@: $ua, $uab) =  map: { (pack: "U0a*", $_) }, @:  $a, $ab

    my $ub = pack: "U0a*", 'b'

    my $t1 = $a; $t1 .= $ab

    ok: scalar $t1 =~ m/b/

    my $t2 = $a; $t2 .= $uab

    ok: scalar eval '$t2 =~ m/$ub/'

    my $t3 = $ua; $t3 .= $ab

    ok: scalar $t3 =~ m/$ub/

    my $t4 = $ua; $t4 .= $uab

    ok: scalar eval '$t4 =~ m/$ub/'

    my $t5 = $a; $t5 = $ab . $t5

    ok: scalar $t5 =~ m/$ub/

    my $t6 = $a; $t6 = $uab . $t6

    ok: scalar eval '$t6 =~ m/$ub/'

    my $t7 = $ua; $t7 = $ab . $t7

    ok: scalar $t7 =~ m/$ub/

    my $t8 = $ua; $t8 = $uab . $t8

    ok: scalar eval '$t8 =~ m/$ub/'



do
    # ID 20001020.006
    use utf8

    "x" =~ m/(.)/ # unset $2

    # Without the fix this 5.7.0 would croak:
    # Modification of a read-only value attempted at ...
    try {"$2\x{1234}"}
    ok: !$^EVAL_ERROR, "bug id 20001020.006, left"

    # For symmetry with the above.
    try {"\x{1234}$2"}
    ok: !$^EVAL_ERROR, "bug id 20001020.006, right"

    our $pi
    *pi = \undef
    # This bug existed earlier than the $2 bug, but is fixed with the same
    # patch. Without the fix this 5.7.0 would also croak:
    # Modification of a read-only value attempted at ...
    try{"$pi\x{1234}"}
    ok: !$^EVAL_ERROR, "bug id 20001020.006, constant left"

    # For symmetry with the above.
    try{"\x{1234}$pi"}
    ok: !$^EVAL_ERROR, "bug id 20001020.006, constant right"


do
    # concat should not upgrade its arguments.
    use utf8
    my($l, $r, $c)

    (@: $l, $r, $c) = @: "\x{101}", "\x[fe]", "\x{101}\x[fe]"
    ok: $l.$r eq $c, "concat utf8 and byte"
    ok: $l eq "\x{101}", "right not changed after concat"
    ok: $r eq "\x[fe]", "left not changed after concat"


do
    my $a; ($a .= 5) . 6
    ok: $a == 5, '($a .= 5) . 6 - present since 5.000'


do
    # [perl #24508] optree construction bug
    sub strfoo { "x" }
    my ($x, $y)
    $y = ($x = '' . (strfoo: )) . "y"
    ok:  "$x,$y" eq "x,xy", 'figures out correct target' 

