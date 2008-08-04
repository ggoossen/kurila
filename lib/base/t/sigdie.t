#!/usr/bin/perl -w

BEGIN {
   if( %ENV{PERL_CORE} ) {
        chdir 't' if -d 't';
        @INC = @( qw(../lib ../t/lib) );
    }
}

use strict;
use Test::More tests => 1;

use base;

{
    package Test::SIGDIE;

    local $^DIE_HOOK = sub { 
        main::fail('sigdie not caught, this test should not run') 
    };
    try {
      'base'->import(qw(Huh::Boo));
    };

    main::like($@->{description}, qr/^Base class package "Huh::Boo" is empty/, 
         'Base class empty error message');
}
