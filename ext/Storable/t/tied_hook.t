#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

use Config;

sub BEGIN {
    if (%ENV{PERL_CORE}){
	push @INC, '../ext/Storable/t';
    } else {
	unshift @INC, 't';
    }
    if (%ENV{PERL_CORE} and %Config{'extensions'} !~ m/\bStorable\b/) {
        print "1..0 # Skip: Storable was not built\n";
        exit 0;
    }
    require 'st-dump.pl';
}

sub ok;

use Storable qw(freeze thaw);

print "1..25\n";

our ($scalar_fetch, $array_fetch, $hash_fetch) = (0, 0, 0);

package TIED_HASH;

sub TIEHASH {
	my $self = bless \%(), shift;
	return $self;
}

sub FETCH {
	my $self = shift;
	my ($key) = <@_;
	$main::hash_fetch++;
	return $self->{$key};
}

sub STORE {
	my $self = shift;
	my ($key, $value) = <@_;
	$self->{$key} = $value;
}

sub FIRSTKEY {
	my $self = shift;
	scalar keys %{$self};
	return each %{$self};
}

sub NEXTKEY {
	my $self = shift;
	return each %{$self};
}

sub STORABLE_freeze {
	my $self = shift;
	$main::hash_hook1++;
	return join(":", keys %$self) . ";" . join(":", values %$self);
}

sub STORABLE_thaw {
	my ($self, $cloning, $frozen) = @_;
	my ($keys, $values) = split(m/;/, $frozen);
	my @keys = @(split(m/:/, $keys));
	my @values = @(split(m/:/, $values));
	for (my $i = 0; $i +< nelems @keys; $i++) {
		$self->{@keys[$i]} = @values[$i];
	}
	$main::hash_hook2++;
}

package TIED_SCALAR;

sub TIESCALAR {
	my $scalar;
	my $self = bless \$scalar, shift;
	return $self;
}

sub FETCH {
	my $self = shift;
	$main::scalar_fetch++;
	return $$self;
}

sub STORE {
	my $self = shift;
	my ($value) = <@_;
	$$self = $value;
}

sub STORABLE_freeze {
	my $self = shift;
	$main::scalar_hook1++;
	return $$self;
}

sub STORABLE_thaw {
	my ($self, $cloning, $frozen) = <@_;
	$$self = $frozen;
	$main::scalar_hook2++;
}

package main;

$a = 'toto';
$b = \$a;

my $c = tie my %hash, 'TIED_HASH';
tie my $scalar, 'TIED_SCALAR';

$scalar = 'foo';
%hash{'attribute'} = 'plain value';
@array[0] = dump::view(\$scalar);
@array[1] = dump::view($c);
@array[2] = dump::view(\@array);
@array[3] = "plaine scalaire";

my @tied = @(\$scalar, \@array, \%hash);
my %a = %('key', 'value', 1, 0, $a, $b, 'cvar', \$a, 'scalarref', \$scalar);
my @a = @('first', 3, -4, -3.14159, 456, 4.5, $d, \$d,
         $b, \$a, $a, $c, \$c, \%a, \@array, \%hash, \@tied);

my $f;
ok 1, defined($f = freeze(\@a));

my $dumped = &dump(\@a);
ok 2, 1;

my $root = thaw($f);
ok 3, defined $root;

my $got = &dump($root);
ok 4, 1;

ok 5, $got eq $dumped;

my $g = freeze($root);
ok 6, length($f) == length($g);

# Ensure the tied items in the retrieved image work
my @old = @($scalar_fetch, $array_fetch, $hash_fetch);
(<@tied) = our ($tscalar, $tarray, $thash) = < @{$root->[(nelems @$root)-1]};
my @type = @(qw(SCALAR  ARRAY  HASH));

ok 7, tied $$tscalar;
ok 8, tied @{$tarray};
ok 9, tied %{$thash};

our @new = @($$tscalar, $tarray->[0], $thash->{'attribute'});
@new = @($scalar_fetch, $array_fetch, $hash_fetch);

# Tests 10..15
for (my $i = 0; $i +< @new; $i++) {
	ok 10 + 2*$i, @new[$i] == @old[$i] + 1;		# Tests 10,12,14
	ok 11 + 2*$i, ref @tied[$i] eq @type[$i];	# Tests 11,13,15
}

ok 16, $$tscalar eq 'foo';
ok 17, $tarray->[3] eq 'plaine scalaire';
ok 18, $thash->{'attribute'} eq 'plain value';

# Ensure hooks were called
our ($scalar_hook1, $scalar_hook2, $array_hook1, $array_hook2, $hash_hook1, $hash_hook2);
ok 19, ($scalar_hook1 && $scalar_hook2);
ok 20, ($array_hook1 && $array_hook2);
ok 21, ($hash_hook1 && $hash_hook2);

#
# And now for the "blessed ref to tied hash" with "store hook" test...
#

my $bc = bless \%hash, 'FOO';		# FOO does not exist -> no hook
my $bx = thaw freeze $bc;

ok 22, ref $bx eq 'FOO';
my $old_hash_fetch = $hash_fetch;
my $v = $bx->{attribute};
ok 23, $hash_fetch == $old_hash_fetch + 1;	# Still tied

package TIED_HASH_REF;


sub STORABLE_freeze {
        my ($self, $cloning) = @_;
        return if $cloning;
        return('ref lost');
}

sub STORABLE_thaw {
        my ($self, $cloning, $data) = @_;
        return if $cloning;
}

package main;

$bc = bless \%hash, 'TIED_HASH_REF';
$bx = thaw freeze $bc;

ok 24, ref $bx eq 'TIED_HASH_REF';
$old_hash_fetch = $hash_fetch;
$v = $bx->{attribute};
ok 25, $hash_fetch == $old_hash_fetch + 1;	# Still tied
