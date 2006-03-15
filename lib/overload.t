#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require Config;
    if (($Config::Config{'extensions'} !~ m!\bList/Util\b!) ){
	print "1..0 # Skip -- Perl configured without List::Util module\n";
	exit 0;
    }
}

package Oscalar;
use overload ( 
				# Anonymous subroutines:
'+'	=>	sub {new Oscalar $ {$_[0]}+$_[1]},
'-'	=>	sub {new Oscalar
		       $_[2]? $_[1]-${$_[0]} : ${$_[0]}-$_[1]},
'<=>'	=>	sub {new Oscalar
		       $_[2]? $_[1]-${$_[0]} : ${$_[0]}-$_[1]},
'cmp'	=>	sub {new Oscalar
		       $_[2]? ($_[1] cmp ${$_[0]}) : (${$_[0]} cmp $_[1])},
'*'	=>	sub {new Oscalar ${$_[0]}*$_[1]},
'/'	=>	sub {new Oscalar 
		       $_[2]? $_[1]/${$_[0]} :
			 ${$_[0]}/$_[1]},
'%'	=>	sub {new Oscalar
		       $_[2]? $_[1]%${$_[0]} : ${$_[0]}%$_[1]},
'**'	=>	sub {new Oscalar
		       $_[2]? $_[1]**${$_[0]} : ${$_[0]}-$_[1]},

qw(
""	stringify
0+	numify)			# Order of arguments unsignificant
);

sub new {
  my $foo = $_[1];
  bless \$foo, $_[0];
}

sub stringify { "${$_[0]}" }
sub numify { 0 + "${$_[0]}" }	# Not needed, additional overhead
				# comparing to direct compilation based on
				# stringify

package main;

$| = 1;
use Test::More tests=>503;


$a = new Oscalar "087";
$b= "$a";

is($b, $a);
is($b, "087");
is(ref $a, "Oscalar");
is($a, $a);
is($a, "087");

$c = $a + 7;

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

eval q[ package Oscalar; use overload ('++' => sub { $ {$_[0]}++;$_[0] } ) ];

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

$b=$a;
$b++;				

is(ref $b, "Oscalar");
is($a, "087");
is($b, "88");
is(ref $a, "Oscalar");

undef $b;			# Destroying updates tables too...

eval q[package Oscalar; use overload ('++' => sub { $ {$_[0]} += 2; $_[0] } ) ];

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
						   local $new=$ {$_[0]};
						   bless \$new } ) ];

$b=new Oscalar "$a";

is(ref $b, "Oscalar");
is($a, "087");
is($b, "087");
is(ref $a, "Oscalar");

$b++;

is(ref $b, "Oscalar");
is($a, "087");
is($b, "89");
is(ref $a, "Oscalar");
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

eval q[package Oscalar; use overload ('+=' => sub {$ {$_[0]} += 3*$_[1];
						   $_[0] } ) ];
$c=new Oscalar;			# Cause rehash

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
       use overload ('x' => sub {new Oscalar ( $_[2] ? "_.$_[1]._" x $ {$_[0]}
					      : "_.${$_[0]}._" x $_[1])}) ];

$a=new Oscalar "yy";
$a x= 3;
is($a, "_.yy.__.yy.__.yy._");

eval q[package Oscalar; 
       use overload ('.' => sub {new Oscalar ( $_[2] ? 
					      "_.$_[1].__.$ {$_[0]}._"
					      : "_.$ {$_[0]}.__.$_[1]._")}) ];

$a=new Oscalar "xx";

is("b${a}c", "_._.b.__.xx._.__.c._");

# Check inheritance of overloading;
{
  package OscalarI;
  @ISA = 'Oscalar';
}

$aI = new OscalarI "$a";
is(ref $aI, "OscalarI");
is("$aI", "xx");
is($aI, "xx");
is("b${aI}c", "_._.b.__.xx._.__.c._");

# Here we test blessing to a package updates hash

eval "package Oscalar; no overload '.'";

is("b${a}", "_.b.__.xx._");
$x="1";
bless \$x, Oscalar;
is("b${a}c", "bxxc");
new Oscalar 1;
is("b${a}c", "bxxc");

# Negative overloading:

$na = eval { ~$a };
like($@, qr/no method found/);

# Check AUTOLOADING:

*Oscalar::AUTOLOAD = 
  sub { *{"Oscalar::$AUTOLOAD"} = sub {"_!_" . shift() . "_!_"} ;
	goto &{"Oscalar::$AUTOLOAD"}};

