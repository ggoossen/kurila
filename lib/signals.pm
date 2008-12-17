package signals;

use warnings;

sub temp_set_handler {
    my @($name, $handler) = @_;
    my $oldhandler = handler($name);
    unshift dynascope->{parent}->{onleave},
      sub { set_handler($name, $oldhandler) };
    set_handler($name, $handler);
    return;
}

1;
