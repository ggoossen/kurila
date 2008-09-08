#!./perl

BEGIN { require "./test.pl"; }
plan( tests => 6 );

my $x = \ %( aap => 'noot', Mies => 'Wim' );
is $x->{aap}, 'noot', "anon hash ref construction";
is $x->{Mies}, 'Wim', "anon hash ref construction";

is( (join '*', sort @:< %( aap => 'noot', Mies => 'Wim' )), 'Mies*Wim*aap*noot', "anon hash is list in list context");

is %(aap => 'noot', Mies => 'Wim'){aap}, 'noot', "using helem directy on anon hash";

my $x = \ %();
is Internals::SvREFCNT($x), 1, "there is only one reference";

eval_dies_like( q| %( aap => 'noot', Mies => 'Wim' )->{aap}; |,
                qr/Hash may not be used as a reference/,
                "anon hash as reference" );
