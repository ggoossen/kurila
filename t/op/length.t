#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
}

my $test = 0;

print "1..20\n";

print "not " unless length("")    == 0;
print "ok 1\n";

print "not " unless length("abc") == 3;
print "ok 2\n";

$_ = "foobar";
print "not " unless length()      == 6;
print "ok 3\n";

# Okay, so that wasn't very challenging.  Let's go Unicode.

{
    my $a = "\x{41}";

    print "not " unless length($a) == 1;
    print "ok 4\n";
    $test++;

    use bytes;
    print "not " unless $a eq "\x41" && length($a) == 1;
    print "ok 5\n";
    $test++;
}

{
    my $a = pack("U", 0xFF);

    use utf8;
    print "not " unless length($a) == 1;
    print "ok 6\n";
    $test++;

    no utf8;
    print "not " unless $a eq "\xc3\xbf" && length($a) == 2;
    print "ok 7\n";
    $test++;
}

{
    use utf8;
    my $a = "\x{100}";
    print "not " unless length($a) == 1;
    print "ok 8\n";
    $test++;

    use bytes;
    print "not " unless $a eq "\xc4\x80" && length($a) == 2;
    print "ok 9\n";
    $test++;
}

{
    use utf8;
    my $a = "\x{100}\x{80}";

    print "not " unless length($a) == 2;
    print "ok 10\n";
    $test++;

    use bytes;
    print "not " unless $a eq "\xc4\x80\xc2\x80" && length($a) == 4;
    print "ok 11\n";
    $test++;
}

{
    use utf8;
    my $a = "\x{80}\x{100}";
    print "not " unless length($a) == 2;
    print "ok 12\n";
    $test++;

    use bytes;
    print "not " unless $a eq "\xc2\x80\xc4\x80" && length($a) == 4;
    print "ok 13\n";
    $test++;
}

# Now for Unicode with magical vtbls

{
    require Tie::Scalar;
    my $a;
    tie $a, 'Tie::StdScalar';  # makes $a magical
    
    use utf8;
    $a = "\x{263A}";

    print "not " unless length($a) == 1;
    print "ok 14\n";
    $test++;

    use bytes;
    print "not " unless length($a) == 3;
    print "ok 15\n";
    $test++;
}

{
    # Play around with Unicode strings,
    # give a little workout to the UTF-8 length cache.
    use utf8;
    my $a = chr(256) x 100;
    print length $a == 100 ? "ok 16\n" : "not ok 16\n";
    chop $a;
    print length $a ==  99 ? "ok 17\n" : "not ok 17\n";
    $a .= $a;
    print length $a == 198 ? "ok 18\n" : "not ok 18\n";
    $a = chr(256) x 999;
    print length $a == 999 ? "ok 19\n" : "not ok 19\n";
    substr($a, 0, 1) = '';
    print length $a == 998 ? "ok 20\n" : "not ok 20\n";
}
