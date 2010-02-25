# A template for Makefile.PL.
# - Set the $PACKAGE variable to the name of your module.
# - Set $LAST_API_CHANGE to reflect the last version you changed the API 
#   of your module.
# - Fill in your dependencies in PREREQ_PM
# Alternatively, you can say the hell with this and use h2xs.

use ExtUtils::MakeMaker
eval 'use ExtUtils::MakeMaker::Coverage'

my $PACKAGE = 'XSLoader'
(my $PACKAGE_FILE = $PACKAGE) =~ s|::|/|g
my $LAST_API_CHANGE = 0

eval "require $PACKAGE"

unless ($^EVAL_ERROR) # Make sure we did find the module.
    print: <<"CHANGE_WARN" if $PACKAGE::VERSION +< $LAST_API_CHANGE

NOTE: There have been API changes between this version and any older
than version $LAST_API_CHANGE!  Please read the Changes file if you
are upgrading from a version older than $LAST_API_CHANGE.

CHANGE_WARN

# In case the empty lib/ directory was not created.
mkdir: 'lib', 0755 unless env::var: 'PERL_CORE'

WriteMakefile: 
    NAME            => $PACKAGE
    LICENSE         => 'perl'
    AUTHOR          => 'Sebastien Aperghis-Tramoni <sebastien@aperghis.net>'
    VERSION_FROM    => 'XSLoader_pm.PL'
    ABSTRACT_FROM   => 'XSLoader_pm.PL'
    PL_FILES        => (%: 'XSLoader_pm.PL'  => 'XSLoader.pm' )
    PM              => (%: 'XSLoader.pm' => '$(INST_ARCHLIB)/XSLoader.pm' )
    PREREQ_PM       => %:
        'Test::More' => '0.62'
    
    clean           => (%: FILES => 'XSLoader-*' )
    

# Unlink the .pm file included with the distribution
1 while unlink: "XSLoader.pm"
