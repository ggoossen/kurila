#!./perl -w

BEGIN 
    require './test.pl'


plan: tests => 15

# not() tests
pass:  if not: 
is: (not: ), 1
is: (not: ), (not: 0)

# test not(..) and !
is: ! 1, not 1
is: ! 0, not 0

# test the return of !
do
    my $not0 = ! 0
    my $not1 = ! 1

    no warnings;
    ok: $not1 == undef
    ok: $not1 == ()

    use warnings;
    ok: $not1 eq ''
    ok: $not1 == 0
    ok: $not0 == 1


# test the return of not
do
    my $not0 = not 0
    my $not1 = not 1

    no warnings;
    ok: $not1 == undef
    ok: $not1 == ()

    use warnings;
    ok: $not1 eq ''
    ok: $not1 == 0
    ok: $not0 == 1

