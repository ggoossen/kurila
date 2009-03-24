package env;

sub temp_set_var($key, $value) {
    push dynascope->{parent}->{onleave}, make_restore_var($key);
    set_var($key, $value);
    return;
}

sub make_restore_var($key) {
    my $old_value = env::var($key);
    my $restore_var = sub {
        set_var($key, $old_value);
        return;
    };
    return $restore_var;
}

sub make_restore {
    my %old = %+: map { %: $_ => env::var($_) }, env::keys();
    my $restore= sub {
        my $old_copy = %old;
        for my $key (env::keys()) {
            env::set_var($key, delete $old_copy{$key});
        }
        for my $key (CORE::keys $old_copy) {
            env::set_var($key, $old_copy{$key});
        }
        return;
    };
    return $restore;
}

1;
