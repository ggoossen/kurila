#!/usr/bin/perl -w

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}


use Test::More tests => 10;
use Test::Builder;
my $tb = Test::Builder->create;
$tb->level(0);

ok !eval { $tb->plan( tests => 'no_plan' ); };
is $@->{description}, sprintf "Number of tests must be a positive integer.  You gave it 'no_plan' at \%s line \%d.\n", $0, __LINE__ - 1;

my $foo = [];
my @foo = ($foo, 2, 3);
ok !eval { $tb->plan( tests => @foo ) };
like $@->{description}, qr/reference as string/;

#line 25
ok !eval { $tb->plan( tests => -1 ) };
is $@->{description}, "Number of tests must be a positive integer.  You gave it '-1' at $0 line 25.\n";

#line 29
ok !eval { $tb->plan( tests => '' ) };
is $@->{description}, "You said to run 0 tests at $0 line 29.\n";

#line 33
ok !eval { $tb->plan( 'wibble' ) };
is $@->{description}, "plan() doesn't understand wibble at $0 line 33.\n";
