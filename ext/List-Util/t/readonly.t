#!./perl

use Config;

BEGIN {
    unless (-d 'blib') {
	if (%Config{extensions} !~ m/\bList\/Util\b/) {
	    print "1..0 # Skip: List::Util was not built\n";
	    exit 0;
	}
    }
}

use Scalar::Util qw(readonly);
use Test::More tests => 11;

ok( readonly(1),	'number constant');

my $var = 2;

ok( !readonly($var),	'number variable');
is( $var,	2,	'no change to number variable');

ok( readonly("fred"),	'string constant');

$var = "fred";

ok( !readonly($var),	'string variable');
is( $var,	'fred',	'no change to string variable');

$var = \2;

ok( !readonly($var),	'reference to constant');
ok( readonly($$var),	'de-reference to constant');

ok( !readonly(*STDOUT),	'glob');

sub tryreadonly
{
    my $v = \@_[0];
    return readonly $$v;
}

$var = 123;
{
    local $TODO = %Config::Config{useithreads} ? "doesn't work with threads" : undef;
    ok( tryreadonly("abc"), 'reference a constant in a sub');
}
ok( !tryreadonly($var), 'reference a non-constant in a sub');
