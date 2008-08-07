#!./perl

use TestInit;

package Oscalar;
use overload ( 
				# Anonymous subroutines:
'+'	=>	sub { Oscalar->new( $ {@_[0]}+@_[1])},
'-'	=>	sub { Oscalar->new(
		       @_[2]? @_[1]-${@_[0]} : ${@_[0]}-@_[1])},
'<+>'	=>	sub { Oscalar->new(
		       @_[2]? @_[1]-${@_[0]} : ${@_[0]}-@_[1])},
'cmp'	=>	sub { Oscalar->new(
		       @_[2]? (@_[1] cmp ${@_[0]}) : (${@_[0]} cmp @_[1]))},
'*'	=>	sub { Oscalar->new( ${@_[0]}*@_[1])},
'/'	=>	sub { Oscalar->new( 
		       @_[2]? @_[1]/${@_[0]} :
			 ${@_[0]}/@_[1])},
'%'	=>	sub { Oscalar->new(
		       @_[2]? @_[1]%${@_[0]} : ${@_[0]}%@_[1])},
'**'	=>	sub { Oscalar->new(
		       @_[2]? @_[1]**${@_[0]} : ${@_[0]}-@_[1])},

'""'	=> \&stringify,
'0+'	=> \&numify,			# Order of arguments insignificant
);

sub new {
  my $foo = @_[1];
  bless \$foo, @_[0];
}

sub stringify { "${@_[0]}" }
sub numify { 0 + "${@_[0]}" }	# Not needed, additional overhead
				# comparing to direct compilation based on
				# stringify

package main;

$| = 1;
use Test::More tests => 133;


$a = Oscalar->new( "087");
$b= "$a";

is($b, $a);
is($b, "087");
is(ref $a, "Oscalar");
is($a, $a);
is($a, "087");

my $c = $a + 7;

is(ref $c, "Oscalar");
isnt($c, $a);
is($c, "94");

$b=$a;

is(ref $a, "Oscalar");

$b++;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "88");
is(ref $a, "Oscalar");

$c=$b;
$c-=$a;

is(ref $c, "Oscalar");
is($a, "087");
is($c, "1");
is(ref $a, "Oscalar");

$b=1;
$b+=$a;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "88");
is(ref $a, "Oscalar");

eval q[ package Oscalar; use overload ('++' => sub { $ {@_[0]}++;@_[0] } ) ];

$b=$a;

is(ref $a, "Oscalar");

$b++;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "88");
is(ref $a, "Oscalar");

package Oscalar;
our $dummy;
$dummy=bless \$dummy;		# Now cache of method should be reloaded
package main;

$b=$a;
$b++;				

is(ref $b, "Oscalar");
is($a, "087");
is($b, "88");
is(ref $a, "Oscalar");

undef $b;			# Destroying updates tables too...

eval q[package Oscalar; use overload ('++' => sub { $ {@_[0]} += 2; @_[0] } ) ];

$b=$a;

is(ref $a, "Oscalar");

$b++;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "88");
is(ref $a, "Oscalar");

package Oscalar;
$dummy=bless \$dummy;		# Now cache of method should be reloaded
package main;

$b++;				

is(ref $b, "Oscalar");
is($a, "087");
is($b, "90");
is(ref $a, "Oscalar");

$b=$a;
$b++;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "89");
is(ref $a, "Oscalar");


ok($b? 1:0);

eval q[ package Oscalar; use overload ('=' => sub {$main::copies++; 
						   package Oscalar;
						   local our $new=$ {@_[0]};
						   bless \$new } ) ];

$b= Oscalar->new( "$a");

is(ref $b, "Oscalar");
is($a, "087");
is($b, "087");
is(ref $a, "Oscalar");

$b++;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "89");
is(ref $a, "Oscalar");
our $copies;
is($copies, undef);

$b+=1;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "90");
is(ref $a, "Oscalar");
is($copies, undef);

