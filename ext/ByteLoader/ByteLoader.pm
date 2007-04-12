package ByteLoader;

use strict;
use vars qw($VERSION @ISA);

require DynaLoader;

@ISA = qw(DynaLoader);

$VERSION = 0.01;

bootstrap ByteLoader $VERSION;

# Preloaded methods go here.

1;
__END__

=head1 NAME

ByteLoader - load byte compiled perl code

=head1 SYNOPSIS

  use ByteLoader 0.01;
  <byte code>

  use ByteLoader 0.01;
  <byte code>

=head1 DESCRIPTION

This module is used to load byte compiled perl code. It uses the source
filter mechanism to read the byte code and insert it into the compiled
code at the appropriate point.

=head1 AUTHOR

Tom Hughes <tom@compton.nu> based on the ideas of Tim Bunce and others.

=head1 SEE ALSO

perl(1).

=cut
