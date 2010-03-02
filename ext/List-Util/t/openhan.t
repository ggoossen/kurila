#!./perl

use Config

use Test::More tests => 4
use Scalar::Util < qw(openhandle)

ok: exists &openhandle, 'defined'

my $fh = $^STDERR
is: (openhandle: $fh), $fh, 'STDERR'

is: (fileno: (openhandle: $^STDERR)), (fileno: $^STDERR), 'fileno(STDERR)'

is: (openhandle: \*CLOSED), undef, 'closed'

