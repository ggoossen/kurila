#!./perl

BEGIN
    require './test.pl'

plan tests => 1

# Test pod after use
fresh_perl_is(<<'EOT', "ok\n")
use warnings

=head1 TEST
test pod
=cut

print $^STDOUT, "ok\n"
EOT
