
use Test::More tests => 10;

use signals;

sub foo { }

ok( ! defined(signals::handler("INT")) );
signals::handler("INT") = \&foo;
is( signals::handler("INT"), \&foo );

do {
    my $called = 0;
    signals::handler("INT") = sub { $called++ };
    kill "INT",$^PID; sleep 1;
    is( $called, 1 );

    signals::handler("INT") = "IGNORE";
    kill "INT",$^PID; sleep 1;
    ok(1);
};

do {
    is( signals::handler("INT"), "IGNORE" );
    do {
        local signals::handler("INT") = \&foo ;
        is( signals::handler("INT"), \&foo );
    };
    is( signals::handler("INT"), "IGNORE" );
};

do {
    dies_like( sub { signals::handler("TERM") = 'foo' },
               qr/signal handler should be a code reference or .../ );
};

do {
    is( signals::supported("ALRM"), 1 );
    is( signals::supported("NON-EXIST"), '' );
}
