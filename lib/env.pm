package env

sub make_restore
    my %old = %+: map: { %: $_ => (env::var: $_) }, (env::keys: )
    my $restore= sub ()
        my $old_copy = %old
        for my $key ((env::keys: ))
            (env::var: $key) = delete $old_copy{$key}
        for my $key (CORE::keys $old_copy)
            (env::var: $key) = $old_copy{$key}
        return
    return $restore

1
