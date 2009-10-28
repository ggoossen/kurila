#! ./perl

BEGIN { require "./test.pl" }

plan: tests => 3

is: (ref::reftype: \$@), 'ARRAY'
is: (ref::reftype: \$%), 'HASH'
my $x = bless: \$@, 'Foo'
is: (ref::reftype: $x), 'ARRAY'
