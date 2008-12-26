#!perl -w

BEGIN {
    if( env::var('PERL_CORE') ) {
        chdir 't';
        @INC = @('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}


use Test::More 'no_plan';

require Test::Builder;
my $tb = Test::Builder->new;

# These should not change;
local $@ = 42;
local $! = 23;

is $tb->_try(sub { 2 }), 2;
is $tb->_try(sub { return '' }), '';

is $tb->_try(sub { die; }), undef;

is_deeply \@($tb->_try(sub { die "Foo\n" })),
          \@(undef);

is $@, 42;
cmp_ok $!, '==', 23;
