#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

BEGIN {
    if (env::var('PERL_CORE')){
	push $^INCLUDE_PATH, '../ext/Storable/t';
    }
    require 'st-dump.pl';
}

use Storable < qw(freeze thaw);

%::immortals
  = %(u => \undef,
     'y' => \(1 == 1),
     n => \(1 == 0)
);

use Test::More;

my $test = 12;
my $tests = $test + 6 + 2 * 6 * nkeys %::immortals;
plan tests => $tests;

package SHORT_NAME;

sub make { bless \@(), shift }

package SHORT_NAME_WITH_HOOK;

sub make { bless \@(), shift }

sub STORABLE_freeze {
	my $self = shift;
	return @("", $self);
}

sub STORABLE_thaw($self, $cloning, $x, $obj) {
	die "STORABLE_thaw" unless $obj \== $self;
}

package main;

# Still less than 256 bytes, so long classname logic not fully exercised
# Wait until Perl removes the restriction on identifier lengths.
my $name = "LONG_NAME_" . 'xxxxxxxxxxxxx::' x 14 . "final";

eval <<EOC;
package $name;

our \@ISA = \@("SHORT_NAME");
EOC
die $^EVAL_ERROR if $^EVAL_ERROR;
ok $^EVAL_ERROR eq '';

eval <<EOC;
package $($name)_WITH_HOOK;

our \@ISA = \@("SHORT_NAME_WITH_HOOK");
EOC
ok ! $^EVAL_ERROR ;

# Construct a pool of objects
my @pool;

for my $i (0..9) {
	push(@pool, SHORT_NAME->make);
	push(@pool, SHORT_NAME_WITH_HOOK->make);
	push(@pool, $name->make);
	push(@pool, "$($name)_WITH_HOOK"->make);
}

my $x = freeze \@pool;
ok 1;

my $y = thaw $x;
ok ref $y eq 'ARRAY';
ok nelems(@{$y}) == nelems(@pool);

ok ref $y->[0] eq 'SHORT_NAME';
ok ref $y->[1] eq 'SHORT_NAME_WITH_HOOK';
ok ref $y->[2] eq $name;
ok ref $y->[3] eq "$($name)_WITH_HOOK";

my $good = 1;
for my $i (0..9) {
	do { $good = 0; last } unless ref $y->[4*$i]   eq 'SHORT_NAME';
	do { $good = 0; last } unless ref $y->[4*$i+1] eq 'SHORT_NAME_WITH_HOOK';
	do { $good = 0; last } unless ref $y->[4*$i+2] eq $name;
	do { $good = 0; last } unless ref $y->[4*$i+3] eq "$($name)_WITH_HOOK";
}
ok $good;

do {
	my $blessed_ref = bless \\\@(1,2,3), 'Foobar';
	my $x = freeze $blessed_ref;
	my $y = thaw $x;
	ok ref $y eq 'Foobar';
	ok $$$y->[0] == 1;
};

package RETURNS_IMMORTALS;

sub make { my $self = shift; bless \ @_, $self }

sub STORABLE_freeze {
  # Some reference some number of times.
  my $self = shift;
  my @($what, $times) =  @$self;
  return @("$what$times", < (@(%::immortals{?$what}) x $times));
}

sub STORABLE_thaw($self, $cloning, $x, @< @refs) {
	my @($what, $times) = @: $x =~ m/(.)(\d+)/;
	die "'$x' didn't match" unless defined $times;
	main::ok nelems(@refs) == $times;
	my $expect = %::immortals{?$what};
	die "'$x' did not give a reference" unless ref $expect;
	my $fail;
	foreach ( @refs) {
	  $fail++ if $_ \!= $expect;
	}
	main::ok !$fail;
}

package main;

# $Storable::DEBUGME = 1;
foreach my $count (1..3) {
  foreach my $immortal (keys %::immortals) {
    print $^STDOUT, "# $immortal x $count\n";
    my $i =  RETURNS_IMMORTALS->make ($immortal, $count);

    my $f = freeze ($i);
    ok $f;
    my $t = thaw $f;
    ok 1;
  }
}

# Test automatic require of packages to find thaw hook.

package HAS_HOOK;

our $loaded_count = 0;
our $thawed_count = 0;

sub make {
  bless \@();
}

sub STORABLE_freeze {
  my $self = shift;
  return @('');
}

package main;

my $f = freeze (HAS_HOOK->make);

ok $HAS_HOOK::loaded_count == 0;
ok $HAS_HOOK::thawed_count == 0;

my $t = thaw $f;
ok $HAS_HOOK::loaded_count == 1;
ok $HAS_HOOK::thawed_count == 1;
ok $t;
ok ref $t eq 'HAS_HOOK';

# Can't do this because the method is still cached by UNIVERSAL::can
# delete $INC{"HAS_HOOK.pm"};
# undef &HAS_HOOK::STORABLE_thaw;
# 
# warn HAS_HOOK->can('STORABLE_thaw');
# $t = thaw $f;
# ok $HAS_HOOK::loaded_count == 2;
# ok $HAS_HOOK::thawed_count == 2;
# ok $t;
# ok ref $t eq 'HAS_HOOK';