eval "package Oscalar; sub comple; use overload '~' => 'comple'";

$na = eval { ~$a };		# Hash was not updated
like($@, qr/no method found/);

bless \$x, Oscalar;

$na = eval { ~$a };		# Hash updated
warn "`$na', $@" if $@;
ok !$@;
is($na, '_!_xx_!_');

$na = 0;

$na = eval { ~$aI };		# Hash was not updated
like($@, qr/no method found/);

bless \$x, OscalarI;

$na = eval { ~$aI };
print $@;

ok(!$@);
is($na, '_!_xx_!_');

eval "package Oscalar; sub rshft; use overload '>>' => 'rshft'";

$na = eval { $aI >> 1 };	# Hash was not updated
like($@, qr/no method found/);

bless \$x, OscalarI;

$na = 0;

$na = eval { $aI >> 1 };
print $@;

ok(!$@);
is($na, '_!_xx_!_');

# warn overload::Method($a, '0+'), "\n";
is(overload::Method($a, '0+'), \&Oscalar::numify);
is(overload::Method($aI,'0+'), \&Oscalar::numify);
ok(overload::Overloaded($aI));
ok(!overload::Overloaded('overload'));

ok(! defined overload::Method($aI, '<<'));
ok(! defined overload::Method($a, '<'));

like (overload::StrVal($aI), qr/^OscalarI=SCALAR\(0x[\da-fA-F]+\)$/);
is(overload::StrVal(\$aI), "@{[\$aI]}");

# Check overloading by methods (specified deep in the ISA tree).
{
  package OscalarII;
  @ISA = 'OscalarI';
  sub Oscalar::lshft {"_<<_" . shift() . "_<<_"}
  eval "package OscalarI; use overload '<<' => 'lshft', '|' => 'lshft'";
}

$aaII = "087";
$aII = \$aaII;
bless $aII, 'OscalarII';
bless \$fake, 'OscalarI';		# update the hash
is(($aI | 3), '_<<_xx_<<_');
# warn $aII << 3;
is(($aII << 3), '_<<_087_<<_');

{
  BEGIN { $int = 7; overload::constant 'integer' => sub {$int++; shift}; }
  $out = 2**10;
}
is($int, 9);
is($out, 1024);

$foo = 'foo';
$foo1 = 'f\'o\\o';
{
  BEGIN { $q = $qr = 7; 
	  overload::constant 'q' => sub {$q++; push @q, shift, ($_[1] || 'none'); shift},
			     'qr' => sub {$qr++; push @qr, shift, ($_[1] || 'none'); shift}; }
  $out = 'foo';
  $out1 = 'f\'o\\o';
  $out2 = "a\a$foo,\,";
  /b\b$foo.\./;
}

is($out, 'foo');
is($out, $foo);
is($out1, 'f\'o\\o');
is($out1, $foo1);
is($out2, "a\afoo,\,");
is("@q", "foo q f'o\\\\o q a\\a qq ,\\, qq");
is($q, 11);
is("@qr", "b\\b qq .\\. qq");
is($qr, 9);

{
  $_ = '!<b>!foo!<-.>!';
  BEGIN { overload::constant 'q' => sub {push @q1, shift, ($_[1] || 'none'); "_<" . (shift) . ">_"},
			     'qr' => sub {push @qr1, shift, ($_[1] || 'none'); "!<" . (shift) . ">!"}; }
  $out = 'foo';
  $out1 = 'f\'o\\o';
  $out2 = "a\a$foo,\,";
  $res = /b\b$foo.\./;
  $a = <<EOF;
oups
EOF
  $b = <<'EOF';
oups1
EOF
  $c = bareword;
  m'try it';
  s'first part'second part';
  s/yet another/tail here/;
  tr/A-Z/a-z/;
}

