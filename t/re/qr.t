#!./perl -w

BEGIN 
    require './test.pl'


plan: tests => 1

my $rx = qr//

is: ref $rx, "Regexp", "qr// blessed into `Regexp' by default"
