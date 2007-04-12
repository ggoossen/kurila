#!/usr/bin/perl -w

# Test if MakeMaker declines to build man pages under the right conditions.

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't' if -d 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use Test::More tests => 9;

use TieOut;
use MakeMaker::Test::Utils;
use MakeMaker::Test::Setup::BFD;

use ExtUtils::MakeMaker;

chdir 't';

perl_lib();

ok( setup_recurs(), 'setup' );
END {
    ok( chdir File::Spec->updir );
    ok( teardown_recurs(), 'teardown' );
}

ok( chdir 'Big-Dummy', "chdir'd to Big-Dummy" ) ||
  diag("chdir failed: $!");

ok( my $stdout = tie *STDOUT, 'TieOut' );

{
    my $mm = WriteMakefile(
        NAME            => 'Big::Dummy',
        VERSION_FROM    => 'lib/Big/Dummy.pm',
    );

    ok( keys %{ $mm->{MAN3PODS} } );
}

{
    my $mm = WriteMakefile(
        NAME            => 'Big::Dummy',
        VERSION_FROM    => 'lib/Big/Dummy.pm',
        INSTALLMAN3DIR  => 'none'
    );

    ok( !keys %{ $mm->{MAN3PODS} } );
}


{
    my $mm = WriteMakefile(
        NAME            => 'Big::Dummy',
        VERSION_FROM    => 'lib/Big/Dummy.pm',
        MAN3PODS        => {}
    );

    is_deeply( $mm->{MAN3PODS}, { } );
}


{
    my $mm = WriteMakefile(
        NAME            => 'Big::Dummy',
        VERSION_FROM    => 'lib/Big/Dummy.pm',
        MAN3PODS        => { "Foo.pm" => "Foo.1" }
    );

    is_deeply( $mm->{MAN3PODS}, { "Foo.pm" => "Foo.1" } );
}
