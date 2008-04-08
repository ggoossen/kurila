#!/usr/bin/perl

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}


use Test::More tests => 3;
use Test::Builder;

my $tb = Test::Builder->create;
sub foo { $tb->croak("foo") }
sub bar { $tb->carp("bar")  }

eval { foo() };
is $@->{description}, sprintf "foo at \%s line \%s.\n", $0, __LINE__ - 1;

eval { $tb->croak("this") };
is $@->{description}, sprintf "this at \%s line \%s.\n", $0, __LINE__ - 1;

{
    my $warning = '';
    local $^WARN_HOOK = sub {
        $warning .= @_[0]->{description};
    };

    bar();
    is $warning, sprintf "bar at \%s line \%s.\n", $0, __LINE__ - 1;
}
