#!./perl

BEGIN { require "./test.pl" }

plan tests => 3;

my @a = @('aap', 'noot', 'mies', 'teun');

is( join('**', @a[[0..2]]), 'aap**noot**mies' );
is( join('**', @a[[2..5]]), 'mies**teun****' );

dies_like( sub { eval '0+@a[[0..1]]'; die if $@; },
           qr/array slice may not be used in scalar context/ );
