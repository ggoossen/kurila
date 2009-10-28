## This -*- perl -*- script writes the Makefile for lib.pm
# You should read "perldoc perlmodinstall" for instructions on
#  how to install modules like this.

use ExtUtils::MakeMaker

my $lib_version = '0.62'

my $extra_meta = <<"EMETA"
provides:
  lib:
    file: lib_pm.PL
    version: $lib_version
EMETA

my $extra_meta_hash = %:
  provides => %:
    lib => %: file => 'lib_pm.PL'
              version => $lib_version

my $mm_version = $ExtUtils::MakeMaker::VERSION

WriteMakefile: 
  'NAME' => 'lib'
  'VERSION' => $lib_version
  'LICENSE' => 'perl'
  'PREREQ_PM' => $%
  'ABSTRACT_FROM' => 'lib_pm.PL'
  'AUTHOR' => 'Steffen Mueller <smueller@cpan.org>'
  'PL_FILES' => (%: 'lib_pm.PL' => 'lib.pm')
  'PM' => (%: 'lib.pm' => '$(INST_LIBDIR)/lib.pm' )
  'clean' => (%: FILES => 'lib.pm')
  


