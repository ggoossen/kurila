# IO::Socket.pm
#
# Copyright (c) 1997-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package IO::Socket


use IO::Handle
use Socket v1.3
use Carp

our(@ISA, $VERSION, @EXPORT_OK)
use Exporter
use Errno < qw|EINPROGRESS EWOULDBLOCK EISCONN|

# legacy

@ISA = qw(IO::Handle)

$VERSION = "1.30_01"

@EXPORT_OK = qw(sockatmark)

sub import
    my $pkg = shift
    if ((nelems @_) && @_[0] eq 'sockatmark') # not very extensible but for now, fast
        Exporter::export_to_level: 'IO::Socket', 1, $pkg, 'sockatmark'
    else
        my $callpkg = caller
        Exporter::export:  'Socket', $callpkg, < @_
    


sub new($class,%< %arg)
    my $sock = $class->SUPER::new: 

    $sock->autoflush: 1

    $sock->*->{+'io_socket_timeout'} = delete %arg{Timeout}

    return (scalar: %arg) ?? $sock->configure: \%arg
        !! $sock


my @domain2pkg

sub register_domain($p,$d)
    @domain2pkg[+$d] = $p


sub configure($sock,$arg)
    my $domain = delete $arg->{Domain}

    die: 'IO::Socket: Cannot configure a generic socket'
        unless defined $domain

    die: "IO::Socket: Unsupported socket domain"
        unless defined @domain2pkg[$domain]

    die: "IO::Socket: Cannot configure socket in domain '$domain'"
        unless (ref: $sock) eq "IO::Socket"

    bless: $sock, @domain2pkg[$domain]
    $sock->configure: $arg


sub socket($sock,$domain,$type,$protocol)

    socket: $sock,$domain,$type,$protocol or
        return undef

    $sock->*->{+'io_socket_domain'} = $domain
    $sock->*->{+'io_socket_type'}   = $type
    $sock->*->{+'io_socket_proto'}  = $protocol

    $sock


sub socketpair($class,$domain,$type,$protocol)
    my $sock1 = $class->new: 
    my $sock2 = $class->new: 

    socketpair: $sock1,$sock2,$domain,$type,$protocol or
        return ()

    $sock1->*->{+'io_socket_type'}  = $sock2->*->{+'io_socket_type'}  = $type
    $sock1->*->{+'io_socket_proto'} = $sock2->*->{+'io_socket_proto'} = $protocol

    return @: $sock1, $sock2


sub connect($sock, $addr)
    my $timeout = $sock->*->{?'io_socket_timeout'}
    my $err
    my $blocking

    $blocking = ($sock->blocking: 0) if $timeout
    if (!(connect: $sock, $addr))
        if (defined $timeout && ($^OS_ERROR == (EINPROGRESS: )|| $^OS_ERROR == (EWOULDBLOCK: )))
            require IO::Select

            my $sel = IO::Select->new:  $sock

            undef $^OS_ERROR
            if (!($sel->can_write: $timeout))
                $err = $^OS_ERROR || (exists &Errno::ETIMEDOUT ?? (Errno::ETIMEDOUT:  < @_ ) !! 1)
                $^EVAL_ERROR = "connect: timeout"
            elsif (!(connect: $sock,$addr) &&
                not: $^OS_ERROR == (EISCONN: )|| ($^OS_ERROR == 10022 && $^OS_NAME eq 'MSWin32')
                )
                # Some systems refuse to re-connect() to
                # an already open socket and set errno to EISCONN.
                # Windows sets errno to WSAEINVAL (10022)
                $err = $^OS_ERROR
                $^EVAL_ERROR = "connect: $^OS_ERROR"
            
        elsif ($blocking || !($^OS_ERROR == (EINPROGRESS: )|| $^OS_ERROR == (EWOULDBLOCK: )))
            $err = $^OS_ERROR
            $^EVAL_ERROR = "connect: $^OS_ERROR"
        
    

    $sock->blocking: 1 if $blocking

    $^OS_ERROR = $err if $err

    $err ?? undef !! $sock


# Enable/disable blocking IO on sockets.
# Without args return the current status of blocking,
# with args change the mode as appropriate, returning the
# old setting, or in case of error during the mode change
# undef.

