#!./perl


use warnings

require q(./test.pl); plan: tests => 4

do
    package Foo
    our @ISA = qw//


ok: !(mro::get_pkg_gen: 'ReallyDoesNotExist')
    "pkg_gen 0 for non-existant pkg"

my $f_gen = mro::get_pkg_gen: 'Foo'
ok: $f_gen +> 0, 'Foo pkg_gen > 0'

do
    no warnings 'once'
    *Foo::foo_func = sub (@< @_) { 123 }

my $new_f_gen = mro::get_pkg_gen: 'Foo'
ok: $new_f_gen +> $f_gen, 'Foo pkg_gen incs for methods'
$f_gen = $new_f_gen

@Foo::ISA = qw/Bar/
$new_f_gen = mro::get_pkg_gen: 'Foo'
ok: $new_f_gen +> $f_gen, 'Foo pkg_gen incs for @ISA'
