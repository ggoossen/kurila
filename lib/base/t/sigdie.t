#!/usr/bin/perl -w

BEGIN {
   if( %ENV{PERL_CORE} ) {
        chdir 't' if -d 't';
        @INC = qw(../lib ../t/lib);
    }
}

use strict;
use Test::More tests => 2;

use base;

{
    package Test::SIGDIE;

    local $^DIE_HOOK = sub { 
        ::fail('sigdie not caught, this test should not run') 
    };
    eval {
      'base'->import(qw(Huh::Boo));
    };

    ::like($@->{description}, qr/^Base class package "Huh::Boo" is empty/, 
         'Base class empty error message');
}


{
    use lib 't/lib';
    
    local $^DIE_HOOK;
    base->import(qw(HasSigDie));
    ok $^DIE_HOOK, 'base.pm does not mask SIGDIE';
}
