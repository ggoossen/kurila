#!perl
# ioleaks.t

use warnings
use Test::More 'no_plan'

# :unix   -> not ok
# :stdio  -> not ok
# :perlio -> ok
# :crlf   -> ok

:TODO do
    local $TODO = "[perl #56644] PerlIO resource leaks on open() and then :pop in :unix and :stdio"
    foreach my $layer(qw(:unix :stdio  :perlio :crlf))
        my $base_fd = do{ open: my $in, '<', $^PROGRAM_NAME or die: $^OS_ERROR; fileno $in }

        for(1 .. 3)
            open: my $fh, "<$layer", $^PROGRAM_NAME or die: $^OS_ERROR

            is: (fileno: $fh), $base_fd, $layer
            binmode: $fh, ':pop'

