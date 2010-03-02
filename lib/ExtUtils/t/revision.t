#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 2

use ExtUtils::MakeMaker
use ExtUtils::MM_VMS

# Why 1?  Because a common mistake is for the regex to run in scalar context
# thus getting the count of captured elements (1) rather than the value of $1
cmp_ok: $ExtUtils::MakeMaker::Revision, '+>', 1
cmp_ok: $ExtUtils::MM_VMS::Revision,    '+>', 1
