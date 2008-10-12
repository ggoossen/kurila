#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 17;

#
# This file tries to test builtin override using CORE::GLOBAL
#
my $dirsep = "/";

BEGIN { package Foo; *main::getlogin = sub { "kilroy"; } }

is( getlogin, "kilroy" );

my $t = 42;
BEGIN { *CORE::GLOBAL::time = sub () { $t; } }

is( 45, time + 3 );

#
# require has special behaviour
#
my $r;
BEGIN { *CORE::GLOBAL::require = sub { $r = shift; 1; } }

require Foo;
is( $r, "Foo.pm" );

require Foo::Bar;
is( $r, join($dirsep, @( "Foo", "Bar.pm")) );

require 'Foo';
is( $r, "Foo" );

eval "use Foo";
is( $r, "Foo.pm" );

eval "use Foo::Bar";
is( $r, join($dirsep, @( "Foo", "Bar.pm")) );

# localizing *CORE::GLOBAL::foo should revert to finding CORE::foo
do {
    local(*CORE::GLOBAL::require);
    $r = '';
    eval "require NoNeXiSt;";
    ok( ! ( $r or $@->{description} !~ m/^Can't locate NoNeXiSt/i ) );
};

#
# readline() has special behaviour too
#

our $fh;

do {
    local our $TODO = "overrie readline";
    $r = 11;
    BEGIN { *CORE::GLOBAL::readline = sub (;*) { ++$r }; }
    is( (~< *FH)	, 12 );
if (0) {
    is( (~< $fh)	, 13 );
    my $pad_fh;
    is( (~< $pad_fh)	, 14 );

    # Non-global readline() override
    BEGIN { *Rgs::readline = sub (;*) { --$r }; }
    do {
        package Rgs;
        ::is( (~< *FH)	, 13 );
        ::is( (~< $fh)	, 12 );
        ::is( (~< $pad_fh)	, 11 );
    };
}
};

# Global readpipe() override
BEGIN { *CORE::GLOBAL::readpipe = sub ($) { "@_[0] " . --$r }; }
is( `rm`,	    "rm 10", '``' );
is( qx/cp/,	    "cp 9", 'qx' );

# Non-global readpipe() override
BEGIN { *Rgs::readpipe = sub ($) { ++$r . " @_[0]" }; }
do {
    package Rgs;
    main::is( `rm`,		  "10 rm", '``' );
    main::is( qx/cp/,	  "11 cp", 'qx' );
};

# Verify that the parsing of overriden keywords isn't messed up
# by the indirect object notation
do {
    local $^WARN_HOOK = sub {
	main::like( @_[0]->message, qr/^ok overriden at/ );
    };
    BEGIN { *OverridenWarn::warn = sub { CORE::warn "$(join ' ',@_) overriden"; }; }
    package OverridenWarn;
    sub foo { "ok" }
    warn( OverridenWarn->foo() );
    warn OverridenWarn->foo();
};
BEGIN { *OverridenPop::pop = sub { main::is( @_[0]->[0], "ok" ) }; }
do {
    package OverridenPop;
    sub foo { \@( "ok" ) }
    pop( OverridenPop->foo() );
    pop OverridenPop->foo();
};

do {
    local *CORE::GLOBAL::require = sub {
        CORE::require(@_[0]);
    }        ;
    require Text::ParseWords;
};
