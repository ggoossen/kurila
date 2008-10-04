#!/usr/bin/perl -w

# Make sure this is in place before Test::More is loaded.
my $handler;
BEGIN {
    $handler = sub { die "ARR"; };
    $^DIE_HOOK = $handler;
}

use Test::More tests => 1;

do {
    local $TODO = "CV refernce changed";
    ok $^DIE_HOOK \== $handler, 'existing DIE handler not overridden';
};
