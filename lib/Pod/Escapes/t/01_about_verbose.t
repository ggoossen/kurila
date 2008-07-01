BEGIN {
    if(%ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = @( '../lib' );
    }
}

# Time-stamp: "2004-04-27 19:44:49 ADT"

# Summary of, well, things.

use Test;
BEGIN {plan tests => 2};

ok 1;

use Pod::Escapes ();

ok 1;

