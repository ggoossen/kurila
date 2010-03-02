#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 4

use_ok: 'ExtUtils::MakeMaker::bytes'

do
    use utf8

    my $chr = chr: 400
    is:  length $chr, 1 

    do
        use ExtUtils::MakeMaker::bytes
        is:  length $chr, 2, 'byte.pm in effect' 
    

    is:  length $chr, 1, '  score is lexical' 

