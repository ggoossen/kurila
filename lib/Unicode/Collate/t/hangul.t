BEGIN {
    unless ("A" eq pack('U', 0x41)) {
	print "1..0 # Unicode::Collate " .
	    "cannot stringify a Unicode code point\n";
	exit 0;
    }
    if (%ENV{PERL_CORE}) {
	chdir('t') if -d 't';
	@INC = $^O eq 'MacOS' ? qw(::lib) : qw(../lib);
    }
}

use Test::More;
BEGIN { plan tests => 72 };

use strict;
use warnings;
use Unicode::Collate;

#########################

ok(1);

# a standard collator (3.1.1)
my $Collator = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
);


# a collator for hangul sorting,
# cf. http://std.dkuug.dk/JTC1/SC22/WG20/docs/documents.html
#     http://std.dkuug.dk/JTC1/SC22/WG20/docs/n1051-hangulsort.pdf
my $hangul = Unicode::Collate->new(
  level => 3,
  table => undef,
  normalization => undef,

  entry => <<'ENTRIES',
0061      ; [.0A15.0020.0002] # LATIN SMALL LETTER A
0041      ; [.0A15.0020.0008] # LATIN CAPITAL LETTER A
#1161     ; [.1800.0020.0002] # <comment> initial jungseong A
#1163     ; [.1801.0020.0002] # <comment> initial jungseong YA
1100      ; [.1831.0020.0002] # choseong KIYEOK
1100 1161 ; [.1831.0020.0002][.1800.0020.0002] # G-A
1100 1163 ; [.1831.0020.0002][.1801.0020.0002] # G-YA
1101      ; [.1831.0020.0002][.1831.0020.0002] # choseong SSANGKIYEOK
1101 1161 ; [.1831.0020.0002][.1831.0020.0002][.1800.0020.0002] # GG-A
1101 1163 ; [.1831.0020.0002][.1831.0020.0002][.1801.0020.0002] # GG-YA
1102      ; [.1833.0020.0002] # choseong NIEUN
1102 1161 ; [.1833.0020.0002][.1800.0020.0002] # N-A
1102 1163 ; [.1833.0020.0002][.1801.0020.0002] # N-YA
3042      ; [.1921.0020.000E] # HIRAGANA LETTER A
11A8      ; [.FE10.0020.0002] # jongseong KIYEOK
11A9      ; [.FE10.0020.0002][.FE10.0020.0002] # jongseong SSANGKIYEOK
1161      ; [.FE20.0020.0002] # jungseong A <non-initial>
1163      ; [.FE21.0020.0002] # jungseong YA <non-initial>
ENTRIES
);

is(ref $hangul, "Unicode::Collate");

my $trailwt = Unicode::Collate->new(
  level => 3,
  table => undef,
  normalization => undef,
  hangul_terminator => 16,

  entry => <<'ENTRIES', # Term < Jongseong < Jungseong < Choseong
0061  ; [.0A15.0020.0002] # LATIN SMALL LETTER A
0041  ; [.0A15.0020.0008] # LATIN CAPITAL LETTER A
11A8  ; [.1801.0020.0002] # HANGUL JONGSEONG KIYEOK
11A9  ; [.1801.0020.0002][.1801.0020.0002] # HANGUL JONGSEONG SSANGKIYEOK
1161  ; [.1831.0020.0002] # HANGUL JUNGSEONG A
1163  ; [.1832.0020.0002] # HANGUL JUNGSEONG YA
1100  ; [.1861.0020.0002] # HANGUL CHOSEONG KIYEOK
1101  ; [.1861.0020.0002][.1861.0020.0002] # HANGUL CHOSEONG SSANGKIYEOK
1102  ; [.1862.0020.0002] # HANGUL CHOSEONG NIEUN
3042  ; [.1921.0020.000E] # HIRAGANA LETTER A
ENTRIES
);

#########################

# L(simp)L(simp) vs L(comp): /GGA/
is($Collator->cmp("\x{1100}\x{1100}\x{1161}", "\x{1101}\x{1161}"), -1);
ok($hangul  ->eq("\x{1100}\x{1100}\x{1161}", "\x{1101}\x{1161}"));
ok($trailwt ->eq("\x{1100}\x{1100}\x{1161}", "\x{1101}\x{1161}"));

# L(simp) vs L(simp)L(simp): /GA/ vs /GGA/
is($Collator->cmp("\x{1100}\x{1161}", "\x{1100}\x{1100}\x{1161}"), 1);
is($hangul  ->cmp("\x{1100}\x{1161}", "\x{1100}\x{1100}\x{1161}"), -1);
is($trailwt ->cmp("\x{1100}\x{1161}", "\x{1100}\x{1100}\x{1161}"), -1);

