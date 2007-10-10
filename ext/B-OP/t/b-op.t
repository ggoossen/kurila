#!/usr/bin/perl -w

use Test::More tests => 4;

use B qw|svref_2object|;

{
    # cop_io
    use open IN  => ":crlf", OUT => ":bytes";
    sub foo {
        return @_ + 1;
    }

    my $cop = svref_2object(\&foo)->START;
    is ref($cop), "B::COP", "start opcode";
    is $cop->line, 11, '&foo line number';
    isa_ok($cop->io, "B::PV");
    is $cop->io->sv, ":crlf\0:bytes";
}
