#!./perl

BEGIN {
    require './test.pl';
}

use Symbol;

plan 'no_plan';

my $sym = Symbol::geniosym();
is Internals::SvREFCNT($sym), 1, "start with one ref";
#is Internals::peek($sym), 1, "start with one ref";
my $old = select $sym;
is Internals::SvREFCNT($sym), 2, "refcnt increased";
$sym = \ select $old;
is Internals::SvREFCNT($sym), 1, "reference count restored";
