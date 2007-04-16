#!./perl

BEGIN {
    require './test.pl';
}
use strict;

plan tests => 24;

open(FOO,'op/read.t') || open(FOO,'t/op/read.t') || open(FOO,':op:read.t') || die "Can't open op.read";
seek(FOO,4,0) or die "Seek failed: $!";
my $buf;
my $got = read(FOO,$buf,4);

is ($got, 4);
is ($buf, "perl");

seek (FOO,0,2) || seek(FOO,20000,0);
$got = read(FOO,$buf,4);

is ($got, 0);
is ($buf, "");

# This is true if Config is not built, or if PerlIO is enabled
# ie assume that PerlIO is present, unless we know for sure otherwise.
my $has_perlio = !eval {
    no warnings;
    require Config;
    !$Config::Config{useperlio}
};

my $tmpfile = 'Op_read.tmp';

{
    use utf8;
    my $value = "\x{236a}" x 3; # e2.8d.aa x 3

    open FH, ">$tmpfile" or die "Can't open $tmpfile: $!";
    print FH $value;
    close FH;

    use bytes;
    for ([length($value), 0, '', length($value), "$value"],
         [4, 0, '', 4, "\xE2\x8D\xAA\xE2"],
         [9+8, 0, '', 9, $value],
         [9, 3, '', 9, "\0" x 3 . $value],
         [9+8, 3, '', 9, "\0" x 3 . $value]
        )
    {
        my ($length, $offset, $buffer, $expect_length, $expect) = @$_;
        my $buffer = "";
        open FH, $tmpfile or die "Can't open $tmpfile: $!";
        $got = read (FH, $buffer, $length, $offset);
        is($got, $expect_length);
        is($buffer, $expect);
        close FH;
    }

    use utf8;
    for ([length($value), 0, '', length($value), "$value"],
         [2, 0, '', 2, "\x{236a}" x 2],
         [3+8, 0, '', 3, $value],
         [3, 3, '', 3, "\0" x 3 . $value],
         [3+8, 3, '', 3, "\0" x 3 . $value]
        )
    {
        my ($length, $offset, $buffer, $expect_length, $expect) = @$_;
        my $buffer = "";
        open FH, $tmpfile or die "Can't open $tmpfile: $!";
        $got = read (FH, $buffer, $length, $offset);
        is($got, $expect_length);
        is($buffer, $expect);
        close FH;
    }
}

END { 1 while unlink $tmpfile }
