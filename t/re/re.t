#!./perl

use warnings

use Test::More # test count at bottom of file
use re < qw(is_regexp regexp_pattern
          regname regnames regnames_count)
do
    my $qr=qr/foo/pi
    ok: (is_regexp: $qr),'is_regexp($qr)'
    ok: !(is_regexp: ''),'is_regexp("")'
    is: (regexp_pattern: $qr),'(?pi-uxsm:foo)','scalar regexp_pattern'
    ok: !(regexp_pattern: ''),'!regexp_pattern("")'


if ('1234' =~ m/(?:(?<A>\d)|(?<C>!))(?<B>\d)(?<A>\d)(?<B>\d)/)
    my @names = sort: $( (regnames: ) )
    is: "$((join: ' ',@names))","A B","regnames"
    @names = sort: $( (regnames: 0) )
    is: "$((join: ' ',@names))","A B","regnames"
    @names = sort: $( (regnames: 1) )
    is: "$((join: ' ',@names))","A B C","regnames"
    is: (join: "", (regname: "A",1)->@),"13"
    is: (join: "", (regname: "B",1)->@),"24"
    do
        if ('foobar' =~ m/(?<foo>foo)(?<bar>bar)/)
            is: (regnames_count: ),2
        else
            (ok: 0); ok: 0
        
    
    is: (regnames_count: ),3

# New tests above this line, don't forget to update the test count below!
use Test::More tests => 11
# No tests here!
