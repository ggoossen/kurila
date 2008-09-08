#!./perl -T

use Config;

use Test::More tests => 4;

use Scalar::Util < qw(tainted);

ok( !tainted(1), 'constant number');

my $var = 2;

ok( !tainted($var), 'known variable');

my $key = (keys %ENV)[0];

ok( tainted(%ENV{$key}),	'environment variable');

$var = %ENV{$key};
ok( tainted($var),	'copy of environment variable');
