BEGIN {
    unless ("A" eq pack('U', 0x41)) {
	print $^STDOUT, "1..0 # Unicode::Collate " .
	    "cannot stringify a Unicode code point\n";
	exit 0;
    }
    if (env::var('PERL_CORE')) {
	chdir('t') if -d 't';
	$^INCLUDE_PATH = @( $^OS_NAME eq 'MacOS' ?? < qw(::lib) !! < qw(../lib) );
    }
}

use Test::More;
BEGIN { plan tests => 76 };

use warnings;
use Unicode::Collate;

ok(1);

##### 2..6

my $all_undef_8 = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  overrideCJK => undef,
  overrideHangul => undef,
  UCA_Version => 8,
);

# All in the Unicode code point order.
# No hangul decomposition.

is($all_undef_8->cmp("\x{3402}", "\x{4E00}"), -1);
is($all_undef_8->cmp("\x{4DFF}", "\x{4E00}"), -1);
is($all_undef_8->cmp("\x{4E00}", "\x{AC00}"), -1);
is($all_undef_8->cmp("\x{AC00}", "\x{1100}\x{1161}"), 1);
is($all_undef_8->cmp("\x{AC00}", "\x{ABFF}"), 1);


##### 7..11

my $all_undef_9 = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  overrideCJK => undef,
  overrideHangul => undef,
  UCA_Version => 9,
);

# CJK Ideo. < CJK ext A/B < Others.
# No hangul decomposition.

is($all_undef_9->cmp("\x{4E00}", "\x{3402}"), -1);
is($all_undef_9->cmp("\x{3402}", "\x{20000}"), -1);
is($all_undef_9->cmp("\x{20000}", "\x{AC00}"), -1);
is($all_undef_9->cmp("\x{AC00}", "\x{1100}\x{1161}"), 1);
is($all_undef_9->cmp("\x{AC00}", "\x{ABFF}"), 1); # U+ABFF: not assigned

##### 12..16

my $ignoreHangul = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  overrideHangul => sub {()},
  entry => <<'ENTRIES',
AE00 ; [.0100.0020.0002.AE00]  # Hangul GEUL
ENTRIES
);

# All Hangul Syllables except U+AE00 are ignored.

ok($ignoreHangul->eq("\x{AC00}", ""));
is($ignoreHangul->cmp("\x{AC00}", "\0"), -1);
is($ignoreHangul->cmp("\x{AC00}", "\x{AE00}"), -1);
is($ignoreHangul->cmp("\x{AC00}", "\x{1100}\x{1161}"), -1); # Jamo are not ignored.
is($ignoreHangul->cmp("Pe\x{AE00}rl", "Perl"), -1); # 'r' is unassigned.


my $ignoreCJK = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  overrideCJK => sub {()},
  entry => <<'ENTRIES',
5B57 ; [.0107.0020.0002.5B57]  # CJK Ideograph "Letter"
ENTRIES
);

# All CJK Unified Ideographs except U+5B57 are ignored.

##### 17..21
ok($ignoreCJK->eq("\x{4E00}", ""));
is($ignoreCJK->cmp("\x{4E00}", "\0"), -1);
ok($ignoreCJK->eq("Pe\x{4E00}rl", "Perl")); # U+4E00 is a CJK.
is($ignoreCJK->cmp("\x{4DFF}", "\x{4E00}"), 1); # U+4DFF is not CJK.
is($ignoreCJK->cmp("Pe\x{5B57}rl", "Perl"), -1); # 'r' is unassigned.

##### 22..29
ok($ignoreCJK->eq("\x{3400}", ""));
ok($ignoreCJK->eq("\x{4DB5}", ""));
ok($ignoreCJK->eq("\x{9FA5}", ""));
ok($ignoreCJK->eq("\x{9FA6}", "")); # UI since Unicode 4.1.0
ok($ignoreCJK->eq("\x{9FBB}", "")); # UI since Unicode 4.1.0
is($ignoreCJK->cmp("\x{9FBC}", "Perl"), 1);
ok($ignoreCJK->eq("\x{20000}", ""));
ok($ignoreCJK->eq("\x{2A6D6}", ""));

