package ExtUtils::CBuilder::Platform::cygwin

use File::Spec
use ExtUtils::CBuilder::Platform::Unix

our ($VERSION, @ISA)
$VERSION = '0.22'
@ISA = qw(ExtUtils::CBuilder::Platform::Unix)

sub link_executable
    my $self = shift
    # $Config{ld} is set up as a special script for building
    # perl-linkable libraries.  We don't want that here.
    local $self->{config}->{+ld} = 'gcc'
    return $self->SUPER::link_executable(< @_)


sub link($self, %< %args)

    %args{+extra_linker_flags} = \@( <
                                     File::Spec->catdir( <$self->perl_inc(), 'libperl.dll.a'), <
                                     $self->split_like_shell(%args{extra_linker_flags})
        )

    return $self->SUPER::link(< %args)


1
