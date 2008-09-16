#!/usr/bin/perl -w

# This is a test of the verification of the arguments to
# WriteMakefile.

BEGIN {
    if( %ENV{PERL_CORE} ) {
        push @INC, 'lib';
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use Test::More tests => 24;

use MakeMaker::Test::Utils;
use MakeMaker::Test::Setup::BFD;

use ExtUtils::MakeMaker;

perl_lib();

ok( setup_recurs(), 'setup' );
END {
    ok( chdir File::Spec->updir );
    ok( teardown_recurs(), 'teardown' );
}

ok( chdir 'Big-Dummy', "chdir'd to Big-Dummy" ) ||
  diag("chdir failed: $!");

{
    my $stdout = \$( '' );
    open my $stdout_fh, '>>', $stdout or die;
    *STDOUT = *{$stdout_fh}{IO};
    my $warnings = '';
    local $^WARN_HOOK = sub {
        $warnings .= @_[0]->{description};
    };

    my $mm;

    $warnings = '';
    try {
        $mm = WriteMakefile(
            NAME            => 'Big::Dummy',
            VERSION_FROM    => 'lib/Big/Dummy.pm',
            AUTHOR          => sub {},
        );
    };

    is( $warnings, <<VERIFY );
WARNING: AUTHOR takes a string/number not a CODE reference.
         Please inform the author.
VERIFY

    # LIBS accepts *both* a string or an array ref.  The first cut of
    # our verification did not take this into account.
    $warnings = '';
    $mm = WriteMakefile(
        NAME            => 'Big::Dummy',
        VERSION_FROM    => 'lib/Big/Dummy.pm',
        LIBS            => '-lwibble -lwobble',
    );

    # We'll get warnings about the bogus libs, that's ok.
    unlike( $warnings, qr/WARNING: .* takes/ );
    is_deeply( $mm->{LIBS}, \@('-lwibble -lwobble') );

    $warnings = '';
    $mm = WriteMakefile(
        NAME            => 'Big::Dummy',
        VERSION_FROM    => 'lib/Big/Dummy.pm',
        LIBS            => \@('-lwibble', '-lwobble'),
    );

    # We'll get warnings about the bogus libs, that's ok.
    unlike( $warnings, qr/WARNING: .* takes/ );
    is_deeply( $mm->{LIBS}, \@('-lwibble', '-lwobble') );

    $warnings = '';
    try {
        $mm = WriteMakefile(
            NAME            => 'Big::Dummy',
            VERSION_FROM    => 'lib/Big/Dummy.pm',
            LIBS            => \%( wibble => "wobble" ),
        );
    };

    # We'll get warnings about the bogus libs, that's ok.
    like( $warnings, qr{^WARNING: LIBS takes a ARRAY reference or string/number not a HASH reference}m );


    $warnings = '';
    $mm = WriteMakefile(
        NAME            => 'Big::Dummy',
        WIBBLE          => 'something',
        wump            => \%( foo => 42 ),
    );

    like( $warnings, qr{^WARNING: WIBBLE is not a known parameter.\n}m );
    like( $warnings, qr{^WARNING: wump is not a known parameter.\n}m );

    is( $mm->{WIBBLE}, 'something' );
    is_deeply( $mm->{wump}, \%( foo => 42 ) );


    # Test VERSION
    $warnings = '';
    try {
        $mm = WriteMakefile(
        NAME       => 'Big::Dummy',
        VERSION    => \@(1,2,3),
        );
    };
    like( $warnings, qr{^WARNING: VERSION takes a version object or string/number} );

    $warnings = '';
    try {
        $mm = WriteMakefile(
        NAME       => 'Big::Dummy',
        VERSION    => 1.002_003,
        );
    };
    is( $warnings, '' );
    is( $mm->{VERSION}, '1.002003' );

    $warnings = '';
    try {
        $mm = WriteMakefile(
        NAME       => 'Big::Dummy',
        VERSION    => '1.002_003',
        );
    };
    is( $warnings, '' );
    is( $mm->{VERSION}, '1.002_003' );


    $warnings = '';
    try {
        $mm = WriteMakefile(
        NAME       => 'Big::Dummy',
        VERSION    => bless \%(), "Some::Class",
        );
    };
    like( $warnings, '/^WARNING: VERSION takes a version object or string/number not a Some::Class object/' );


    SKIP: {
        skip("Can't test version objects",6) unless try { require version };
        version->import;

        my $version = version->new("1.2.3");
        $warnings = '';
        $mm = WriteMakefile(
            NAME       => 'Big::Dummy',
            VERSION    => $version,
        );
        is( $warnings, '' );
        is( $mm->{VERSION}, $version->stringify );

        $warnings = '';
        $version = qv('1.2.3');
        $mm = WriteMakefile(
            NAME       => 'Big::Dummy',
            VERSION    => $version,
        );
        is( $warnings, '' );
        is( $mm->{VERSION}, $version->stringify, 'correct version' );
    }
}
