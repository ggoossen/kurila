#!/usr/bin/perl -w

use Test::More;

BEGIN {
    if( !env::var('HARNESS_ACTIVE') && env::var('PERL_CORE') ) {
        plan skip_all => "Won't work with t/TEST";
    }
}

use strict;
use Test::Builder;

plan 'no_plan';
is(Test::Builder->new->has_plan, 'no_plan', 'has no_plan');
