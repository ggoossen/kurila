#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

BEGIN {
    if (env::var('PERL_CORE')){
	chdir('t') if -d 't';
	$^INCLUDE_PATH = @('.', '../lib', '../ext/Storable/t');
    } else {
	unshift $^INCLUDE_PATH, 't';
    }
    require 'st-dump.pl';
}

use Storable < qw(freeze nfreeze thaw);

use Test::More;
plan tests => 20;

$a = 'toto';
$b = \$a;
our $c = bless \%(), 'CLASS';
$c->{+attribute} = $b;
our $d = \%();
our $e = \@();
$d->{+'a'} = $e;
$e->[+0] = $d;
our %a = %('key', 'value', 1, 0, $a, $b, 'cvar', \$c);
our @a = @('first', undef, 3, -4, -3.14159, 456, 4.5, $d, \$d, \$e, $e,
	$b, \$a, $a, $c, \$c, \%a);

ok defined (our $f1 = freeze(\@a));

our $dumped = &dump(\@a);
ok 1;

our $root = thaw($f1);
ok defined $root;

our $got = &dump($root);
ok 1;

ok $got eq $dumped; 

package FOO; our @ISA = qw(Storable);

sub make {
	my $self = bless \%();
	$self->{+key} = \%main::a;
	return $self;
};

package main;

our $foo = FOO->make;
ok(our $f2 = $foo->freeze);

ok(our $f3 = $foo->nfreeze);

our $root3 = thaw($f3);
ok defined $root3;

ok &dump($foo) eq &dump($root3);

$root = thaw($f2);
ok &dump($foo) eq &dump($root);

ok &dump($root3) eq &dump($root);

our $other = freeze($root);
ok length($other) == length($f2);

our $root2 = thaw($other);
ok &dump($root2) eq &dump($root);

our $VAR1 = \@(
	'method',
	1,
	'prepare',
	q|SELECT table_name, table_owner, num_rows FROM iitables
                  where table_owner != '$ingres' and table_owner != 'DBA'|
);

our $x = nfreeze($VAR1);
our $VAR2 = thaw($x);
ok $VAR2->[3] eq $VAR1->[3];

# Test the workaround for LVALUE bug in perl 5.004_04 -- from Gisle Aas
sub foo { @_[0] = 1 }
$foo = \@();
foo($foo->[?1]);
freeze($foo);
ok 1;

# Test cleanup bug found by Claudio Garcia -- RAM, 08/06/2001
my $thaw_me = 'asdasdasdasd';

try {
	my $thawed = thaw $thaw_me;
};
ok $^EVAL_ERROR;

my %to_be_frozen = %(foo => 'bar');
my $frozen;
try {
	$frozen = freeze \%to_be_frozen;
};
ok !$^EVAL_ERROR;

freeze \%();
try { thaw $thaw_me };
try { $frozen = freeze \%( foo => \%() ) };
ok !$^EVAL_ERROR;

thaw $frozen;			# used to segfault here
ok 1;

    eval '
        $a = \@(undef, undef);
        $b = thaw freeze $a;
        @a = map { exists $a->[$_] }, 0 .. (nelems @$a)-1;
        our @b = map { exists $b->[$_] }, 0 .. (nelems @$b)-1;
        ok (join " ", @a) eq (join " ", @b);
    ';
    die if $^EVAL_ERROR;
