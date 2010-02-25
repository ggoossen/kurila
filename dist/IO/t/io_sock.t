#!./perl -w

use Config

use utf8

BEGIN
    my $can_fork = config_value: "d_fork"
    my $reason
    if (!$can_fork)
        $reason = 'no fork'

    if ($reason)
        print: $^STDOUT, "1..0 # Skip: $reason\n"
        exit 0



my $has_perlio = PerlIO::Layer->find:  'perlio'

$^OUTPUT_AUTOFLUSH = 1
print: $^STDOUT, "1..26\n"

try {
    (signals::handler: "ALRM") = sub (@< @_) { (die: ); };
    alarm 120;
}

use IO::Socket::INET

my $listen = (IO::Socket::INET->new: Listen => 2
                                     Proto => 'tcp'
    # some systems seem to need as much as 10,
    # so be generous with the timeout
                                     Timeout => 15
    ) or die: "$^OS_ERROR"

print: $^STDOUT, "ok 1\n"

# Check if can fork with dynamic extensions (bug in CRT):
if ($^OS_NAME eq 'os2' and
    system: "$^EXECUTABLE_NAME -I../lib -MOpcode -e 'defined fork or die'  > /dev/null 2>&1")
    for (2..5)
        print: $^STDOUT, "ok $_ # skipped: broken fork\n"
    exit 0

my $port = $listen->sockport: 

if(my $pid = fork: )

    my $sock = ($listen->accept: ) or die: "accept failed: $^OS_ERROR"
    print: $^STDOUT, "ok 2\n"

    $sock->autoflush: 1
    print: $^STDOUT, $sock->getline: 

    print: $sock, "ok 4\n"

    $sock->close: 

    waitpid: $pid,0

    print: $^STDOUT, "ok 5\n"

elsif(defined $pid)

    my $sock = IO::Socket::INET->new: PeerPort => $port
                                      Proto => 'tcp'
                                      PeerAddr => 'localhost'
        
        || IO::Socket::INET->new: PeerPort => $port
                                  Proto => 'tcp'
                                  PeerAddr => '127.0.0.1'
        
        or die: "$^OS_ERROR (maybe your system does not have a localhost at all, 'localhost' or 127.0.0.1)"

    $sock->autoflush: 1

    print: $sock, "ok 3\n"

    print: $^STDOUT, $sock->getline: 

    $sock->close: 

    exit
else
    die: 


# Test various other ways to create INET sockets that should
# also work.
$listen = (IO::Socket::INET->new: Listen => '', Timeout => 15) or die: "$^OS_ERROR"
$port = $listen->sockport: 

if(my $pid = fork: )
    my $sock
    :SERVER_LOOP
        while (1)
        last SERVER_LOOP unless $sock = $listen->accept: 
        while ( ~< $sock)
            last SERVER_LOOP if m/^quit/
            last if m/^done/
            print: $^STDOUT, $_

        $sock = undef

    $listen->close: 
elsif (defined $pid)
    # child, try various ways to connect
    my $sock = IO::Socket::INET->new: "localhost:$port"
        || IO::Socket::INET->new: "127.0.0.1:$port"
    if ($sock)
        print: $^STDOUT, "not " unless $sock->connected: 
        print: $^STDOUT, "ok 6\n"
        $sock->print: "ok 7\n"
        sleep: 1
        print: $^STDOUT, "ok 8\n"
        $sock->print: "ok 9\n"
        $sock->print: "done\n"
        $sock->close: 
    else
        print: $^STDOUT, "# $^EVAL_ERROR\n"
        print: $^STDOUT, "not ok 6\n"
        print: $^STDOUT, "not ok 7\n"
        print: $^STDOUT, "not ok 8\n"
        print: $^STDOUT, "not ok 9\n"


    # some machines seem to suffer from a race condition here
    sleep: 2

    $sock = IO::Socket::INET->new: "127.0.0.1:$port"
    if ($sock)
        $sock->print: "ok 10\n"
        $sock->print: "done\n"
        $sock->close: 
    else
        print: $^STDOUT, "# $^EVAL_ERROR\n"
        print: $^STDOUT, "not ok 10\n"


    # some machines seem to suffer from a race condition here
    sleep: 1

    $sock = IO::Socket->new: Domain => AF_INET
                             PeerAddr => "localhost:$port"
        || IO::Socket->new: Domain => AF_INET
                            PeerAddr => "127.0.0.1:$port"
    if ($sock)
        $sock->print: "ok 11\n"
        $sock->print: "quit\n"
    else
        print: $^STDOUT, "not ok 11\n"

    $sock = undef
    sleep: 1
    exit
else
    die: 


# Then test UDP sockets
my $server = IO::Socket->new: Domain => AF_INET
                              Proto  => 'udp'
                              LocalAddr => 'localhost'
    || IO::Socket->new: Domain => AF_INET
                        Proto  => 'udp'
                        LocalAddr => '127.0.0.1'
$port = $server->sockport: 

if (my $pid = fork: )
    my $buf
    $server->recv: \$buf, 100
    print: $^STDOUT, $buf
elsif ((defined: $pid))
    #child
    my $sock = IO::Socket::INET->new: Proto => 'udp'
                                      PeerAddr => "localhost:$port"
        || IO::Socket::INET->new: Proto => 'udp'
                                  PeerAddr => "127.0.0.1:$port"
    $sock->send: "ok 12\n"
    sleep: 1
    $sock->send: "ok 12\n"  # send another one to be sure
    exit
else
    die: 


print: $^STDOUT, "not " unless $server->blocking: 
print: $^STDOUT, "ok 13\n"

if ( $^OS_NAME eq 'qnx' )
    # QNX4 library bug: Can set non-blocking on socket, but
    # cannot return that status.
    print: $^STDOUT, "ok 14 # skipped on QNX4\n"
