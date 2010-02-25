#!./perl

BEGIN 
    unless ((PerlIO::Layer->find:  'perlio'))
        print: $^STDOUT, "1..0 # Skip: not perlio\n"
        exit 0


use Test::More

use utf8

plan: tests => 5

my $io

use_ok: 'IO::File'

$io = IO::File->new: 

ok: ($io->open: "io_utf8", ">:utf8"), "open >:utf8"
ok: ((print: $io, (chr: 256))), "print chr(256)"
undef $io

$io = IO::File->new: 
ok: ($io->open: "io_utf8", "<:utf8"), "open <:utf8"
is: (ord:  ~< $io), 256, "readline chr(256)"
undef $io

END 
    1 while unlink: "io_utf8"

