use ExtUtils::MakeMaker;

my @libs;
push @libs, '-L/lib/w32api -lole32 -lversion' if $^OS_NAME eq "cygwin";

WriteMakefile(
    NAME          => 'Win32',
    VERSION_FROM  => 'Win32.pm',
    LIBS          => \@libs,
    INSTALLDIRS   => 'perl',
    NO_META       => 1,

    AUTHOR        => 'Jan Dubois <jand@activestate.com>',
    ABSTRACT_FROM => 'Win32.pm',
);