# T(simp)T(simp) vs T(comp): /AGG/
is($Collator->cmp("\x{1161}\x{11A8}\x{11A8}", "\x{1161}\x{11A9}"), -1);
ok($hangul  ->eq("\x{1161}\x{11A8}\x{11A8}", "\x{1161}\x{11A9}"));
ok($trailwt ->eq("\x{1161}\x{11A8}\x{11A8}", "\x{1161}\x{11A9}"));

# T(simp) vs T(simp)T(simp): /AG/ vs /AGG/
is($Collator->cmp("\x{1161}\x{11A8}", "\x{1161}\x{11A8}\x{11A8}"), -1);
is($hangul  ->cmp("\x{1161}\x{11A8}", "\x{1161}\x{11A8}\x{11A8}"), -1);
is($trailwt ->cmp("\x{1161}\x{11A8}", "\x{1161}\x{11A8}\x{11A8}"), -1);

# LV vs LLV: /GA/ vs /GNA/
is($Collator->cmp("\x{1100}\x{1161}", "\x{1100}\x{1102}\x{1161}"), 1);
is($hangul  ->cmp("\x{1100}\x{1161}", "\x{1100}\x{1102}\x{1161}"), -1);
is($trailwt ->cmp("\x{1100}\x{1161}", "\x{1100}\x{1102}\x{1161}"), -1);

# LVX vs LVV: /GAA/ vs /GA/.latinA
is($Collator->cmp("\x{1100}\x{1161}\x{1161}", "\x{1100}\x{1161}A"), 1);
is($hangul  ->cmp("\x{1100}\x{1161}\x{1161}", "\x{1100}\x{1161}A"), 1);
is($trailwt ->cmp("\x{1100}\x{1161}\x{1161}", "\x{1100}\x{1161}A"), 1);

# LVX vs LVV: /GAA/ vs /GA/.hiraganaA
is($Collator->cmp("\x{1100}\x{1161}\x{1161}", "\x{1100}\x{1161}\x{3042}"), -1);
is($hangul  ->cmp("\x{1100}\x{1161}\x{1161}", "\x{1100}\x{1161}\x{3042}"), 1);
is($trailwt ->cmp("\x{1100}\x{1161}\x{1161}", "\x{1100}\x{1161}\x{3042}"), 1);

# LVX vs LVV: /GAA/ vs /GA/.hanja
is($Collator->cmp("\x{1100}\x{1161}\x{1161}", "\x{1100}\x{1161}\x{4E00}"), -1);
is($hangul  ->cmp("\x{1100}\x{1161}\x{1161}", "\x{1100}\x{1161}\x{4E00}"), 1);
is($trailwt ->cmp("\x{1100}\x{1161}\x{1161}", "\x{1100}\x{1161}\x{4E00}"), 1);

# LVL vs LVT: /GA/./G/ vs /GAG/
is($Collator->cmp("\x{1100}\x{1161}\x{1100}", "\x{1100}\x{1161}\x{11A8}"), -1);
is($hangul  ->cmp("\x{1100}\x{1161}\x{1100}", "\x{1100}\x{1161}\x{11A8}"), -1);
is($trailwt ->cmp("\x{1100}\x{1161}\x{1100}", "\x{1100}\x{1161}\x{11A8}"), -1);

# LVT vs LVX: /GAG/ vs /GA/.latinA
is($Collator->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}A"), 1);
is($hangul  ->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}A"), 1);
is($trailwt ->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}A"), 1);

# LVT vs LVX: /GAG/ vs /GA/.hiraganaA
is($Collator->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}\x{3042}"), -1);
is($hangul  ->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}\x{3042}"), 1);
is($trailwt ->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}\x{3042}"), 1);

# LVT vs LVX: /GAG/ vs /GA/.hanja
is($Collator->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}\x{4E00}"), -1);
is($hangul  ->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}\x{4E00}"), 1);
is($trailwt ->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}\x{4E00}"), 1);

# LVT vs LVV: /GAG/ vs /GAA/
is($Collator->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}\x{1161}"), 1);
is($hangul  ->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}\x{1161}"), -1);
is($trailwt ->cmp("\x{1100}\x{1161}\x{11A8}", "\x{1100}\x{1161}\x{1161}"), -1);

# LVL vs LVV: /GA/./G/ vs /GAA/
is($Collator->cmp("\x{1100}\x{1161}\x{1100}", "\x{1100}\x{1161}\x{1161}"), -1);
is($hangul  ->cmp("\x{1100}\x{1161}\x{1100}", "\x{1100}\x{1161}\x{1161}"), -1);
is($trailwt ->cmp("\x{1100}\x{1161}\x{1100}", "\x{1100}\x{1161}\x{1161}"), -1);

