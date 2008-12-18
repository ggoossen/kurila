#! perl -w

 

use private::MakeUtil;
use ExtUtils::MakeMaker v5.16 ;

UpDowngrade( <getPerlFiles('MANIFEST')) 
    unless env::var('PERL_CORE');

WriteMakefile( 
    NAME         => 'IO::Compress::Base',
    VERSION_FROM => 'lib/IO/Compress/Base.pm',

    (
      env::var('SKIP_FOR_CORE')
        ?? (MAN3PODS    => \%())
        !! (PREREQ_PM   => \%( 'Scalar::Util'  => 0, )
	      )
    ),
       
    ABSTRACT_FROM => 'lib/IO/Compress/Base.pm',
    AUTHOR       => 'Paul Marquess <pmqs@cpan.org>',

    INSTALLDIRS => 'perl',

    'LICENSE'  => 'perl',
    
) ;

# end of file Makefile.PL


