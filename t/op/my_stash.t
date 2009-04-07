#!./perl

package Foo;

use Test::More;

plan tests => 7;

use constant MyClass => 'Foo::Bar::Biz::Baz';

do {
    package Foo::Bar::Biz::Baz;
    1;
};

for (qw(Foo Foo:: MyClass __PACKAGE__)) {
    eval "sub \{ my $_ \$obj = shift; \}";
    ok $^EVAL_ERROR->{?description} =~ m/Expected variable after declarator/;
}

use constant NoClass => 'Nope::Foo::Bar::Biz::Baz';

for (qw(Nope Nope:: NoClass)) {
    eval "sub \{ my $_ \$obj = shift; \}";
    ok $^EVAL_ERROR;
#    print $@ if $@;
}
