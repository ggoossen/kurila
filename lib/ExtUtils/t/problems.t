# Test problems in Makefile.PL's and hint files.

BEGIN 
    unshift: $^INCLUDE_PATH, 'lib', '../../lib'


use Test::More tests => 7
use ExtUtils::MM
use MakeMaker::Test::Setup::Problem

my $MM = bless: \(%:  DIR => (@: 'subdir') ), 'MM'

ok:  (setup_recurs: ), 'setup' 
END 
    ok:  chdir File::Spec->updir 
    ok:  (teardown_recurs: ), 'teardown' 


(ok:  chdir 'Problem-Module', "chdir'd to Problem-Module" ) ||
    diag: "chdir failed: $^OS_ERROR"


# Make sure when Makefile.PL's break, they issue a warning.
# Also make sure Makefile.PL's in subdirs still have '.' in $^INCLUDE_PATH.
do
    my $stdout
    close $^STDOUT
    open: $^STDOUT, '>>', \$stdout or die: "$^OS_ERROR"

    my $warning = ''
    local $^WARN_HOOK = sub (@< @_) { $warning = @_[0]->{?description} }
    dies_like:  { $MM->eval_in_subdirs }, qr/YYYAaaaakkk/ 

    is:  $stdout, qq{\$^INCLUDE_PATH has .\n}, 'cwd in $^INCLUDE_PATH' 
    $stdout = ''
    like:  $^EVAL_ERROR->{?description}
           qr{^ERROR from evaluation of .*subdir.*Makefile.PL: YYYAaaaakkk}
           'Makefile.PL death in subdir warns' 

