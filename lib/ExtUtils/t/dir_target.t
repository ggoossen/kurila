#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib/'
    else
        unshift: $^INCLUDE_PATH, 't/lib/'
    

chdir 't'

use Test::More tests => 1
use ExtUtils::MakeMaker

# dir_target() was typo'd as dir_targets()
can_ok: 'MM', 'dir_target'
