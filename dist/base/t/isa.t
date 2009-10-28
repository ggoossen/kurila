#!/usr/bin/perl -w

# Regression test some quirky behavior of base.pm.

use Test::More tests => 1

do
    package Parent

    sub foo { 42 }

    package Middle

    use base < qw(Parent)

    package Child

    base->import:  <qw(Middle Parent)


is_deeply: \ @Child::ISA, \qw(Middle)
           'base.pm will not add to @ISA if you already are-a'
