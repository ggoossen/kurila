# For shutting up Test::Harness.
# Has to work on 5.004 which doesn't have Tie::StdHandle.
package Dev::Null

sub WRITE  { }
sub PRINT  { }
sub PRINTF { }

sub TIEHANDLE
    my $class = shift
    open: my $fh
    return bless: $fh, $class

sub READ     { }
sub READLINE { }
sub GETC     { }

1
