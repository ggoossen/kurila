
BEGIN
    require "./test.pl"

plan(tests => 2)

do
    my $subref = sub ($x) $x
    my $sub = $subref->$
    is( ($sub <: "aap"), "aap" )

do
    dies_like( { "foo" <: "aap" }, qr/Can't use string ("foo") as a subroutine ref/)
