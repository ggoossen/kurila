BEGIN 
    if(env::var('PERL_CORE')) {
        chdir 't' if -d 't';
        $^INCLUDE_PATH = @( '../lib' );
    }


# Time-stamp: "2004-04-27 19:44:49 ADT"

# Summary of, well, things.

use Test::More
BEGIN {plan tests => 2};

ok 1

use Pod::Escapes ();

ok 1

