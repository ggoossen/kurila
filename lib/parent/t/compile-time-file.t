#!/usr/bin/perl -w

use Test::More tests => 6
use lib '../lib/parent/t/lib'

do
    package Child
    use parent 'Dummy'

do
    package Child2
    require Dummy
    use parent '-norequire', 'Dummy::InlineChild'

my $obj = \ $%
bless: $obj, 'Child'
isa_ok: $obj, 'Dummy'
can_ok: $obj, 'exclaim'
is: $obj->exclaim, "I CAN FROM Dummy", 'Inheritance is set up correctly'

$obj = \ $%
bless: $obj, 'Child2'
isa_ok: $obj, 'Dummy::InlineChild'
can_ok: $obj, 'exclaim'
is: $obj->exclaim, "I CAN FROM Dummy::InlineChild", 'Inheritance is set up correctly for inlined classes'
