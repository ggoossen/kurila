#!./perl -w
#
#  Copyright 2002, Larry Wall.
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

BEGIN {
    chdir('t') if -d 't';
    if (%ENV{PERL_CORE}){
	@INC = @('.', '../lib', '../ext/Storable/t');
    } else {
        if (!eval "require Hash::Util") {
            if ($@->{description} =~ m/Can\'t locate Hash\/Util\.pm in \@INC/s) {
                print "1..0 # Skip: No Hash::Util:\n";
                exit 0;
            } else {
                die;
            }
        }
	unshift @INC, 't';
    }
    require 'st-dump.pl';
}


use Storable < qw(dclone freeze thaw);
use Hash::Util < qw(lock_hash unlock_value);

print "1..100\n";

my %hash = %(question => '?', answer => 42, extra => 'junk', undef => undef);
lock_hash %hash;
unlock_value %hash, 'answer';
unlock_value %hash, 'extra';
delete %hash{'extra'};

my $test;

package Restrict_Test;

sub me_second {
  return  @(undef, @_[0]);
}

package main;

sub freeze_thaw {
  my $temp = freeze @_[0];
  return thaw $temp;
}

sub testit {
  my $hash = shift;
  my $cloner = shift;
  my $copy = &$cloner($hash);

  my @in_keys = sort keys %$hash;
  my @out_keys = sort keys %$copy;
  unless (ok ++$test, join(' ',@in_keys) eq join(' ',@out_keys)) {
    print "# Failed: keys mis-match after deep clone.\n";
    print "# Original keys: $(join ' ',@in_keys)\n";
    print "# Copy's keys: $(join ' ',@out_keys)\n";
  }

  # $copy = $hash;	# used in initial debug of the tests

  ok ++$test, Internals::SvREADONLY(%$copy), "cloned hash restricted?";

  ok ++$test, Internals::SvREADONLY($copy->{question}),
    "key 'question' not locked in copy?";

  ok ++$test, !Internals::SvREADONLY($copy->{answer}),
    "key 'answer' not locked in copy?";

  try { $copy->{+extra} = 15 } ;
  unless (ok ++$test, !$@, "Can assign to reserved key 'extra'?") {
      die $@;
  }

  try { $copy->{nono} = 7 } ;
  ok ++$test, $@, "Can not assign to invalid key 'nono'?";

  ok ++$test, exists $copy->{undef},
    "key 'undef' exists";

  ok ++$test, !defined $copy->{undef},
    "value for key 'undef' is undefined";
}

for my $canonical  (@(0, 1)) {
  $Storable::canonical = $canonical;
  for my $cloner (@(\&dclone, \&freeze_thaw)) {
    print "# \$Storable::canonical = $Storable::canonical\n";
    testit (\%hash, $cloner);
    my $object = \%hash;
    # bless {}, "Restrict_Test";

    my %hash2;
    %hash2{+"k$_"} = "v$_" for 0..16;
    lock_hash %hash2;
    for (0..16) {
      unlock_value %hash2, "k$_";
      delete %hash2{"k$_"};
    }
    my $copy = &$cloner(\%hash2);

    for (0..16) {
      my $k = "k$_";
      try { $copy->{+$k} = undef } ;
      unless (ok ++$test, !$@, "Can assign to reserved key '$k'?") {
          die $@;
      }
    }
  }
}
