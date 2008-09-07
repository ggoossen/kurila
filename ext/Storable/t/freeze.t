#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

sub BEGIN {
    if (%ENV{PERL_CORE}){
	chdir('t') if -d 't';
	@INC = @('.', '../lib', '../ext/Storable/t');
    } else {
	unshift @INC, 't';
    }
    require 'st-dump.pl';
}

use Storable < qw(freeze nfreeze thaw);

print "1..20\n";

$a = 'toto';
$b = \$a;
our $c = bless \%(), 'CLASS';
$c->{attribute} = $b;
our $d = \%();
our $e = \@();
$d->{'a'} = $e;
$e->[0] = $d;
our %a = %('key', 'value', 1, 0, $a, $b, 'cvar', \$c);
our @a = @('first', undef, 3, -4, -3.14159, 456, 4.5, $d, \$d, \$e, $e,
	$b, \$a, $a, $c, \$c, \%a);

print "not " unless defined (our $f1 = freeze(\@a));
print "ok 1\n";

our $dumped = &dump(\@a);
print "ok 2\n";

our $root = thaw($f1);
print "not " unless defined $root;
print "ok 3\n";

our $got = &dump($root);
print "ok 4\n";

print "not " unless $got eq $dumped; 
print "ok 5\n";

package FOO; our @ISA = qw(Storable);

sub make {
	my $self = bless \%();
	$self->{key} = \%main::a;
	return $self;
};

package main;

our $foo = FOO->make;
print "not " unless our $f2 = $foo->freeze;
print "ok 6\n";

print "not " unless our $f3 = $foo->nfreeze;
print "ok 7\n";

our $root3 = thaw($f3);
print "not " unless defined $root3;
print "ok 8\n";

print "not " unless &dump($foo) eq &dump($root3);
print "ok 9\n";

$root = thaw($f2);
print "not " unless &dump($foo) eq &dump($root);
print "ok 10\n";

print "not " unless &dump($root3) eq &dump($root);
print "ok 11\n";

our $other = freeze($root);
print "not " unless length($other) == length($f2);
print "ok 12\n";

our $root2 = thaw($other);
print "not " unless &dump($root2) eq &dump($root);
print "ok 13\n";

our $VAR1 = \@(
	'method',
	1,
	'prepare',
	q|SELECT table_name, table_owner, num_rows FROM iitables
                  where table_owner != '$ingres' and table_owner != 'DBA'|
);

our $x = nfreeze($VAR1);
our $VAR2 = thaw($x);
print "not " unless $VAR2->[3] eq $VAR1->[3];
print "ok 14\n";

# Test the workaround for LVALUE bug in perl 5.004_04 -- from Gisle Aas
sub foo { @_[0] = 1 }
$foo = \@();
foo($foo->[1]);
try { freeze($foo) };
print "not " if $@;
print "ok 15\n";

# Test cleanup bug found by Claudio Garcia -- RAM, 08/06/2001
my $thaw_me = 'asdasdasdasd';

try {
	my $thawed = thaw $thaw_me;
};
ok 16, $@;

my %to_be_frozen = %(foo => 'bar');
my $frozen;
try {
	$frozen = freeze \%to_be_frozen;
};
ok 17, !$@;

freeze \%();
try { thaw $thaw_me };
try { $frozen = freeze \%( foo => \%() ) };
ok 18, !$@;

thaw $frozen;			# used to segfault here
ok 19, 1;

    eval '
        $a = \@(undef, undef);
        $b = thaw freeze $a;
        @a = map { exists $a->[$_] } 0 .. (nelems @$a)-1;
        our @b = map { exists $b->[$_] } 0 .. (nelems @$b)-1;
        ok 20, (join " ", @a) eq (join " ", @b);
    ';
    die if $@;
