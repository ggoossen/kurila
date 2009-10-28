#!./perl

BEGIN { require "./test.pl" }

plan: tests => 15

my %a = %: 'aap', 'noot', 'mies', 'teun'

is:  (join: "*", (sort: keys %a)), "aap*mies", "properly initialized" 
is:  %a{"aap"}, "noot", "key found" 
is:  %a{?"aap"}, "noot", "key found also with '?'" 
is:  %a{+"aap"}, "noot", "key found also with '+'" 

dies_like:  sub (@< @_) { %a{"monkey"} }
            qr/Missing hash key 'monkey'/ 
is:  %a{?"monkey"}, undef, "undef returned with '?'"
is:  exists %a{"monkey"}, '', "key not created"
is:  %a{+"monkey"}, undef, "undef returned with '?'"
is:  exists %a{"monkey"}, 1, "key created with '+'"

do
    my %b = %:  aap => "muis" 
    # localization
    do
        local %b{"aap"} = "vis"
        is:  %b{"aap"}, "vis" 
    
    is:  %b{"aap"}, "muis" 


do
    is:  (%:  'aap', 'noot' ){"aap"}, "noot", "direct helem from \%:.."


do
    my %c = %:  "aap" => "rat" 
    %c{+"roodborstje"}
    ok:  exists %c{"roodborstje"} 
    is:  %c{"roodborstje"}, undef 


do
    # OPpDEREF and OPpHELEM_OPTIONAL
    my %c = $%
    is:  %c{?"aap"}{?"noot"}, undef 

