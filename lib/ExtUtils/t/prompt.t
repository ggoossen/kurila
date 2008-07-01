#!/usr/bin/perl -w

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't' if -d 't';
        @INC = @('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use Test::More tests => 11;
use ExtUtils::MakeMaker;

eval q{
    prompt();
};
like( $@->{description}, qr/^Not enough arguments for ExtUtils::MakeMaker::prompt/,
                                            'no args' );

try {
    prompt(undef);
};
like( $@->{description}, qr/^prompt function called without an argument/, 
                                            'undef message' );

my $stdout = \$( '' );
open my $stdout_fh, '>>', $stdout or die;
*STDOUT = *$stdout_fh{IO};


%ENV{PERL_MM_USE_DEFAULT} = 1;
is( prompt("Foo?"), '',     'no default' );
like( $$stdout,  qr/^Foo\?\s*\n$/,      '  question' );
$$stdout = '';

is( prompt("Foo?", undef), '',     'undef default' );
like( $$stdout,  qr/^Foo\?\s*\n$/,      '  question' );
$$stdout = '';

is( prompt("Foo?", 'Bar!'), 'Bar!',     'default' );
like( $$stdout,  qr/^Foo\? \[Bar!\]\s+Bar!\n$/,      '  question' );
$$stdout = '';


{
    %ENV{PERL_MM_USE_DEFAULT} = 0;
    close STDIN;
    my $stdin = '';
    open my $stdin_fh, '<', \$stdin or die;
    *STDIN = *$stdin_fh{IO};
    $stdin .= "From STDIN";
    ok( !-t *STDIN,      'STDIN not a tty' );

    is( prompt("Foo?", 'Bar!'), 'From STDIN',     'from STDIN' );
    like( $$stdout,  qr/^Foo\? \[Bar!\]\s*$/,      '  question' );
    $$stdout = '';
}
