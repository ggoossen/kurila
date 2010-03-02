#!./perl

use warnings

use Test::More

BEGIN
    if ((env::var: 'PERL_CORE_MINITEST'))
        plan: skip_all => "no Fcntl under miniperl"
    unless ((PerlIO::Layer->find: 'perlio'))
        plan: skip_all => "not perlio"

    use Config
    unless (" $((config_value: 'extensions')) " =~ m/ Fcntl /)
        plan: skip_all => "no Fcntl (how did you get this far?)"

plan: tests => 6

use Fcntl ':seek'

do
    (ok: ((open: my $fh, "+>", undef)), "open my \$fh, '+>', undef");
    print: $fh, "the right write stuff";
    (ok: (seek: $fh, 0, SEEK_SET), "seek to zero");
    my $data = ~<$fh
    (is: $data, "the right write stuff", "found the right stuff");

do
    (ok: ((open: my $fh, "+<", undef)), "open my \$fh, '+<', undef");
    print: $fh, "the right read stuff";
    (ok: (seek: $fh, 0, SEEK_SET), "seek to zero");
    my $data = ~<$fh
    (is: $data, "the right read stuff", "found the right stuff");




