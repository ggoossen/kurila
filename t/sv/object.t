#!./perl

BEGIN { require './test.pl'; }

plan: 1

# assignment of hash to object
fresh_perl_is:  <<'PROG', 'ref: FOO, svtype: HASH' 
my $x = bless \$@, "FOO";
$x->$ = $%;
print $^STDOUT, "ref: ", ref($x), ", svtype: ", ref::svtype($x->$);
PROG
