#!./perl

# must use a BEGIN or the prototypes wont be respected meaning
# tests could pass that shouldn't
BEGIN
    require "test.pl"
my $out = runperl: progfile => "t/lexical_debug.pl", stderr => 1 

print: $^STDOUT, "1..10\n"

# Each pattern will produce an EXACT node with a specific string in
# it, so we will look for that. We can't just look for the string
# alone as the string being matched against contains all of them.

ok:  $out =~ m/EXACT <foo>/, "Expect 'foo'"    
ok:  $out !~ m/EXACT <bar>/, "No 'bar'"        
ok:  $out =~ m/EXACT <baz>/, "Expect 'baz'"    
ok:  $out !~ m/EXACT <bop>/, "No 'bop'"        
ok:  $out =~ m/EXACT <fip>/, "Expect 'fip'"    
ok:  $out !~ m/EXACT <fop>/, "No 'baz'"        
ok:  $out =~ m/<liz>/,       "Got 'liz'"        # in a TRIE so no EXACT
ok:  $out =~ m/<zoo>/,       "Got 'zoo'"        # in a TRIE so no EXACT
ok:  $out =~ m/<zap>/,       "Got 'zap'"        # in a TRIE so no EXACT
ok:  $out =~ m/Count=7\n/,   "Count is 7"
    or diag: $out

