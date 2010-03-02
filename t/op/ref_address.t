#! ./perl

BEGIN { require "./test.pl" }

plan: tests => 4

my ($foo, $bar)
is: (ref::address: 'foo'), undef
ok: ref::address: \$foo
is: (ref::address: \$foo), ref::address: \$foo
isnt: (ref::address: \$foo), ref::address: \$bar
