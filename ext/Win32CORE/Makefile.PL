use ExtUtils::MakeMaker

WriteMakefile(
    'NAME'		=> 'Win32CORE',
    'VERSION_FROM'	=> 'Win32CORE.pm',
    )

# undef USEIMPORTLIB for static compilation
sub MY::cflags($self, ?$libperl)
    package MY         # so that "SUPER" works right
    return '' unless $self->needs_linking()
    my $base = $self->SUPER::cflags($libperl)
    if ($self->{LINKTYPE} eq 'static')
        $base =~ s/CCFLAGS =(.*)$/CCFLAGS =\1 -UUSEIMPORTLIB /m
    return $base
