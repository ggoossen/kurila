#!./perl

# check to see if subroutine declarations work everwhere

sub one {
    print "ok 1\n";
}

print "1..4\n";

one();
two();

sub two {
    print "ok 2\n";
}

our $x;
if ($x eq $x) {
    sub three {
	print "ok 3\n";
    }
    three();
}

four();

sub four {
    print "ok 4\n";
}
