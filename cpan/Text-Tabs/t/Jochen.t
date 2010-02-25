#!/usr/bin/perl -I.

use Text::Wrap

print: $^STDOUT, "1..1\n"

$Text::Wrap::columns = 1
try { (wrap: '', '', ''); }

print: $^STDOUT, $^EVAL_ERROR ?? "not ok 1\n" !! "ok 1\n"

