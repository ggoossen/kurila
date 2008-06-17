#!/usr/bin/perl -w

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't';
        @INC = @( '../lib' );
    }
}


use Test::More tests => 10;
use Test::Builder;
my $tb = Test::Builder->create;
$tb->level(0);

ok !try { $tb->plan( tests => 'no_plan' ); };
is $@->{description}, "Number of tests must be a positive integer.  You gave it 'no_plan'";

my $foo = \@();
my @foo = @($foo, 2, 3);
ok !try { $tb->plan( tests => < @foo ) };
like $@->{description}, qr/reference as string/;

#line 25
ok !try { $tb->plan( tests => -1 ) };
is $@->{description}, "Number of tests must be a positive integer.  You gave it '-1'";

#line 29
ok !try { $tb->plan( tests => '' ) };
is $@->{description}, "You said to run 0 tests";

#line 33
ok !try { $tb->plan( 'wibble' ) };
is $@->{description}, "plan() doesn't understand wibble";
