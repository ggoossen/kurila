#! ./perl

# BEGIN {
#     require './test.pl';
# }

#plan tests => 6;

my $h=%();
tie $h, 'TIED_HASH';

$h{aap} = 'noot';
#is($h{aap}, 'noot');

$h{aap} = %( teun => 'vuur' );

#is($h{aap}{teun}, 'vuur');


package TIED_HASH;

sub TIEHASH {
	my $self = bless \%(), shift;
	return $self;
}

sub FETCH {
	my $self = shift;
	my ($key) = < @_;
	$main::hash_fetch++;
	return $self->{$key};
}

sub STORE {
	my $self = shift;
	my ($key, $value) = < @_;
        warn dump::view($value);
	$self->{$key} = $value;
}

sub FIRSTKEY {
	my $self = shift;
	keys %{$self};
	return each %{$self};
}

sub NEXTKEY {
	my $self = shift;
	return each %{$self};
}

sub CLEAR {
	my $self = shift;
	%$self = %( () );  
}
