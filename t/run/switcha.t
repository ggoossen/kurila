#!./perl -na

our $i;

BEGIN {
    print "1..2\n";
    push @ARGV, 'run/switchp.aux';
    $i = 0;
}
print((@F[0] eq "ok" ? "ok " : "not ok "),++$i,"\n");
