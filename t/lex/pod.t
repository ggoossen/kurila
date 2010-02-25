#!./perl

BEGIN
    require './test.pl'

plan: tests => 2

# Test pod after use
fresh_perl_is: <<'EOT', "ok\n"
use warnings

=head1 TEST
test pod
=cut

print: $^STDOUT, "ok\n"
EOT

fresh_perl_is: <<'EOT', "ok\n", undef, "pod where block expected"
do
=head1 TEST
test pod
=cut
    print: $^STDOUT, "ok\n"
EOT
