#!/usr/bin/perl -w

BEGIN {
    if( env::var('PERL_CORE') ) {
        chdir 't';
        $^INCLUDE_PATH = @('../lib', 'lib');
    }
    else {
        unshift $^INCLUDE_PATH, 't/lib';
    }
}

use Test::More tests => 13;

# Using Symbol because it's core and exports lots of stuff.
do {
    package Foo::one;
    main::use_ok("Symbol");
    main::ok( defined &gensym,        'use_ok() no args exports defaults' );
};

do {
    package Foo::two;
    main::use_ok("Symbol", < qw(qualify));
    main::ok( !defined &gensym,       '  one arg, defaults overriden' );
    main::ok( defined &qualify,       '  right function exported' );
};

do {
    package Foo::three;
    main::use_ok("Symbol", < qw(gensym ungensym));
    main::ok( defined &gensym && defined &ungensym,   '  multiple args' );
};

do {
    package Foo::four;
    my $warn; local $^WARN_HOOK = sub { $warn .= shift; };
    main::use_ok("constant", < qw(foo bar));
    main::ok( defined &foo, 'constant' );
    main::is( $warn, undef, 'no warning');
};

do {
    package Foo::five;
    main::use_ok("Symbol", v1.02);
};

do {
    package Foo::six;
    main::use_ok("NoExporter", v1.02);
};

do {
    package Foo::seven;
    local $^WARN_HOOK = sub {
            # Old perls will warn on X.YY_ZZ style versions.  Not our problem
            warn < @_ unless @_[0] =~ m/^Argument "\d+\.\d+_\d+" isn't numeric/;
        };
    main::use_ok("Test::More", v0.47);
};
