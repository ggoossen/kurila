#!perl -w

use IO::Handle # ungetc()

use Test::More tests => 19

require_ok: q{PerlIO::scalar}

my $s = 'foo'
Internals::SvREADONLY: \$s, 1
dies_like:  { $s = 'bar' }
            qr/Modification of a read-only value/, '$s is readonly' 

ok: (open: my $io, '<', \$s), 'open'

getc $io

my $a = ord 'A'

diag: "buffer[$s]"
is: ($io->ungetc: $a), $a, 'ungetc'
diag: "buffer[$s]"

is: (getc: $io), (chr: $a), 'getc'

is: $s, 'foo', '$s remains "foo"'

is: (getc: $io), 'o', 'getc/2'
is: (getc: $io), 'o', 'getc/3'

for my $c ($a .. ($a+10))
    is: ($io->ungetc: $c), $c, "ungetc($c)"
