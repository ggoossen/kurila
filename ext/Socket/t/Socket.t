#!./perl

use Config;

use Test::More;

our $has_alarm;
BEGIN {
    if (%Config{'extensions'} !~ m/\bSocket\b/ && 
        !(($^O eq 'VMS') && %Config{d_socket})) {
	print "1..0\n";
	exit 0;
    }
    $has_alarm = %Config{d_alarm};
}
	
use Socket < qw(:all);

plan tests => 14;

my $has_echo = $^O ne 'MSWin32';
my $alarmed = 0;
sub arm      { $alarmed = 0; alarm(shift) if $has_alarm }
sub alarmed  { $alarmed = 1 }
%SIG{ALRM} = \&alarmed                    if $has_alarm;

if (socket(T, PF_INET, SOCK_STREAM, IPPROTO_TCP)) {

  arm(5);
  my $host = $^O eq 'MacOS' || ($^O eq 'irix' && %Config{osvers} == 5) ?
                 '127.0.0.1' : 'localhost';
  my $localhost = inet_aton($host);

  SKIP:
  {
      if ( not ($has_echo && defined $localhost && connect(T,pack_sockaddr_in(7,$localhost)) ) ) {

          print "# You're allowed to fail tests 2 and 3 if\n";
          print "# the echo service has been disabled or if your\n";
          print "# gethostbyname() cannot resolve your localhost.\n";
          print "# 'Connection refused' indicates disabled echo service.\n";
          print "# 'Interrupted system call' indicates a hanging echo service.\n";
          print "# Error: $!\n";
          skip "failed something", 2;
      }

      arm(0);

        ok 2;

	print "# Connected to " .
		inet_ntoa(( <unpack_sockaddr_in(getpeername(T)))[[1]])."\n";

	arm(5);
	syswrite(T,"hello",5);
	arm(0);

	arm(5);
	my $read = sysread(T,my $buff,10);	# Connection may be granted, then closed!
	arm(0);

	while ($read +> 0 && length($buff) +< 5) {
	    # adjust for fact that TCP doesn't guarantee size of reads/writes
	    arm(5);
	    $read = sysread(T,$buff,10,length($buff));
	    arm(0);
	}
	ok(($read == 0 || $buff eq "hello"));
  }
}
else {
	print "# Error: $!\n";
        ok 0;
}

if( socket(S, PF_INET,SOCK_STREAM, IPPROTO_TCP) ){
    ok 1;

    arm(5);
  
  SKIP:
    {
        if ( not ($has_echo && connect(S,pack_sockaddr_in(7,INADDR_LOOPBACK)) ) ){
            print "# You're allowed to fail tests 5 and 6 if\n";
            print "# the echo service has been disabled.\n";
            print "# 'Interrupted system call' indicates a hanging echo service.\n";
            print "# Error: $!\n";
            skip "echo skipped", 2;
        }

        arm(0);

        ok 1;

	print "# Connected to " .
		inet_ntoa(( <unpack_sockaddr_in(getpeername(S)))[[1]])."\n";

	arm(5);
	syswrite(S,"olleh",5);
	arm(0);

	arm(5);
	my $read = sysread(S,my $buff,10);	# Connection may be granted, then closed!
	arm(0);

	while ($read +> 0 && length($buff) +< 5) {
	    # adjust for fact that TCP doesn't guarantee size of reads/writes
	    arm(5);
	    $read = sysread(S,$buff,10,length($buff));
	    arm(0);
	}
	ok(($read == 0 || $buff eq "olleh"));
    }
}
else {
	print "# Error: $!\n";
        ok 0;
}

# warnings
dies_like( sub { sockaddr_in(1,2,3,4,5,6) },
           qr/usage: .../ );

is(inet_ntoa(inet_aton("10.20.30.40")), "10.20.30.40");
is(inet_ntoa("\x{a}\x{14}\x{1e}\x{28}"), "10.20.30.40");
# Thest that whatever we give into pack/unpack_sockaddr retains
# the value thru the entire chain.
is(inet_ntoa(unpack_sockaddr_in( pack_sockaddr_in(100, inet_aton("10.250.230.10")))[1]), '10.250.230.10');
{
    my ($port,$addr) = < unpack_sockaddr_in(pack_sockaddr_in(100,"\x{a}\x{a}\x{a}\x{a}"));
    is($port, 100);
    is(inet_ntoa($addr), "10.10.10.10");
}

dies_like( sub { inet_ntoa("\x{a}\x{14}\x{1e}\x{190}") },
           qr/^Bad arg length for Socket::inet_ntoa, length is 5, should be 4/ );

is(sockaddr_family(pack_sockaddr_in(100,inet_aton("10.250.230.10"))), AF_INET);

dies_like( sub { sockaddr_family("") },
           qr/^Bad arg length for Socket::sockaddr_family, length is 0, should be at least \d+/ );