$b=$a;
$b+=1;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "88");
is(ref $a, "Oscalar");
is($copies, undef);

$b=$a;
$b++;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "89");
is(ref $a, "Oscalar");
is($copies, 1);

eval q[package Oscalar; use overload ('+=' => sub {$ {@_[0]} += 3*@_[1];
						   @_[0] } ) ];
$c= Oscalar->new();			# Cause rehash

$b=$a;
$b+=1;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "90");
is(ref $a, "Oscalar");
is($copies, 2);

$b+=$b;

is(ref $b, "Oscalar");
is($b, "360");
is($copies, 2);
$b=-$b;

is(ref $b, "Oscalar");
is($b, "-360");
is($copies, 2);

$b=abs($b);

is(ref $b, "Oscalar");
is($b, "360");
is($copies, 2);

$b=abs($b);

is(ref $b, "Oscalar");
is($b, "360");
is($copies, 2);

eval q[package Oscalar; 
       use overload ('x' => sub {Oscalar->new( @_[2] ? "_.@_[1]._" x $ {@_[0]}
					      : "_.${@_[0]}._" x @_[1])}) ];

$a= Oscalar->new( "yy");
$a x= 3;
is($a, "_.yy.__.yy.__.yy._");

eval q[package Oscalar; 
       use overload ('.' => sub {Oscalar->new( @_[2] ? 
					      "_.@_[1].__.$ {@_[0]}._"
					      : "_.$ {@_[0]}.__.@_[1]._")}) ];

$a= Oscalar->new( "xx");

is("b{$a}c", "_._.b.__.xx._.__.c._");

# Check inheritance of overloading;
{
  package OscalarI;
  our @ISA = @( 'Oscalar' );
}

my $aI = OscalarI->new( "$a");
is(ref $aI, "OscalarI");
is("$aI", "xx");
is($aI, "xx");
is("b{$aI}c", "_._.b.__.xx._.__.c._");

# Here we test blessing to a package updates hash

eval "package Oscalar; no overload '.'";

is("b{$a}", "_.b.__.xx._");
my $x="1";
bless \$x, 'Oscalar';
is("b{$a}c", "bxxc");
 Oscalar->new( 1);
is("b{$a}c", "bxxc");

# Negative overloading:

my $na = try { ^~^$a };
like($@->{description}, qr/no method found/);

eval "package Oscalar; sub numify \{ return '_!_' . shift() . '_!_' \} use overload '0+' => \\&numify";
is $@, '';
eval "package Oscalar; sub rshft \{ return '_!_' . shift() . '_!_' \} use overload '>>' => \\&rshft";
is $@, '';

$na = try { $aI >> 1 };       # Hash was not updated
like($@->{description}, qr/no method found/);

bless \$x, 'OscalarI';

$na = 0;

$na = try { $aI >> 1 };
print $@;

ok(!$@);
is($na, '_!_xx_!_');

# warn overload::Method($a, '0+'), "\n";
cmp_ok(overload::Method($a, '0+'), '\==', \&Oscalar::numify);
cmp_ok(overload::Method($aI,'0+'), '\==', \&Oscalar::numify);
ok(overload::Overloaded($aI));
ok(!overload::Overloaded('overload'));

ok(! defined overload::Method($aI, '<<'));
ok(! defined overload::Method($a, '+<'));

like (overload::StrVal($aI), qr/^OscalarI=SCALAR\(0x[\da-fA-F]+\)$/);
{
    local $TODO = "find out what this should do.";
    cmp_ok(overload::StrVal(\$aI), '\==', \$aI);
}

our ($int, $out);
{
  BEGIN { $int = 7; overload::constant 'integer' => sub {$int++; shift}; }
  $out = 2**10;
}
is($int, 9);
is($out, 1024);

