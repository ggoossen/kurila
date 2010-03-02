#!./perl -w

BEGIN 
    require './test.pl'


plan:  tests => 8 

sub empty_sub {}

is: (empty_sub: ),undef,"Is empty"
is: (empty_sub: 1,2,3),undef,"Is still empty"
my @test = (empty_sub: )
is: (scalar: nelems @test), 0, 'Didnt return anything'
@test = empty_sub: 1,2,3
is: (scalar: nelems @test), 0, 'Didnt return anything'


# no-arguments subs are not too good
my $no_args = 1
my $main = 33
my $xsub = sub()
    return $main if $no_args--
    return 44

is: $no_args, 1
is: ($xsub->& <: ), 33
is: $no_args, 0
is: ($xsub->& <: ), 44

