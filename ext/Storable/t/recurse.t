#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#  

use Config;

BEGIN {
    if (env::var('PERL_CORE')){
	push $^INCLUDE_PATH, '../ext/Storable/t';
    } else {
	unshift $^INCLUDE_PATH, 't';
    }
    require 'st-dump.pl';
}

use Storable < qw(freeze thaw dclone);

package OBJ_REAL;

use Storable < qw(freeze thaw);

my @x = @('a', 1);

sub make { bless \@(), shift }

sub STORABLE_freeze {
	my $self = shift;
	my $cloning = shift;
	die "STORABLE_freeze" unless Storable::is_storing;
	return @(freeze(\@x), $self);
}

sub STORABLE_thaw($self, $cloning, $x, $obj) {
	die "STORABLE_thaw #1" unless $obj \== $self;
	my $len = length $x;
	my $a = thaw $x;
	die "STORABLE_thaw #2" unless ref $a eq 'ARRAY';
	die "STORABLE_thaw #3" unless nelems @$a == 2 && $a->[0] eq 'a' && $a->[1] == 1;
	@$self = @$a;
	die "STORABLE_thaw #4" unless Storable::is_retrieving;
}

package OBJ_SYNC;

@x = @('a', 1);

sub make { bless \%(), shift }

sub STORABLE_freeze($self, $cloning) {
	return if $cloning;
	return @("", \@x, $self);
}

sub STORABLE_thaw($self, $cloning, $undef, $a, $obj) {
	die "STORABLE_thaw #1" unless $obj \== $self;
	die "STORABLE_thaw #2" unless ref $a eq 'ARRAY' || @$a != 2;
	$self->{+ok} = $self;
}

package OBJ_SYNC2;

use Storable < qw(dclone);

sub make($class, $ext) {
	my $self = bless \%(), $class;

	$self->{+sync} = OBJ_SYNC->make;
	$self->{+ext} = $ext;
	return $self;
}

sub STORABLE_freeze {
	my $self = shift;
	my %copy = %$self;
	my $r = \%copy;
	my $t = dclone($r->{?sync});
	return @("", \@($t, $self->{?ext}), $r, $self, $r->{?ext});
}

sub STORABLE_thaw($self, $cloning, $undef, $a, $r, $obj, $ext) {
	die "STORABLE_thaw #1" unless $obj \== $self;
	die "STORABLE_thaw #2" unless ref $a eq 'ARRAY';
	die "STORABLE_thaw #3" unless ref $r eq 'HASH';
	die "STORABLE_thaw #4" unless $a->[1] \== $r->{?ext};
	$self->{+ok} = $self;
	@($self->{+sync}, $self->{+ext}) = @$a;
}

package OBJ_REAL2;

use Storable < qw(freeze thaw);

my $MAX = 20;
my $recursed = 0;
my $hook_called = 0;

sub make { bless \@(), shift }

sub STORABLE_freeze {
	my $self = shift;
	$hook_called++;
	return @(freeze($self), $self) if ++$recursed +< $MAX;
	return @("no", $self);
}

sub STORABLE_thaw($self, $cloning, $x, $obj) {
	die "STORABLE_thaw #1" unless $obj \== $self;
	$self->[+0] = thaw($x) if $x ne "no";
	$recursed--;
}

package main;

use Test::More tests => 32;

my $real = OBJ_REAL->make;
my $x = freeze $real;

my $y = thaw $x;
ok ref $y eq 'OBJ_REAL';
ok $y->[0] eq 'a';
ok $y->[1] == 1;

my $sync = OBJ_SYNC->make;
$x = freeze $sync;
ok 1;

$y = thaw $x;
ok 1;
ok $y->{?ok} \== $y;

my $ext = \@(1, 2);
$sync = OBJ_SYNC2->make($ext);
$x = freeze \@($sync, $ext);
ok 1;

my $z = thaw $x;
$y = $z->[0];
ok 1;
ok $y->{?ok} \== $y;
ok ref $y->{?sync} eq 'OBJ_SYNC';
ok $y->{?ext} \== $z->[1];

