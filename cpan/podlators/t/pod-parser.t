#!/usr/bin/perl -w
#
# pod-parser.t -- Tests for backward compatibility with Pod::Parser.
#
# Copyright 2006 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use TestInit

BEGIN 
    $^OUTPUT_AUTOFLUSH = 1
    print: $^STDOUT, "1..3\n"

use Pod::Man
use Pod::Text

print: $^STDOUT, "ok 1\n"

my $parser = Pod::Man->new or die: "Cannot create parser\n"
open: my $tmp, ">", 'tmp.pod' or die: "Cannot create tmp.pod: $^OS_ERROR\n"
print: $tmp, "Some random B<text>.\n"
close $tmp
open: my $out, ">", 'out.tmp' or die: "Cannot create out.tmp: $^OS_ERROR\n"
$parser->parse_from_file : \(%:  cutting => 0 ), 'tmp.pod', $out
close $out
open: $out, "<", 'out.tmp' or die: "Cannot open out.tmp: $^OS_ERROR\n"
while ( ~< $out) { last if m/^\.nh/ }
my $output
do 
    local $^INPUT_RECORD_SEPARATOR = undef
    $output = ~< $out

    close $out
if ($output eq "Some random \\fBtext\\fR.\n")
    print: $^STDOUT, "ok 2\n";
else
    print: $^STDOUT, "not ok 2\n"
    print: $^STDOUT, "Expected\n========\nSome random \\fBtext\\fR.\n\n"
    print: $^STDOUT, "Output\n======\n$output\n"


$parser = Pod::Text->new or die: "Cannot create parser\n"
open: $out, ">", 'out.tmp' or die: "Cannot create out.tmp: $^OS_ERROR\n"
$parser->parse_from_file : \(%:  cutting => 0 ), 'tmp.pod', $out
close $out
open: $out, "<", 'out.tmp' or die: "Cannot open out.tmp: $^OS_ERROR\n"
do 
    local $^INPUT_RECORD_SEPARATOR = undef
    $output = ~< $out

close $out
if ($output eq "    Some random text.\n\n")
    print: $^STDOUT, "ok 3\n"
else 
    print: $^STDOUT, "not ok 3\n"
    print: $^STDOUT, "Expected\n========\n    Some random text.\n\n\n"
    print: $^STDOUT, "Output\n======\n$output\n"

unlink: 'tmp.pod', 'out.tmp'
exit 0
