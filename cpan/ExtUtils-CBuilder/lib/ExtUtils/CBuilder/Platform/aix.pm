package ExtUtils::CBuilder::Platform::aix

use ExtUtils::CBuilder::Platform::Unix
use File::Spec

our ($VERSION, @ISA)
$VERSION = '0.22'
@ISA = qw(ExtUtils::CBuilder::Platform::Unix)

sub need_prelink { 1 }

sub link($self, %< %args)
    my $cf = $self->{?config}

    (my $baseext = %args{?module_name}) =~ s/.*:://
    my $perl_inc = $self->perl_inc

    # Massage some very naughty bits in %Config
    local $cf->{+lddlflags} = $cf->{?lddlflags}
    for ((@: $cf->{?lddlflags}))
        s/\$ [(] BASEEXT [)] /$baseext/x
        s/\$ [(] PERL_INC [)] /$perl_inc/x
    

    return $self->SUPER::link: < %args



1
