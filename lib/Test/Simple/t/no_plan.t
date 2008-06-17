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

use Test::More tests => 6;

my $tb = Test::Builder->create;
$tb->level(0);

#line 19
ok !try { $tb->plan(tests => undef) };
is($@->{description}, "Got an undefined number of tests");

#line 23
ok !try { $tb->plan(tests => 0) };
is($@->{description}, "You said to run 0 tests");

#line 27
ok !try { $tb->ok(1) };
is( $@->{description}, "You tried to run a test without a plan");
