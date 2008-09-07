#!./perl -T

print "1..2\n";
use File::Glob;
print "ok 1\n";

# all filenames should be tainted
my @a = File::Glob::bsd_glob("*");
try { $a = join("", @a), kill 0; 1 };
unless ($@->{description} =~ m/Insecure dependency/) {
    print "not ";
}
print "ok 2\n";
