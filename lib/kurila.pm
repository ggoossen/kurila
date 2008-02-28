package kurila;

our $VERSION = v1.8;

$^V eq "kurila-1.8"
  or die "Perl lib version (kurila-1.8) doesn't match executable version (" . $^V . ")";

1;

__END__

=head1 NAME

kurila - Perl Kurila

=head1 SYNOPSIS

  use kurila 1.8;

=head1 DESCRIPTION

This pragma indicates that your module requires Perl Kurila. When used
with Perl 5 it will give an error.

=head1 SEE ALSO

L<kurilaintro>.

=cut
