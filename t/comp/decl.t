#!./perl

# check to see if subroutine declarations work everwhere

sub one
    print: $^STDOUT, "ok 1\n"


print: $^STDOUT, "1..4\n"

(one: )
(two: )

sub two
    print: $^STDOUT, "ok 2\n"


our $x
if ($x eq $x)
    sub three
        print: $^STDOUT, "ok 3\n"
    
    (three: )


(four: )

sub four
    print: $^STDOUT, "ok 4\n"

