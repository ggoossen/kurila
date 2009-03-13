#!./perl

use Config;

use Scalar::Util ();
use Test::More  (grep { m/set_prototype/ }, @Scalar::Util::EXPORT_FAIL)
			?? (skip_all => 'set_prototype requires XS version')
			!! (tests => 9);

Scalar::Util->import('set_prototype');

sub f { }
is( prototype(\&f),	undef,	'no prototype');

my $r = set_prototype(\&f,'$');
is( prototype(\&f),	'$',	'set prototype');
is( $r,			\&f,	'return value');

set_prototype(\&f,undef);
is( prototype(\&f),	undef,	'remove prototype');

set_prototype(\&f,'');
is( prototype(\&f),	'',	'empty prototype');

sub g (@) { }
is( prototype(\&g),	'@',	'@ prototype');

set_prototype(\&g,undef);
is( prototype(\&g),	undef,	'remove prototype');

try { &set_prototype( 'f', '' ); };
print \*STDOUT, "not " unless 
ok($^EVAL_ERROR->{?description} =~ m/^set_prototype: not a reference/,	'not a reference');

try { &set_prototype( \'f', '' ); };
ok($^EVAL_ERROR->{?description} =~ m/^set_prototype: not a subroutine reference/,	'not a sub reference');
