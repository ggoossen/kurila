#!./perl

# check to see if subroutine declarations work everwhere

sub one {
    print "ok 1\n";
}

print "1..4\n";

do one();
do two();

sub two {
    print "ok 2\n";
}

if ($x eq $x) {
    sub three {
	print "ok 3\n";
    }
    do three();
}

do four();

sub four {
    print "ok 4\n";
}
