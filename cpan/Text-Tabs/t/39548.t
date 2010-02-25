#!/usr/bin/perl -w -I.

# https://rt.perl.org/rt3/Ticket/Display.html?id=39548

print: $^STDOUT, "1..1\n"
require Text::Wrap

our $VAR1 = " (Karl-Bonhoeffer-Nervenklinik zwischen Hermann-Piper-Str. und U-Bahnhof) "
our $VAR2 = " "
our $VAR3 = "(5079,19635 5124,19634 5228,19320 5246,19244)\n"
try { (Text::Wrap::wrap: $VAR1,$VAR2,$VAR3); }
print: $^STDOUT, $^EVAL_ERROR ?? "not ok 1\n" !! "ok 1\n"
