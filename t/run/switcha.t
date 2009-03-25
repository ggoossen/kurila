#!./perl -na

our $i;

BEGIN {
    print $^STDOUT, "1..2\n";
    push @ARGV, 'run/switchp.aux';
    $i = 0;
}
print($^STDOUT, (@F[0] eq "ok" ?? "ok " !! "not ok "),++$i,"\n");
