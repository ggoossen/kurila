#!./perl -w

BEGIN {
    require './test.pl';
}

plan( tests => 2 );

my ($a, $b, $c);
$a = $: $b = 3; 
is( $a, 3);

eval_dies_like( '$a = $b ||= $c',
                qr/Can't do logical or assignment [(]||=[)] to assignment/ );
