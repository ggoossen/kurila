#!./perl

# $Id: compat-0.6.t,v 0.7 2000/08/03 22:04:44 ram Exp $
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#
# $Log: compat-0.6.t,v $
# Revision 0.7  2000/08/03 22:04:44  ram
# Baseline for second beta release.
#

BEGIN {
    chdir('t') if -d 't';    
    unshift @INC, '../lib';
    require Config; import Config;
    if ($Config{'extensions'} !~ /\bStorable\b/) {
        print "1..0 # Skip: Storable was not built\n";
        exit 0;
    }
    require 'lib/st-dump.pl';
}

sub ok;

print "1..8\n";

use Storable qw(freeze nfreeze thaw);

package TIED_HASH;

sub TIEHASH {
	my $self = bless {}, shift;
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
	my ($key, $val) = @_;
	$self->{$key} = $val;
}

package SIMPLE;

sub make {
	my $self = bless [], shift;
	my ($x) = @_;
	$self->[0] = $x;
	return $self;
}

package ROOT;

sub make {
	my $self = bless {}, shift;
	my $h = tie %hash, TIED_HASH;
	$self->{h} = $h;
	$self->{ref} = \%hash;
	my @pool;
	for (my $i = 0; $i < 5; $i++) {
		push(@pool, SIMPLE->make($i));
	}
	$self->{obj} = \@pool;
	my @a = ('string', $h, $self);
	$self->{a} = \@a;
	$self->{num} = [1, 0, -3, -3.14159, 456, 4.5];
	$h->{key1} = 'val1';
	$h->{key2} = 'val2';
	return $self;
};

sub num { $_[0]->{num} }
sub h   { $_[0]->{h} }
sub ref { $_[0]->{ref} }
sub obj { $_[0]->{obj} }

package main;

my $r = ROOT->make;

my $data = '';
while (<DATA>) {
	next if /^#/;
	$data .= unpack("u", $_);
}

ok 1, length $data == 278;

my $y = thaw($data);
ok 2, 1;
ok 3, ref $y eq 'ROOT';

$Storable::canonical = 1;		# Prevent "used once" warning
$Storable::canonical = 1;
ok 4, nfreeze($y) eq nfreeze($r);

ok 5, $y->ref->{key1} eq 'val1';
ok 6, $y->ref->{key2} eq 'val2';
ok 7, $hash_fetch == 2;

my $num = $r->num;
my $ok = 1;
for (my $i = 0; $i < @$num; $i++) {
	do { $ok = 0; last } unless $num->[$i] == $y->num->[$i];
}
ok 8, $ok;

__END__
#
# using Storable-0.6@11, output of: print pack("u", nfreeze(ROOT->make));
# original size: 278 bytes
#
M`P,````%!`(````&"(%8"(!8"'U8"@@M,RXQ-#$U.5@)```!R%@*`S0N-5A8
M6`````-N=6T$`P````(*!'9A;#%8````!&ME>3$*!'9A;#)8````!&ME>3)B
M"51)141?2$%32%A8`````6@$`@````,*!G-T<FEN9U@$``````I8!```````
M6%A8`````6$$`@````4$`@````$(@%AB!E-)35!,15A8!`(````!"(%88@93
M24U03$586`0"`````0B"6&(&4TE-4$Q%6%@$`@````$(@UAB!E-)35!,15A8
M!`(````!"(188@9324U03$586%A8`````V]B:@0,!``````*6%A8`````W)E
(9F($4D]/5%@`
