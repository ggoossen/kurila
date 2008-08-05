#!/usr/bin/perl -w

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't';
        @INC = @('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use Test::More tests => 7;

ok( !Test::Builder->is_fh("foo"), 'string is not a filehandle' );
ok( !Test::Builder->is_fh(''),    'empty string' );
ok( !Test::Builder->is_fh(undef), 'undef' );

ok( open(FILE, ">", 'foo') );
END { close FILE; 1 while unlink 'foo' }

ok( Test::Builder->is_fh(\*FILE) );
ok( Test::Builder->is_fh(*FILE{IO}) );

package Lying::isa;

sub isa {
    my $self = shift;
    my $parent = shift;
    
    return 1 if $parent eq 'IO::Handle';
}

main::ok( Test::Builder->is_fh(bless \%(), "Lying::isa"));
