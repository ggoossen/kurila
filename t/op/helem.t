#!./perl

BEGIN { require "./test.pl" }

plan tests => 12;

my %a = %('aap', 'noot', 'mies', 'teun');

is( join("*", sort keys %a), "aap*mies", "properly initialized" );
is( %a{"aap"}, "noot", "key found" );
is( %a{?"aap"}, "noot", "key found also with '?'" );
is( %a{+"aap"}, "noot", "key found also with '+'" );

dies_like( sub { %a{"monkey"} },
           qr/Missing hash key 'monkey'/ );
is( %a{?"monkey"}, undef, "undef returned with '?'");
is( exists %a{"monkey"}, '', "key not created");
is( %a{+"monkey"}, undef, "undef returned with '?'");
is( exists %a{"monkey"}, 1, "key created with '+'");

do {
    # localization
    do {
        local %a{"aap"} = "vis";
        is( %a{"aap"}, "vis" );
    };
    is( %a{"aap"}, "noot" );
};

do {
    is( %( 'aap', 'noot' ){+"aap"}, "noot", "direct helem from \%(..)");
};
