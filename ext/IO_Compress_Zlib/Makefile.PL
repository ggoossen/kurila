#! perl -w

 

$::VERSION = '2.006' ;

use private::MakeUtil;
use ExtUtils::MakeMaker v5.16 ;

UpDowngrade( <getPerlFiles('MANIFEST')) 
    unless env::var('PERL_CORE');

WriteMakefile( 
    NAME         => 'IO::Compress::Zlib',
    VERSION_FROM => 'lib/IO/Compress/Gzip.pm',

    (
      env::var('SKIP_FOR_CORE')
        ?? (MAN3PODS    => \%())
	    !! (PREREQ_PM   => \%( 'Compress::Raw::Zlib'  => $::VERSION,
                                  'IO::Compress::Base'   => $::VERSION,
                                  'IO::Uncompress::Base' => $::VERSION,
                                )
	      )
    ),
       
    ABSTRACT => 'Perl interface to zlib',
    AUTHOR  => 'Paul Marquess <pmqs@cpan.org>',

    INSTALLDIRS => 'perl',

    'LICENSE'  => 'perl',    

) ;

# end of file Makefile.PL

