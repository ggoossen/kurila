#!./perl

BEGIN 
    require './test.pl'


plan:  tests => 49 

require bytes

run_tests:  unless caller

sub run_tests

    my $foo = 'Now is the time for all good men to come to the aid of their country.'

    my $first = substr: $foo,0,(index: $foo,'the')
    is: $first, "Now is "

    my $last = substr: $foo,(rindex: $foo,'the'),100
    is: $last, "their country."

    $last = substr: $foo,(index: $foo,'Now'),2
    is: $last, "No"

    $last = substr: $foo,(rindex: $foo,'Now'),2
    is: $last, "No"

    $last = substr: $foo,(index: $foo,'.'),100
    is: $last, "."

    $last = substr: $foo,(rindex: $foo,'.'),100
    is: $last, "."

    is: (index: "ababa","a",-1), 0
    is: (index: "ababa","a",0), 0
    is: (index: "ababa","a",1), 2
    is: (index: "ababa","a",2), 2
    is: (index: "ababa","a",3), 4
    is: (index: "ababa","a",4), 4
    is: (index: "ababa","a",5), -1

    is: (rindex: "ababa","a",-1), -1
    is: (rindex: "ababa","a",0), 0
    is: (rindex: "ababa","a",1), 0
    is: (rindex: "ababa","a",2), 2
    is: (rindex: "ababa","a",3), 2
    is: (rindex: "ababa","a",4), 4
    is: (rindex: "ababa","a",5), 4

    # tests for empty search string
    is: (index: "abc", "", -1), 0
    is: (index: "abc", "", 0), 0
    is: (index: "abc", "", 1), 1
    is: (index: "abc", "", 2), 2
    is: (index: "abc", "", 3), 3
    is: (index: "abc", "", 4), 3
    is: (rindex: "abc", "", -1), 0
    is: (rindex: "abc", "", 0), 0
    is: (rindex: "abc", "", 1), 1
    is: (rindex: "abc", "", 2), 2
    is: (rindex: "abc", "", 3), 3
    is: (rindex: "abc", "", 4), 3

    do
        # utf8
        use utf8
        $a = "foo \x{1234}bar"

        is: (index: $a, "\x{1234}"), 4
        is: (index: $a, "bar",    ), 5

        is: (rindex: $a, "\x{1234}"), 4
        is: (rindex: $a, "foo",    ), 0
        is: (rindex: $a, "bar",    ), 5

        is: (bytes::index: $a, "\x{1234}"), 4
        is: (bytes::index: $a, "bar",    ), 7

        is: (bytes::rindex: $a, "\x{1234}"), 4
        is: (bytes::rindex: $a, "foo",    ), 0
        is: (bytes::rindex: $a, "bar",    ), 7
    

    do
        use utf8
        my $needle = "\x{1230}\x{1270}"
        my @needles = @: "\x{1230}", "\x{1270}"
        my $haystack = "\x{1228}\x{1228}\x{1230}\x{1270}"
        foreach (  @needles )
            my $a = index:  "\x{1228}\x{1228}\x{1230}\x{1270}", $_ 
            my $b = index:  $haystack, $_ 
            is: $a, $b, q{[perl #22375] 'split'/'index' problem for utf8}
        
        $needle = "\x{1270}\x{1230}" # Transpose them.
        @needles = @: "\x{1270}", "\x{1230}"
        foreach (  @needles )
            my $a = index:  "\x{1228}\x{1228}\x{1230}\x{1270}", $_ 
            my $b = index:  $haystack, $_ 
            is: $a, $b, q{[perl #22375] 'split'/'index' problem for utf8}
        
    

    do
        use utf8

        my $a = "\x{80000000}"
        my $s = $a.'defxyz'
        is: (index: $s, 'def'), 1, "0x80000000 is a single character"

        my $b = "\x{fffffffd}"
        my $t = $b.'pqrxyz'
        is: (index: $t, 'pqr'), 1, "0xfffffffd is a single character"

        local $^UTF8CACHE = -1
        is: (index: $t, 'xyz'), 4, "0xfffffffd and utf8cache"
