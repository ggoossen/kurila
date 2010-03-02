
use TestInit
use Config

use Test::More tests => 10

BEGIN { (use_ok: 'XS::APItest') };

#########################

my $rv

$XS::APItest::exception_caught = undef

$rv = try { (apitest_exception: 0) }
is: $^EVAL_ERROR, ''
ok: defined $rv
is: $rv, 42
is: $XS::APItest::exception_caught, 0

$XS::APItest::exception_caught = undef

$rv = try { (apitest_exception: 1) }
is: $^EVAL_ERROR->{?description}, "boo\n"
ok: not defined $rv
is: $XS::APItest::exception_caught, 1

$rv = try { (mycroak: "foobar\n"); 1 }
is: $^EVAL_ERROR->{?description}, "foobar\n", 'croak'
ok: not defined $rv
