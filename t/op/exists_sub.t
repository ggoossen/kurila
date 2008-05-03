#!./perl

BEGIN { require "./test.pl" }

plan 9;

sub t1;
sub t2 : locked;
sub t3 ();
sub t4 ($);
sub t5 {1;}
{
    package P1;
    sub tmc {1;}
    package P2;
    our @ISA = 'P1';
}

ok( exists &t1 && not defined &t1 );
ok( exists &t2 && not defined &t2 );
ok( exists &t3 && not defined &t3 );
ok( exists &t4 && not defined &t4 );
ok( exists &t5 && defined &t5 );
'P2'->tmc;
ok( not exists &P2::tmc && not defined &P2::tmc );
my $ref;
$ref->{A}[0] = \&t4;
ok( exists &{$ref->{A}[0]} && not defined &{$ref->{A}[0]} );
undef &P1::tmc;
ok( exists &P1::tmc && not defined &P1::tmc );
eval_dies_like('exists &t5()',
               qr/exists argument is not a subroutine name/); 
