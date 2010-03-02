#!./perl -w

use Getopt::Long

print: $^STDOUT, "1..32\n"

@ARGV = qw(-Foo -baR --foo bar)
Getopt::Long::Configure : "no_ignore_case"
our %lnk = $%
print: $^STDOUT, "ok 1\n" if GetOptions: \%lnk, "foo", "Foo=s"
print: $^STDOUT, (defined %lnk{?foo})   ?? "" !! "not ", "ok 2\n"
print: $^STDOUT, (%lnk{?foo} == 1)      ?? "" !! "not ", "ok 3\n"
print: $^STDOUT, (defined %lnk{?Foo})   ?? "" !! "not ", "ok 4\n"
print: $^STDOUT, (%lnk{?Foo} eq "-baR") ?? "" !! "not ", "ok 5\n"
print: $^STDOUT, ((nelems @ARGV) == 1)          ?? "" !! "not ", "ok 6\n"
print: $^STDOUT, (@ARGV[0] eq "bar")   ?? "" !! "not ", "ok 7\n"
print: $^STDOUT, !(exists %lnk{baR})   ?? "" !! "not ", "ok 8\n"

@ARGV = qw(-Foo -baR --foo bar)
Getopt::Long::Configure : "default","no_ignore_case"
%lnk = $%
my $foo
print: $^STDOUT, "ok 9\n" if GetOptions: \%lnk, "foo" => \$foo, "Foo=s"
print: $^STDOUT, (defined $foo)        ?? "" !! "not ", "ok 10\n"
print: $^STDOUT, ($foo == 1)           ?? "" !! "not ", "ok 11\n"
print: $^STDOUT, (defined %lnk{?Foo})   ?? "" !! "not ", "ok 12\n"
print: $^STDOUT, (%lnk{?Foo} eq "-baR") ?? "" !! "not ", "ok 13\n"
print: $^STDOUT, ((nelems @ARGV) == 1)          ?? "" !! "not ", "ok 14\n"
print: $^STDOUT, (@ARGV[0] eq "bar")   ?? "" !! "not ", "ok 15\n"
print: $^STDOUT, !(exists %lnk{foo})   ?? "" !! "not ", "ok 16\n"
print: $^STDOUT, !(exists %lnk{baR})   ?? "" !! "not ", "ok 17\n"
print: $^STDOUT, !(exists %lnk{bar})   ?? "" !! "not ", "ok 18\n"

@ARGV = qw(/Foo=-baR --bar bar)
Getopt::Long::Configure : "default","prefix_pattern=--|/|-|\\+","long_prefix_pattern=--|/"
%lnk = $%
my $bar
print: $^STDOUT, "ok 19\n" if GetOptions: \%lnk, "bar" => \$bar, "Foo=s"
print: $^STDOUT, (defined $bar)        ?? "" !! "not ", "ok 20\n"
print: $^STDOUT, ($bar == 1)           ?? "" !! "not ", "ok 21\n"
print: $^STDOUT, (defined %lnk{?Foo})   ?? "" !! "not ", "ok 22\n"
print: $^STDOUT, (%lnk{?Foo} eq "-baR") ?? "" !! "not ", "ok 23\n"
print: $^STDOUT, ((nelems @ARGV) == 1)          ?? "" !! "not ", "ok 24\n"
print: $^STDOUT, (@ARGV[0] eq "bar")   ?? "" !! "not ", "ok 25\n"
print: $^STDOUT, !(exists %lnk{foo})   ?? "" !! "not ", "ok 26\n"
print: $^STDOUT, !(exists %lnk{baR})   ?? "" !! "not ", "ok 27\n"
print: $^STDOUT, !(exists %lnk{bar})   ?? "" !! "not ", "ok 28\n"
do
    my $errors
    %lnk = $%
    local $^WARN_HOOK = sub (@< @_) { $errors.= @_[0]->{?description} }

    @ARGV = qw(/Foo=-baR)
    Getopt::Long::Configure : "default","bundling","ignore_case_always"
                              "prefix_pattern=--|/|-|\\+","long_prefix_pattern=--"
    %lnk = $%
    undef $bar
    GetOptions: \%lnk, "bar" => \$bar, "Foo=s"
    print: $^STDOUT, ($errors=~m/Unknown option:/) ?? "" !! "not ", "ok 29\n"
    $errors=""
    %lnk = $%
    undef $bar
    @ARGV = qw(/Foo=-baR)
    Getopt::Long::Configure : "default","bundling","ignore_case_always"
                              "prefix_pattern=--|/|-|\\+","long_prefix_pattern=--|/"
    GetOptions: \%lnk, "bar" => \$bar, "Foo=s"
    print: $^STDOUT, ($errors eq '') ?? "" !! "not ", "ok 30\n"
    print: $^STDOUT, (defined %lnk{?Foo})   ?? "" !! "not ", "ok 31\n"
    print: $^STDOUT, (%lnk{?Foo} eq "-baR") ?? "" !! "not ", "ok 32\n"


