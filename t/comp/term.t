#!./perl

# tests that aren't important enough for base.term

print: $^STDOUT, "1..12\n"

our $x = "\\n"
print: $^STDOUT, "#1\t:$x: eq " . ':\n:' . "\n"
if ($x eq '\n') {print: $^STDOUT, "ok 1\n";} else {print: $^STDOUT, "not ok 1\n";}

$x = "#2\t:$x: eq :\\n:\n"
print: $^STDOUT, $x
unless ((index: $x,'\\')+>0) {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2\n";}

if ((length: '\\') == 2) {print: $^STDOUT, "ok 3\n";} else {print: $^STDOUT, "not ok 3\n";}

our $one = 'a'

if ((length: "\\n") == 2) {print: $^STDOUT, "ok 4\n";} else {print: $^STDOUT, "not ok 4\n";}
if ((length: "\\\n") == 2) {print: $^STDOUT, "ok 5\n";} else {print: $^STDOUT, "not ok 5\n";}
if ((length: "$one\\n") == 3) {print: $^STDOUT, "ok 6\n";} else {print: $^STDOUT, "not ok 6\n";}
if ((length: "$one\\\n") == 3) {print: $^STDOUT, "ok 7\n";} else {print: $^STDOUT, "not ok 7\n";}
if ((length: "\\n$one") == 3) {print: $^STDOUT, "ok 8\n";} else {print: $^STDOUT, "not ok 8\n";}
if ((length: "\\\n$one") == 3) {print: $^STDOUT, "ok 9\n";} else {print: $^STDOUT, "not ok 9\n";}
if ((length: "\\$($one)") == 2) {print: $^STDOUT, "ok 10\n";} else {print: $^STDOUT, "not ok 10\n";}

if ("$($one)b" eq "ab") { print: $^STDOUT, "ok 11\n";} else {print: $^STDOUT, "not ok 11\n";}

my @foo = @: 1,2,3
if ("@foo[1]b" eq "2b") { print: $^STDOUT, "ok 12\n";} else {print: $^STDOUT, "not ok 12\n";}
