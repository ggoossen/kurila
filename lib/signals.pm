package signals;

use warnings;

sub temp_set_handler($name, $handler) {
    my $oldhandler = handler($name);
    push dynascope->{parent}->{onleave},
      sub { set_handler($name, $oldhandler) };
    set_handler($name, $handler);
    return;
}

1;
