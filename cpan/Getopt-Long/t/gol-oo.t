#!./perl -w

use Getopt::Long
my $want_version="2.24"
die: "Getopt::Long version $want_version required--this is only version ".
         $Getopt::Long::VERSION
    unless $Getopt::Long::VERSION +>= $want_version
print: $^STDOUT, "1..9\n"

our ($opt_baR, $opt_bar, $opt_foo, $opt_Foo)

@ARGV = qw(-Foo -baR --foo bar)
my $p = Getopt::Long::Parser->new: config => \(@: "no_ignore_case")
undef $opt_baR
undef $opt_bar
print: $^STDOUT, "ok 1\n" if $p->getoptions : "foo", "Foo=s"
print: $^STDOUT, (defined $opt_foo)   ?? "" !! "not ", "ok 2\n"
print: $^STDOUT, ($opt_foo == 1)      ?? "" !! "not ", "ok 3\n"
print: $^STDOUT, (defined $opt_Foo)   ?? "" !! "not ", "ok 4\n"
print: $^STDOUT, ($opt_Foo eq "-baR") ?? "" !! "not ", "ok 5\n"
print: $^STDOUT, ((nelems @ARGV) == 1)         ?? "" !! "not ", "ok 6\n"
print: $^STDOUT, (@ARGV[0] eq "bar")  ?? "" !! "not ", "ok 7\n"
print: $^STDOUT, !(defined $opt_baR)  ?? "" !! "not ", "ok 8\n"
print: $^STDOUT, !(defined $opt_bar)  ?? "" !! "not ", "ok 9\n"
