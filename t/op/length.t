#!./perl

BEGIN {
    require './test.pl';
}

plan (tests => 28);

ok(length("")    == 0);

ok(length("abc") == 3);

$_ = "foobar";
ok(length()      == 6);

# Okay, so that wasn't very challenging.  Let's go Unicode.

{
    my $a = "\x{41}";

    ok(length($a) == 1);

    use bytes;
    ok($a eq "\x[41]" && length($a) == 1);
}

{
    my $a = pack("U", 0xFF);

    use utf8;
    ok(length($a) == 1);

    no utf8;
    ok($a eq "\x[c3bf]" && length($a) == 2);
}

{
    use utf8;
    my $a = "\x{100}";
    ok(length($a) == 1);

    use bytes;
    ok( $a eq "\x[c480]" && length($a) == 2 );
}

{
    use utf8;
    my $a = "\x{100}\x{80}";

    ok(length($a) == 2);

    use bytes;
    ok( $a eq "\x[c480c280]" && length($a) == 4);
}

{
    use utf8;
    my $a = "\x{80}\x{100}";
    ok(length($a) == 2);

    use bytes;
    ok( $a eq "\x[c280c480]" && length($a) == 4 );
}

# Now for Unicode with magical vtbls

{
    require Tie::Scalar;
    my $a;
    tie $a, 'Tie::StdScalar';  # makes $a magical
    
    use utf8;
    $a = "\x{263A}";

    ok(length($a) == 1);

    use bytes;
    ok(length($a) == 3);
}

{
    # Play around with Unicode strings,
    # give a little workout to the UTF-8 length cache.
    use utf8;
    my $a = chr(256) x 100;
    ok(length $a == 100);
    chop $a;
    ok(length $a ==  99);
    $a .= $a;
    ok(length $a == 198);
    $a = chr(256) x 999;
    ok(length $a == 999);
    substr($a, 0, 1, '');
    ok(length $a == 998);
}

curr_test(21);

require Tie::Scalar;

my $u = "ASCII";

tie $u, 'Tie::StdScalar', chr 256;

is(length $u, 1, "Length of a UTF-8 scalar returned from tie");
is(length $u, 1, "Again! Again!");

$^W = 1;

my $warnings = 0;

$^WARN_HOOK = sub {
    $warnings++;
    warn < @_;
};

is(length(undef), undef, "Length of literal undef");

my $u;

is(length($u), undef, "Length of regular scalar");

$u = "Gotcha!";

tie $u, 'Tie::StdScalar';

is(length($u), undef, "Length of tied scalar (MAGIC)");

is($u, undef);

{
    package U;
    use overload '""' => sub {return undef;};
}

my $uo = bless \@(), 'U';

is(length($uo), undef, "Length of overloaded reference");

# ok(!defined $uo); Turns you can't test this. FIXME for pp_defined?

is($warnings, 0, "There were no warnings");
