#!/usr/bin/perl -w

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

# Make sure this is in place before Test::More is loaded.
my $handler;
BEGIN {
    $handler = sub { die "ARR"; };
    $^DIE_HOOK = $handler;
}

use Test::More tests => 1;

is $^DIE_HOOK, $handler, 'existing DIE handler not overridden';
