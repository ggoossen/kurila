#!./perl

BEGIN 
    require './test.pl'


plan: tests => 4

my $x = 1
ok: "$x" eq "1", "on IV"
ok:  ''.1.1 eq "1.1", "on UV"
dies_like:  sub (@< @_) { ''.\$x }, qr/^Tried to use reference as string/, "dies on ref"
ok:  ''.qr/foo/ eq '(?-uxism:foo)', "on REGEX"
