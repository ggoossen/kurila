#!/usr/bin/perl -w

# This is a test of WriteEmptyMakefile.

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't' if -d 't';
        @INC = @('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

chdir 't';

use strict;
use Test::More tests => 4;

use ExtUtils::MakeMaker < qw(WriteEmptyMakefile);

can_ok __PACKAGE__, 'WriteEmptyMakefile';

try { WriteEmptyMakefile("something"); };
like $@->{description}, qr/Need an even number of args/;


{
    my $stdout = '';
    close STDOUT;
    open STDOUT, '>>', \$stdout or die;

    ok !-e 'wibble';
    END { 1 while unlink 'wibble' }

    WriteEmptyMakefile(
        NAME            => "Foo",
        FIRST_MAKEFILE  => "wibble",
    );
    ok -e 'wibble';
}
