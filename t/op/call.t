
BEGIN
    require "./test.pl"

plan(tests => 5)

do
    my $subref = sub ($x) $x
    my $sub = $subref->$
    is( ($sub <: "aap"), "aap" )

do
    my $x = "foo"
    dies_like( { $x <: "aap" }, qr/Can't use string [(]"foo"[)] as a subroutine ref/)

sub foo()
    return "original foo"

warn "xx" . dump::view(\(*foo->&))
*foo = sub() return "new foo"
warn "xx" . dump::view(\(*foo->&))
is( foo(), "original foo" )

warn "xx" . dump::view(\(*foo->&))
*foo->& = sub () return "new foo with ->&"
warn "xx" . dump::view(\(*foo->&))
is( (*foo->& <: ), "new foo with ->&" )

eval_dies_like('non_existing_sub()', qr/Undefined subroutine &non_existing_sub called/);
