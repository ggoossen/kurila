#!./perl
#
# Tests for Perl run-time environment variable settings
#
# $PERL5OPT, $PERL5LIB, etc.

use TestInit;
use Config;

BEGIN {
    unless (config_value('d_fork')) {
        print "1..0 # Skip: no fork\n";
        exit 0;
    }
}

BEGIN { require './test.pl'; }

plan tests => 11;

my $STDOUT = './results-0';
my $STDERR = './results-1';
my $PERL = env::var('PERL') || './perl';
my $FAILURE_CODE = 119;

env::set_var('PERLLIB', undef);
env::set_var('PERL5LIB', undef);
env::set_var('PERL5OPT', undef);

# Run perl with specified environment and arguments returns a list.
# First element is true if Perl's stdout and stderr match the
# supplied $stdout and $stderr argument strings exactly.
# second element is an explanation of the failure
sub runperl {
  local *F;
  my @($env, $args, $stdout, $stderr) =  @_;

  unshift @$args, '-I../lib';

  $stdout = '' unless defined $stdout;
  $stderr = '' unless defined $stderr;
  env::temp_set_var('PERLLIB', undef);
  env::temp_set_var('PERL5LIB', undef);
  env::temp_set_var('PERL5OPT', undef);
  my $pid = fork;
  return  @(0, "Couldn't fork: $^OS_ERROR") unless defined $pid;   # failure
  if ($pid) {                   # parent
    my ($actual_stdout, $actual_stderr);
    wait;
    return  @(0, "Failure in child.\n") if ($^CHILD_ERROR>>8) == $FAILURE_CODE;

    open F, "<", $STDOUT or return  @(0, "Couldn't read $STDOUT file");
    do { local $^INPUT_RECORD_SEPARATOR; $actual_stdout = ~< *F };
    open F, "<", $STDERR or return  @(0, "Couldn't read $STDERR file");
    do { local $^INPUT_RECORD_SEPARATOR; $actual_stderr = ~< *F };

    if ($actual_stdout ne $stdout) {
      return  @(0, "Stdout mismatch: expected:\n[$stdout]\nsaw:\n[$actual_stdout]");
    } elsif ($actual_stderr ne $stderr) {
      return  @(0, "Stderr mismatch: expected:\n[$stderr]\nsaw:\n[$actual_stderr]");
    } else {
      return @(1, '');                 # success
    }
  } else {                      # child
      my $old = %:< map { $_ => env::var($_) } keys %$env;
      push dynascope->{onleave}, sub {
          for (keys $old) {
              env::set_var($_, $old{$_});
          }
      };
      env::set_var($_ => $env->{$_}) for keys %$env;
      open STDOUT, ">", $STDOUT or exit $FAILURE_CODE;
      open STDERR, ">", $STDERR or it_didnt_work();
      do { exec $PERL, < @$args };
      it_didnt_work();
  }
}


sub it_didnt_work {
    print STDOUT "IWHCWJIHCI\cNHJWCJQWKJQJWCQW\n";
    exit $FAILURE_CODE;
}

sub tryrun {
  my @($success, $reason) =  runperl(< @_);
  ok( $success, $reason );
}

#  PERL5OPT    Command-line options (switches).  Switches in
#                    this variable are taken as if they were on
#                    every Perl command line.  Only the -[DIMUdmtw]
#                    switches are allowed.  When running taint
#                    checks (because the program was running setuid
#                    or setgid, or the -T switch was used), this
#                    variable is ignored.  If PERL5OPT begins with
#                    -T, tainting will be enabled, and any
#                    subsequent options ignored.

tryrun(\%(PERL5OPT => '-w'), \@('-e', 'print $main::x'),
    "", 
    qq{Name "main::x" used only once: possible typo
Use of uninitialized value \$main::x in print at -e line 1 character 1.
});

tryrun(\%(PERL5OPT => '-MExporter'), \@('-e0'),
    "", 
    "");

# Fails in 5.6.0
tryrun(\%(PERL5OPT => '-MExporter -MExporter'), \@('-e0'),
    "", 
    "");

tryrun(\%(PERL5OPT => '-Mwarnings'), 
    \@('-e', 'print "ok" if $^INCLUDED{"warnings.pm"}'),
    "ok",
    "");

tryrun(\%(PERL5OPT => '-w -w'),
    \@('-e', 'print env::var(q[PERL5OPT])'),
    '-w -w',
    '');

tryrun(\%(PERLLIB => "foobar$(config_value('path_sep'))42"),
    \@('-e', 'print < grep { $_ eq "foobar" } $^INCLUDE_PATH'),
    'foobar',
    '');

tryrun(\%(PERLLIB => "foobar$(config_value('path_sep'))42"),
    \@('-e', 'print < grep { $_ eq "42" } $^INCLUDE_PATH'),
    '42',
    '');

tryrun(\%(PERL5LIB => "foobar$(config_value('path_sep'))42"),
    \@('-e', 'print < grep { $_ eq "foobar" } $^INCLUDE_PATH'),
    'foobar',
    '');

tryrun(\%(PERL5LIB => "foobar$(config_value('path_sep'))42"),
    \@('-e', 'print < grep { $_ eq "42" } $^INCLUDE_PATH'),
    '42',
    '');

tryrun(\%(PERL5LIB => "foo",
     PERLLIB => "bar"),
    \@('-e', 'print < grep { $_ eq "foo" } $^INCLUDE_PATH'),
    'foo',
    '');

tryrun(\%(PERL5LIB => "foo",
     PERLLIB => "bar"),
    \@('-e', 'print < grep { $_ eq "bar" } $^INCLUDE_PATH'),
    '',
    '');

# PERL5LIB tests with included arch directories still missing

END {
    1 while unlink $STDOUT;
    1 while unlink $STDERR;
}
