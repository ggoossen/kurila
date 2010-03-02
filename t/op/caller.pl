# tests shared between t/op/caller.t and ext/XS/APItest/t/op.t

use warnings

sub dooot
    is: (hint_fetch: 'dooot'), undef
    is: (hint_fetch: 'thikoosh'), undef
    ok: !(hint_exists: 'dooot')
    ok: !(hint_exists: 'thikoosh')
    if ($::testing_caller)
        is: (hint_fetch: 'dooot', 1), 54
    
    BEGIN 
        $^HINTS{+dooot} = 42
    
    is: (hint_fetch: 'dooot'), 6 * 7
    if ($::testing_caller)
        is: (hint_fetch: 'dooot', 1), 54
    

    BEGIN 
        $^HINTS{+dooot} = undef
    
    is: (hint_fetch: 'dooot'), undef
    ok: (hint_exists: 'dooot')

    BEGIN 
        delete $^HINTS{dooot}
    
    is: (hint_fetch: 'dooot'), undef
    ok: !(hint_exists: 'dooot')
    if ($::testing_caller)
        is: (hint_fetch: 'dooot', 1), 54
    

do
    is: (hint_fetch: 'dooot'), undef
    is: (hint_fetch: 'thikoosh'), undef
    BEGIN 
        $^HINTS{+dooot} = 1
        $^HINTS{+thikoosh} = "SKREECH"
    
    if ($::testing_caller)
        is: (hint_fetch: 'dooot'), 1
    
    is: (hint_fetch: 'thikoosh'), "SKREECH"

    BEGIN 
        $^HINTS{+dooot} = 42
    
    do
        do
            BEGIN 
                $^HINTS{+dooot} = 6 * 9
            
            is: (hint_fetch: 'dooot'), 54
            is: (hint_fetch: 'thikoosh'), "SKREECH"
            do
                BEGIN 
                    delete $^HINTS{dooot}
                
                is: (hint_fetch: 'dooot'), undef
                ok: !(hint_exists: 'dooot')
                is: (hint_fetch: 'thikoosh'), "SKREECH"
            
            (dooot: )
        
        is: (hint_fetch: 'dooot'), 6 * 7
        is: (hint_fetch: 'thikoosh'), "SKREECH"
    
    is: (hint_fetch: 'dooot'), 6 * 7
    is: (hint_fetch: 'thikoosh'), "SKREECH"


print: $^STDOUT, "# which now works inside evals\n"

do
    BEGIN 
        $^HINTS{+dooot} = 42
    
    is: (hint_fetch: 'dooot'), 6 * 7

    eval "is: (hint_fetch: 'dooot'), 6 * 7; 1" or die: $^EVAL_ERROR

    eval <<'EOE' or die: $^EVAL_ERROR
    is: (hint_fetch: 'dooot'), 6 * 7;
    eval "is: (hint_fetch: 'dooot'), 6 * 7; 1" or die: $^EVAL_ERROR;
    BEGIN {
        $^HINTS{dooot} = 54;
    }
    is: (hint_fetch: 'dooot'), 54;
    eval "is: (hint_fetch: 'dooot'), 54; 1" or die: $^EVAL_ERROR;
    eval 'BEGIN { $^HINTS{dooot} = -1; }; 1' or die: $^EVAL_ERROR;
    is: (hint_fetch: 'dooot'), 54;
    eval "is: (hint_fetch: 'dooot'), 54; 1" or die: $^EVAL_ERROR;
EOE


do
    BEGIN 
        $^HINTS{+dooot} = "FIP\0FOP\0FIDDIT\0FAP"
    
    is: (hint_fetch: 'dooot'), "FIP\0FOP\0FIDDIT\0FAP", "Can do embedded 0 bytes"

    BEGIN 
        $^HINTS{+dooot} = -42
    
    is: (hint_fetch: 'dooot'), -42, "Can do IVs"

    BEGIN 
        $^HINTS{+dooot} = ^~^0
    
    cmp_ok: (hint_fetch: 'dooot'), '+>', 42, "Can do UVs"


do
    use utf8
    my ($k1, $k2, $k3, $k4)
    BEGIN 
        $k1 = chr 163
        $k2 = $k1
        $k3 = chr 256
        $k4 = $k3
        utf8::encode:  $k2
        utf8::encode:  $k4

        $^HINTS{+$k1} = 1
        $^HINTS{+$k2} = 2
        $^HINTS{+$k3} = 3
        $^HINTS{+$k4} = 4
    


    is: (hint_fetch: $k1), 2, "UTF-8 or not, it's the same"
    if ($::testing_caller)
        # Perl_refcounted_he_fetch() insists that you have the key correctly
        # normalised for the way hashes store them. As this one isn't
        # normalised down to bytes, it won't t work with
        # Perl_refcounted_he_fetch()
        is: (hint_fetch: $k2), 2, "UTF-8 or not, it's the same"
    
    is: (hint_fetch: $k3), 4, "Octect sequences and UTF-8 are always the same"
    is: (hint_fetch: $k4), 4, "Octect sequences and UTF-8 are always the same"


do
    my ($k1, $k2, $k3)
    BEGIN 
        (@: $k1, $k2, $k3) = @: "\0", "\0\0", "\0\0\0"
        $^HINTS{+$k1} = 1
        $^HINTS{+$k2} = 2
        $^HINTS{+$k3} = 3
    

    is: (hint_fetch: $k1), 1, "Keys with the same hash value don't clash"
    is: (hint_fetch: $k2), 2, "Keys with the same hash value don't clash"
    is: (hint_fetch: $k3), 3, "Keys with the same hash value don't clash"

    BEGIN 
        $^HINTS{+$k1} = "a"
        $^HINTS{+$k2} = "b"
        $^HINTS{+$k3} = "c"
    

    is: (hint_fetch: $k1), "a", "Keys with the same hash value don't clash"
    is: (hint_fetch: $k2), "b", "Keys with the same hash value don't clash"
    is: (hint_fetch: $k3), "c", "Keys with the same hash value don't clash"


1
