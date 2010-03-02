#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    

chdir 't'

use Test::More tests => 9

use File::Spec
use MakeMaker::Test::Setup::PL_FILES
use MakeMaker::Test::Utils

my $perl = (which_perl: )
my $make = (make_run: )
(perl_lib: )

(setup: )

END 
    ok:  chdir (File::Spec->updir: ) 
    ok:  (teardown: )


ok: chdir: 'PL_FILES-Module'

run: qq{$perl Makefile.PL}
cmp_ok:  $^CHILD_ERROR, '==', 0 

my $make_out = run: "$make"
(is:  $^CHILD_ERROR, 0 ) || diag: $make_out

foreach my $file (qw(single.out 1.out 2.out blib/lib/PL/Bar.pm))
    ok:  -e $file, "$file was created" 

