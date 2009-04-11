package kurila;

our $VERSION = v1.19;

$^PERL_VERSION eq "kurila-1.19"
  or die "Perl lib version (kurila-1.19) doesn't match executable version (" . $^PERL_VERSION . ")";

1;

__END__

=head1 NAME

kurila - Perl Kurila

=head1 SYNOPSIS

  use kurila v1.19;

=head1 DESCRIPTION

This pragma indicates that your module requires Perl Kurila. When used
with Perl 5 it will give an error.

=head1 SEE ALSO

L<kurilaintro>.

=cut
