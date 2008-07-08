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
	chdir('t') if -d 't';
	@INC = ('.', '../lib', '../ext/Storable/t');
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

print "1..23\n";

our ($scalar_fetch, $array_fetch, $hash_fetch) = (0, 0, 0);

package TIED_HASH;

sub TIEHASH {
	my $self = bless \%(), shift;
	return $self;
}

sub FETCH {
	my $self = shift;
	my ($key) = @_;
	$main::hash_fetch++;
	return $self->{$key};
}

sub STORE {
	my $self = shift;
	my ($key, $value) = @_;
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
	my ($value) = @_;
	$$self = $value;
}

package FAULT;

our $fault = 0;

sub TIESCALAR {
	my $pkg = shift;
	return bless \@(@_), $pkg;
}

sub FETCH {
	my $self = shift;
	my ($href, $key) = @$self;
	$fault++;
	untie $href->{$key};
	return $href->{$key} = 1;
}

package main;

$a = 'toto';
$b = \$a;

our $c = tie our %hash, 'TIED_HASH';
tie our $scalar, 'TIED_SCALAR';

#$scalar = 'foo';
#$hash{'attribute'} = \$d;
#$array[0] = $c;
#$array[1] = \$scalar;

### If I say
###   $hash{'attribute'} = $d;
### below, then dump() incorectly dumps the hash value as a string the second
### time it is reached. I have not investigated enough to tell whether it's
### a bug in my dump() routine or in the Perl tieing mechanism.
$scalar = 'foo';
%hash{'attribute'} = 'plain value';
@array[0] = \$scalar;
@array[1] = $c;
@array[2] = \@array;

our @tied = (\$scalar, \@array, \%hash);
our %a = ('key', 'value', 1, 0, $a, $b, 'cvar', \$a, 'scalarref', \$scalar);
our @a = ('first', 3, -4, -3.14159, 456, 4.5,
	$b, \$a, $a, $c, \$c, \%a, \@array, \%hash, \@tied);

ok 1, defined(our $f = freeze(\@a));

our $dumped = &dump(\@a);
ok 2, 1;

our $root = thaw($f);
ok 3, defined $root;

our $got = &dump($root);
ok 4, 1;

### Used to see the manifestation of the bug documented above.
### print "original: $dumped";
### print "--------\n";
### print "got: $got";
### print "--------\n";

ok 5, $got eq $dumped; 

our $g = freeze($root);
ok 6, length($f) == length($g);

# Ensure the tied items in the retrieved image work
our @old = ($scalar_fetch, $array_fetch, $hash_fetch);
@tied = our ($tscalar, $tarray, $thash) = @{$root->[@$root -1]};
our @type = qw(SCALAR  ARRAY  HASH);

ok 7, tied $$tscalar;
ok 8, tied @{$tarray};
ok 9, tied %{$thash};

our @new = ($$tscalar, $tarray->[0], $thash->{'attribute'});
@new = ($scalar_fetch, $array_fetch, $hash_fetch);

# Tests 10..15
for (my $i = 0; $i +< @new; $i++) {
	print "not " unless @new[$i] == @old[$i] + 1;
	printf "ok \%d\n", 10 + 2*$i;	# Tests 10,12,14
	print "not " unless ref @tied[$i] eq @type[$i];
	printf "ok \%d\n", 11 + 2*$i;	# Tests 11,13,15
}

# Check undef ties
my $h = \%();
tie $h->{'x'}, 'FAULT', $h, 'x';
my $hf = freeze($h);
ok 16, defined $hf;
ok 17, $FAULT::fault == 0;
ok 18, $h->{'x'} == 1;
ok 19, $FAULT::fault == 1;

my $ht = thaw($hf);
ok 20, defined $ht;
ok 21, $ht->{'x'} == 1;
ok 22, $FAULT::fault == 2;

{
    package P;
    use Storable qw(freeze thaw);
    use vars qw($a $b);
    $b = "not ok ";
    sub TIESCALAR { bless \$a } sub FETCH { "ok " }
    tie $a, 'P'; my $r = thaw freeze \$a; $b = $$r;
    print $b , 23, "\n";
}

