#! ./perl

BEGIN {
    require './test.pl';
}

plan tests => 2;

my $h=%();
tie $h, 'TIED_HASH';

$h{aap} = 'noot';
is($h{aap}, 'noot');

TODO: {
    todo_skip("hash to key assignment", 1);
    $h{aap} = %( teun => 'vuur' );
    is($h{aap}{teun}, 'vuur');
}


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
