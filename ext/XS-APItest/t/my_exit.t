#!perl

use strict;
use warnings;

require "test.pl";

plan(4);

use XS::APItest;

fresh_perl_is(<<'CODE', <<'ERROR'); is($? >> 8, 2);
use XS::APItest;
BEGIN {
    my_exit(1);
}
CODE
Callback called exit at - line 4.
BEGIN failed--compilation aborted at - line 4.
ERROR

fresh_perl_is(<<'CODE', <<'ERROR'); is($? >> 8, 1);
use XS::APItest;

my_exit(1);

print "NOT REACHED\n";
CODE
ERROR
