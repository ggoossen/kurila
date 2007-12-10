#! perl -w

use strict ;

use private::MakeUtil;
use ExtUtils::MakeMaker v5.16 ;

UpDowngrade(getPerlFiles('MANIFEST')) 
    unless $ENV{PERL_CORE};

WriteMakefile( 
    NAME         => 'IO::Compress::Base',
    VERSION_FROM => 'lib/IO/Compress/Base.pm',
    'dist'       => { COMPRESS     => 'gzip', 
                      TARFLAGS     => '-chvf',
                      SUFFIX       => 'gz',
                      DIST_DEFAULT => 'MyTrebleCheck tardist',
                    },

    (
      $ENV{SKIP_FOR_CORE}
        ? (MAN3PODS    => {})
        : (PREREQ_PM   => { 'Scalar::Util'  => 0, }
	      )
    ),
       
    ABSTRACT_FROM => 'lib/IO/Compress/Base.pm',
    AUTHOR       => 'Paul Marquess <pmqs@cpan.org>',

    INSTALLDIRS => 'perl',

    ((ExtUtils::MakeMaker->VERSION() gt '6.30') ?
        ('LICENSE'  => 'perl')         : ()),
    
) ;

# end of file Makefile.PL