is($out, '_<foo>_');
is($out1, '_<f\'o\\o>_');
is($out2, "_<a\a>_foo_<,\,>_");
is("@q1", "foo q f'o\\\\o q a\\a qq ,\\, qq oups
 qq oups1
 q second part q tail here s A-Z tr a-z tr");
is("@qr1", "b\\b qq .\\. qq try it q first part q yet another qq");
is($res, 1);
is($a, "_<oups
>_");
is($b, "_<oups1
>_");
is($c, "bareword");

{
  package symbolic;		# Primitive symbolic calculator
  use overload nomethod => \&wrap, '""' => \&str, '0+' => \&num,
      '=' => \&cpy, '++' => \&inc, '--' => \&dec;

  sub new { shift; bless ['n', @_] }
  sub cpy {
    my $self = shift;
    bless [@$self], ref $self;
  }
  sub inc { $_[0] = bless ['++', $_[0], 1]; }
  sub dec { $_[0] = bless ['--', $_[0], 1]; }
  sub wrap {
    my ($obj, $other, $inv, $meth) = @_;
    if ($meth eq '++' or $meth eq '--') {
      @$obj = ($meth, (bless [@$obj]), 1); # Avoid circular reference
      return $obj;
    }
    ($obj, $other) = ($other, $obj) if $inv;
    bless [$meth, $obj, $other];
  }
  sub str {
    my ($meth, $a, $b) = @{+shift};
    $a = 'u' unless defined $a;
    if (defined $b) {
      "[$meth $a $b]";
    } else {
      "[$meth $a]";
    }
  } 
  my %subr = ( 'n' => sub {$_[0]} );
  foreach my $op (split " ", $overload::ops{with_assign}) {
    $subr{$op} = $subr{"$op="} = eval "sub {shift() $op shift()}";
  }
  my @bins = qw(binary 3way_comparison num_comparison str_comparison);
  foreach my $op (split " ", "@overload::ops{ @bins }") {
    $subr{$op} = eval "sub {shift() $op shift()}";
  }
  foreach my $op (split " ", "@overload::ops{qw(unary func)}") {
    $subr{$op} = eval "sub {$op shift()}";
  }
  $subr{'++'} = $subr{'+'};
  $subr{'--'} = $subr{'-'};
  
  sub num {
    my ($meth, $a, $b) = @{+shift};
    my $subr = $subr{$meth} 
      or die "Do not know how to ($meth) in symbolic";
    $a = $a->num if ref $a eq __PACKAGE__;
    $b = $b->num if ref $b eq __PACKAGE__;
    $subr->($a,$b);
  }
  sub TIESCALAR { my $pack = shift; $pack->new(@_) }
  sub FETCH { shift }
  sub nop {  }		# Around a bug
  sub vars { my $p = shift; tie($_, $p), $_->nop foreach @_; }
  sub STORE { 
    my $obj = shift; 
    $#$obj = 1; 
    $obj->[1] = shift;
  }
}

{
  my $foo = new symbolic 11;
  my $baz = $foo++;
  is((sprintf "%d", $foo), '12');
  is((sprintf "%d", $baz), '11');
  my $bar = $foo;
  $baz = ++$foo;
  is((sprintf "%d", $foo), '13');
  is((sprintf "%d", $bar), '12');
  is((sprintf "%d", $baz), '13');
  my $ban = $foo;
  $baz = ($foo += 1);
  is((sprintf "%d", $foo), '14');
  is((sprintf "%d", $bar), '12');
  is((sprintf "%d", $baz), '14');
  is((sprintf "%d", $ban), '13');
  $baz = 0;
  $baz = $foo++;
  is((sprintf "%d", $foo), '15');
  is((sprintf "%d", $baz), '14');
  is("$foo", '[++ [+= [++ [++ [n 11] 1] 1] 1] 1]');
}

{
  my $iter = new symbolic 2;
  my $side = new symbolic 1;
  my $cnt = $iter;
  
  while ($cnt) {
    $cnt = $cnt - 1;		# The "simple" way
    $side = (sqrt(1 + $side**2) - 1)/$side;
  }
  my $pi = $side*(2**($iter+2));
  is("$side", '[/ [- [sqrt [+ 1 [** [/ [- [sqrt [+ 1 [** [n 1] 2]]] 1] [n 1]] 2]]] 1] [/ [- [sqrt [+ 1 [** [n 1] 2]]] 1] [n 1]]]');
  is((sprintf "%f", $pi), '3.182598');
}

{
  my $iter = new symbolic 2;
  my $side = new symbolic 1;
  my $cnt = $iter;
  
  while ($cnt--) {
    $side = (sqrt(1 + $side**2) - 1)/$side;
  }
  my $pi = $side*(2**($iter+2));
  is("$side", '[/ [- [sqrt [+ 1 [** [/ [- [sqrt [+ 1 [** [n 1] 2]]] 1] [n 1]] 2]]] 1] [/ [- [sqrt [+ 1 [** [n 1] 2]]] 1] [n 1]]]');
  is((sprintf "%f", $pi), '3.182598');
}

{
  my ($a, $b);
  symbolic->vars($a, $b);
  my $c = sqrt($a**2 + $b**2);
  $a = 3; $b = 4;
  is((sprintf "%d", $c), '5');
  $a = 12; $b = 5;
  is((sprintf "%d", $c), '13');
}

{
  package symbolic1;		# Primitive symbolic calculator
  # Mutator inc/dec
  use overload nomethod => \&wrap, '""' => \&str, '0+' => \&num, '=' => \&cpy;

  sub new { shift; bless ['n', @_] }
  sub cpy {
    my $self = shift;
    bless [@$self], ref $self;
  }
  sub wrap {
    my ($obj, $other, $inv, $meth) = @_;
    if ($meth eq '++' or $meth eq '--') {
      @$obj = ($meth, (bless [@$obj]), 1); # Avoid circular reference
      return $obj;
    }
    ($obj, $other) = ($other, $obj) if $inv;
    bless [$meth, $obj, $other];
  }
  sub str {
    my ($meth, $a, $b) = @{+shift};
    $a = 'u' unless defined $a;
    if (defined $b) {
      "[$meth $a $b]";
    } else {
      "[$meth $a]";
    }
  } 
  my %subr = ( 'n' => sub {$_[0]} );
  foreach my $op (split " ", $overload::ops{with_assign}) {
    $subr{$op} = $subr{"$op="} = eval "sub {shift() $op shift()}";
  }
  my @bins = qw(binary 3way_comparison num_comparison str_comparison);
  foreach my $op (split " ", "@overload::ops{ @bins }") {
    $subr{$op} = eval "sub {shift() $op shift()}";
  }
  foreach my $op (split " ", "@overload::ops{qw(unary func)}") {
    $subr{$op} = eval "sub {$op shift()}";
  }
  $subr{'++'} = $subr{'+'};
  $subr{'--'} = $subr{'-'};
  
  sub num {
    my ($meth, $a, $b) = @{+shift};
    my $subr = $subr{$meth} 
      or die "Do not know how to ($meth) in symbolic";
    $a = $a->num if ref $a eq __PACKAGE__;
    $b = $b->num if ref $b eq __PACKAGE__;
    $subr->($a,$b);
  }
  sub TIESCALAR { my $pack = shift; $pack->new(@_) }
  sub FETCH { shift }
  sub nop {  }		# Around a bug
  sub vars { my $p = shift; tie($_, $p), $_->nop foreach @_; }
  sub STORE { 
    my $obj = shift; 
    $#$obj = 1; 
    $obj->[1] = shift;
  }
}

{
  my $foo = new symbolic1 11;
  my $baz = $foo++;
  is((sprintf "%d", $foo), '12');
  is((sprintf "%d", $baz), '11');
  my $bar = $foo;
  $baz = ++$foo;
  is((sprintf "%d", $foo), '13');
  is((sprintf "%d", $bar), '12');
  is((sprintf "%d", $baz), '13');
  my $ban = $foo;
  $baz = ($foo += 1);
  is((sprintf "%d", $foo), '14');
  is((sprintf "%d", $bar), '12');
  is((sprintf "%d", $baz), '14');
  is((sprintf "%d", $ban), '13');
  $baz = 0;
  $baz = $foo++;
  is((sprintf "%d", $foo), '15');
  is((sprintf "%d", $baz), '14');
  is("$foo", '[++ [+= [++ [++ [n 11] 1] 1] 1] 1]');
}

{
  my $iter = new symbolic1 2;
  my $side = new symbolic1 1;
  my $cnt = $iter;
  
  while ($cnt) {
    $cnt = $cnt - 1;		# The "simple" way
    $side = (sqrt(1 + $side**2) - 1)/$side;
  }
  my $pi = $side*(2**($iter+2));
  is("$side", '[/ [- [sqrt [+ 1 [** [/ [- [sqrt [+ 1 [** [n 1] 2]]] 1] [n 1]] 2]]] 1] [/ [- [sqrt [+ 1 [** [n 1] 2]]] 1] [n 1]]]');
  is((sprintf "%f", $pi), '3.182598');
}

{
  my $iter = new symbolic1 2;
  my $side = new symbolic1 1;
  my $cnt = $iter;
  
  while ($cnt--) {
    $side = (sqrt(1 + $side**2) - 1)/$side;
  }
  my $pi = $side*(2**($iter+2));
  is("$side", '[/ [- [sqrt [+ 1 [** [/ [- [sqrt [+ 1 [** [n 1] 2]]] 1] [n 1]] 2]]] 1] [/ [- [sqrt [+ 1 [** [n 1] 2]]] 1] [n 1]]]');
  is((sprintf "%f", $pi), '3.182598');
}

{
  my ($a, $b);
  symbolic1->vars($a, $b);
  my $c = sqrt($a**2 + $b**2);
  $a = 3; $b = 4;
  is((sprintf "%d", $c), '5');
  $a = 12; $b = 5;
  is((sprintf "%d", $c), '13');
}

{
  package two_face;		# Scalars with separate string and
                                # numeric values.
  sub new { my $p = shift; bless [@_], $p }
  use overload '""' => \&str, '0+' => \&num, fallback => 1;
  sub num {shift->[1]}
  sub str {shift->[0]}
}

{
  my $seven = new two_face ("vii", 7);
  is((sprintf "seven=$seven, seven=%d, eight=%d", $seven, $seven+1),
	'seven=vii, seven=7, eight=8');
  is(scalar ($seven =~ /i/), '1');
}

{
  package sorting;
  use overload 'cmp' => \&comp;
  sub new { my ($p, $v) = @_; bless \$v, $p }
  sub comp { my ($x,$y) = @_; ($$x * 3 % 10) <=> ($$y * 3 % 10) or $$x cmp $$y }
}
{
  my @arr = map sorting->new($_), 0..12;
  my @sorted1 = sort @arr;
  my @sorted2 = map $$_, @sorted1;
  is("@sorted2", '0 10 7 4 1 11 8 5 12 2 9 6 3');
}
{
  package iterator;
  use overload '<>' => \&iter;
  sub new { my ($p, $v) = @_; bless \$v, $p }
  sub iter { my ($x) = @_; return undef if $$x < 0; return $$x--; }
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
  $acc .= " $out" while $out = <${iter}>;
  is($acc, ' 5 4 3 2 1 0');
  $iter = iterator->new(5);
  is(scalar <${iter}>, '5');
  $acc = '';
  $acc .= " $out" while $out = <$iter>;
  is($acc, ' 4 3 2 1 0');
}
{
  package deref;
  use overload '%{}' => \&hderef, '&{}' => \&cderef, 
    '*{}' => \&gderef, '${}' => \&sderef, '@{}' => \&aderef;
  sub new { my ($p, $v) = @_; bless \$v, $p }
  sub deref {
    my ($self, $key) = (shift, shift);
    my $class = ref $self;
    bless $self, 'deref::dummy'; # Disable overloading of %{} 
    my $out = $self->{$key};
    bless $self, $class;	# Restore overloading
    $out;
  }
  sub hderef {shift->deref('h')}
  sub aderef {shift->deref('a')}
  sub cderef {shift->deref('c')}
  sub gderef {shift->deref('g')}
  sub sderef {shift->deref('s')}
}
{
  my $deref = bless { h => { foo => 5 , fake => 23 },
		      c => sub {return shift() + 34},
		      's' => \123,
		      a => [11..13],
		      g => \*srt,
		    }, 'deref';
  # Hash:
  my @cont = sort %$deref;
  if ("\t" eq "\011") { # ascii
      is("@cont", '23 5 fake foo');
  } 
  else {                # ebcdic alpha-numeric sort order
      is("@cont", 'fake foo 23 5');
  }
  my @keys = sort keys %$deref;
  is("@keys", 'fake foo');
  my @val = sort values %$deref;
  is("@val", '23 5');
  is($deref->{foo}, 5);
  is(defined $deref->{bar}, '');
  my $key;
  @keys = ();
  push @keys, $key while $key = each %$deref;
  @keys = sort @keys;
  is("@keys", 'fake foo');
  is(exists $deref->{bar}, '');
  is(exists $deref->{foo}, 1);
  # Code:
  is($deref->(5), 39);
  is(&$deref(6), 40);
  sub xxx_goto { goto &$deref }
  is(xxx_goto(7), 41);
  my $srt = bless { c => sub {$b <=> $a}
		  }, 'deref';
  *srt = \&$srt;
  my @sorted = sort srt 11, 2, 5, 1, 22;
  is("@sorted", '22 11 5 2 1');
  # Scalar
  is($$deref, 123);
  # Code
  @sorted = sort $srt 11, 2, 5, 1, 22;
  is("@sorted", '22 11 5 2 1');
  # Array
  is("@$deref", '11 12 13');
  is($#$deref, '2');
  my $l = @$deref;
  is($l, 3);
  is($deref->[2], '13');
  $l = pop @$deref;
  is($l, 13);
  $l = 1;
  is($deref->[$l], '12');
  # Repeated dereference
  my $double = bless { h => $deref,
		     }, 'deref';
  is($double->{foo}, 5);
}

{
  package two_refs;
  use overload '%{}' => \&gethash, '@{}' => sub { ${shift()} };
  sub new { 
    my $p = shift; 
    bless \ [@_], $p;
  }
  sub gethash {
    my %h;
    my $self = shift;
    tie %h, ref $self, $self;
    \%h;
  }

  sub TIEHASH { my $p = shift; bless \ shift, $p }
  my %fields;
  my $i = 0;
  $fields{$_} = $i++ foreach qw{zero one two three};
  sub STORE { 
    my $self = ${shift()};
    my $key = $fields{shift()};
    defined $key or die "Out of band access";
    $$self->[$key] = shift;
  }
  sub FETCH { 
    my $self = ${shift()};
    my $key = $fields{shift()};
    defined $key or die "Out of band access";
    $$self->[$key];
  }
}

my $bar = new two_refs 3,4,5,6;
$bar->[2] = 11;
is($bar->{two}, 11);
$bar->{three} = 13;
is($bar->[3], 13);

{
  package two_refs_o;
  @ISA = ('two_refs');
}

$bar = new two_refs_o 3,4,5,6;
$bar->[2] = 11;
is($bar->{two}, 11);
$bar->{three} = 13;
is($bar->[3], 13);

{
  package two_refs1;
  use overload '%{}' => sub { ${shift()}->[1] },
               '@{}' => sub { ${shift()}->[0] };
  sub new { 
    my $p = shift; 
    my $a = [@_];
    my %h;
    tie %h, $p, $a;
    bless \ [$a, \%h], $p;
  }
  sub gethash {
    my %h;
    my $self = shift;
    tie %h, ref $self, $self;
    \%h;
  }

  sub TIEHASH { my $p = shift; bless \ shift, $p }
  my %fields;
  my $i = 0;
  $fields{$_} = $i++ foreach qw{zero one two three};
  sub STORE { 
    my $a = ${shift()};
    my $key = $fields{shift()};
    defined $key or die "Out of band access";
    $a->[$key] = shift;
  }
  sub FETCH { 
    my $a = ${shift()};
    my $key = $fields{shift()};
    defined $key or die "Out of band access";
    $a->[$key];
  }
}

$bar = new two_refs_o 3,4,5,6;
$bar->[2] = 11;
is($bar->{two}, 11);
$bar->{three} = 13;
is($bar->[3], 13);

{
  package two_refs1_o;
  @ISA = ('two_refs1');
}

$bar = new two_refs1_o 3,4,5,6;
$bar->[2] = 11;
is($bar->{two}, 11);
$bar->{three} = 13;
is($bar->[3], 13);

{
  package B;
  use overload bool => sub { ${+shift} };
}

my $aaa;
{ my $bbbb = 0; $aaa = bless \$bbbb, B }

is !$aaa, 1;

unless ($aaa) {
  pass();
} else {
  fail();
}

# check that overload isn't done twice by join
{ my $c = 0;
  package Join;
  use overload '""' => sub { $c++ };
  my $x = join '', bless([]), 'pq', bless([]);
  main::is $x, '0pq1';
};

# Test module-specific warning
{
    # check the Odd number of arguments for overload::constant warning
    my $a = "" ;
    local $SIG{__WARN__} = sub {$a = $_[0]} ;
    $x = eval ' overload::constant "integer" ; ' ;
    is($a, "");
    use warnings 'overload' ;
    $x = eval ' overload::constant "integer" ; ' ;
    like($a, qr/^Odd number of arguments for overload::constant at/);
}

{
    # check the `$_[0]' is not an overloadable type warning
    my $a = "" ;
    local $SIG{__WARN__} = sub {$a = $_[0]} ;
    $x = eval ' overload::constant "fred" => sub {} ; ' ;
    is($a, "");
    use warnings 'overload' ;
    $x = eval ' overload::constant "fred" => sub {} ; ' ;
    like($a, qr/^`fred' is not an overloadable type at/);
}

{
    # check the `$_[1]' is not a code reference warning
    my $a = "" ;
    local $SIG{__WARN__} = sub {$a = $_[0]} ;
    $x = eval ' overload::constant "integer" => 1; ' ;
    is($a, "");
    use warnings 'overload' ;
    $x = eval ' overload::constant "integer" => 1; ' ;
    like($a, qr/^`1' is not a code reference at/);
}

{
  my $c = 0;
  package ov_int1;
  use overload '""'    => sub { 3+shift->[0] },
               '0+'    => sub { 10+shift->[0] },
               'int'   => sub { 100+shift->[0] };
  sub new {my $p = shift; bless [shift], $p}

  package ov_int2;
  use overload '""'    => sub { 5+shift->[0] },
               '0+'    => sub { 30+shift->[0] },
               'int'   => sub { 'ov_int1'->new(1000+shift->[0]) };
  sub new {my $p = shift; bless [shift], $p}

  package noov_int;
  use overload '""'    => sub { 2+shift->[0] },
               '0+'    => sub { 9+shift->[0] };
  sub new {my $p = shift; bless [shift], $p}

  package main;

  my $x = new noov_int 11;
  my $int_x = int $x;
  main::is("$int_x", 20);
  $x = new ov_int1 31;
  $int_x = int $x;
  main::is("$int_x", 131);
  $x = new ov_int2 51;
  $int_x = int $x;
  main::is("$int_x", 1054);
}

# make sure that we don't inifinitely recurse
{
  my $c = 0;
  package Recurse;
  use overload '""'    => sub { shift },
               '0+'    => sub { shift },
               'bool'  => sub { shift },
               fallback => 1;
  my $x = bless([]);
  # For some reason beyond me these have to be oks rather than likes.
  main::ok("$x" =~ /Recurse=ARRAY/);
  main::ok($x);
  main::ok($x+0 =~ qr/Recurse=ARRAY/);
}

# BugID 20010422.003
package Foo;

use overload
  'bool' => sub { return !$_[0]->is_zero() || undef; }
;
 
sub is_zero
  {
  my $self = shift;
  return $self->{var} == 0;
  }

sub new
  {
  my $class = shift;
  my $self =  {};
  $self->{var} = shift;
  bless $self,$class;
  }

package main;

use strict;

my $r = Foo->new(8);
$r = Foo->new(0);

is(($r || 0), 0);

package utf8_o;

use overload 
  '""'  =>  sub { return $_[0]->{var}; }
  ;
  
sub new
  {
    my $class = shift;
    my $self =  {};
    $self->{var} = shift;
    bless $self,$class;
  }

package main;


my $utfvar = new utf8_o 200.2.1;
is("$utfvar", 200.2.1); # 223 - stringify
is("a$utfvar", "a".200.2.1); # 224 - overload via sv_2pv_flags

# 225..227 -- more %{} tests.  Hangs in 5.6.0, okay in later releases.
# Basically this example implements strong encapsulation: if Hderef::import()
# were to eval the overload code in the caller's namespace, the privatisation
# would be quite transparent.
package Hderef;
use overload '%{}' => sub { (caller(0))[0] eq 'Foo' ? $_[0] : die "zap" };
package Foo;
@Foo::ISA = 'Hderef';
sub new { bless {}, shift }
sub xet { @_ == 2 ? $_[0]->{$_[1]} :
	  @_ == 3 ? ($_[0]->{$_[1]} = $_[2]) : undef }
package main;
my $a = Foo->new;
$a->xet('b', 42);
is ($a->xet('b'), 42);
ok (!defined eval { $a->{b} });
like ($@, qr/zap/);

{
   package t229;
   use overload '='  => sub { 42 },
                '++' => sub { my $x = ${$_[0]}; $_[0] };
   sub new { my $x = 42; bless \$x }

   my $warn;
   {  
     local $SIG{__WARN__} = sub { $warn++ };
      my $x = t229->new;
      my $y = $x;
      eval { $y++ };
   }
   main::ok (!$warn);
}

{
    my ($int, $out1, $out2);
    {
        BEGIN { $int = 0; overload::constant 'integer' => sub {$int++; 17}; }
        $out1 = 0;
        $out2 = 1;
    }
    is($int,  2,  "#24313");	# 230
    is($out1, 17, "#24313");	# 231
    is($out2, 17, "#24313");	# 232
}

{
    package Numify;
    use overload (qw(0+ numify fallback 1));

    sub new {
	my $val = $_[1];
	bless \$val, $_[0];
    }

    sub numify { ${$_[0]} }
}

{
    package perl31793;
    use overload cmp => sub { 0 };
    package perl31793_fb;
    use overload cmp => sub { 0 }, fallback => 1;
    package main;
    my $o  = bless [], 'perl31793';
    my $of = bless [], 'perl31793_fb';
    my $no = bless [], 'no_overload';
    like(overload::StrVal(\"scalar"), qr/^SCALAR\(0x[0-9a-f]+\)$/);
    like(overload::StrVal([]),        qr/^ARRAY\(0x[0-9a-f]+\)$/);
    like(overload::StrVal({}),        qr/^HASH\(0x[0-9a-f]+\)$/);
    like(overload::StrVal(sub{1}),    qr/^CODE\(0x[0-9a-f]+\)$/);
    like(overload::StrVal(\*GLOB),    qr/^GLOB\(0x[0-9a-f]+\)$/);
    like(overload::StrVal(\$o),       qr/^REF\(0x[0-9a-f]+\)$/);
    like(overload::StrVal(qr/a/),     qr/^Regexp=SCALAR\(0x[0-9a-f]+\)$/);
    like(overload::StrVal($o),        qr/^perl31793=ARRAY\(0x[0-9a-f]+\)$/);
    like(overload::StrVal($of),       qr/^perl31793_fb=ARRAY\(0x[0-9a-f]+\)$/);
    like(overload::StrVal($no),       qr/^no_overload=ARRAY\(0x[0-9a-f]+\)$/);
}

# These are all check that overloaded values rather than reference addressess
# are what is getting tested.
my ($two, $one, $un, $deux) = map {new Numify $_} 2, 1, 1, 2;
my ($ein, $zwei) = (1, 2);

my %map = (one => 1, un => 1, ein => 1, deux => 2, two => 2, zwei => 2);
foreach my $op (qw(<=> == != < <= > >=)) {
    foreach my $l (keys %map) {
	foreach my $r (keys %map) {
	    my $ocode = "\$$l $op \$$r";
	    my $rcode = "$map{$l} $op $map{$r}";

	    my $got = eval $ocode;
	    die if $@;
	    my $expect = eval $rcode;
	    die if $@;
	    is ($got, $expect, $ocode) or print "# $rcode\n";
	}
    }
}
{
    # check that overloading works in regexes
    {
	package Foo493;
	use overload
	    '""' => sub { "^$_[0][0]\$" },
	    '.'  => sub { 
		    bless [
			     $_[2]
			    ? (ref $_[1] ? $_[1][0] : $_[1]) . ':' .$_[0][0] 
			    : $_[0][0] . ':' . (ref $_[1] ? $_[1][0] : $_[1])
		    ], 'Foo493'
			};
    }

    my $a = bless [ "a" ], 'Foo493';
    like('a', qr/$a/);
    like('x:a', qr/x$a/);
    like('x:a:=', qr/x$a=$/);
    like('x:a:a:=', qr/x$a$a=$/);

}

{
    my $twenty_three = 23;
    # Check that constant overloading propagates into evals
    BEGIN { overload::constant integer => sub { 23 } }
    is(eval "17", $twenty_three);
}

{
    package Sklorsh;
    use overload
	bool     => sub { shift->is_cool };

    sub is_cool {
	$_[0]->{name} eq 'cool';
    }

    sub delete {
	undef %{$_[0]};
	bless $_[0], 'Brap';
	return 1;
    }

    sub delete_with_self {
	my $self = shift;
	undef %$self;
	bless $self, 'Brap';
	return 1;
    }

    package Brap;

    1;

    package main;

    my $obj;
    $obj = bless {name => 'cool'}, 'Sklorsh';
    $obj->delete;
    ok(eval {if ($obj) {1}; 1}, $@ || 'reblessed into nonexist namespace');

    $obj = bless {name => 'cool'}, 'Sklorsh';
    $obj->delete_with_self;
    ok (eval {if ($obj) {1}; 1}, $@);
    
    my $a = $b = {name => 'hot'};
    bless $b, 'Sklorsh';
    is(ref $a, 'Sklorsh');
    is(ref $b, 'Sklorsh');
    ok(!$b, "Expect overloaded boolean");
    ok(!$a, "Expect overloaded boolean");
}
