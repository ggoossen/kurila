#!./perl

use Config

BEGIN 
    my $reason

    if ($^OS_NAME eq 'apollo')
        $reason = "unknown *FIXME*"
    
    if ($reason)
        print: $^STDOUT, "1..0 # Skip: $reason\n"
        exit 0

sub compare_addr
    no utf8
    my $a = shift
    my $b = shift
    if ((length: $a) != length $b)
        my $min = ((length: $a) +< length $b) ?? (length: $a) !! length $b
        if ($min and (substr: $a, 0, $min) eq (substr: $b, 0, $min))
            printf: $^STDOUT, "# Apparently: \%d bytes junk at the end of \%s\n# \%s\n"
                    (abs: (length: $a) - (length: $b))
                    @_[(length: $a) +< (length: $b) ?? 1 !! 0]
                    "consider decreasing bufsize of recfrom."
            substr: $a, $min, undef, ""
            substr: $b, $min, undef, ""
        
        return 0
    
    my @a = unpack_sockaddr_in: $a
    my @b = unpack_sockaddr_in: $b
    "@a[0]@a[1]" eq "@b[0]@b[1]"


$^OUTPUT_AUTOFLUSH = 1
print: $^STDOUT, "1..7\n"

require 'test.pl'
(watchdog: 15)

use Socket
use IO::Socket < qw(AF_INET SOCK_DGRAM INADDR_ANY)
use IO::Socket::INET

my $udpa = IO::Socket::INET->new: Proto => 'udp', LocalAddr => 'localhost'
    || IO::Socket::INET->new: Proto => 'udp', LocalAddr => '127.0.0.1'
    or die: "$^OS_ERROR (maybe your system does not have a localhost at all, 'localhost' or 127.0.0.1)"

print: $^STDOUT, "ok 1\n"

my $udpb = IO::Socket::INET->new: Proto => 'udp', LocalAddr => 'localhost'
    || IO::Socket::INET->new: Proto => 'udp', LocalAddr => '127.0.0.1'
    or die: "$^OS_ERROR (maybe your system does not have a localhost at all, 'localhost' or 127.0.0.1)"

print: $^STDOUT, "ok 2\n"

$udpa->send: "ok 4\n",0, ($udpb->sockname: )

print: $^STDOUT, "not "
    unless compare_addr: ($udpa->peername: ),($udpb->sockname: ), 'peername', 'sockname'
print: $^STDOUT, "ok 3\n"

my $where = $udpb->recv: \(my $buf=""),5
print: $^STDOUT, $buf

my @xtra = $@

unless((compare_addr: $where,($udpa->sockname: ), 'recv name', 'sockname'))
    print: $^STDOUT, "not "
    @xtra = @: 0, <$udpa->sockname: 

print: $^STDOUT, "ok 5\n"

$udpb->send: "ok 6\n",< @xtra
$udpa->recv: \($buf=""),5
print: $^STDOUT, $buf

print: $^STDOUT, "not " if $udpa->connected: 
print: $^STDOUT, "ok 7\n"
