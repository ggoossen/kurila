#!./perl

BEGIN 
    require './test.pl'



plan: tests => 24

my $foo
(open: $foo, "<",'op/read.t') || (open: $foo, "<",'t/op/read.t') || (open: $foo, "<",':op:read.t') || die: "Can't open op.read"
seek: $foo,4,0 or die: "Seek failed: $^OS_ERROR"
my $buf
my $got = read: $foo,$buf,4

is: $got, 4
is: $buf, "perl"

(seek: $foo,0,2) || seek: $foo,20000,0
$got = read: $foo,$buf,4

is: $got, 0
is: $buf, ""

# This is true if Config is not built, or if PerlIO is enabled
# ie assume that PerlIO is present, unless we know for sure otherwise.
my $has_perlio = !try
    no warnings
    require Config
    ! Config::config_value: "useperlio"

my $tmpfile = 'Op_read.tmp'

do
    use utf8
    my $value = "\x{236a}" x 3 # e2.8d.aa x 3

    open: my $fh, ">", "$tmpfile" or die: "Can't open $tmpfile: $^OS_ERROR"
    print: $fh, $value
    close $fh

    use bytes;
    for (@: \(@: (length: $value), 0, '', (length: $value), "$value")
            \(@: 4, 0, '', 4, "\x[E28DAAE2]")
            \(@: 9+8, 0, '', 9, $value)
            \(@: 9, 3, '', 9, "\0" x 3 . $value)
            \(@: 9+8, 3, '', 9, "\0" x 3 . $value)
        )
        my (@: $length, $offset, $buffer, $expect_length, $expect) =  $_->@
        my $buffer = ""
        open: $fh, "<", $tmpfile or die: "Can't open $tmpfile: $^OS_ERROR"
        $got = read: $fh, $buffer, $length, $offset
        is: $got, $expect_length
        is: $buffer, $expect
        close $fh

    use utf8
    for (@: \(@: (length: $value), 0, '', (length: $value), "$value")
            \(@: 2, 0, '', 2, "\x{236a}" x 2)
            \(@: 3+8, 0, '', 3, $value)
            \(@: 3, 3, '', 3, "\0" x 3 . $value)
            \(@: 3+8, 3, '', 3, "\0" x 3 . $value)
        )
        my (@: $length, $offset, $buffer, $expect_length, $expect) =  $_->@
        my $buffer = ""
        open: $fh, "<", $tmpfile or die: "Can't open $tmpfile: $^OS_ERROR"
        $got = read: $fh, $buffer, $length, $offset
        is: $got, $expect_length
        is: $buffer, $expect
        close $fh


END { 1 while (unlink: $tmpfile) }
