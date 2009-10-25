
BEGIN
    require "./test.pl"

plan: tests => 5

do
    my $sub = sub ($x) $x
    is:  (($sub <: "aap")), "aap" 

do
    my $x = "foo"
    dies_like:  {( $x <: "aap" )}, qr/Can't use string [(]"foo"[)] as a subroutine ref/

sub foo()
    return "original foo"

*foo = sub() return "new foo"
is:  (foo: ), "original foo" 

*foo->& = sub () return "new foo with ->&"
is: (*foo->&->& <: ), "new foo with ->&" 

eval_dies_like: 'non_existing_sub:', qr/Undefined subroutine &non_existing_sub called/
