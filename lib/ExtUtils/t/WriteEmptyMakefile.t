#!/usr/bin/perl -w

# This is a test of WriteEmptyMakefile.

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


chdir 't'

use Test::More tests => 4

use ExtUtils::MakeMaker < qw(WriteEmptyMakefile)

can_ok: __PACKAGE__, 'WriteEmptyMakefile'

try
    local $^WARN_HOOK = sub($e) { die: $e }
    WriteEmptyMakefile: "something"
like: $^EVAL_ERROR->{description}, qr/Odd number of elements/

do
    my $stdout = ''
    close $^STDOUT
    open: $^STDOUT, '>>', \$stdout or die: 

    ok: !-e 'wibble'
    END { 1 while (unlink: 'wibble') }

    WriteEmptyMakefile: 
        NAME            => "Foo"
        FIRST_MAKEFILE  => "wibble"
        
    ok: -e 'wibble'

