#!./perl

print: $^STDOUT, "1..1\n"

# there is an equivelent test in t/re/pat.t which does NOT fail
# its not clear why it doesnt fail, so this todo gets its own test
# file until we can work it out.

my $x
($x='abc')=~m/(abc)/g
$x='123'

print: $^STDOUT, "not " if $1 ne 'abc'
print: $^STDOUT, "ok 1 # TODO safe match vars make /g slow\n"
