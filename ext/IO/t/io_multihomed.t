#!./perl

use Config;

BEGIN {
    my $can_fork = config_value("d_fork");
    my $reason;
    if (!$can_fork) {
        $reason = 'no fork';
    }
    if ($reason) {
	print "1..0 # Skip: $reason\n";
	exit 0;
    }
}

$^OUTPUT_AUTOFLUSH = 1;

print "1..8\n";

try {
    signals::set_handler(ALRM => sub { die; });
    alarm 60;
};

package Multi;
require IO::Socket::INET;
our @ISA=qw(IO::Socket::INET);

use Socket < qw(inet_aton inet_ntoa unpack_sockaddr_in);

sub _get_addr
{
    my@($sock,$addr_str, $multi) =  @_;
    #print "_get_addr($sock, $addr_str, $multi)\n";

    print "not " unless $multi;
    print "ok 2\n";

     @(
     # private IP-addresses which I hope does not work anywhere :-)
     inet_aton("10.250.230.10"),
     inet_aton("10.250.230.12"),
     inet_aton("127.0.0.1")        # loopback
    )
}

sub connect
{
    my $self = shift;
    if ((nelems @_) == 1) {
	my@($port, $addr) =  unpack_sockaddr_in(@_[0]);
	$addr = inet_ntoa($addr);
	#print "connect($self, $port, $addr)\n";
	if($addr eq "10.250.230.10") {
	    print "ok 3\n";
	    return 0;
	}
	if($addr eq "10.250.230.12") {
	    print "ok 4\n";
	    return 0;
	}
    }
    $self->SUPER::connect(< @_);
}



package main;

use IO::Socket;

my $listen = IO::Socket::INET->new(Listen => 2,
				Proto => 'tcp',
				Timeout => 5,
			       ) or die "$^OS_ERROR";

print "ok 1\n";

my $port = $listen->sockport;

if(my $pid = fork()) {

    my $sock = $listen->accept() or die "$^OS_ERROR";
    print "ok 5\n";

    print $sock->getline();
    print $sock "ok 7\n";

    waitpid($pid,0);

    $sock->close;

    print "ok 8\n";

} elsif(defined $pid) {

    my $sock = Multi->new(PeerPort => $port,
		       Proto => 'tcp',
		       PeerAddr => 'localhost',
		       MultiHomed => 1,
		       Timeout => 1,
		      ) or die "$^OS_ERROR";

    print $sock "ok 6\n";
    sleep(1); # race condition
    print $sock->getline();

    $sock->close;

    exit;
} else {
    die;
}