our $foo = 'foo';
our $foo1 = q|f'o\\o|;
our ($q, $qr, @q, @qr, $out1, $out2, @q1, @qr1);
{
  BEGIN { $q = $qr = 7; 
	  overload::constant 'q' => sub {$q++; push @q, shift, (@_[1] || 'none'); shift},
			     'qr' => sub {$qr++; push @qr, shift, (@_[1] || 'none'); shift}; }
  $out = 'foo';
  $out1 = q|f'o\\o|;
  $out2 = "a\a$foo,\,";
  m/b\b$foo.\./;
}

is($out, 'foo');
is($out, $foo);
is($out1, q|f'o\\o|);
is($out1, $foo1);
is($out2, "a\afoo,\,");
is("{join ' ', <@q}", "foo q f'o\\\\o q a\\a qq ,\\, qq");
is($q, 11);
is("{join ' ', <@qr}", "b\\b qq .\\. qq");
is($qr, 9);

our $res;
{
  $_ = '!<b>!foo!<-.>!';
  BEGIN { overload::constant 'q' => sub {push @q1, shift, (@_[1] || 'none'); "_<" . (shift) . ">_"},
			     'qr' => sub {push @qr1, shift, (@_[1] || 'none'); "!<" . (shift) . ">!"}; }
  $out = 'foo';
  $out1 = q|f'o\\o|;
  $out2 = "a\a$foo,\,";
  $res = m/b\b$foo.\./;
  $a = <<EOF;
oups
EOF
  $b = <<'EOF';
oups1
EOF
  m'try it';
  s'first part'second part';
  s/yet another/tail here/;
}
is($out, '_<foo>_'); is($out1, q|_<f'o\\o>_|); is($out2, "_<a\a>_foo_<,\,>_"); is("{join ' ', <@q1}", "foo q f'o\\\\o q a\\a qq ,\\, qq oups
 qq oups1
 q second part s tail here s");
is("{join ' ', <@qr1}", "b\\b qq .\\. qq try it qq first part qq yet another qq");
is($res, 1);
is($a, "_<oups
>_");
is($b, "_<oups1
>_");

{
  package two_face;		# Scalars with separate string and
                                # numeric values.
  sub new { my $p = shift; bless \@(< @_), $p }
  use overload '""' => \&str, '0+' => \&num, fallback => 1;
  sub num {shift->[1]}
  sub str {shift->[0]}
}

{
  my $seven = two_face->new("vii", 7);
  is((sprintf "seven=$seven, seven=\%d, eight=\%d", $seven, $seven+1),
	'seven=vii, seven=7, eight=8');
  is(scalar ($seven =~ m/i/), '1');
}

{
  package sorting;
  use overload 'cmp' => \&comp;
  sub new { my ($p, $v) = < @_; bless \$v, $p }
  sub comp { my ($x,$y) = < @_; ($$x * 3 % 10) <+> ($$y * 3 % 10) or $$x cmp $$y }
}
{
  my @arr = @( map sorting->new($_), 0..12 );
  my @sorted1 = @( sort < @arr );
  my @sorted2 = @( map $$_, < @sorted1 );
  is("{join ' ', <@sorted2}", '0 10 7 4 1 11 8 5 12 2 9 6 3');
}
{
  package iterator;
  use overload '<>' => \&iter;
  sub new { my ($p, $v) = < @_; bless \$v, $p }
  sub iter { my ($x) = < @_; return undef if $$x +< 0; return $$x--; }
}

# XXX iterator overload not intended to work with CORE::GLOBAL?
if (defined &CORE::GLOBAL::glob) {
  is('1', '1');
  is('1', '1');
  is('1', '1');
}
else {
  my $iter = iterator->new(5);
  my $acc = '';
  my $out;
  $acc .= " $out" while $out = glob("{$iter}");
  is($acc, ' 5 4 3 2 1 0');
  $iter = iterator->new(5);
  is(scalar glob("{$iter}"), '5');
  $acc = '';
  $acc .= " $out" while $out = ~< $iter;
  is($acc, ' 4 3 2 1 0');
}

