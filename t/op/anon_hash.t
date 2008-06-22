#!./perl

BEGIN { require "./test.pl"; }
plan( tests => 6 );

my $x = \ %( aap => 'noot', mies => 'teun' );
is $x->{aap}, 'noot', "anon hash ref construction";
is $x->{mies}, 'teun', "anon hash ref construction";

is( (join '*', sort < %( aap => 'noot', mies => 'teun' )), 'aap*mies*noot*teun', "anon hash is list in list context");

is %(aap => 'noot', mies => 'teun'){aap}, 'noot', "using helem directy on anon hash";

my $x = \ %();
is Internals::SvREFCNT($x), 1, "there is only one reference";

eval_dies_like( q| %( aap => 'noot', mies => 'teun' )->{aap}; |,
                qr/Hash may not be used as a reference/,
                "anon hash as reference" );
