#!./perl -w

BEGIN {
    require './test.pl';
}

plan( tests => 4 );

sub empty_sub {}

is(empty_sub,undef,"Is empty");
is(empty_sub(1,2,3),undef,"Is still empty");
my @test = @( < empty_sub() );
is(scalar(nelems @test), 0, 'Didnt return anything');
@test = @( < empty_sub(1,2,3) );
is(scalar(nelems @test), 0, 'Didnt return anything');

