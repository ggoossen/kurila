#!./perl -p

BEGIN {
    print $^STDOUT, "1..2\n";
    push @ARGV, 'run/switchp.aux';
}
