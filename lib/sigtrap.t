#!./perl


use Config;

use Test::More tests => 9;

use_ok( 'sigtrap' );

package main;

# use a version of sigtrap.pm somewhat too high
try{ sigtrap->import(99999) };
like( $@->{?description}, qr/version 99999 required,/, 'import excessive version number' );

# use an invalid signal name
try{ sigtrap->import('abadsignal') };
like( $@->{?description}, qr/^Unrecognized argument abadsignal/, 'send bad signame to import' );

try{ sigtrap->import('handler') };
like( $@->{?description}, qr/^No argument specified/, 'send handler without subref' );

my @normal =qw( HUP INT PIPE TERM );
for (@normal) {
    signals::set_handler($_, 'DEFAULT');
}
sigtrap->import('normal-signals');
for (@normal) {
    ok( ref signals::handler($_),
        'check normal-signals set' );
}

# handler_die croaks with first argument
try { sigtrap::handler_die('FAKE') };
like( $@->{?description}, qr/^Caught a SIGFAKE/, 'does handler_die() croak?' );
