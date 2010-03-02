package ExtUtils::CBuilder::Platform::dec_osf

use ExtUtils::CBuilder::Platform::Unix
use File::Spec

our ($VERSION, @ISA)
@ISA = qw(ExtUtils::CBuilder::Platform::Unix)
$VERSION = '0.22'

sub link_executable
    my $self = shift
    # $Config{ld} is 'ld' but that won't work: use the cc instead.
    local $self->{config}->{+ld} = $self->{config}->{?cc}
    return $self->SUPER::link_executable: < @_


1
