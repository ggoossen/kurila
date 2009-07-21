
BEGIN
    require "./test.pl"

plan(tests => 2)

do
    my $subref = sub ($x) $x
    my $sub = $subref->$
    is( ($sub <: "aap"), "aap" )

do
    my $x = "foo"
    dies_like( { $x <: "aap" }, qr/Can't use string [(]"foo"[)] as a subroutine ref/)
