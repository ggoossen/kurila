#!./perl

require './test.pl'

plan:  tests => 1 

do
    my @a = @: "foo", "bar"
    my @b = reverse: @a

    ok:  @b[0] eq @a[1] && @b[1] eq @a[0] 

