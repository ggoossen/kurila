BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use Test::More;

BEGIN {
    if( !$ENV{HARNESS_ACTIVE} && $ENV{PERL_CORE} ) {
        plan skip_all => "Won't work with t/TEST";
    }
}

BEGIN {
    require Test::Harness;
}

# This feature requires a fairly new version of Test::Harness
if( $Test::Harness::VERSION < 2.03 ) {
    plan tests => 1;
    diag "Need Test::Harness 2.03 or up.  You have $Test::Harness::VERSION.";
    fail 'Need Test::Harness 2.03 or up';
    exit;
}

plan 'no_plan';

pass('Just testing');
ok(1, 'Testing again');
