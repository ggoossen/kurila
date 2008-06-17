#!./perl

use Test::More tests => 1;

use Tie::Handle;

{
    package Foo;
    our @ISA = @(qw(Tie::StdHandle));
}

# For backwards compatabilty with 5.8.x
ok( Foo->can("TIEHANDLE"), "loading Tie::Handle loads TieStdHandle" );
