#!./perl

use Config

BEGIN 
    my $can_fork = config_value: "d_fork"
    my $reason
    if (!$can_fork)
        $reason = 'no fork'
    
    if ($reason)
        print: $^STDOUT, "1..0 # Skip: $reason\n"
        exit 0


$^OUTPUT_AUTOFLUSH = 1

print: $^STDOUT, "1..8\n"

require '../../t/test.pl'

(watchdog: 15)

package Multi
require IO::Socket::INET
our @ISA=qw(IO::Socket::INET)

use Socket < qw(inet_aton inet_ntoa unpack_sockaddr_in)

sub _get_addr($sock,$addr_str, $multi)
    #print "_get_addr($sock, $addr_str, $multi)\n";

    print: $^STDOUT, "not " unless $multi
    print: $^STDOUT, "ok 2\n"

    @:
     # private IP-addresses which I hope does not work anywhere :-)
     inet_aton: "10.250.230.10"
     inet_aton: "10.250.230.12"
     inet_aton: "127.0.0.1"        # loopback
        


sub connect
    my $self = shift
    if ((nelems @_) == 1)
        my(@: $port, $addr) =  unpack_sockaddr_in: @_[0]
        $addr = inet_ntoa: $addr
        #print "connect($self, $port, $addr)\n";
        if($addr eq "10.250.230.10")
            print: $^STDOUT, "ok 3\n"
            return 0
        
        if($addr eq "10.250.230.12")
            print: $^STDOUT, "ok 4\n"
            return 0


     $self->SUPER::connect: < @_




package main

use IO::Socket

my $listen = (IO::Socket::INET->new: Listen => 2
                                     Proto => 'tcp'
                                     Timeout => 5
    ) or die: "$^OS_ERROR"

print: $^STDOUT, "ok 1\n"

my $port = $listen->sockport

if(my $pid = fork())

    my $sock = $listen->accept or die: "$^OS_ERROR"
    print: $^STDOUT, "ok 5\n"

    print: $^STDOUT, $sock->getline
    print: $sock, "ok 7\n"

    waitpid: $pid,0

    $sock->close

    print: $^STDOUT, "ok 8\n"

elsif(defined $pid)

    my $sock = (Multi->new: PeerPort => $port
                            Proto => 'tcp'
                            PeerAddr => 'localhost'
                            MultiHomed => 1
                            Timeout => 1
        ) or die: "$^OS_ERROR"

    print: $sock, "ok 6\n"
    sleep: 1 # race condition
    print: $^STDOUT, $sock->getline

    $sock->close

    exit
else
    die: 

