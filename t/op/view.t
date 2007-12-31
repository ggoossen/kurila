#! ./perl

BEGIN { require "./test.pl" }

plan tests => 5;

is dump::view('foo'), q|'foo'|;
is dump::view("'foo"), q|"'foo"|;
is dump::view("\nfoo"), q|"\nfoo"|;

is dump::view(*foo), '*main::foo';
is dump::view(15), '15';