$real = OBJ_REAL2->make;
$x = freeze $real;
ok 1;
ok $OBJ_REAL2::recursed == $OBJ_REAL2::MAX;
ok $OBJ_REAL2::hook_called == $OBJ_REAL2::MAX;

$y = thaw $x;
ok 1;
ok $OBJ_REAL2::recursed == 0;

$x = dclone $real;
ok 1;
ok ref $x eq 'OBJ_REAL2';
ok $OBJ_REAL2::recursed == 0;
ok $OBJ_REAL2::hook_called == 2 * $OBJ_REAL2::MAX;

ok !Storable::is_storing;
ok !Storable::is_retrieving;

#
# The following was a test-case that Salvador Ortiz Garcia <sog@msg.com.mx>
# sent me, along with a proposed fix.
#

package Foo;

sub new {
	my $class = shift;
	my $dat = shift;
	return bless \%(dat => $dat), $class;
}

package Bar;
sub new {
	my $class = shift;
	return bless \%(
		a => 'dummy',
		b => \@( 
			Foo->new(1),
			Foo->new(2), # Second instance of a Foo 
		)
	), $class;
}

sub STORABLE_freeze($self,$clonning) {
	return @( "$self->{?a}", $self->{?b} );
}

sub STORABLE_thaw($self,$clonning,$dummy,$o) {
	$self->{+a} = $dummy;
	$self->{+b} = $o;
}

package main;

my $bar = Bar->new();
my $bar2 = thaw freeze $bar;

ok ref($bar2) eq 'Bar';
ok ref($bar->{b}->[0]) eq 'Foo';
ok ref($bar->{b}->[1]) eq 'Foo';
ok ref($bar2->{b}->[0]) eq 'Foo';
ok ref($bar2->{b}->[1]) eq 'Foo';

#
# The following attempts to make sure blessed objects are blessed ASAP
# at retrieve time.
#

package CLASS_1;

sub make {
	my $self = bless \%(), shift;
	return $self;
}

package CLASS_2;

sub make($class, $o) {
	my $self = bless \%(), $class;

	$self->{+c1} = CLASS_1->make();
	$self->{+o} = $o;
	$self->{+c3} = bless CLASS_1->make(), "CLASS_3";
	$o->set_c2($self);
	return $self;
}

sub STORABLE_freeze($self, $clonning) {
	return @( "", $self->{?c1}, $self->{?c3}, $self->{?o} );
}

sub STORABLE_thaw($self, $clonning, $frozen, $c1, $c3, $o) {
	main::ok ref $self eq "CLASS_2";
	main::ok ref $c1 eq "CLASS_1";
	main::ok ref $c3 eq "CLASS_3";
	main::ok ref $o eq "CLASS_OTHER";
	$self->{+c1} = $c1;
	$self->{+c3} = $c3;
}

package CLASS_OTHER;

sub make {
	my $self = bless \%(), shift;
	return $self;
}

sub set_c2 { @_[0]->{+c2} = @_[1] }

#
# Is the reference count of the extra references returned from a
# STORABLE_freeze hook correct? [ID 20020601.005]
#
package Foo2;

sub new {
	my $self = bless \%(), @_[0];
	$self->{+freezed} = dump::view($self);
	return $self;
}

sub DESTROY {
	my $self = shift;
	$main::refcount_ok = 1 unless dump::view($self) eq $self->{?freezed};
}

package Foo3;

sub new {
	bless \%(), @_[0];
}

sub STORABLE_freeze {
	my $obj = shift;
	return @("", $obj, Foo2->new);
}

sub STORABLE_thaw { } # Not really used

package main;
our ($refcount_ok);

my $o = CLASS_OTHER->make();
my $c2 = CLASS_2->make($o);
my $so = thaw freeze $o;

$refcount_ok = 0;
thaw freeze(Foo3->new);
ok $refcount_ok == 1;
