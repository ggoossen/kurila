#!./perl -w

BEGIN { require './test.pl'; }

plan tests => 4;

is defined('aap'), 1, 'simple string is defined';
is defined(undef), '', "undef is not defined";
is defined( @() ), 1, "empty array is defined";
is defined( %() ), 1, "empty hash is defined";
