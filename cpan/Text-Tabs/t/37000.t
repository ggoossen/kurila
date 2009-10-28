#!/usr/bin/perl -I.

#Causes Text::Wrap to die...
use warnings

use Text::Wrap

my $toPrint = "(1) Category\t(2 or greater) New Category\n\n"
my $good =    "(1) Category\t(2 or greater) New Category\n"

my $toprint

print: $^STDOUT, "1..6\n"

local($Text::Wrap::break) = '\s'
try { $toPrint = (wrap: "","",$toPrint); }
print: $^STDOUT, $^EVAL_ERROR ?? "not ok 1\n" !! "ok 1\n"
print: $^STDOUT, $toPrint eq $good ?? "ok 2\n" !! "not ok 2\n"

local($Text::Wrap::break) = '\d'
try { $toPrint = (wrap: "","",$toPrint); }
print: $^STDOUT, $^EVAL_ERROR ?? "not ok 3\n" !! "ok 3\n"
print: $^STDOUT, $toPrint eq $good ?? "ok 4\n" !! "not ok 4\n"

local($Text::Wrap::break) = 'a'
try { $toPrint = (wrap: "","",$toPrint); }
print: $^STDOUT, $^EVAL_ERROR ?? "not ok 5\n" !! "ok 5\n"
print: $^STDOUT, $toPrint eq $good ?? "ok 6\n" !! "not ok 6\n"

