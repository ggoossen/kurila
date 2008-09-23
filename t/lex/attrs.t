#!./perl

# Regression tests for attributes.pm and the C< : attrs> syntax.

use warnings;

BEGIN {
    require './test.pl';
}

plan 'no_plan';

$^WARN_HOOK = sub { die < @_ };

our ($anon1, $anon2, $anon3);

sub eval_ok ($;$) {
    eval shift;
    diag $@->message if $@;
    ok( ! $@, < @_);
}

eval_ok 'sub t1 ($) : locked { @_[0]++ }';
eval_ok 'sub t2 : locked { @_[0]++ }';
eval_ok '$anon1 = sub ($) : locked:method { @_[0]++ }';
eval_ok '$anon2 = sub : locked : method { @_[0]++ }';
eval_ok '$anon3 = sub : method { @_[0]->[1] }';

eval 'sub e1 ($) : plugh { 1 }';
like $@->message, qr/^Invalid CODE attributes?: ["']?plugh["']? at/;

eval 'sub e2 ($) : plugh(0,0) xyzzy { 1 }';
like $@->message, qr/^Invalid CODE attributes: ["']?plugh\(0,0\)["']? /;

eval 'sub e3 ($) : plugh(0,0 xyzzy { 1 }';
like $@->message, qr/Unterminated attribute parameter in attribute list at/;

eval 'sub e4 ($) : plugh + xyzzy { 1 }';
like $@->message, qr/Invalid separator character '[+]' in attribute list at/;

eval_ok 'my $x ;';
eval_ok 'my ($x,$y) ;';
