
package Net::Config;
# $Id: //depot/libnet/Net/Config.pm#6 $

require Exporter;
use vars qw(@ISA @EXPORT %NetConfig $VERSION $CONFIGURE $LIBNET_CFG);
use Socket qw(inet_aton inet_ntoa);
use strict;

@EXPORT  = qw(%NetConfig);
@ISA     = qw(Net::LocalCfg Exporter);
$VERSION = "1.04";

eval { local $SIG{__DIE__}; require Net::LocalCfg };

%NetConfig = (
    nntp_hosts => [],
    snpp_hosts => [],
    pop3_hosts => [],
    smtp_hosts => [],
    ph_hosts => [],
    daytime_hosts => [],
    time_hosts => [],
    inet_domain => undef,
    ftp_firewall => undef,
    ftp_ext_passive => 0,
    ftp_int_passive => 0,
    test_hosts => 1,
    test_exist => 1,
);

my $file = __FILE__;
my $ref;
$file =~ s/Config.pm/libnet.cfg/;
if ( -f $file ) {
    $ref = eval { do $file };
    if (ref($ref) eq 'HASH') {
	%NetConfig = (%NetConfig, %{ $ref });
	$LIBNET_CFG = $file;
    }
}
if ($< == $> and !$CONFIGURE)  {
    my $home = eval { (getpwuid($>))[7] } || $ENV{HOME};
    $file = $home . "/.libnetrc";
    $ref = eval { do $file } if -f $file;
    %NetConfig = (%NetConfig, %{ $ref })
	if ref($ref) eq 'HASH';	
}
my ($k,$v);
while(($k,$v) = each %NetConfig) {
    $v = [ $v ]
	if($k =~ /_hosts$/ && !ref($v));
}

# Take a hostname and determine if it is inside te firewall

sub requires_firewall {
    shift; # ignore package
    my $host = shift;

    return 0 unless defined $NetConfig{'ftp_firewall'};

    $host = inet_aton($host) or return -1;
    $host = inet_ntoa($host);

    if(exists $NetConfig{'local_netmask'}) {
	my $quad = unpack("N",pack("C*",split(/\./,$host)));
	my $list = $NetConfig{'local_netmask'};
	$list = [$list] unless ref($list);
	foreach (@$list) {
	    my($net,$bits) = (m#^(\d+\.\d+\.\d+\.\d+)/(\d+)$#) or next;
	    my $mask = ~0 << (32 - $bits);
	    my $addr = unpack("N",pack("C*",split(/\./,$net)));

	    return 0 if (($addr & $mask) == ($quad & $mask));
	}
	return 1;
    }

    return 0;
}

use vars qw(*is_external);
*is_external = \&requires_firewall;

1;

__END__

=head1 NAME

Net::Config - Local configuration data for libnet

=head1 SYNOPSYS

    use Net::Config qw(%NetConfig);

=head1 DESCRIPTION

C<Net::Config> holds configuration data for the modules in the libnet
distribuion. During installation you will be asked for these values.

The configuration data is held globally in a file in the perl installation
tree, but a user may override any of these values by providing thier own. This
can be done by having a C<.libnetrc> file in thier home directory. This file
should return a reference to a HASH containing the keys described below.
For example

    # .libnetrc
    {
        nntp_hosts => [ "my_prefered_host" ],
	ph_hosts   => [ "my_ph_server" ],
    }
    __END__

=head1 METHODS

C<Net::Config> defines the following methods. They are methods as they are
invoked as class methods. This is because C<Net::Config> inherits from
C<Net::LocalCfg> so you can override these methods if you want.

=over 4

=item requires_firewall HOST

Attempts to determine if a given host is outside your firewall. Possible
return values are.

  -1  Cannot lookup hostname
   0  Host is inside firewall (or there is no ftp_firewall entry)
   1  Host is outside the firewall

This is done by using hostname lookup and the C<local_netmask> entry in
the configuration data.

=back

=head1 NetConfig VALUES

=over 4

=item nntp_hosts

=item snpp_hosts

=item pop3_hosts

=item smtp_hosts

=item ph_hosts

=item daytime_hosts

=item time_hosts

Each is a reference to an array of hostnames (in order of preference),
which should be used for the given protocol

=item inet_domain

Your internet domain name

=item ftp_firewall

If you have an FTP proxy firewall (B<NOT> a HTTP or SOCKS firewall)
then this value should be set to the firewall hostname. If your firewall
does not listen to port 21, then this value should be set to
C<"hostname:port"> (eg C<"hostname:99">)

=item ftp_ext_passive

=item ftp_int_pasive

FTP servers normally work on a non-passive mode. That is when you want to
transfer data you have to tell the server the address and port to
connect to.

With some firewalls this does not work as te server cannot
connect to your machine (because you are beind a firewall) and the firewall
does not re-write te command. In this case you should set C<ftp_ext_passive>
to a I<true> value.

Some servers are configured to only work in passive mode. If you have
one of these you can force C<Net::FTP> to always transfer in passive
mode, when not going via a firewall, by cetting C<ftp_int_passive> to
a I<true> value.

=item local_netmask

A reference to a list of netmask strings in the form C<"134.99.4.0/24">.
These are used by the C<requires_firewall> function to determine if a given
host is inside or outside your firewall.

=back

The following entries are used during installation & testing on the
libnet package

=over 4

=item test_hosts

If true them C<make test> may attempt to connect to hosts given in the
configuration.

=item test_exists

If true the C<Configure> will check each hostname given that it exists

=back

=cut
