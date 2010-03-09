use Test::More 'no_plan'

use IO::Socket::INET

# proper setting of $^EVAL_ERROR on error
dies_like: sub () IO::Socket::INET->new: Proto => 'tcp'
                                         Port => 'foo'
                                         PeerAddr => '127.0.0.1'
                      or die:
           qr/Cannot determine remote port/
