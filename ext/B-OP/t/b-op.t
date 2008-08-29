#!/usr/bin/perl -w

use Test::More tests => 3;

use B < qw|svref_2object|;

{
    # cop_io
    use open IN  => ":crlf", OUT => ":bytes";
    sub foo {
        return (nelems @_) + 1;
    }

    my $cop = svref_2object(\&foo)->START;
    is ref($cop), "B::COP", "start opcode";
    isa_ok($cop->io, "B::PV");
    is $cop->io->sv, ":crlf\0:bytes";
}

{
    # new
    my $op = B::OP->new('null', 0, undef);
    $op->free;
}