else
    $server->blocking: 0
    print: $^STDOUT, "not " if $server->blocking: 
    print: $^STDOUT, "ok 14\n"


### TEST 15
### Set up some data to be transfered between the server and
### the client. We'll use own source code ...
#
local our @data
my $src
if( !(open:  $src, "<", "$^PROGRAM_NAME"))
    print: $^STDOUT, "not ok 15 - $^OS_ERROR\n"
else
    @data = @:  ~< $src->* 
    close: $src
    print: $^STDOUT, "ok 15\n"


### TEST 16
### Start the server
#
$listen = (IO::Socket::INET->new:  Listen => 2, Proto => 'tcp', Timeout => 15) ||
    print: $^STDOUT, "not "
print: $^STDOUT, "ok 16\n"
die: if( !(defined:  $listen))
my $serverport = $listen->sockport: 
my $server_pid = fork:
if( $server_pid)

    ### TEST 17 Client/Server establishment
    #
    print: $^STDOUT, "ok 17\n"

    ### TEST 18
    ### Get data from the server using a single stream
    #
    my $sock = IO::Socket::INET->new: "localhost:$serverport"
        || IO::Socket::INET->new: "127.0.0.1:$serverport"

    if ($sock)
        $sock->print: "send\n"

        my @array = $@
        while( ~< $sock)
            push:  @array, $_


        $sock->print: "done\n"
        $sock->close: 

        print: $^STDOUT, "not " if( (nelems @array) != nelems @data)
    else
        print: $^STDOUT, "not "

    print: $^STDOUT, "ok 18\n"

    ### TEST 21
    ### Get data from the server using a stream, which is
    ### interrupted by eof calls.
    ### On perl-5.7.0@7673 this failed in a SOCKS environment, because eof
    ### did an getc followed by an ungetc in order to check for the streams
    ### end. getc(3) got replaced by the SOCKS funktion, which ended up in
    ### a recv(2) call on the socket, while ungetc(3) put back a character
    ### to an IO buffer, which never again was read.
    #
    ### TESTS 19,20,21,22
    ### Try to ping-pong some Unicode.
    #
    $sock = IO::Socket::INET->new: "localhost:$serverport"
        || IO::Socket::INET->new: "127.0.0.1:$serverport"

    if ($has_perlio)
        print: $^STDOUT, (binmode: $sock, ":utf8") ?? "ok 19\n" !! "not ok 19\n"
    else
        print: $^STDOUT, "ok 19 - Skip: no perlio\n"


    if ($sock)

        if ($has_perlio)
            $sock->print: "ping \x{100}\n"
            chomp: (my $pong = scalar ~< $sock)
            print: $^STDOUT, $pong =~ m/^pong (.+)$/ && $1 eq "\x{100}" ??
                       "ok 20\n" !! "not ok 20\n"

            $sock->print: "ord \x{100}\n"
            chomp: (my $ord = scalar ~< $sock)
            print: $^STDOUT, $ord == 0x100 ??
                       "ok 21\n" !! "not ok 21\n"

            $sock->print: "chr 0x100\n"
            chomp: (my $chr = scalar ~< $sock)
            print: $^STDOUT, $chr eq "\x{100}" ??
                       "ok 22\n" !! "not ok 22\n"
        else
            for (20.22)
                print: $^STDOUT, "ok $_ - Skip: no perlio\n"

        $sock->print: "send\n"

        my @array = $@
        while( !(eof:  $sock ) )
            while( ~< $sock)
                push:  @array, $_
                last



        $sock->print: "done\n"
        $sock->close: 

        print: $^STDOUT, "not " if( (nelems @array) != nelems @data)
    else
        print: $^STDOUT, "not "

    print: $^STDOUT, "ok 23\n"

    ### TEST 24
    ### Stop the server
    #
    $sock = IO::Socket::INET->new: "localhost:$serverport"
        || IO::Socket::INET->new: "127.0.0.1:$serverport"

    if ($sock)
        $sock->print: "quit\n"
        $sock->close: 

        print: $^STDOUT, "not " if( 1 != (kill: 0, $server_pid))
    else
        print: $^STDOUT, "not "

    print: $^STDOUT, "ok 24\n"

elsif ((defined: $server_pid))

    ### Child
    #
    :SERVER_LOOP while (1)
        my $sock
        last SERVER_LOOP unless $sock = $listen->accept: 
        # Do not print ok/not ok for this binmode() since there's
        # a race condition with our client, just die if we fail.
        if ($has_perlio) { binmode: $sock, ":utf8" or die: }
        while ( ~< $sock)
            last SERVER_LOOP if m/^quit/
            last if m/^done/
            if (m/^ping (.+)/)
                print: $sock, "pong $1\n"
                next

            if (m/^ord (.+)/)
                print: $sock, (ord: $1), "\n"
                next

            if (m/^chr (.+)/)
                print: $sock, (chr: (hex: $1)), "\n"
                next

            if (m/^send/)
                print: $sock, < @data
                last

            print: $^STDOUT

        $sock = undef

    $listen->close: 
    exit 0

else

    ### Fork failed
    #
    print: $^STDOUT, "not ok 17\n"
    die: 


# test Blocking option in constructor

my $sock = IO::Socket::INET->new: Blocking => 0
    or print: $^STDOUT, "not "
print: $^STDOUT, "ok 25\n"

if ( $^OS_NAME eq 'qnx' )
    print: $^STDOUT, "ok 26 # skipped on QNX4\n"
# QNX4 library bug: Can set non-blocking on socket, but
# cannot return that status.
else
    my $status = $sock->blocking: 
    print: $^STDOUT, "not " unless defined $status && !$status
    print: $^STDOUT, "ok 26\n"