##### 30..37
$ignoreCJK->change(UCA_Version => 9);
ok($ignoreCJK->eq("\x{3400}", ""));
ok($ignoreCJK->eq("\x{4DB5}", ""));
ok($ignoreCJK->eq("\x{9FA5}", ""));
is($ignoreCJK->cmp("\x{9FA6}", "Perl"), 1);
is($ignoreCJK->cmp("\x{9FBB}", "Perl"), 1);
is($ignoreCJK->cmp("\x{9FBC}", "Perl"), 1);
ok($ignoreCJK->eq("\x{20000}", ""));
ok($ignoreCJK->eq("\x{2A6D6}", ""));

##### 38..45
$ignoreCJK->change(UCA_Version => 8);
ok($ignoreCJK->eq("\x{3400}", ""));
ok($ignoreCJK->eq("\x{4DB5}", ""));
ok($ignoreCJK->eq("\x{9FA5}", ""));
is($ignoreCJK->cmp("\x{9FA6}", "Perl"), 1);
is($ignoreCJK->cmp("\x{9FBB}", "Perl"), 1);
is($ignoreCJK->cmp("\x{9FBC}", "Perl"), 1);
ok($ignoreCJK->eq("\x{20000}", ""));
ok($ignoreCJK->eq("\x{2A6D6}", ""));

##### 46..53
$ignoreCJK->change(UCA_Version => 14);
ok($ignoreCJK->eq("\x{3400}", ""));
ok($ignoreCJK->eq("\x{4DB5}", ""));
ok($ignoreCJK->eq("\x{9FA5}", ""));
ok($ignoreCJK->eq("\x{9FA6}", "")); # UI since Unicode 4.1.0
ok($ignoreCJK->eq("\x{9FBB}", "")); # UI since Unicode 4.1.0
is($ignoreCJK->cmp("\x{9FBC}", "Perl"), 1);
ok($ignoreCJK->eq("\x{20000}", ""));
ok($ignoreCJK->eq("\x{2A6D6}", ""));

##### 54..76
my $overCJK = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  entry => <<'ENTRIES',
0061 ; [.0101.0020.0002.0061] # latin a
0041 ; [.0101.0020.0008.0041] # LATIN A
4E00 ; [.B1FC.0030.0004.4E00] # Ideograph; B1FC = FFFF - 4E03.
ENTRIES
  overrideCJK => sub {
    my $u = 0xFFFF - @_[0]; # reversed
    @(\@($u, 0x20, 0x2, $u));
  },
);

is($overCJK->cmp("a", "A"), -1); # diff. at level 3.
is($overCJK->cmp( "\x{4E03}",  "\x{4E00}"), -1); # diff. at level 2.
is($overCJK->cmp("A\x{4E03}", "A\x{4E00}"), -1);
is($overCJK->cmp("A\x{4E03}", "a\x{4E00}"), -1);
is($overCJK->cmp("a\x{4E03}", "A\x{4E00}"), -1);

is($overCJK->cmp("a\x{3400}", "A\x{4DB5}"), 1);
is($overCJK->cmp("a\x{4DB5}", "A\x{9FA5}"), 1);
is($overCJK->cmp("a\x{9FA5}", "A\x{9FA6}"), 1);
is($overCJK->cmp("a\x{9FA6}", "A\x{9FBB}"), 1);
is($overCJK->cmp("a\x{9FBB}", "A\x{9FBC}"), -1);
is($overCJK->cmp("a\x{9FBC}", "A\x{9FBF}"), -1);

$overCJK->change(UCA_Version => 9);

is($overCJK->cmp("a\x{3400}", "A\x{4DB5}"), 1);
is($overCJK->cmp("a\x{4DB5}", "A\x{9FA5}"), 1);
is($overCJK->cmp("a\x{9FA5}", "A\x{9FA6}"), -1);
is($overCJK->cmp("a\x{9FA6}", "A\x{9FBB}"), -1);
is($overCJK->cmp("a\x{9FBB}", "A\x{9FBC}"), -1);
is($overCJK->cmp("a\x{9FBC}", "A\x{9FBF}"), -1);

$overCJK->change(UCA_Version => 14);

is($overCJK->cmp("a\x{3400}", "A\x{4DB5}"), 1);
is($overCJK->cmp("a\x{4DB5}", "A\x{9FA5}"), 1);
is($overCJK->cmp("a\x{9FA5}", "A\x{9FA6}"), 1);
is($overCJK->cmp("a\x{9FA6}", "A\x{9FBB}"), 1);
is($overCJK->cmp("a\x{9FBB}", "A\x{9FBC}"), -1);
is($overCJK->cmp("a\x{9FBC}", "A\x{9FBF}"), -1);

