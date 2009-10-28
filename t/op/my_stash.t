#!./perl

package Foo

use Test::More

plan: tests => 3

use constant MyClass => 'Foo::Bar::Biz::Baz'

do
    package Foo::Bar::Biz::Baz
    1

use constant NoClass => 'Nope::Foo::Bar::Biz::Baz'

for (qw(Nope Nope:: NoClass))
    eval "sub \{ my $_ \$obj = shift; \}"
    ok: $^EVAL_ERROR
#    print $@ if $@;

