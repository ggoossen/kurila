# needs to explicitly link against librt to pull in clock_nanosleep
our $self;
$self->{+LIBS} = \@('-lrt');
