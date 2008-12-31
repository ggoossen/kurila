#!/usr/bin/perl -w

BEGIN {
    if( env::var('PERL_CORE') ) {
        chdir 't';
        @INC = @('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use Test::More;

my $result;
BEGIN {
    try {
        require_ok("Wibble");
    };
    $result = $^EVAL_ERROR;
}

plan tests => 1;
like $result->message, '/^You tried to run a test without a plan/';
