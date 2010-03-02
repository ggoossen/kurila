#! kurila

use Test::More 'no_plan'

use IO::Socket

my $socket = IO::Socket->new

ok: $socket

$socket->timeout = 3
is: $socket->timeout, 3, "setting+getting of socket timeout"

