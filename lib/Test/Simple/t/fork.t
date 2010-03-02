#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


use Test::More
use Config

my $Can_Fork = config_value: 'd_fork'

if( !$Can_Fork )
    plan: skip_all => "This system cannot fork"
else
    plan: tests => 1


if( fork ) # parent
    pass: "Only the parent should process the ending, not the child"
else
    exit   # child


