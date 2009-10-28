use Perl6::Form

my $nums = do{local$^INPUT_RECORD_SEPARATOR = undef; ~< $^DATA}

print: $^STDOUT, < form: 
           "Brittannia      Continental     East Indies      Tyrol           Nippon"
           "_____________   _____________   ______________   _____________   _____________"
           "\{],]]],]]].[\}   \{].]]].]]],[\}    \{]],]],]]].[\}   \{]']]]']]],[\}   \{]]]],]]]].[\}"
           "$nums",         "$nums",         "$nums",        "$nums",        "$nums"

print: $^STDOUT, < form: 
           ""
           "Quintuple "
           "_____________"
           "\{]],]]]]].[\}"
           "$nums"
           ""
           "Hyperspatial "
           "_____________"
           "\{] ]]] ]]]|[\}"
           "$nums"
           \(%: locale=>1)
           ""
           "Locale "
           "_____________"
           "\{]].]]]]],[\}"
           "$nums"

__DATA__
0
1
1.1
1.23456789
4567.89
34567.89
234567.89
1234567.89
991234567.89
