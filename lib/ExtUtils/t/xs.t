#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib/'
    else
        unshift: $^INCLUDE_PATH, 't/lib/'
    

chdir 't'

use Test::More
use MakeMaker::Test::Utils
use MakeMaker::Test::Setup::XS
use File::Find
use File::Spec
use File::Path

if( (have_compiler: ) )
    plan: tests => 5
else
    plan: skip_all => "ExtUtils::CBuilder not installed or couldn't find a compiler"


my $Is_VMS = $^OS_NAME eq 'VMS'
my $perl = (which_perl: )

# GNV logical interferes with testing
(env::var: 'bin' ) = '[.bin]' if $Is_VMS

chdir 't'

(perl_lib: )

$^OUTPUT_AUTOFLUSH = 1

ok:  (setup_xs: ), 'setup' 
END 
    chdir (File::Spec->updir: ) or die: 
    teardown_xs:  or die: 


(ok:  (chdir: 'XS-Test'), "chdir'd to XS-Test" ) ||
    diag: "chdir failed: $^OS_ERROR"

my $mpl_out = run: qq{$perl Makefile.PL}

(cmp_ok:  $^CHILD_ERROR, '==', 0, 'Makefile.PL exited with zero' ) ||
    diag: $mpl_out

my $make = (make_run: )
my $make_out = run: "$make"
(is:  $^CHILD_ERROR, 0,                                 '  make exited normally' ) ||
    diag: $make_out

my $test_out = run: "$make"
(is:  $^CHILD_ERROR, 0,                                 '  make test exited normally' ) ||
    diag: $test_out
