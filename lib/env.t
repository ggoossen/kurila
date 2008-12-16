use Test::More tests => 5;
use env;

is( env::var("PERL_CORE") == 1, "PERL_CORE is set" );
