
use Test::More tests => 10;

use signals;

sub foo { }

ok( ! defined(signals::handler("INT")) );
signals::set_handler("INT", \&foo);
is( signals::handler("INT"), \&foo );

do {
    my $called = 0;
    signals::set_handler("INT", sub { $called++ });
    kill "INT",$$; sleep 1;
    is( $called, 1 );

    signals::set_handler("INT", "IGNORE");
    kill "INT",$$; sleep 1;
    ok(1);
};

do {
    is( signals::handler("INT"), "IGNORE" );
    do {
        signals::temp_set_handler("INT", \&foo );
        is( signals::handler("INT"), \&foo );
    };
    is( signals::handler("INT"), "IGNORE" );
};

do {
    dies_like( sub { signals::set_handler("TERM", 'foo') },
               qr/signal handler should be a code reference or .../ );
};

do {
    is( signals::supported("ALRM"), 1 );
    is( signals::supported("NON-EXIST"), '' );
}
