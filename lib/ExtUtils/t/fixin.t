#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib/'
    else
        unshift: $^INCLUDE_PATH, 't/lib/'
    

chdir 't'

use File::Spec

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

# [rt.cpan.org 26234]
do
    local $^INPUT_RECORD_SEPARATOR = "foo"
    MY->fixin: "bin/program"
    is: $^INPUT_RECORD_SEPARATOR, "foo", '$/ not clobbered'


