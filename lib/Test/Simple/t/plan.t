BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use Test::More;

plan tests => 2;

pass('Just testing plan()');
pass('Testing it some more');
