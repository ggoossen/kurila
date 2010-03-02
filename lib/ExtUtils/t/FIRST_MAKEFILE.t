#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    

chdir 't'

use Test::More tests => 7

use MakeMaker::Test::Setup::BFD
use MakeMaker::Test::Utils

my $perl = (which_perl: )
my $make = (make_run: )
(perl_lib: )


ok:  (setup_recurs: ), 'setup' 
END 
    ok:  chdir File::Spec->updir 
    ok:  (teardown_recurs: ), 'teardown' 


(ok:  (chdir: 'Big-Dummy'), "chdir'd to Big-Dummy" ) ||
    diag: "chdir failed: $^OS_ERROR"

my $mpl_out = run: qq{$perl Makefile.PL FIRST_MAKEFILE=jakefile}
(cmp_ok:  $^CHILD_ERROR, '==', 0, 'Makefile.PL exited with zero' ) || diag: $mpl_out

ok:  -e 'jakefile', 'FIRST_MAKEFILE honored' 

like:  $mpl_out, qr/^Writing jakefile(?:\.)? for Big::Dummy/m
       'Makefile.PL output looks right' 
