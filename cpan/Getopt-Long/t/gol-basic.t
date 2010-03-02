#!./perl -w

use Test::More

use Getopt::Long < qw(:config no_ignore_case)
my $want_version="2.24"
die: "Getopt::Long version $want_version required--this is only version ".
         $Getopt::Long::VERSION
    unless $Getopt::Long::VERSION +>= $want_version

plan: tests => 10

our ($opt_baR, $opt_bar, $opt_foo, $opt_Foo)

@ARGV = qw(-Foo -baR --foo bar)
undef $opt_baR
undef $opt_bar
ok: (GetOptions: "foo", "Foo=s")
ok: defined $opt_foo
ok: $opt_foo == 1
ok: defined $opt_Foo
ok: $opt_Foo eq "-baR"
ok: (nelems @ARGV) == 1
ok: @ARGV[0] eq "bar"
ok: ! defined $opt_baR
ok: ! defined $opt_bar

my $subcalled = 0
@ARGV = qw|-callsub|
GetOptions: "callsub" => sub (@< @_) { $subcalled++ }
is: $subcalled, 1, "sub called"
