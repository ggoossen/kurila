#!./perl -w

use Getopt::Long qw(GetOptionsFromString :config no_ignore_case);
my $want_version="2.3501";
die("Getopt::Long version $want_version required--this is only version ".
    $Getopt::Long::VERSION)
  unless $Getopt::Long::VERSION +>= $want_version;

print "1..12\n";

our ($opt_baR, $opt_bar, $opt_foo, $opt_Foo);

my $args = "-Foo -baR --foo";
@ARGV = @( qw(foo bar) );
undef $opt_baR;
undef $opt_bar;
print (GetOptionsFromString($args, "foo", "Foo=s") ? "" : "not ", "ok 1\n");
print ((defined $opt_foo)   ? "" : "not ", "ok 2\n");
print (($opt_foo == 1)      ? "" : "not ", "ok 3\n");
print ((defined $opt_Foo)   ? "" : "not ", "ok 4\n");
print (($opt_Foo eq "-baR") ? "" : "not ", "ok 5\n");
print (!(defined $opt_baR)  ? "" : "not ", "ok 6\n");
print (!(defined $opt_bar)  ? "" : "not ", "ok 7\n");
print ("{join ' ', <@ARGV}" eq "foo bar" ? "" : "not ", "ok 8\n");

$args = "-Foo -baR blech --foo bar";
@ARGV = @( qw(foo bar) );
undef $opt_baR;
undef $opt_bar;
{ my $msg = "";
  local $^WARN_HOOK = sub { $msg .= @_[0]->{description} };
  my $ret = GetOptionsFromString($args, "foo", "Foo=s");
  print ($ret ? "not " : "ok 9\n");
  print ($msg =~ m/^GetOptionsFromString: Excess data / ? "" : "$msg\nnot ", "ok 10\n");
}
print ("{join ' ', <@ARGV}" eq "foo bar" ? "" : "not ", "ok 11\n");

$args = "-Foo -baR blech --foo bar";
@ARGV = @( qw(foo bar) );
undef $opt_baR;
undef $opt_bar;
print ("{join ' ', <@ARGV}" eq "foo bar" ? "" : "not ", "ok 12\n");