sub blocking
    my $sock = shift

    return $sock->SUPER::blocking: < @_
        if $^OS_NAME ne 'MSWin32'

    # Windows handles blocking differently
    #
    # http://groups.google.co.uk/group/perl.perl5.porters/browse_thread/thread/b4e2b1d88280ddff/630b667a66e3509f?#630b667a66e3509f
    # http://msdn.microsoft.com/library/default.asp?url=/library/en-us/winsock/winsock/ioctlsocket_2.asp
    #
    # 0x8004667e is FIONBIO
    #
    # which is used to set blocking behaviour.

    # NOTE:
    # This is a little confusing, the perl keyword for this is
    # 'blocking' but the OS level behaviour is 'non-blocking', probably
    # because sockets are blocking by default.
    # Therefore internally we have to reverse the semantics.

    my $orig= !$sock->*->{?io_sock_nonblocking}

    return $orig unless (nelems @_)

    my $block = shift

    if ( !$block != !$orig )
        $sock->*->{+io_sock_nonblocking} = $block ?? 0 !! 1
        ioctl: $sock, 0x8004667e, (pack: "L!",$sock->*->{?io_sock_nonblocking})
            or return undef
    

    return $orig



sub close($sock)
    $sock->*->{+'io_socket_peername'} = undef
    $sock->SUPER::close: 


sub bind($sock, $addr)
    return (bind: $sock, $addr) ?? $sock
        !! undef


sub listen($sock,?$queue)
    $queue = 5
        unless $queue && $queue +> 0

    return (listen: $sock, $queue) ?? $sock
        !! undef


sub accept($sock, ?$pkg)
    $pkg ||= $sock
    my $timeout = $sock->*->{?'io_socket_timeout'}
    my $new = $pkg->new: Timeout => $timeout
    my $peer = undef

    if(defined $timeout)
        require IO::Select

        my $sel = IO::Select->new:  $sock

        unless ( (@:  ($sel->can_read: $timeout) ) )
            $^EVAL_ERROR = 'accept: timeout'
            $^OS_ERROR = (exists &Errno::ETIMEDOUT ?? (Errno::ETIMEDOUT:  < @_ ) !! 1)
            return
        
    

    $peer = accept: $new,$sock
        or return

    return $new


sub sockname($sock)
    getsockname: $sock


sub peername($sock)
    $sock->*->{+'io_socket_peername'} ||= getpeername: $sock


sub connected($sock)
    getpeername: $sock


sub send($sock, $buf, ?$flags, ?$to)
    $flags ||= 0
    my $peer  = $to || $sock->peername:

    croak: 'send: Cannot determine peer address'
        unless(defined $peer)

    my $r = defined: (getpeername: $sock)
        ?? send: $sock, $buf, $flags
        !! send: $sock, $buf, $flags, $peer

    # remember who we send to, if it was successful
    $sock->*->{+'io_socket_peername'} = $peer
        if (defined $to) && defined $r

    $r


sub recv($sock, $buf, $len, ?$flags)
    $flags //= 0

    # remember who we recv'd from
    $sock->*->{+'io_socket_peername'} = recv: $sock, ($buf->$=''), $len, $flags


sub shutdown($sock, $how)
    $sock->*->{+'io_socket_peername'} = undef
    shutdown: $sock, $how


sub setsockopt
    4 == (nelems: @_) or croak: '$sock->setsockopt(LEVEL, OPTNAME, OPTVAL)'
    setsockopt: @_[0],@_[1],@_[2],@_[3]


my $intsize = length: (pack: "i",0)

sub getsockopt
    3 == (nelems: @_) or croak: '$sock->getsockopt(LEVEL, OPTNAME)'
    my $r = getsockopt: @_[0],@_[1],@_[2]
    # Just a guess
    $r = unpack: "i", $r
        if(defined $r && (length: $r) == $intsize)
    $r


sub sockopt
    my $sock = shift
    (nelems @_) == 1 ?? $sock->getsockopt: SOL_SOCKET,< @_
        !! $sock->setsockopt: SOL_SOCKET,< @_


sub atmark($sock)
    sockatmark: $sock


sub timeout($sock ?= $val)
    my $r = $sock->*->{?'io_socket_timeout'}

    if ($^is_assignment)
        $sock->*->{+'io_socket_timeout'} = defined $val ?? 0 + $val !! $val

    $r


sub sockdomain($sock)
    $sock->*->{?'io_socket_domain'}


sub socktype($sock)
    $sock->*->{?'io_socket_type'}


sub protocol($sock)
    $sock->*->{?'io_socket_proto'}


1

__END__

=head1 NAME

IO::Socket - Object interface to socket communications

