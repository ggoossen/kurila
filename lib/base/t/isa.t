#!/usr/bin/perl -w

# Regression test some quirky behavior of base.pm.

BEGIN {
   if( env::var('PERL_CORE') ) {
        chdir 't' if -d 't';
        $^INCLUDE_PATH = qw(../lib);
    }
}

use Test::More tests => 1;

do {
    package Parent;

    sub foo { 42 }

    package Middle;

    use base < qw(Parent);

    package Child;

    base->import( <qw(Middle Parent));
};

is_deeply \ @Child::ISA, \qw(Middle),
          'base.pm will not add to @ISA if you already are-a';
