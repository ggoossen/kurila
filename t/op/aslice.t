#!./perl

BEGIN { require "./test.pl" }

plan: tests => 2

my @a = @: 'aap', 'noot', 'mies', 'teun'

is:  (join: '**', @a[[0..2]]), 'aap**noot**mies' 
is:  (join: '**', @a[[2..5]]), 'mies**teun****' 
