# https://bugzilla.redhat.com/bugzilla/show_bug.cgi?id=101767
# explicit linking is required to ensure the use of versioned symbols
our $self;
$self->{LIBS} = \@('-lpthread') if %Config{libs} =~ m/-lpthread/;
