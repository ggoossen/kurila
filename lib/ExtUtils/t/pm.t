#!/usr/bin/perl -w

# Test that MakeMaker honors user's PM override.

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 5

use MakeMaker::Test::Utils
use MakeMaker::Test::Setup::BFD

use ExtUtils::MakeMaker

chdir 't'

(perl_lib: )

ok:  (setup_recurs: ), 'setup' 
END 
    ok:  chdir (File::Spec->updir: ) 
    ok:  (teardown_recurs: ), 'teardown' 


(ok:  chdir 'Big-Dummy', "chdir'd to Big-Dummy" ) ||
    diag: "chdir failed: $^OS_ERROR"

my $stdout = ''
close $^STDOUT
open: $^STDOUT, '>>', \$stdout or die: 

do
    my $mm = WriteMakefile: 
        NAME            => 'Big::Dummy'
        VERSION_FROM    => 'lib/Big/Dummy.pm'
        PM              => %:  'wibble' => 'woof' 
        

    is_deeply:  $mm->{PM},  (%:  wibble => 'woof' ) 

