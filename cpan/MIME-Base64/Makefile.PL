use ExtUtils::MakeMaker

my @makefileopts
push: @makefileopts, INSTALLDIRS => 'perl'

WriteMakefile: 
    NAME         => 'MIME::Base64'
    VERSION_FROM => 'Base64.pm'
    dist         => (%:  COMPRESS => 'gzip -9f', SUFFIX => 'gz', )
    < @makefileopts
    
