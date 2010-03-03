#!/usr/bin/perl -w

# Tests INSTALL_BASE

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use File::Path
use Config

use Test::More tests => 21
use MakeMaker::Test::Utils
use MakeMaker::Test::Setup::BFD

my $Is_VMS = $^OS_NAME eq 'VMS'

my $perl = (which_perl: )

chdir 't'
(perl_lib: )

ok:  (setup_recurs: ), 'setup' 
END 
    ok:  chdir File::Spec->updir 
    ok:  (teardown_recurs: ), 'teardown' 


(ok:  (chdir: 'Big-Dummy'), "chdir'd to Big-Dummy") || diag: "chdir failed; $^OS_ERROR"

my $mpl_out = run: qq{$perl Makefile.PL "INSTALL_BASE=../dummy-install"}
END { (rmtree: '../dummy-install'); }

(cmp_ok:  $^CHILD_ERROR, '==', 0, 'Makefile.PL exited with zero' ) ||
    diag: $mpl_out

my $makefile = (makefile_name: )
like:  $mpl_out, qr/^Writing $makefile for Big::Dummy/m
       'Makefile.PL output looks right'

my $make = (make_run: )
run: "$make"   # this is necessary due to a dmake bug.
my $install_out = run: "$make install"
(is:  $^CHILD_ERROR, 0, '  make install exited normally' ) || diag: $install_out
like:  $install_out, qr/^Installing /m 
like:  $install_out, qr/^Writing /m 

ok:  -r '../dummy-install',      '  install dir created' 

my @installed_files =
    @: '../dummy-install/lib/perl5/Big/Dummy.pm'
       '../dummy-install/lib/perl5/Big/Liar.pm'
       '../dummy-install/bin/program'
       "../dummy-install/lib/perl5/$((config_value: 'archname'))/perllocal.pod"
       "../dummy-install/lib/perl5/$((config_value: 'archname'))/auto/Big/Dummy/.packlist"

foreach my $file ( @installed_files)
    ok:  -e $file, "  $file installed" 
    ok:  -r $file, "  $file readable" 


# nmake outputs its damned logo
# Send STDERR off to oblivion.
open: my $saverr, ">&", $^STDERR or die: $^OS_ERROR
open: $^STDERR, ">", "".File::Spec->devnull or die: $^OS_ERROR

my $realclean_out = run: "$make realclean"
(is:  $^CHILD_ERROR, 0, 'realclean' ) || diag: $realclean_out

open: $^STDERR, ">&", \$saverr->* or die: $^OS_ERROR
close $saverr
