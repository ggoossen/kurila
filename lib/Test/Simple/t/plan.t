#!/usr/bin/perl -w

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use Test::More;

plan tests => 4;
try { plan tests => 4 };
is( $@->{description}, sprintf("You tried to plan twice at \%s line \%d.\n", $0, __LINE__ - 1),
    'disallow double plan' );
try { plan 'no_plan'  };
is( $@->{description}, sprintf("You tried to plan twice at \%s line \%d.\n", $0, __LINE__ -1),
    'disallow changing plan' );

pass('Just testing plan()');
pass('Testing it some more');
