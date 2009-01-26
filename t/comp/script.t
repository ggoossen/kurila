#!./perl

BEGIN {
    require './test.pl';	# for which_perl() etc
}

my $Perl = which_perl();

print "1..3\n";

our $x = `$Perl -le "print 'ok';"`;

if ($x eq "ok\n") {print "ok 1\n";} else {print "not ok 1\n";}

open(my $try, ">","Comp.script") || (die "Can't open temp file.");
print $try 'print "ok\n";'; print $try "\n";
close $try or die "Could not close: $^OS_ERROR";

$x = `$Perl Comp.script`;

if ($x eq "ok\n") {print "ok 2\n";} else {print "not ok 2\n";}

$x = `$Perl <Comp.script`;

if ($x eq "ok\n") {print "ok 3\n";} else {print "not ok 3\n";}

unlink 'Comp.script' || `/bin/rm -f Comp.script`;
