#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

use Storable < qw(store retrieve store_fd nstore_fd fd_retrieve);

use Test::More;

plan tests => 19;

$a = 'toto';
$b = \$a;
my $c = bless \%(), 'CLASS';
$c->{+attribute} = 'attrval';
my %a = %('key', 'value', 1, 0, $a, $b, 'cvar', \$c);
my @a = @('first', undef, 3, -4, -3.14159, 456, 4.5,
	$b, \$a, $a, $c, \$c, \%a);

ok(defined store(\@a, 'store'));

my $root = retrieve('store');
ok(defined $root);

is_deeply($root, \@a);

1 while unlink 'store';

package FOO; our @ISA = qw(Storable);

sub make {
	my $self = bless \%();
	$self->{+key} = \%main::a;
	return $self;
};

package main;

my $foo = FOO->make;
ok($foo->store('store'));

ok(open(my $outfh, ">>", 'store'));
binmode $outfh;

ok(defined store_fd(\@a, \*$outfh));
ok(defined nstore_fd($foo, \*$outfh));
ok(defined nstore_fd(\%a, \*$outfh));

ok(close($outfh));

ok(open($outfh, "<", 'store'));
binmode $outfh;

my $r = fd_retrieve(\*$outfh);
ok(defined $r);
is_deeply($foo, $r);

$r = fd_retrieve(\*$outfh);
ok(defined $r);
is_deeply(\@a, $r);

$r = fd_retrieve(\*$outfh);
ok(defined $r);
is_deeply($foo, $r);

$r = fd_retrieve(\*$outfh);
ok(defined $r);
is_deeply(\%a, $r);

try { $r = fd_retrieve(\*$outfh); };
ok($^EVAL_ERROR);

close $outfh or die "Could not close: $^OS_ERROR";
END { 1 while unlink 'store' }
