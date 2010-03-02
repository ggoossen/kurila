#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


chdir 't'

use Test::More tests => 1
use MakeMaker::Test::Utils
use ExtUtils::MakeMaker
use File::Path

(perl_lib: )

mkdir: 'Odd-Version', 0777
END { chdir (File::Spec->updir: );  (rmtree: 'Odd-Version') }
chdir 'Odd-Version'

(open: my $mpl, ">", "Version") || die: $^OS_ERROR
print: $mpl, "\$VERSION = 0\n"
close $mpl
END { (unlink: 'Version') }

my $stdout = ''
close $^STDOUT
open: $^STDOUT, '>>', \$stdout or die: 
my $mm = WriteMakefile: 
    NAME         => 'Version'
    VERSION_FROM => 'Version'
    

is:  $mm->{VERSION}, 0, 'VERSION_FROM when $VERSION = 0' 
