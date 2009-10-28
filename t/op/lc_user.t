BEGIN 
    require './test.pl'


plan: tests => 4

use utf8

sub ToUpper
    return <<END
0061	0063	0041
END


is: (uc: "foo\x{101}"), "foo\x{101}", "no changes on 'foo'"
is: (uc: "bar\x{101}"), "BAr\x{101}", "changing 'ab' on 'bar' "

sub ToLower
    return <<END
0041		0061
END


is: (lc: "FOO\x{100}"), "FOO\x{100}", "no changes on 'FOO'"
is: (lc: "BAR\x{100}"), "BaR\x{100}", "changing 'A' on 'BAR' "

