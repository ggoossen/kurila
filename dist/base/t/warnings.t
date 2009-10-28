#!/usr/bin/perl -w

use Test::More tests => 1

my $warnings
BEGIN 
    $^WARN_HOOK = sub (@< @_) { $warnings = @_[0]->{?description} }


do
    package Foo
    use fields < qw(thing)


do
    package Bar
    use fields < qw(stuff)
    use base < qw(Foo)


main::like:  $warnings
             '/^Bar is inheriting from Foo but already has its own fields!/'
             'Inheriting from a base with protected fields warns'
