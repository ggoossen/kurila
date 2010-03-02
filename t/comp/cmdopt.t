#!./perl

print: $^STDOUT, "1..44\n"

# test the optimization of constants

if (1) { print: $^STDOUT, "ok 1\n";} else { print: $^STDOUT, "not ok 1\n";}
unless (0) { print: $^STDOUT, "ok 2\n";} else { print: $^STDOUT, "not ok 2\n";}

if (0) { print: $^STDOUT, "not ok 3\n";} else { print: $^STDOUT, "ok 3\n";}
unless (1) { print: $^STDOUT, "not ok 4\n";} else { print: $^STDOUT, "ok 4\n";}

unless (!1) { print: $^STDOUT, "ok 5\n";} else { print: $^STDOUT, "not ok 5\n";}
if (!0) { print: $^STDOUT, "ok 6\n";} else { print: $^STDOUT, "not ok 6\n";}

unless (!0) { print: $^STDOUT, "not ok 7\n";} else { print: $^STDOUT, "ok 7\n";}
if (!1) { print: $^STDOUT, "not ok 8\n";} else { print: $^STDOUT, "ok 8\n";}

our $x = 1
if (1 && $x) { print: $^STDOUT, "ok 9\n";} else { print: $^STDOUT, "not ok 9\n";}
if (0 && $x) { print: $^STDOUT, "not ok 10\n";} else { print: $^STDOUT, "ok 10\n";}
$x = ''
if (1 && $x) { print: $^STDOUT, "not ok 11\n";} else { print: $^STDOUT, "ok 11\n";}
if (0 && $x) { print: $^STDOUT, "not ok 12\n";} else { print: $^STDOUT, "ok 12\n";}

$x = 1
if (1 || $x) { print: $^STDOUT, "ok 13\n";} else { print: $^STDOUT, "not ok 13\n";}
if (0 || $x) { print: $^STDOUT, "ok 14\n";} else { print: $^STDOUT, "not ok 14\n";}
$x = ''
if (1 || $x) { print: $^STDOUT, "ok 15\n";} else { print: $^STDOUT, "not ok 15\n";}
if (0 || $x) { print: $^STDOUT, "not ok 16\n";} else { print: $^STDOUT, "ok 16\n";}


# test the optimization of variables

$x = 1
if ($x) { print: $^STDOUT, "ok 17\n";} else { print: $^STDOUT, "not ok 17\n";}
unless ($x) { print: $^STDOUT, "not ok 18\n";} else { print: $^STDOUT, "ok 18\n";}

$x = ''
if ($x) { print: $^STDOUT, "not ok 19\n";} else { print: $^STDOUT, "ok 19\n";}
unless ($x) { print: $^STDOUT, "ok 20\n";} else { print: $^STDOUT, "not ok 20\n";}

# test optimization of string operations

$a = 'a'
if ($a eq 'a') { print: $^STDOUT, "ok 21\n";} else { print: $^STDOUT, "not ok 21\n";}
if ($a ne 'a') { print: $^STDOUT, "not ok 22\n";} else { print: $^STDOUT, "ok 22\n";}

if ($a =~ m/a/) { print: $^STDOUT, "ok 23\n";} else { print: $^STDOUT, "not ok 23\n";}
if ($a !~ m/a/) { print: $^STDOUT, "not ok 24\n";} else { print: $^STDOUT, "ok 24\n";}
# test interaction of logicals and other operations

$a = 'a'
$x = 1
if ($a eq 'a' and $x) { print: $^STDOUT, "ok 25\n";} else { print: $^STDOUT, "not ok 25\n";}
if ($a ne 'a' and $x) { print: $^STDOUT, "not ok 26\n";} else { print: $^STDOUT, "ok 26\n";}
$x = ''
if ($a eq 'a' and $x) { print: $^STDOUT, "not ok 27\n";} else { print: $^STDOUT, "ok 27\n";}
if ($a ne 'a' and $x) { print: $^STDOUT, "not ok 28\n";} else { print: $^STDOUT, "ok 28\n";}

$x = 1
if ($a eq 'a' or $x) { print: $^STDOUT, "ok 29\n";} else { print: $^STDOUT, "not ok 29\n";}
if ($a ne 'a' or $x) { print: $^STDOUT, "ok 30\n";} else { print: $^STDOUT, "not ok 30\n";}
$x = ''
if ($a eq 'a' or $x) { print: $^STDOUT, "ok 31\n";} else { print: $^STDOUT, "not ok 31\n";}
if ($a ne 'a' or $x) { print: $^STDOUT, "not ok 32\n";} else { print: $^STDOUT, "ok 32\n";}

$x = 1
if ($a =~ m/a/ && $x) { print: $^STDOUT, "ok 33\n";} else { print: $^STDOUT, "not ok 33\n";}
if ($a !~ m/a/ && $x) { print: $^STDOUT, "not ok 34\n";} else { print: $^STDOUT, "ok 34\n";}
$x = ''
if ($a =~ m/a/ && $x) { print: $^STDOUT, "not ok 35\n";} else { print: $^STDOUT, "ok 35\n";}
if ($a !~ m/a/ && $x) { print: $^STDOUT, "not ok 36\n";} else { print: $^STDOUT, "ok 36\n";}

$x = 1
if ($a =~ m/a/ || $x) { print: $^STDOUT, "ok 37\n";} else { print: $^STDOUT, "not ok 37\n";}
if ($a !~ m/a/ || $x) { print: $^STDOUT, "ok 38\n";} else { print: $^STDOUT, "not ok 38\n";}
$x = ''
if ($a =~ m/a/ || $x) { print: $^STDOUT, "ok 39\n";} else { print: $^STDOUT, "not ok 39\n";}
if ($a !~ m/a/ || $x) { print: $^STDOUT, "not ok 40\n";} else { print: $^STDOUT, "ok 40\n";}

$x = 1
if ($a eq 'a' xor $x) { print: $^STDOUT, "not ok 41\n";} else { print: $^STDOUT, "ok 41\n";}
if ($a ne 'a' xor $x) { print: $^STDOUT, "ok 42\n";} else { print: $^STDOUT, "not ok 42\n";}
$x = ''
if ($a eq 'a' xor $x) { print: $^STDOUT, "ok 43\n";} else { print: $^STDOUT, "not ok 43\n";}
if ($a ne 'a' xor $x) { print: $^STDOUT, "not ok 44\n";} else { print: $^STDOUT, "ok 44\n";}
