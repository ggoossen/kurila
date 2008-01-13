
BEGIN {
    unless ("A" eq pack('U', 0x41)) {
	print "1..0 # Unicode::Collate " .
	    "cannot stringify a Unicode code point\n";
	exit 0;
    }
    if ($ENV{PERL_CORE}) {
	chdir('t') if -d 't';
	@INC = $^O eq 'MacOS' ? qw(::lib) : qw(../lib);
    }
}

use Test::More;
BEGIN { plan tests => 101 };

use strict;
use warnings;
use Unicode::Collate;

ok(1);

sub _pack_U   { Unicode::Collate::pack_U(@_) }
sub _unpack_U { Unicode::Collate::unpack_U(@_) }

my $A_acute = _pack_U(0xC1);
my $a_acute = _pack_U(0xE1);
my $acute   = _pack_U(0x0301);

my $hiragana = "\x{3042}\x{3044}";
my $katakana = "\x{30A2}\x{30A4}";

##### 2..7

my $Collator = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
);

is(ref $Collator, "Unicode::Collate");

is($Collator->cmp("", ""), 0);
ok($Collator->eq("", ""));
is($Collator->cmp("", "perl"), -1);

is(
  join(':', $Collator->sort( qw/ acha aca ada acia acka / ) ),
  join(':',                  qw/ aca acha acia acka ada / ),
);

is(
  join(':', $Collator->sort( qw/ ACHA ACA ADA ACIA ACKA / ) ),
  join(':',                  qw/ ACA ACHA ACIA ACKA ADA / ),
);

##### 8..18

is($Collator->cmp("A$acute", $A_acute), 0); # @version 3.1.1 (prev: -1)
is($Collator->cmp($a_acute, $A_acute), -1);
ok($Collator->eq("A\cA$acute", $A_acute)); # UCA v9. \cA is invariant.

my %old_level = $Collator->change(level => 1);
ok($Collator->eq("A$acute", $A_acute));
ok($Collator->eq("A", $A_acute));

ok($Collator->change(level => 2)->eq($a_acute, $A_acute));
is($Collator->cmp("A", $A_acute), -1);

is($Collator->change(%old_level)->cmp("A", $A_acute), -1);
is($Collator->cmp("A", $A_acute), -1);
is($Collator->cmp("A", $a_acute), -1);
is($Collator->cmp($a_acute, $A_acute), -1);

##### 19..25

$Collator->change(level => 2);

is($Collator->{level}, 2);

is( $Collator->cmp("ABC","abc"), 0);
ok( $Collator->eq("ABC","abc") );
is( $Collator->cmp($hiragana, $katakana), 0);
ok( $Collator->eq($hiragana, $katakana) );

##### 26..31

# hangul
ok( $Collator->eq("a\x{AC00}b", "a\x{1100}\x{1161}b") );
ok( $Collator->eq("a\x{AE00}b", "a\x{1100}\x{1173}\x{11AF}b") );
is( $Collator->cmp("a\x{AE00}b", "a\x{1100}\x{1173}b\x{11AF}"), 1 );
is( $Collator->cmp("a\x{AC00}b", "a\x{AE00}b"), -1 );
is( $Collator->cmp("a\x{D7A3}b", "a\x{C544}b"), 1 );
is( $Collator->cmp("a\x{C544}b", "a\x{30A2}b"), -1 ); # hangul < hiragana

##### 32..40

$Collator->change(%old_level, katakana_before_hiragana => 1);

is($Collator->{level}, 4);

is( $Collator->cmp("abc", "ABC"), -1);
ok( $Collator->ne("abc", "ABC") );
is( $Collator->cmp($hiragana, $katakana), 1);
ok( $Collator->ne($hiragana, $katakana) );

##### 41..46

$Collator->change(upper_before_lower => 1);

is( $Collator->cmp("abc", "ABC"), 1);
is( $Collator->cmp($hiragana, $katakana), 1);

##### 47..48

$Collator->change(katakana_before_hiragana => 0);

is( $Collator->cmp("abc", "ABC"), 1);
is( $Collator->cmp($hiragana, $katakana), -1);

##### 49..52

$Collator->change(upper_before_lower => 0);

is( $Collator->cmp("abc", "ABC"), -1);
is( $Collator->cmp($hiragana, $katakana), -1);

##### 53..54

my $ignoreAE = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
  ignoreChar => qr/^[aAeE]$/,
);

ok($ignoreAE->eq("element","lament"));
ok($ignoreAE->eq("Perl","ePrl"));

##### 55

