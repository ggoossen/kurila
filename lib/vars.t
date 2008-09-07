#!./perl 

use TestInit;

$| = 1;

print "1..27\n";

# catch "used once" warnings
my @warns;
BEGIN { $^WARN_HOOK = sub { push @warns, @_[0]->{description} }; $^W = 1 };

%main::x = %( () );
$main::y = 3;
@main::z = @( () );
$X::x = 13;

use vars < qw($p @q %r *s);

my $e = !(grep m/^Name "X::x" used only once: possible typo/, @warns) && 'not ';
print "{$e}ok 1\n";
$e = !(grep m/^Name "main::x" used only once: possible typo/, @warns) && 'not ';
print "{$e}ok 2\n";
$e = !(grep m/^Name "main::y" used only once: possible typo/, @warns) && 'not ';
print "{$e}ok 3\n";
$e = !(grep m/^Name "main::z" used only once: possible typo/, @warns) && 'not ';
print "{$e}ok 4\n";
($e, < @warns) = (nelems @warns) != 4 && 'not ';
print "{$e}ok 5\n";

# this is inside eval() to avoid creation of symbol table entries and
# to avoid "used once" warnings
eval <<'EOE';
$e = ! %main::{p} && 'not ';
print "{$e}ok 6\n";
$e = ! *q{ARRAY} && 'not ';
print "{$e}ok 7\n";
$e = ! *r{HASH} && 'not ';
print "{$e}ok 8\n";
$e = ! %main::{s} && 'not ';
print "{$e}ok 9\n";
print "ok 10\n";
$e = defined %X::{q} && 'not ';
print "{$e}ok 11\n";
print "ok 12\n";
EOE
$e = $@ && 'not ';
print "{$e}ok 13\n";

eval q{use vars q(!abc);};
print "ok 14\n";
$e = $@->{description} !~ m/^'!abc' is not a valid variable name/ && 'not ';
print "{$e}ok 15\n";

eval 'use vars q($x[3])';
$e = $@->{description} !~ m/^Can't declare individual elements of hash or array/ && 'not ';
print "{$e}ok 16\n";

{ local $^W;
  eval 'use vars q($!)';
  $e = $@->{description} !~ m/^'\$!' is not a valid variable name/ && 'not ';
  print "{$e}ok 17\n";
};

# NB the next test only works because vars.pm has already been loaded
eval 'use warnings "vars"; use vars q($!)';
$e = ($@ || (shift(@warns)||'') !~ m/^No need to declare built-in vars/)
			&& 'not ';
print "{$e}ok 18\n";

print "ok 19\n";
print "ok 20\n";
print "ok 21\n";
print "ok 22\n";
print "ok 23\n";
eval '$u = 3; @v = (); %w = ()';
my @errs = split m/\n/, $@->{description};
$e = (nelems @errs) != 3 && 'not ';
print "{$e}ok 24\n";
$e = !(grep(m/^Global symbol "\$u" requires explicit package name/, @errs))
			&& 'not ';
print "{$e}ok 25\n";
$e = !(grep(m/^Global symbol "\@v" requires explicit package name/, @errs))
			&& 'not ';
print "{$e}ok 26\n";
$e = !(grep(m/^Global symbol "\%w" requires explicit package name/, @errs))
			&& 'not ';
print "{$e}ok 27\n";
