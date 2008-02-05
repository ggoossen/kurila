#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

use Storable qw(store retrieve store_fd nstore_fd fd_retrieve);

use Test::More;

plan tests => 19;

$a = 'toto';
$b = \$a;
$c = bless {}, 'CLASS';
$c->{attribute} = 'attrval';
%a = ('key', 'value', 1, 0, $a, $b, 'cvar', \$c);
@a = ('first', undef, 3, -4, -3.14159, 456, 4.5,
	$b, \$a, $a, $c, \$c, \%a);

ok(defined store(\@a, 'store'));

$root = retrieve('store');
ok(defined $root);

is_deeply($root, \@a);

1 while unlink 'store';

package FOO; @ISA = qw(Storable);

sub make {
	my $self = bless {};
	$self->{key} = \%main::a;
	return $self;
};

package main;

$foo = FOO->make;
ok($foo->store('store'));

ok(open(OUT, ">>", 'store'));
binmode OUT;

ok(defined store_fd(\@a, '::OUT'));
ok(defined nstore_fd($foo, '::OUT'));
ok(defined nstore_fd(\%a, '::OUT'));

ok(close(OUT));

ok(open(OUT, "<", 'store'));
binmode OUT;

$r = fd_retrieve('::OUT');
ok(defined $r);
is_deeply($foo, $r);

$r = fd_retrieve('::OUT');
ok(defined $r);
is_deeply(\@a, $r);

$r = fd_retrieve('main::OUT');
ok(defined $r);
is_deeply($foo, $r);

$r = fd_retrieve('::OUT');
ok(defined $r);
is_deeply(\%a, $r);

eval { $r = fd_retrieve('::OUT'); };
ok($@);

close OUT or die "Could not close: $!";
END { 1 while unlink 'store' }
