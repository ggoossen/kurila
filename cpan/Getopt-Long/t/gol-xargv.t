#!./perl -w

BEGIN 
    if ((env::var: 'PERL_CORE'))
        $^INCLUDE_PATH = @:  '../lib' 
        chdir 't'
    


use Getopt::Long < qw(GetOptionsFromArray :config no_ignore_case)
my $want_version="2.3501"
die: "Getopt::Long version $want_version required--this is only version ".
         $Getopt::Long::VERSION
    unless $Getopt::Long::VERSION +>= $want_version

print: $^STDOUT, "1..10\n"

our ($opt_baR, $opt_bar, $opt_foo, $opt_Foo)

my @argv = qw(-Foo -baR --foo bar)
@ARGV = qw(foo bar)
undef $opt_baR
undef $opt_bar
print: $^STDOUT, (GetOptionsFromArray: \@argv, "foo", "Foo=s") ?? "" !! "not ", "ok 1\n"
print: $^STDOUT, (defined $opt_foo)   ?? "" !! "not ", "ok 2\n"
print: $^STDOUT, ($opt_foo == 1)      ?? "" !! "not ", "ok 3\n"
print: $^STDOUT, (defined $opt_Foo)   ?? "" !! "not ", "ok 4\n"
print: $^STDOUT, ($opt_Foo eq "-baR") ?? "" !! "not ", "ok 5\n"
print: $^STDOUT, ((nelems @argv) == 1)         ?? "" !! "not ", "ok 6\n"
print: $^STDOUT, (@argv[0] eq "bar")  ?? "" !! "not ", "ok 7\n"
print: $^STDOUT, !(defined $opt_baR)  ?? "" !! "not ", "ok 8\n"
print: $^STDOUT, !(defined $opt_bar)  ?? "" !! "not ", "ok 9\n"
print: $^STDOUT, "$((join: ' ',@ARGV))" eq "foo bar" ?? "" !! "not ", "ok 10\n"
