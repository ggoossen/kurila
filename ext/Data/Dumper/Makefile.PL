use ExtUtils::MakeMaker;
WriteMakefile(
	NAME		=> "Data::Dumper",
	VERSION_FROM	=> 'Dumper.pm',
        (
            (grep { $_ eq 'PERL_CORE=1' } @ARGV)
                ? ()
                : ('DEFINE' => '-DUSE_PPPORT_H')
        ),
);