=head1 SYNOPSIS

    use IO::Socket;

=head1 DESCRIPTION

C<IO::Socket> provides an object interface to creating and using sockets. It
is built upon the L<IO::Handle> interface and inherits all the methods defined
by L<IO::Handle>.

C<IO::Socket> only defines methods for those operations which are common to all
types of socket. Operations which are specified to a socket in a particular 
domain have methods defined in sub classes of C<IO::Socket>

C<IO::Socket> will export all functions (and constants) defined by L<Socket>.

=head1 CONSTRUCTOR

=over 4

=item new ( [ARGS] )

Creates an C<IO::Socket>, which is a reference to a
newly created symbol (see the C<Symbol> package). C<new>
optionally takes arguments, these arguments are in key-value pairs.
C<new> only looks for one key C<Domain> which tells new which domain
the socket will be in. All other arguments will be passed to the
configuration method of the package for that domain, See below.

 NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE

As of VERSION 1.18 all IO::Socket objects have autoflush turned on
by default. This was not the case with earlier releases.

 NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE

=back

=head1 METHODS

See L<perlfunc> for complete descriptions of each of the following
supported C<IO::Socket> methods, which are just front ends for the
corresponding built-in functions:

    socket
    socketpair
    bind
    listen
    accept
    send
    recv
    peername (getpeername)
    sockname (getsockname)
    shutdown

Some methods take slightly different arguments to those defined in L<perlfunc>
in attempt to make the interface more flexible. These are

=over 4

=item accept([PKG])

perform the system call C<accept> on the socket and return a new
object. The new object will be created in the same class as the listen
socket, unless C<PKG> is specified. This object can be used to
communicate with the client that was trying to connect.

In a scalar context the new socket is returned, or undef upon
failure. In a list context a two-element array is returned containing
the new socket and the peer address; the list will be empty upon
failure.

The timeout in the [PKG] can be specified as zero to effect a "poll",
but you shouldn't do that because a new IO::Select object will be
created behind the scenes just to do the single poll.  This is
horrendously inefficient.  Use rather true select() with a zero
timeout on the handle, or non-blocking IO.

=item socketpair(DOMAIN, TYPE, PROTOCOL)

Call C<socketpair> and return a list of two sockets created, or an
empty list on failure.

=back

Additional methods that are provided are:

=over 4

=item atmark

True if the socket is currently positioned at the urgent data mark,
false otherwise.

    use IO::Socket;

    my $sock = IO::Socket::INET->new('some_server');
    $sock->read($data, 1024) until $sock->atmark;

Note: this is a reasonably new addition to the family of socket
functions, so all systems may not support this yet.  If it is
unsupported by the system, an attempt to use this method will
abort the program.

The atmark() functionality is also exportable as sockatmark() function:

	use IO::Socket 'sockatmark';

This allows for a more traditional use of sockatmark() as a procedural
socket function.  If your system does not support sockatmark(), the
C<use> declaration will fail at compile time.

=item connected

If the socket is in a connected state the peer address is returned.
If the socket is not in a connected state then undef will be returned.

=item protocol

Returns the numerical number for the protocol being used on the socket, if
known. If the protocol is unknown, as with an AF_UNIX socket, zero
is returned.

=item sockdomain

Returns the numerical number for the socket domain type. For example, for
an AF_INET socket the value of &AF_INET will be returned.

=item sockopt(OPT [, VAL])

Unified method to both set and get options in the SOL_SOCKET level. If called
with one argument then getsockopt is called, otherwise setsockopt is called.

=item socktype

Returns the numerical number for the socket type. For example, for
a SOCK_STREAM socket the value of &SOCK_STREAM will be returned.

=item timeout([VAL])

Set or get the timeout value (in seconds) associated with this socket.
If called without any arguments then the current setting is returned. If
called with an argument the current setting is changed and the previous
value returned.

=back

=head1 SEE ALSO

L<Socket>, L<IO::Handle>, L<IO::Socket::INET>, L<IO::Socket::UNIX>

=head1 AUTHOR

Graham Barr.  atmark() by Lincoln Stein.  Currently maintained by the
Perl Porters.  Please report all bugs to <perl5-porters@perl.org>.

=head1 COPYRIGHT

Copyright (c) 1997-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

The atmark() implementation: Copyright 2001, Lincoln Stein <lstein@cshl.org>.
This module is distributed under the same terms as Perl itself.
Feel free to use, modify and redistribute it as long as you retain
the correct attribution.

=cut
