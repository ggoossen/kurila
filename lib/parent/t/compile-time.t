#!/usr/bin/perl -w

use Test::More tests => 3

do
    package MyParent
    sub exclaim { "I CAN HAS PERL?" }

do
    package Child
    use parent '-norequire', 'MyParent'

my $obj = \ $%
bless: $obj, 'Child'
isa_ok: $obj, 'MyParent', 'Inheritance'
can_ok: $obj, 'exclaim'
is: $obj->exclaim, "I CAN HAS PERL?", 'Inheritance is set up correctly'

