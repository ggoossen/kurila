#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


use warnings

# Can't use Test::More, that would set exported_to()
use Test::Builder
use Test::Builder::Module

my $TB = Test::Builder->create
$TB->plan:  tests => 1 
$TB->level: 0

$TB->is_eq:  Test::Builder::Module->builder->exported_to
             undef
             'using Test::Builder::Module does not set exported_to()'
    
