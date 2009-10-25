#!/usr/bin/perl -w

# This test puts MakeMaker through the paces of a basic perl module
# build, test and installation of the Big::Fat::Dummy module.

BEGIN 
    unshift: $^INCLUDE_PATH, 'lib'


use env
use Config
use ExtUtils::MakeMaker

use Test::More tests => 85
use MakeMaker::Test::Utils
use MakeMaker::Test::Setup::BFD
use File::Find
use File::Spec
use File::Path

# 'make disttest' sets a bunch of environment variables which interfere
# with our testing.
for (qw(PREFIX LIB MAKEFLAGS))
    (env::var: $_) = undef

my $perl = (which_perl: )
my $Is_VMS = $^OS_NAME eq 'VMS'

# GNV logical interferes with testing
(env::var: 'bin' ) = '[.bin]' if $Is_VMS

chdir 't'

(perl_lib: )

my $Touch_Time = (calibrate_mtime: )

$^OUTPUT_AUTOFLUSH = 1

ok:  (setup_recurs: ), 'setup' 
END 
    ok:  chdir (File::Spec->updir: ) 
    ok:  (teardown_recurs: ), 'teardown' 


(ok:  (chdir: 'Big-Dummy'), "chdir'd to Big-Dummy" ) ||
    diag: "chdir failed: $^OS_ERROR"

my $mpl_out = run: qq{$perl Makefile.PL "PREFIX=../dummy-install"}
END { (rmtree: '../dummy-install'); }

(cmp_ok:  $^CHILD_ERROR, '==', 0, 'Makefile.PL exited with zero' ) ||
    diag: $mpl_out

my $makefile = (makefile_name: )
like:  $mpl_out, qr/^Writing $makefile for Big::Dummy/m
       'Makefile.PL output looks right'

like:  $mpl_out, qr/^Current package is: main$/m
       'Makefile.PL run in package main'

ok:  -e $makefile,       'Makefile exists' 

# -M is flakey on VMS
my $mtime = (@: (stat: $makefile))[9]
cmp_ok:  $Touch_Time, '+<=', $mtime,  '  its been touched' 

END { (unlink: (makefile_name: ), (makefile_backup: )) }

my $make = (make_run: )

do
    # Supress 'make manifest' noise
    local (env::var: 'PERL_MM_MANIFEST_VERBOSE' ) = 0
    my $manifest_out = run: "$make manifest"
    ok:  -e 'MANIFEST',      'make manifest created a MANIFEST' 
    ok:  -s 'MANIFEST',      '  its not empty'  or diag: $manifest_out


END { (unlink: 'MANIFEST'); }


my $ppd_out = run: "$make ppd"
(is:  $^CHILD_ERROR, 0,                      '  exited normally' ) || diag: $ppd_out
ok:  (open: my $ppd, "<", 'Big-Dummy.ppd'), '  .ppd file generated' 
my $ppd_html
do { local $^INPUT_RECORD_SEPARATOR = undef; $ppd_html = ~< $ppd->* }
close $ppd
like:  $ppd_html, qr{^<SOFTPKG NAME="Big-Dummy" VERSION="0,01,0,0">}m
       '  <SOFTPKG>' 
