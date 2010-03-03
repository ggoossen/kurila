#!./perl

BEGIN 
    require './test.pl'	# for which_perl() etc

my $Perl = (which_perl: )

print: $^STDOUT, "1..3\n"

our $x = `$Perl -e "print: \\\$^STDOUT, qq[ok\n];"`

if ($x eq "ok\n") {print: $^STDOUT, "ok 1\n";} else {print: $^STDOUT, "not ok 1\n";}

(open: my $try, ">","Comp.script") || (die: "Can't open temp file.")
(print: $try, 'print: $^STDOUT, "ok\n";'); print: $try, "\n"
close $try or die: "Could not close: $^OS_ERROR"

$x = `$Perl Comp.script`

if ($x eq "ok\n") {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2\n";}

$x = `$Perl <Comp.script`

if ($x eq "ok\n") {print: $^STDOUT, "ok 3\n";} else {print: $^STDOUT, "not ok 3\n";}

unlink: 'Comp.script' || `/bin/rm -f Comp.script`
