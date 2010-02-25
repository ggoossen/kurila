#!/usr/bin/perl -w

# Make sure this is in place before Test::More is loaded.
my $handler
BEGIN 
    $handler = sub (@< @_) { (die: "ARR"); }
    $^DIE_HOOK = $handler


use Test::More tests => 1

:SKIP do
    skip: "CV reference changed", 1
    ok: $^DIE_HOOK &== $handler, 'existing DIE handler not overridden'

