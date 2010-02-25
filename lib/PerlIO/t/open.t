#!./perl


use warnings

BEGIN 
    unless ((PerlIO::Layer->find:  'perlio'))
        print: $^STDOUT, "1..0 # Skip: not perlio\n"
        exit 0
    
    use Config


use Test::More tests => 6

use Fcntl < qw(:seek)

do
    ok: ((open: my $fh, "+>", undef)), "open my \$fh, '+>', undef"
    print: $fh, "the right write stuff"
    ok: (seek: $fh, 0, SEEK_SET), "seek to zero"
    my $data = ~< $fh
    is: $data, "the right write stuff", "found the right stuff"


do
    ok: ((open: my $fh, "+<", undef)), "open my \$fh, '+<', undef"
    print: $fh, "the right read stuff"
    ok: (seek: $fh, 0, SEEK_SET), "seek to zero"
    my $data = ~< $fh
    is: $data, "the right read stuff", "found the right stuff"