# LV vs Syl(LV): /GA/ vs /[GA]/
ok($Collator->eq("\x{1100}\x{1161}", "\x{AC00}"));
ok($hangul  ->eq("\x{1100}\x{1161}", "\x{AC00}"));
ok($trailwt ->eq("\x{1100}\x{1161}", "\x{AC00}"));

# LVT vs Syl(LV)T: /GAG/ vs /[GA]G/
ok($Collator->eq("\x{1100}\x{1161}\x{11A8}", "\x{AC00}\x{11A8}"));
ok($hangul  ->eq("\x{1100}\x{1161}\x{11A8}", "\x{AC00}\x{11A8}"));
ok($trailwt ->eq("\x{1100}\x{1161}\x{11A8}", "\x{AC00}\x{11A8}"));

# LVT vs Syl(LVT): /GAG/ vs /[GAG]/
ok($Collator->eq("\x{1100}\x{1161}\x{11A8}", "\x{AC01}"));
ok($hangul  ->eq("\x{1100}\x{1161}\x{11A8}", "\x{AC01}"));
ok($trailwt ->eq("\x{1100}\x{1161}\x{11A8}", "\x{AC01}"));

# LVTT vs Syl(LVTT): /GAGG/ vs /[GAGG]/
ok($Collator->eq("\x{1100}\x{1161}\x{11A9}", "\x{AC02}"));
ok($hangul  ->eq("\x{1100}\x{1161}\x{11A9}", "\x{AC02}"));
ok($trailwt ->eq("\x{1100}\x{1161}\x{11A9}", "\x{AC02}"));

# LVTT vs Syl(LVT).T: /GAGG/ vs /[GAG]G/
is($Collator->cmp("\x{1100}\x{1161}\x{11A9}", "\x{AC01}\x{11A8}"), 1);
ok($hangul  ->eq("\x{1100}\x{1161}\x{11A9}", "\x{AC01}\x{11A8}"));
ok($trailwt ->eq("\x{1100}\x{1161}\x{11A9}", "\x{AC01}\x{11A8}"));

# LLVT vs L.Syl(LVT): /GGAG/ vs /G[GAG]/
is($Collator->cmp("\x{1101}\x{1161}\x{11A8}", "\x{1100}\x{AC01}"), 1);
ok($hangul  ->eq("\x{1101}\x{1161}\x{11A8}", "\x{1100}\x{AC01}"));
ok($trailwt ->eq("\x{1101}\x{1161}\x{11A8}", "\x{1100}\x{AC01}"));

#########################

# checks contraction in LVT:
# weights of these contractions may be non-sense.

my $hangcont = Unicode::Collate->new(
  level => 3,
  table => undef,
  normalization => undef,
  entry => <<'ENTRIES',
1100  ; [.1831.0020.0002] # HANGUL CHOSEONG KIYEOK
1101  ; [.1832.0020.0002] # HANGUL CHOSEONG SSANGKIYEOK
1161  ; [.188D.0020.0002] # HANGUL JUNGSEONG A
1162  ; [.188E.0020.0002] # HANGUL JUNGSEONG AE
1163  ; [.188F.0020.0002] # HANGUL JUNGSEONG YA
11A8  ; [.18CF.0020.0002] # HANGUL JONGSEONG KIYEOK
11A9  ; [.18D0.0020.0002] # HANGUL JONGSEONG SSANGKIYEOK
1161 11A9 ; [.0000.0000.0000] # A-GG <contraction>
1100 1163 11A8 ; [.1000.0020.0002] # G-YA-G <contraction> eq. U+AC39
ENTRIES
);

# contracted into VT
is($Collator->cmp("\x{1101}", "\x{1101}\x{1161}\x{11A9}"), -1);
ok($hangcont->eq("\x{1101}", "\x{1101}\x{1161}\x{11A9}"));

# not contracted into LVT but into VT
is($Collator->cmp("\x{1100}", "\x{1100}\x{1161}\x{11A9}"), -1);
ok($hangcont->eq("\x{1100}", "\x{1100}\x{1161}\x{11A9}"));

# contracted into LVT
is($Collator->cmp("\x{1100}\x{1163}\x{11A8}", "\x{1100}"), 1);
is($hangcont->cmp("\x{1100}\x{1163}\x{11A8}", "\x{1100}"), -1);

# LVTT vs Syl(LVTT): /GAGG/ vs /[GAGG]/
ok($Collator->eq("\x{1100}\x{1161}\x{11A9}", "\x{AC02}"));
ok($hangcont->eq("\x{1100}\x{1161}\x{11A9}", "\x{AC02}"));

# LVT vs Syl(LVT): /GYAG/ vs /[GYAG]/
ok($Collator->eq("\x{1100}\x{1163}\x{11A8}", "\x{AC39}"));
ok($hangcont->eq("\x{1100}\x{1163}\x{11A8}", "\x{AC39}"));

1;
__END__
