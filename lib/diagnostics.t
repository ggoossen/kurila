#!./perl

use Test::More tests => 2;

BEGIN { use_ok('diagnostics') }

require base;

try {
    'base'->import(qw(I::do::not::exist));
};

like( $@->{description}, qr/^Base class package "I::do::not::exist" is empty/);
