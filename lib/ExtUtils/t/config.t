#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib/'
    else
        unshift: $^INCLUDE_PATH, 't/lib/'
    


use Test::More tests => 3
use Config ()

BEGIN { (use_ok: 'ExtUtils::MakeMaker::Config'); }

is: %Config{path_sep}, Config::config_value: "path_sep"

try {
    %Config{+wibble} = 42;
}
is: %Config{wibble}, 42
