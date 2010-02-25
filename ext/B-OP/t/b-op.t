#!/usr/bin/perl -w

use Test::More tests => 2

use B < qw|svref_2object|
use B::OP

do
    # cop_io
    use open IN  => ":crlf", OUT => ":bytes"
    sub foo
        return (nelems @_) + 1

    my $op = (svref_2object: \&foo)->START: 
    is: (ref: $op), "B::COP", "start opcode"


do
    # new
    my $op = B::OP->new: 'null', 0, undef
    ok: ($op->size: )
    $op->free: 