my $onlyABC = Unicode::Collate->new(
    table => undef,
    normalization => undef,
    entry => << 'ENTRIES',
0061 ; [.0101.0020.0002.0061] # LATIN SMALL LETTER A
0041 ; [.0101.0020.0008.0041] # LATIN CAPITAL LETTER A
0062 ; [.0102.0020.0002.0062] # LATIN SMALL LETTER B
0042 ; [.0102.0020.0008.0042] # LATIN CAPITAL LETTER B
0063 ; [.0103.0020.0002.0063] # LATIN SMALL LETTER C
0043 ; [.0103.0020.0008.0043] # LATIN CAPITAL LETTER C
ENTRIES
);

ok(
  join(':', $onlyABC->sort( qw/ ABA BAC cc A Ab cAc aB / ) ),
  join(':',                 qw/ A aB Ab ABA BAC cAc cc / ),
);

##### 56..59

my $undefAE = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
  undefChar => qr/^[aAeE]$/,
);

is($undefAE ->cmp("edge","fog"), 1);
is($Collator->cmp("edge","fog"), -1);
is($undefAE ->cmp("lake","like"), 1);
is($Collator->cmp("lake","like"), -1);

##### 60..69

# Table is undefined, then no entry is defined.

my $undef_table = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  level => 1,
);

# in the Unicode code point order
is($undef_table->cmp('', 'A'), -1);
is($undef_table->cmp('ABC', 'B'), -1);

# Hangul should be decomposed (even w/o Unicode::Normalize).
is($undef_table->cmp("Perl", "\x{AC00}"), -1);
ok($undef_table->eq("\x{AC00}", "\x{1100}\x{1161}"));
ok($undef_table->eq("\x{AE00}", "\x{1100}\x{1173}\x{11AF}"));
is($undef_table->cmp("\x{AE00}", "\x{3042}"), -1);
  # U+AC00: Hangul GA
  # U+AE00: Hangul GEUL
  # U+3042: Hiragana A

# Weight for CJK Ideographs is defined, though.
is($undef_table->cmp("", "\x{4E00}"), -1);
is($undef_table->cmp("\x{4E8C}","ABC"), -1);
is($undef_table->cmp("\x{4E00}","\x{3042}"), -1);
is($undef_table->cmp("\x{4E00}","\x{4E8C}"), -1);
  # U+4E00: Ideograph "ONE"
  # U+4E8C: Ideograph "TWO"


##### 70..74

my $few_entries = Unicode::Collate->new(
  entry => <<'ENTRIES',
0050 ; [.0101.0020.0002.0050]  # P
0045 ; [.0102.0020.0002.0045]  # E
0052 ; [.0103.0020.0002.0052]  # R
004C ; [.0104.0020.0002.004C]  # L
1100 ; [.0105.0020.0002.1100]  # Hangul Jamo initial G
1175 ; [.0106.0020.0002.1175]  # Hangul Jamo middle I
5B57 ; [.0107.0020.0002.5B57]  # CJK Ideograph "Letter"
ENTRIES
  table => undef,
  normalization => undef,
);

# defined before undefined

my $sortABC = join '',
    $few_entries->sort(split m//, "ABCDEFGHIJKLMNOPQRSTUVWXYZ ");

ok($sortABC eq "PERL ABCDFGHIJKMNOQSTUVWXYZ");

is($few_entries->cmp('E', 'D'), -1);
is($few_entries->cmp("\x{5B57}", "\x{4E00}"), -1);
is($few_entries->cmp("\x{AE30}", "\x{AC00}"), -1);

# Hangul must be decomposed.

ok($few_entries->eq("\x{AC00}", "\x{1100}\x{1161}"));

##### 75..79

my $dropArticles = Unicode::Collate->new(
  table => "keys.txt",
  normalization => undef,
  preprocess => sub {
    my $string = shift;
    $string =~ s/\b(?:an?|the)\s+//ig;
    $string;
  },
);

ok($dropArticles->eq("camel", "a    camel"));
ok($dropArticles->eq("Perl", "The Perl"));
is($dropArticles->cmp("the pen", "a pencil"), -1);
is($Collator->cmp("Perl", "The Perl"), -1);
is($Collator->cmp("the pen", "a pencil"), 1);

##### 80..81

my $backLevel1 = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  backwards => [ 1 ],
);

# all strings are reversed at level 1.

is($backLevel1->cmp("AB", "BA"), 1);
is($backLevel1->cmp("\x{3042}\x{3044}", "\x{3044}\x{3042}"), 1);

##### 82..89

my $backLevel2 = Unicode::Collate->new(
  table => "keys.txt",
  normalization => undef,
  undefName => qr/HANGUL|HIRAGANA|KATAKANA|BOPOMOFO/,
  backwards => 2,
);

