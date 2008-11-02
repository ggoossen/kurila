#!./perl

use Config;

use Test::More tests => 23;

use Scalar::Util < qw(refaddr);
use vars < qw($t $y $x *F);
use Symbol < qw(gensym);

# Ensure we do not trigger and tied methods
tie *F, 'MyTie';

my $i = 1;
foreach my $v (@: undef, 10, 'string') {
  is(refaddr($v), undef, "not " . (defined($v) ? "'$v'" : "undef"));
}

foreach my $r (@: \%(), \$t, \@(), \*F, sub {}) {
  my $n = dump::view($r);
  $n =~ m/0x(\w+)/;
  my $addr = do { local $^W; hex $1 };
  my $before = ref($r);
  is( refaddr($r), $addr, $n);
  is( ref($r), $before, $n);
}

package MyTie;

sub TIEHANDLE { bless \%() }
sub DESTROY {}

package Hash3;

use Scalar::Util < qw(refaddr);

sub TIEHASH
{
	my $pkg = shift;
	return bless \@( < @_ ), $pkg;
}
sub FETCH
{
	my $self = shift;
	my $key = shift;
	my ($underlying) = < @$self;
	return $underlying->{refaddr($key)};
}
sub STORE
{
	my $self = shift;
	my $key = shift;
	my $value = shift;
	my ($underlying) = < @$self;
	return  @($underlying->{refaddr($key)} = $key);
}
