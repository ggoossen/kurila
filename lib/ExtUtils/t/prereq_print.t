#!/usr/bin/perl -w

BEGIN 
    if (env::var: 'PERL_CORE')
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'


use Config

use Test::More

plan: tests => 11

use MakeMaker::Test::Utils
use MakeMaker::Test::Setup::BFD

# 'make disttest' sets a bunch of environment variables which interfere
# with our testing.
for (qw(PREFIX LIB MAKEFLAGS))
    (env::var: $_) = undef

my $Perl = (which_perl: )
my $Makefile = (makefile_name: )
my $Is_VMS = $^OS_NAME eq 'VMS'

chdir 't'
(perl_lib: )

$^OUTPUT_AUTOFLUSH = 1

ok:  (setup_recurs: ), 'setup' 
END 
    ok:  chdir File::Spec->updir 
    ok:  (teardown_recurs: ), 'teardown' 

(ok:  (chdir: 'Big-Dummy'), "chdir'd to Big-Dummy" ) ||
    diag: "chdir failed: $^OS_ERROR"

unlink: $Makefile
my $prereq_out = run: qq{$Perl Makefile.PL "PREREQ_PRINT=1"}
ok:  !-r $Makefile, "PREREQ_PRINT produces no $Makefile" 
is:  $^CHILD_ERROR, 0,         '  exited normally' 
do
    package _Prereq::Print
    my $PREREQ_PM = undef  # shut up "used only once" warning.
    eval $prereq_out
    die: if $^EVAL_ERROR
    main::is_deeply:  $PREREQ_PM, (%:  strict => 0 ), 'prereqs dumped' 
    main::is:  $^EVAL_ERROR, '',                             '  without error' 


$prereq_out = run: qq{$Perl Makefile.PL "PRINT_PREREQ=1"}
ok:  !-r $Makefile, "PRINT_PREREQ produces no $Makefile" 
is:  $^CHILD_ERROR, 0,         '  exited normally' 
main::like:  $prereq_out, qr/^perl\(strict\) \s* >= \s* 0 \s*$/x
             'prereqs dumped' 


# Currently a bug.
#my $prereq_out = run(qq{$Perl Makefile.PL "PREREQ_PRINT=0"});
#ok( -r $Makefile, "PREREQ_PRINT=0 produces a $Makefile" );
#is( $?, 0,         '  exited normally' );
#unlink $Makefile;

# Currently a bug.
#my $prereq_out = run(qq{$Perl Makefile.PL "PRINT_PREREQ=1"});
#ok( -r $Makefile, "PRINT_PREREQ=0 produces a $Makefile" );
#is( $?, 0,         '  exited normally' );
#unlink $Makefile;
