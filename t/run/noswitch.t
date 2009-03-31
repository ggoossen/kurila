#!./perl

BEGIN {
    print $^STDOUT, "1..3\n";
    push @ARGV, 'run/switchp.aux';
}
print $^STDOUT, ~< *ARGV;
print $^STDOUT, "ok 3\n";
