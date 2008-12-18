package env;

sub temp_set_var {
    my @($key, $value) = @_;
    my $oldvalue = var($key);
    push dynascope->{parent}->{onleave},
      sub { set_var($key, $oldvalue) };
    set_var($key, $value);
    return;
}
1;