is($backLevel2->cmp("Ca\x{300}ca\x{302}", "ca\x{302}ca\x{300}"), 1);
is($backLevel2->cmp("ca\x{300}ca\x{302}", "Ca\x{302}ca\x{300}"), 1);
is($Collator  ->cmp("Ca\x{300}ca\x{302}", "ca\x{302}ca\x{300}"), -1);
is($Collator  ->cmp("ca\x{300}ca\x{302}", "Ca\x{302}ca\x{300}"), -1);

# HIRAGANA and KATAKANA are made undefined via undefName.
# So they are after CJK Unified Ideographs.

is($backLevel2->cmp("\x{4E00}", $hiragana), -1);
is($backLevel2->cmp("\x{4E03}", $katakana), -1);
is($Collator  ->cmp("\x{4E00}", $hiragana), 1);
is($Collator  ->cmp("\x{4E03}", $katakana), 1);


##### 90..96

my $O_str = Unicode::Collate->new(
  table => "keys.txt",
  normalization => undef,
  entry => <<'ENTRIES',
0008  ; [*0008.0000.0000.0000] # BACKSPACE (need to be non-ignorable)
004F 0337 ; [.0B53.0020.0008.004F] # capital O WITH SHORT SOLIDUS OVERLAY
006F 0008 002F ; [.0B53.0020.0002.006F] # LATIN SMALL LETTER O WITH STROKE
004F 0008 002F ; [.0B53.0020.0008.004F] # LATIN CAPITAL LETTER O WITH STROKE
006F 0337 ; [.0B53.0020.0002.004F] # small O WITH SHORT SOLIDUS OVERLAY
200B  ; [.2000.0000.0000.0000] # ZERO WIDTH SPACE (may be non-sense but ...)
#00F8 ; [.0B53.0020.0002.00F8] # LATIN SMALL LETTER O WITH STROKE
#00D8 ; [.0B53.0020.0008.00D8] # LATIN CAPITAL LETTER O WITH STROKE
ENTRIES
);

my $o_BS_slash = _pack_U(0x006F, 0x0008, 0x002F);
my $O_BS_slash = _pack_U(0x004F, 0x0008, 0x002F);
my $o_sol    = _pack_U(0x006F, 0x0337);
my $O_sol    = _pack_U(0x004F, 0x0337);
my $o_stroke = _pack_U(0x00F8);
my $O_stroke = _pack_U(0x00D8);

ok($O_str->eq($o_stroke, $o_BS_slash));
ok($O_str->eq($O_stroke, $O_BS_slash));

ok($O_str->eq($o_stroke, $o_sol));
ok($O_str->eq($O_stroke, $O_sol));

ok($Collator->eq("\x{200B}", "\0"));
is($O_str   ->cmp("\x{200B}", "\0"), 1);
is($O_str   ->cmp("\x{200B}", "A"), 1);

##### 97..107

my %origVer = $Collator->change(UCA_Version => 8);

$Collator->change(level => 3);

is($Collator->cmp("!\x{300}", ""), 1);
is($Collator->cmp("!\x{300}", "!"), 1);
ok($Collator->eq("!\x{300}", "\x{300}"));

$Collator->change(level => 2);

ok($Collator->eq("!\x{300}", "\x{300}"));

$Collator->change(level => 4);

is($Collator->cmp("!\x{300}", "!"), 1);
is($Collator->cmp("!\x{300}", "\x{300}"), -1);

$Collator->change(%origVer, level => 3);

ok($Collator->eq("!\x{300}", ""));
ok($Collator->eq("!\x{300}", "!"));
is($Collator->cmp("!\x{300}", "\x{300}"), -1);

$Collator->change(level => 4);

is($Collator->cmp("!\x{300}", ""), 1);
ok($Collator->eq("!\x{300}", "!"));

##### 108..113

$_ = 'Foo';

my $c = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
  upper_before_lower => 1,
);

ok($_, 'Foo'); # fixed at v. 0.52; no longer clobber $_

my($temp, @temp); # Not the result but the side effect matters.

$_ = 'Foo';
$temp = $c->getSortKey("abc");
ok($_, 'Foo');

$_ = 'Foo';
$temp = $c->viewSortKey("abc");
ok($_, 'Foo');

$_ = 'Foo';
@temp = $c->sort("abc", "xyz", "def");
ok($_, 'Foo');

$_ = 'Foo';
@temp = $c->index("perl5", "RL");
ok($_, 'Foo');

$_ = 'Foo';
@temp = $c->index("perl5", "LR");
ok($_, 'Foo');

#####

