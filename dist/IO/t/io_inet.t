use Test::More 'no_plan'

use IO::Socket::INET

is_deeply: IO::Socket::INET::_sock_info: '127.0.0.1', 'ftp(21)', 'tcp'
           @: '127.0.0.1', '21', Socket::IPPROTO_TCP:

dies_like: sub () IO::Socket::INET::_sock_info: '127.0.0.1', 'foo', 'tcp'
           qr/Bad service 'foo'/