like:  $ppd_html, qr{^\s*<TITLE>Big-Dummy</TITLE>}m,        '  <TITLE>'   
like:  $ppd_html, qr{^\s*<ABSTRACT>Try "our" hot dog's</ABSTRACT>}m
       '  <ABSTRACT>'
like:  $ppd_html
       qr{^\s*<AUTHOR>Michael G Schwern &lt;schwern\@pobox.com&gt;</AUTHOR>}m
       '  <AUTHOR>'  
like:  $ppd_html, qr{^\s*<IMPLEMENTATION>}m,          '  <IMPLEMENTATION>'
like:  $ppd_html, qr{^\s*<DEPENDENCY NAME="strict" VERSION="0,0,0,0" />}m
       '  <DEPENDENCY>' 
like:  $ppd_html, qr{^\s*<OS NAME="$((Config::config_value: 'osname'))" />}m
       '  <OS>'      
my $archname = config_value: 'archname'
$archname .= "-". substr: (config_value: "version"),0,3
like:  $ppd_html, qr{^\s*<ARCHITECTURE NAME="$archname" />}m
       '  <ARCHITECTURE>'
like:  $ppd_html, qr{^\s*<CODEBASE HREF="" />}m,            '  <CODEBASE>'
like:  $ppd_html, qr{^\s*</IMPLEMENTATION>}m,           '  </IMPLEMENTATION>'
like:  $ppd_html, qr{^\s*</SOFTPKG>}m,                      '  </SOFTPKG>'
END { (unlink: 'Big-Dummy.ppd') }


:SKIP do
    skip: 'Test::Harness required for "make test"', 5 if not eval 'require Test::Harness; 1'

    my $test_out = run: "$make test"
    like:  $test_out, qr/All tests successful/, 'make test' 
    (is:  $^CHILD_ERROR, 0,                                 '  exited normally' ) ||
        diag: $test_out

    # Test 'make test TEST_VERBOSE=1'
    my $make_test_verbose = make_macro: $make, 'test', TEST_VERBOSE => 1
    $test_out = run: "$make_test_verbose"
    like:  $test_out, qr/ok \d+ - TEST_VERBOSE/, 'TEST_VERBOSE' 
    like:  $test_out, qr/All tests successful/,  '  successful' 
    (is:  $^CHILD_ERROR, 0,                                  '  exited normally' ) ||
        diag: $test_out


my $install_out = run: "$make install"
(is:  $^CHILD_ERROR, 0, 'install' ) || diag: $install_out
like:  $install_out, qr/^Installing /m 
like:  $install_out, qr/^Writing /m 

ok:  -r '../dummy-install',     '  install dir created' 
my %files = $%
find:  sub (@< @_)
          # do it case-insensitive for non-case preserving OSs
           my $file = lc $_

          # VMS likes to put dots on the end of things that don't have them.
           $file =~ s/\.$// if $Is_VMS

           %files{+$file} = $File::Find::name
       , '../dummy-install' 
ok:  %files{?'dummy.pm'},     '  Dummy.pm installed' 
ok:  %files{?'liar.pm'},      '  Liar.pm installed'  
ok:  %files{?'program'},      '  program installed'  
ok:  %files{?'.packlist'},    '  packlist created'   
ok:  %files{?'perllocal.pod'},'  perllocal.pod created' 


:SKIP do
    skip: 'VMS install targets do not preserve $(PREFIX)', 9 if $Is_VMS

    $install_out = run: "$make install PREFIX=elsewhere"
    (is:  $^CHILD_ERROR, 0, 'install with PREFIX override' ) || diag: $install_out
    like:  $install_out, qr/^Installing /m 
    like:  $install_out, qr/^Writing /m 

    ok:  -r 'elsewhere',     '  install dir created' 
    %files = $%
    find:  sub (@< @_) { %files{+$_} = $File::Find::name; }, 'elsewhere' 
    ok:  %files{?'Dummy.pm'},     '  Dummy.pm installed' 
    ok:  %files{?'Liar.pm'},      '  Liar.pm installed'  
    ok:  %files{?'program'},      '  program installed'  
    ok:  %files{?'.packlist'},    '  packlist created'   
    ok:  %files{?'perllocal.pod'},'  perllocal.pod created' 
    rmtree: 'elsewhere'



:SKIP do
    skip: 'VMS install targets do not preserve $(DESTDIR)', 11 if $Is_VMS

    $install_out = run: "$make install PREFIX= DESTDIR=other"
    (is:  $^CHILD_ERROR, 0, 'install with DESTDIR' ) ||
        diag: $install_out
    like:  $install_out, qr/^Installing /m 
    like:  $install_out, qr/^Writing /m 

    ok:  -d 'other',  '  destdir created' 
    %files = $%
    my $perllocal
    find:  sub (@< @_)
               %files{+$_} = $File::Find::name
           , 'other' 
    ok:  %files{?'Dummy.pm'},     '  Dummy.pm installed' 
    ok:  %files{?'Liar.pm'},      '  Liar.pm installed'  
    ok:  %files{?'program'},      '  program installed'  
    ok:  %files{?'.packlist'},    '  packlist created'   
    ok:  %files{?'perllocal.pod'},'  perllocal.pod created' 

    (ok:  (open: my $perllocalfh, "<", %files{?'perllocal.pod'} ) ) ||
        diag: "Can't open %files{?'perllocal.pod'}: $^OS_ERROR"
    do { local $^INPUT_RECORD_SEPARATOR = undef;
        unlike:  ($: ~< $perllocalfh->*), qr/other/, 'DESTDIR should not appear in perllocal';
    }
    close $perllocalfh

    # TODO not available in the min version of Test::Harness we require
    #    ok( open(PACKLIST, $files{'.packlist'} ) ) ||
    #        diag("Can't open $files{'.packlist'}: $!");
    #    { local $/;
    #      local $TODO = 'DESTDIR still in .packlist';
    #      unlike(<PACKLIST>, qr/other/, 'DESTDIR should not appear in .packlist');
    #    }
    #    close PACKLIST;

    rmtree: 'other'


:SKIP do
    skip: 'VMS install targets do not preserve $(PREFIX)', 10 if $Is_VMS

    $install_out = run: "$make install PREFIX=elsewhere DESTDIR=other/"
    (is:  $^CHILD_ERROR, 0, 'install with PREFIX override and DESTDIR' ) ||
        diag: $install_out
    like:  $install_out, qr/^Installing /m 
    like:  $install_out, qr/^Writing /m 

    ok:  !-d 'elsewhere',       '  install dir not created' 
    ok:  -d 'other/elsewhere',  '  destdir created' 
    %files = $%
    find:  sub (@< @_) { %files{+$_} = $File::Find::name; }, 'other/elsewhere' 
    ok:  %files{?'Dummy.pm'},     '  Dummy.pm installed' 
    ok:  %files{?'Liar.pm'},      '  Liar.pm installed'  
    ok:  %files{?'program'},      '  program installed'  
    ok:  %files{?'.packlist'},    '  packlist created'   
    ok:  %files{?'perllocal.pod'},'  perllocal.pod created' 
    rmtree: 'other'


my $dist_out = run: "$make dist"
(is:  $^CHILD_ERROR, 0, 'dist' ) || diag: $dist_out

my $distdir_out2 = run: "$make distdir"
(is:  $^CHILD_ERROR, 0, 'distdir' ) || diag: $distdir_out2

:SKIP do
    skip: 'Test::Harness required for "make disttest"', 1 if not eval 'require Test::Harness; 1'
    my $dist_test_out = run: "$make disttest"
    (is:  $^CHILD_ERROR, 0, 'disttest' ) || diag: $dist_test_out


# Test META.yml generation
use ExtUtils::Manifest < qw(maniread)

my $distdir  = 'Big-Dummy-0.01'
$distdir =~ s/\./_/g if $Is_VMS
my $meta_yml = "$distdir/META.yml"

ok:  !-f 'META.yml',  'META.yml not written to source dir' 
ok:  -f $meta_yml,    'META.yml written to dist dir' 
ok:  !-e "META_new.yml", 'temp META.yml file not left around' 

ok: (open: my $metafh, "<", $meta_yml) or diag: $^OS_ERROR
my $meta = join: '', @:  ~< \$metafh->*
ok: close $metafh

is: $meta, <<"END"
--- #YAML:1.0
name:                Big-Dummy
version:             0.01
abstract:            Try "our" hot dog's
license:             ~
author:              
    - Michael G Schwern <schwern\@pobox.com>
generated_by:        ExtUtils::MakeMaker version $ExtUtils::MakeMaker::VERSION
distribution_type:   module
requires:     
    strict:                        0
meta-spec:
    url:     http://module-build.sourceforge.net/META-spec-v1.3.html
    version: 1.3
END

my $manifest = maniread: "$distdir/MANIFEST"
# VMS is non-case preserving, so we can't know what the MANIFEST will
# look like. :(
_normalize: $manifest
is:  $manifest->{?'meta.yml'}, 'Module meta-data (added by MakeMaker)' 


# Test NO_META META.yml suppression
unlink: $meta_yml
ok:  !-f $meta_yml,   'META.yml deleted' 
$mpl_out = run: qq{$perl Makefile.PL "NO_META=1"}
(cmp_ok:  $^CHILD_ERROR, '==', 0, 'Makefile.PL exited with zero' ) || diag: $mpl_out
my $distdir_out = run: "$make distdir"
(is:  $^CHILD_ERROR, 0, 'distdir' ) || diag: $distdir_out
ok:  !-f $meta_yml,   'META.yml generation suppressed by NO_META' 


# Make sure init_dirscan doesn't go into the distdir
$mpl_out = run: qq{$perl Makefile.PL "PREFIX=../dummy-install"}

(cmp_ok:  $^CHILD_ERROR, '==', 0, 'Makefile.PL exited with zero' ) || diag: $mpl_out

(like:  $mpl_out, qr/^Writing $makefile for Big::Dummy/m
        'init_dirscan skipped distdir') ||
    diag: $mpl_out

# I know we'll get ignored errors from make here, that's ok.
# Send STDERR off to oblivion.
open: my $saverr, ">&", $^STDERR or die: $^OS_ERROR
open: $^STDERR, ">", "".(File::Spec->devnull: ) or die: $^OS_ERROR

my $realclean_out = run: "$make realclean"
(is:  $^CHILD_ERROR, 0, 'realclean' ) || diag: $realclean_out

open: $^STDERR, ">&", \$saverr->* or die: $^OS_ERROR
close $saverr


sub _normalize
    my $hash = shift

    while(my(@: ?$k,?$v) =(@:  each $hash->%))
        delete $hash->{$k}
        $hash->{+lc $k} = $v
    

