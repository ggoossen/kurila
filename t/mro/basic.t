#!./perl

use warnings

require q(./test.pl); plan: tests => 29

do
    package MRO_ISA_NO_ARRAY
    our @ISA = 'foobar'
    main::dies_like:  sub (@< @_) { (mro::get_linear_isa: 'MRO_ISA_NO_ARRAY') }
                      qr/[@]ISA is not an array but PLAINVALUE/ 


do
    package MRO_A
    our @ISA = qw//
    package MRO_B;
    our @ISA = qw//
    package MRO_C;
    our @ISA = qw//
    package MRO_D;
    our @ISA = qw/MRO_A MRO_B MRO_C/
    package MRO_E;
    our @ISA = qw/MRO_A MRO_B MRO_C/
    package MRO_F;
    our @ISA = qw/MRO_D MRO_E/


ok: (eq_array: 
        (mro::get_linear_isa: 'MRO_F')
        \qw/MRO_F MRO_D MRO_E MRO_A MRO_B MRO_C/
        )

my @isarev = sort: { $a cmp $b }, (mro::get_isarev: 'MRO_B')->@
ok: (eq_array: 
        \@isarev
        \qw/MRO_D MRO_E MRO_F/
        )

ok: !(mro::is_universal: 'MRO_B')

@UNIVERSAL::ISA = qw/MRO_F/
ok: (mro::is_universal: 'MRO_B')

@UNIVERSAL::ISA = $@
ok: (mro::is_universal: 'MRO_B')

# is_universal, get_mro, and get_linear_isa should
# handle non-existant packages sanely
ok: !(mro::is_universal: 'Does_Not_Exist')
ok: (eq_array: 
        (mro::get_linear_isa: 'Does_Not_Exist_Three')
        \qw/Does_Not_Exist_Three/
        )

# Assigning @ISA via globref
do
    package MRO_TestBase
    sub testfunc { return 123 }
    package MRO_TestOtherBase
    sub testfunctwo { return 321 }
    package MRO_M; our @ISA = qw/MRO_TestBase/


# XXX TODO (when there's a way to backtrack through a glob's aliases)
# push(@MRO_M::ISA, 'MRO_TestOtherBase');
# is(try { MRO_N->testfunctwo() }, 321);

# Simple DESTROY Baseline
do
    my $x = 0
    my $obj

    do
        package DESTROY_MRO_Baseline
        sub new { (bless: \$% => shift )}
        sub DESTROY { $x++ }

        package DESTROY_MRO_Baseline_Child
        our @ISA = qw/DESTROY_MRO_Baseline/
    

    $obj = DESTROY_MRO_Baseline->new
    undef $obj
    is: $x, 1

    $obj = DESTROY_MRO_Baseline_Child->new
    undef $obj
    is: $x, 2


# Dynamic DESTROY
do
    my $x = 0
    my $obj

    do
        package DESTROY_MRO_Dynamic
        sub new { (bless: \$% => shift )}

        package DESTROY_MRO_Dynamic_Child
        our @ISA = qw/DESTROY_MRO_Dynamic/
    

    $obj = DESTROY_MRO_Dynamic->new
    undef $obj
    is: $x, 0

    $obj = DESTROY_MRO_Dynamic_Child->new
    undef $obj
    is: $x, 0

    no warnings 'once';
    *DESTROY_MRO_Dynamic::DESTROY = sub (@< @_) { $x++ }

    $obj = DESTROY_MRO_Dynamic->new
    undef $obj
    is: $x, 1

    $obj = DESTROY_MRO_Dynamic_Child->new
    undef $obj
    is: $x, 2


# clearing @ISA in different ways
#  some are destructive to the package, hence the new
#  package name each time
do
    no warnings 'uninitialized'
    do
        package ISACLEAR
        our @ISA = qw/XX YY ZZ/
    
    # baseline
    ok: (eq_array: (mro::get_linear_isa: 'ISACLEAR'),\qw/ISACLEAR XX YY ZZ/)

    # undef the array itself
    undef @ISACLEAR::ISA
    ok: (eq_array: (mro::get_linear_isa: 'ISACLEAR'),\qw/ISACLEAR/)

    # Now, clear more than one package's @ISA at once
    do
        package ISACLEAR1
        our @ISA = qw/WW XX/

        package ISACLEAR2;
        our @ISA = qw/YY ZZ/
    
    # baseline
    ok: (eq_array: (mro::get_linear_isa: 'ISACLEAR1'),\qw/ISACLEAR1 WW XX/)
    ok: (eq_array: (mro::get_linear_isa: 'ISACLEAR2'),\qw/ISACLEAR2 YY ZZ/)
    @ISACLEAR1::ISA = $@
    @ISACLEAR2::ISA = $@

    ok: (eq_array: (mro::get_linear_isa: 'ISACLEAR1'),\qw/ISACLEAR1/)
    ok: (eq_array: (mro::get_linear_isa: 'ISACLEAR2'),\qw/ISACLEAR2/)


# Check that recursion bails out "cleanly" in a variety of cases
# (as opposed to say, bombing the interpreter or something)
do
    my @recurse_codes = @:
        '@MRO_R1::ISA = @: "MRO_R2"; @MRO_R2::ISA = @: "MRO_R1";'
        '@MRO_R3::ISA = @: "MRO_R4"; push(@MRO_R4::ISA, "MRO_R3");'
        '@MRO_R5::ISA = @: "MRO_R6"; @MRO_R6::ISA = qw/XX MRO_R5 YY/;'
        '@MRO_R7::ISA = @: "MRO_R8"; push(@MRO_R8::ISA, < qw/XX MRO_R7 YY/)'

    foreach my $code ( @recurse_codes)
        eval $code
        ok: $: $^EVAL_ERROR->{?description} =~ m/Recursive inheritance detected/


# Check that SUPER caches get invalidated correctly
do
    do
        package SUPERTEST
        sub new { (bless: \$% => shift )}
        sub foo { @_[1]+1 }

        package SUPERTEST::MID
        our @ISA = @:  'SUPERTEST' 

        package SUPERTEST::KID;
        our @ISA = @:  'SUPERTEST::MID' 
        sub foo { my $s = shift;( $s->SUPER::foo: < @_) }

        package SUPERTEST::REBASE
        sub foo { @_[1]+3 }
    

    my $stk_obj = SUPERTEST::KID->new
    is: ($stk_obj->foo: 1), 2
    do { no warnings 'redefine';
        *SUPERTEST::foo = sub (@< @_) { @_[1]+2 };
    }
    is: ($stk_obj->foo: 2), 4
    @SUPERTEST::MID::ISA = @:  'SUPERTEST::REBASE' 
    is: ($stk_obj->foo: 3), 6


do
  do
    # assigning @ISA via arrayref to globref RT 60220
    package P1
    sub new($class)
        bless: \$%, $class
    
    package P2

  *P2::ISA = @: 'P1'
  my $foo = P2->new
  ok: !try { $foo->bark }, "no bark method"
  no warnings 'once'  # otherwise it'll bark about P1::bark used only once
  *P1::bark = sub { "[bark]" }
  is: try { $foo->bark }, "[bark]", "can bark now"
