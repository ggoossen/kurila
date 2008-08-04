#!./perl

BEGIN {
    print "1..3\n";
    push @ARGV, 'run/switchp.aux';
}
print ~< *ARGV;
print "ok 3\n";
