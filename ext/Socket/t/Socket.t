#!./perl

use Config

use Test::More

our $has_alarm
BEGIN 
    $has_alarm = config_value: 'd_alarm'


use Socket < qw(:all)
use signals

plan: tests => 17

my $has_echo = $^OS_NAME ne 'MSWin32'
my $alarmed = 0
sub arm      { $alarmed = 0; alarm: shift if $has_alarm }
sub alarmed  { $alarmed = 1 }
(signals::handler: "ALRM") = &alarmed                    if $has_alarm

if ((socket: my $t, PF_INET, SOCK_STREAM, IPPROTO_TCP))

    arm: 5
    my $host = $^OS_NAME eq 'MacOS' ||
        ($^OS_NAME eq 'irix' && (config_value: 'osvers') == 5) ??
        '127.0.0.1' !! 'localhost'
    my $localhost = inet_aton: $host

    :SKIP
        do
        if ( (not: $has_echo && defined $localhost && (connect: $t,(pack_sockaddr_in: 7,$localhost)) ) )

            print: $^STDOUT, "# You're allowed to fail tests 2 and 3 if\n"
            print: $^STDOUT, "# the echo service has been disabled or if your\n"
            print: $^STDOUT, "# gethostbyname() cannot resolve your localhost.\n"
            print: $^STDOUT, "# 'Connection refused' indicates disabled echo service.\n"
            print: $^STDOUT, "# 'Interrupted system call' indicates a hanging echo service.\n"
            print: $^STDOUT, "# Error: $^OS_ERROR\n"
            skip: "failed something", 2
        

        arm: 0

        ok: 2

        print: $^STDOUT, "# Connected to " .
                   (inet_ntoa: ( <(unpack_sockaddr_in: (getpeername: $t)))[[1]])."\n"

        arm: 5
        syswrite: $t,"hello",5
        arm: 0

        arm: 5
        my $read = sysread: $t,my $buff,10	# Connection may be granted, then closed!
        arm: 0

        while ($read +> 0 && (length: $buff) +< 5)
            # adjust for fact that TCP doesn't guarantee size of reads/writes
            arm: 5
            $read = sysread: $t,$buff,10,(length: $buff)
            arm: 0
        
        ok: ($read == 0 || $buff eq "hello")
    
else
    print: $^STDOUT, "# Error: $^OS_ERROR\n"
    ok: 0


if( (socket: my $s, PF_INET,SOCK_STREAM, IPPROTO_TCP) )
    ok: 1

    arm: 5

    :SKIP
        do
        if ( (not: $has_echo && (connect: $s,(pack_sockaddr_in: 7,INADDR_LOOPBACK)) ) )
            print: $^STDOUT, "# You're allowed to fail tests 5 and 6 if\n"
            print: $^STDOUT, "# the echo service has been disabled.\n"
            print: $^STDOUT, "# 'Interrupted system call' indicates a hanging echo service.\n"
            print: $^STDOUT, "# Error: $^OS_ERROR\n"
            skip: "echo skipped", 2
        

        arm: 0

        ok: 1

        print: $^STDOUT, "# Connected to " .
                   (inet_ntoa: ( <(unpack_sockaddr_in: (getpeername: $s)))[[1]])."\n"

        arm: 5
        syswrite: $s,"olleh",5
        arm: 0

        arm: 5
        my $read = sysread: $s,my $buff,10	# Connection may be granted, then closed!
        arm: 0

        while ($read +> 0 && (length: $buff) +< 5)
            # adjust for fact that TCP doesn't guarantee size of reads/writes
            arm: 5
            $read = sysread: $s,$buff,10,(length: $buff)
            arm: 0
        
        ok: ($read == 0 || $buff eq "olleh")
    
else
    print: $^STDOUT, "# Error: $^OS_ERROR\n"
    ok: 0


# warnings
dies_like:  sub (@< @_) { (sockaddr_in: 1,2,3,4,5,6) }
            qr/usage: .../ 

is: (inet_ntoa: (inet_aton: "10.20.30.40")), "10.20.30.40"
is: (inet_ntoa: "\x{a}\x{14}\x{1e}\x{28}"), "10.20.30.40"
# Thest that whatever we give into pack/unpack_sockaddr retains
# the value thru the entire chain.
is: (inet_ntoa: (unpack_sockaddr_in:  (pack_sockaddr_in: 100, (inet_aton: "10.250.230.10")))[1]), '10.250.230.10'
do
    my (@: $port,$addr) =  unpack_sockaddr_in: (pack_sockaddr_in: 100,"\x{a}\x{a}\x{a}\x{a}")
    is: $port, 100
    is: (inet_ntoa: $addr), "10.10.10.10"


dies_like:  sub (@< @_) { (inet_ntoa: "\x{a}\x{14}\x{1e}\x{190}") }
            qr/^Bad arg length for Socket::inet_ntoa, length is 5, should be 4/ 

is: (sockaddr_family: (pack_sockaddr_in: 100,(inet_aton: "10.250.230.10"))), AF_INET

dies_like:  sub (@< @_) { (sockaddr_family: "") }
            qr/^Bad arg length for Socket::sockaddr_family, length is 0, should be at least \d+/ 

:SKIP do
    skip: 2, "no inetntop or inetaton" if not: (config_value: 'd_inetntop') && (config_value: 'd_inetaton')
    ok: (inet_ntop: AF_INET, (inet_pton: AF_INET, "10.20.30.40")) eq "10.20.30.40"
    ok: (inet_ntop: AF_INET, (inet_aton: "10.20.30.40")) eq "10.20.30.40"
    ok: (lc: (inet_ntop: AF_INET6, (inet_pton: AF_INET6, "2001:503:BA3E::2:30"))) eq "2001:503:ba3e::2:30"
