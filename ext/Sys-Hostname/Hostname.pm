package Sys::Hostname


use Carp

require Exporter

our @ISA     = qw/ Exporter /
our @EXPORT  = qw/ hostname /

our $VERSION

our $host

BEGIN 
    $VERSION = '1.11'
    use XSLoader ();
    XSLoader::load: 'Sys::Hostname', $VERSION



sub hostname

    # we already know it
    return $host if defined $host

    # try to ask the system
    $host = (ghname: ) if exists &ghname
    return $host if defined $host

    die: "Cannot get host name of local machine"


1

__END__

=head1 NAME

Sys::Hostname - Try every conceivable way to get hostname

=head1 SYNOPSIS

    use Sys::Hostname;
    $host = hostname;

=head1 DESCRIPTION

Attempts several methods of getting the system hostname and
then caches the result.  It tries the the C
library's gethostname(). If that fails it C<die>s.

All NULs, returns, and newlines are removed from the result.

=head1 AUTHOR

David Sundstrom E<lt>F<sunds@asictest.sc.ti.com>E<gt>

Texas Instruments

XS code added by Greg Bacon E<lt>F<gbacon@cs.uah.edu>E<gt>

=cut

