#!./perl

# Verify list assignments

BEGIN {
    require "test.pl";
}

plan(3);

my ($x, $y, $z);

($x, $y) = ("first", "second");
is("$x-$y", "first-second", "basic list assignment to multiple variable");

($x, $y) = ("first", "second");
($x, $y) = ($y, $x);
is("$x-$y", "second-first", "list assignment with common variables");

{
    local $TODO = "commonality detection with &&";
    $z = 1;
    ($x, $y) = ("first", "second");
    ($x, $y) = ("new", $z && $x);
    is("$x-$y", "new-first", 'list assignment with common variables "hidden" with &&');
}
