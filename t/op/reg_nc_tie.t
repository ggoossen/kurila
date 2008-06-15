#!./perl

BEGIN {
    require './test.pl';
}

# Do a basic test on all the tied methods of Tie::Hash::NamedCapture

print "1..13\n";

# PL_curpm->paren_names can be a null pointer. See that this succeeds anyway.
'x' =~ m/(.)/;
() = < %+;
pass( 'still alive' );

"hlagh" =~ m/
    (?<a>.)
    (?<b>.)
    (?<a>.)
    .*
    (?<e>$)
/x;

# FETCH
is(%+{a}, "h", "FETCH");
is(%+{b}, "l", "FETCH");
is(%-{a}->[0], "h", "FETCH");
is(%-{a}->[1], "a", "FETCH");

# STORE
try { %+{a} = "yon" };
ok(index($@->{description}, "read-only") != -1, "STORE");

# DELETE
try { delete %+{a} };
ok(index($@->{description}, "read-only") != -1, "DELETE");

# CLEAR
try { %+ = %( () ) };
ok(index($@->{description}, "read-only") != -1, "CLEAR");

# EXISTS
ok(exists %+{e}, "EXISTS");
ok(!exists %+{d}, "EXISTS");

# FIRSTKEY/NEXTKEY
is(join('|', sort keys %+), "a|b|e", "FIRSTKEY/NEXTKEY");

# SCALAR
is(nelems(@(keys %+)), 3, "SCALAR");
is(nelems(@(keys %-)), 3, "SCALAR");
