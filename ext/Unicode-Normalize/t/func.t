
#########################

use Test::More;

use warnings;
BEGIN { plan tests => 211 };
use Unicode::Normalize < qw(:all);
ok(1); # If we made it this far, we're ok.

sub _pack_U { Unicode::Normalize::pack_U(< @_) }
sub hexU { _pack_U < map { hex }, split ' ', shift }

#########################

is(getCombinClass(   0),   0);
is(getCombinClass(  41),   0);
is(getCombinClass(  65),   0);
is(getCombinClass( 768), 230);
is(getCombinClass(1809),  36);

is(getCanon(   0), undef);
is(getCanon(0x29), undef);
is(getCanon(0x41), undef);
is(getCanon(0x00C0), _pack_U(0x0041, 0x0300));
is(getCanon(0x00EF), _pack_U(0x0069, 0x0308));
is(getCanon(0x304C), _pack_U(0x304B, 0x3099));
is(getCanon(0x1EA4), _pack_U(0x0041, 0x0302, 0x0301));
is(getCanon(0x1F82), _pack_U(0x03B1, 0x0313, 0x0300, 0x0345));
is(getCanon(0x1FAF), _pack_U(0x03A9, 0x0314, 0x0342, 0x0345));
is(getCanon(0xAC00), _pack_U(0x1100, 0x1161));
is(getCanon(0xAE00), _pack_U(0x1100, 0x1173, 0x11AF));
is(getCanon(0x212C), undef);
is(getCanon(0x3243), undef);
is(getCanon(0xFA2D), _pack_U(0x9DB4));

is(getCompat(   0), undef);
is(getCompat(0x29), undef);
is(getCompat(0x41), undef);
is(getCompat(0x00C0), _pack_U(0x0041, 0x0300));
is(getCompat(0x00EF), _pack_U(0x0069, 0x0308));
is(getCompat(0x304C), _pack_U(0x304B, 0x3099));
is(getCompat(0x1EA4), _pack_U(0x0041, 0x0302, 0x0301));
is(getCompat(0x1F82), _pack_U(0x03B1, 0x0313, 0x0300, 0x0345));
is(getCompat(0x1FAF), _pack_U(0x03A9, 0x0314, 0x0342, 0x0345));
is(getCompat(0x212C), _pack_U(0x0042));
is(getCompat(0x3243), _pack_U(0x0028, 0x81F3, 0x0029));
is(getCompat(0xAC00), _pack_U(0x1100, 0x1161));
is(getCompat(0xAE00), _pack_U(0x1100, 0x1173, 0x11AF));
is(getCompat(0xFA2D), _pack_U(0x9DB4));

is(getComposite(   0,    0), undef);
is(getComposite(   0, 0x29), undef);
is(getComposite(0x29,    0), undef);
is(getComposite(0x29, 0x29), undef);
is(getComposite(   0, 0x41), undef);
is(getComposite(0x41,    0), undef);
is(getComposite(0x41, 0x41), undef);
is(getComposite(12, 0x0300), undef);
is(getComposite(0x0055, 0xFF00), undef);
is(getComposite(0x0041, 0x0300), 0x00C0);
is(getComposite(0x0055, 0x0300), 0x00D9);
is(getComposite(0x0112, 0x0300), 0x1E14);
is(getComposite(0x1100, 0x1161), 0xAC00);
is(getComposite(0x1100, 0x1173), 0xADF8);
is(getComposite(0x1100, 0x11AF), undef);
is(getComposite(0x1173, 0x11AF), undef);
is(getComposite(0xAC00, 0x11A7), undef);
is(getComposite(0xAC00, 0x11A8), 0xAC01);
is(getComposite(0xADF8, 0x11AF), 0xAE00);

sub uprops {
  my $uv = shift;
  my $r = "";
     $r .= isExclusion($uv)   ?? 'X' !! 'x';
     $r .= isSingleton($uv)   ?? 'S' !! 's';
     $r .= isNonStDecomp($uv) ?? 'N' !! 'n'; # Non-Starter Decomposition
     $r .= isComp_Ex($uv)     ?? 'F' !! 'f'; # Full exclusion (X + S + N)
     $r .= isComp2nd($uv)     ?? 'B' !! 'b'; # B = M = Y
     $r .= isNFD_NO($uv)      ?? 'D' !! 'd';
     $r .= isNFC_MAYBE($uv)   ?? 'M' !! 'm'; # Maybe
     $r .= isNFC_NO($uv)      ?? 'C' !! 'c';
     $r .= isNFKD_NO($uv)     ?? 'K' !! 'k';
     $r .= isNFKC_MAYBE($uv)  ?? 'Y' !! 'y'; # maYbe
     $r .= isNFKC_NO($uv)     ?? 'G' !! 'g';
  return $r;
}

is(uprops(0x0000), 'xsnfbdmckyg'); # NULL
is(uprops(0x0029), 'xsnfbdmckyg'); # RIGHT PARENTHESIS
is(uprops(0x0041), 'xsnfbdmckyg'); # LATIN CAPITAL LETTER A
is(uprops(0x00A0), 'xsnfbdmcKyG'); # NO-BREAK SPACE
is(uprops(0x00C0), 'xsnfbDmcKyg'); # LATIN CAPITAL LETTER A WITH GRAVE
is(uprops(0x0300), 'xsnfBdMckYg'); # COMBINING GRAVE ACCENT
is(uprops(0x0344), 'xsNFbDmCKyG'); # COMBINING GREEK DIALYTIKA TONOS
is(uprops(0x0387), 'xSnFbDmCKyG'); # GREEK ANO TELEIA
is(uprops(0x0958), 'XsnFbDmCKyG'); # DEVANAGARI LETTER QA
is(uprops(0x0F43), 'XsnFbDmCKyG'); # TIBETAN LETTER GHA
is(uprops(0x1100), 'xsnfbdmckyg'); # HANGUL CHOSEONG KIYEIS
is(uprops(0x1161), 'xsnfBdMckYg'); # HANGUL JUNGSEONG A
is(uprops(0x11AF), 'xsnfBdMckYg'); # HANGUL JONGSEONG RIEUL
is(uprops(0x212B), 'xSnFbDmCKyG'); # ANGSTROM SIGN
is(uprops(0xAC00), 'xsnfbDmcKyg'); # HANGUL SYLLABLE GA
is(uprops(0xF900), 'xSnFbDmCKyG'); # CJK COMPATIBILITY IDEOGRAPH-F900
is(uprops(0xFB4E), 'XsnFbDmCKyG'); # HEBREW LETTER PE WITH RAFE
is(uprops(0xFF71), 'xsnfbdmcKyG'); # HALFWIDTH KATAKANA LETTER A

is(decompose(""), "");
is(decompose("A"), "A");
is(decompose("", 1), "");
is(decompose("A", 1), "A");

is(decompose(hexU("1E14 AC01")), hexU("0045 0304 0300 1100 1161 11A8"));
is(decompose(hexU("AC00 AE00")), hexU("1100 1161 1100 1173 11AF"));
is(decompose(hexU("304C FF76")), hexU("304B 3099 FF76"));

is(decompose(hexU("1E14 AC01"), 1), hexU("0045 0304 0300 1100 1161 11A8"));
is(decompose(hexU("AC00 AE00"), 1), hexU("1100 1161 1100 1173 11AF"));
is(decompose(hexU("304C FF76"), 1), hexU("304B 3099 30AB"));

# don't modify the source
my $sDec = "\x{FA19}";
is(decompose($sDec), "\x{795E}");
is($sDec, "\x{FA19}");

is(reorder(""), "");
is(reorder("A"), "A");
is(reorder(hexU("0041 0300 0315 0313 031b 0061")),
	   hexU("0041 031b 0300 0313 0315 0061"));
is(reorder(hexU("00C1 0300 0315 0313 031b 0061 309A 3099")),
	   hexU("00C1 031b 0300 0313 0315 0061 309A 3099"));

# don't modify the source
my $sReord = "\x{3000}\x{300}\x{31b}";
is(reorder($sReord), "\x{3000}\x{31b}\x{300}");
is($sReord, "\x{3000}\x{300}\x{31b}");

is(compose(""), "");
is(compose("A"), "A");
is(compose(hexU("0061 0300")),      hexU("00E0"));
is(compose(hexU("0061 0300 031B")), hexU("00E0 031B"));
is(compose(hexU("0061 0300 0315")), hexU("00E0 0315"));
is(compose(hexU("0061 0300 0313")), hexU("00E0 0313"));
is(compose(hexU("0061 031B 0300")), hexU("00E0 031B"));
is(compose(hexU("0061 0315 0300")), hexU("0061 0315 0300"));
is(compose(hexU("0061 0313 0300")), hexU("0061 0313 0300"));

# don't modify the source
my $sCom = "\x{304B}\x{3099}";
is(compose($sCom), "\x{304C}");
is($sCom, "\x{304B}\x{3099}");

is(composeContiguous(""), "");
is(composeContiguous("A"), "A");
is(composeContiguous(hexU("0061 0300")),      hexU("00E0"));
is(composeContiguous(hexU("0061 0300 031B")), hexU("00E0 031B"));
is(composeContiguous(hexU("0061 0300 0315")), hexU("00E0 0315"));
is(composeContiguous(hexU("0061 0300 0313")), hexU("00E0 0313"));
is(composeContiguous(hexU("0061 031B 0300")), hexU("0061 031B 0300"));
is(composeContiguous(hexU("0061 0315 0300")), hexU("0061 0315 0300"));
is(composeContiguous(hexU("0061 0313 0300")), hexU("0061 0313 0300"));

# don't modify the source
my $sCtg = "\x{30DB}\x{309A}";
is(composeContiguous($sCtg), "\x{30DD}");
is($sCtg, "\x{30DB}\x{309A}");

sub answer { defined @_[0] ?? @_[0] ?? "YES" !! "NO" !! "MAYBE" }

is(answer(checkNFD("")),  "YES");
is(answer(checkNFC("")),  "YES");
is(answer(checkNFKD("")), "YES");
is(answer(checkNFKC("")), "YES");
is(answer(check("NFD", "")), "YES");
is(answer(check("NFC", "")), "YES");
is(answer(check("NFKD","")), "YES");
is(answer(check("NFKC","")), "YES");

# U+0000 to U+007F are prenormalized in all the normalization forms.
is(answer(checkNFD("AZaz\t12!#`")),  "YES");
is(answer(checkNFC("AZaz\t12!#`")),  "YES");
is(answer(checkNFKD("AZaz\t12!#`")), "YES");
is(answer(checkNFKC("AZaz\t12!#`")), "YES");
is(answer(check("D", "AZaz\t12!#`")), "YES");
is(answer(check("C", "AZaz\t12!#`")), "YES");
is(answer(check("KD","AZaz\t12!#`")), "YES");
is(answer(check("KC","AZaz\t12!#`")), "YES");

is(answer(checkNFD(NFD(_pack_U(0xC1, 0x1100, 0x1173, 0x11AF)))), "YES");
is(answer(checkNFD(hexU("20 C1 1100 1173 11AF"))), "NO");
is(answer(checkNFC(hexU("20 C1 1173 11AF"))), "MAYBE");
is(answer(checkNFC(hexU("20 C1 AE00 1100"))), "YES");
is(answer(checkNFC(hexU("20 C1 AE00 1100 0300"))), "MAYBE");
is(answer(checkNFC(hexU("212B 1100 0300"))), "NO");
is(answer(checkNFC(hexU("1100 0300 212B"))), "NO");
is(answer(checkNFC(hexU("0041 0327 030A"))), "MAYBE"); # A+cedilla+ring
is(answer(checkNFC(hexU("0041 030A 0327"))), "NO");    # A+ring+cedilla
is(answer(checkNFC(hexU("20 C1 FF71 2025"))),"YES");
is(answer(check("NFC", hexU("20 C1 212B 300"))), "NO");
is(answer(checkNFKD(hexU("20 C1 FF71 2025"))),   "NO");
is(answer(checkNFKC(hexU("20 C1 AE00 2025"))), "NO");
is(answer(checkNFKC(hexU("212B 1100 0300"))), "NO");
is(answer(checkNFKC(hexU("1100 0300 212B"))), "NO");
is(answer(checkNFKC(hexU("0041 0327 030A"))), "MAYBE"); # A+cedilla+ring
is(answer(checkNFKC(hexU("0041 030A 0327"))), "NO");    # A+ring+cedilla
is(answer(check("NFKC", hexU("20 C1 212B 300"))), "NO");

"012ABC" =~ m/(\d+)(\w+)/;
ok("012" eq NFC($1) && "ABC" eq NFC($2));

is(normalize('C', $1), "012");
is(normalize('C', $2), "ABC");

is(normalize('NFC', $1), "012");
is(normalize('NFC', $2), "ABC");
 # s/^NF// in normalize() must not prevent using $1, $&, etc.

# a string with initial zero should be treated like a number

# LATIN CAPITAL LETTER A WITH GRAVE
is(getCombinClass("0192"), 0);
is(getCanon ("0192"), _pack_U(0x41, 0x300));
is(getCompat("0192"), _pack_U(0x41, 0x300));
is(getComposite("065", "0768"), 192);
ok(isNFD_NO ("0192"));
ok(isNFKD_NO("0192"));

# DEVANAGARI LETTER QA
ok(isExclusion("02392"));
ok(isComp_Ex  ("02392"));
ok(isNFC_NO   ("02392"));
ok(isNFKC_NO  ("02392"));
ok(isNFD_NO   ("02392"));
ok(isNFKD_NO  ("02392"));

# ANGSTROM SIGN
ok(isSingleton("08491"));
ok(isComp_Ex  ("08491"));
ok(isNFC_NO   ("08491"));
ok(isNFKC_NO  ("08491"));
ok(isNFD_NO   ("08491"));
ok(isNFKD_NO  ("08491"));

# COMBINING GREEK DIALYTIKA TONOS
ok(isNonStDecomp("0836"));
ok(isComp_Ex    ("0836"));
ok(isNFC_NO     ("0836"));
ok(isNFKC_NO    ("0836"));
ok(isNFD_NO     ("0836"));
ok(isNFKD_NO    ("0836"));

# COMBINING GRAVE ACCENT
is(getCombinClass("0768"), 230);
ok(isComp2nd   ("0768"));
ok(isNFC_MAYBE ("0768"));
ok(isNFKC_MAYBE("0768"));

# HANGUL SYLLABLE GA
is(getCombinClass("044032"), 0);
is(getCanon("044032"),  _pack_U(0x1100, 0x1161));
is(getCompat("044032"), _pack_U(0x1100, 0x1161));
is(getComposite("04352", "04449"), 0xAC00);

# string with 22 combining characters: (0x300..0x315)
my $str_cc22 = _pack_U(0x3041, < 0x300..0x315, 0x3042);
is(decompose($str_cc22), $str_cc22);
is(reorder($str_cc22), $str_cc22);
is(compose($str_cc22), $str_cc22);
is(composeContiguous($str_cc22), $str_cc22);
is(NFD($str_cc22), $str_cc22);
is(NFC($str_cc22), $str_cc22);
is(NFKD($str_cc22), $str_cc22);
is(NFKC($str_cc22), $str_cc22);
is(FCD($str_cc22), $str_cc22);
is(FCC($str_cc22), $str_cc22);

# string with 40 combining characters of the same class: (0x300..0x313)x2
my $str_cc40 = _pack_U(0x3041, < 0x300..0x313, < 0x300..0x313, 0x3042);
is(decompose($str_cc40), $str_cc40);
is(reorder($str_cc40), $str_cc40);
is(compose($str_cc40), $str_cc40);
is(composeContiguous($str_cc40), $str_cc40);
is(NFD($str_cc40), $str_cc40);
is(NFC($str_cc40), $str_cc40);
is(NFKD($str_cc40), $str_cc40);
is(NFKC($str_cc40), $str_cc40);
is(FCD($str_cc40), $str_cc40);
is(FCC($str_cc40), $str_cc40);

my $precomp = hexU("304C 304E 3050 3052 3054");
my $combseq = hexU("304B 3099 304D 3099 304F 3099 3051 3099 3053 3099");
is(decompose($precomp x 5),  $combseq x 5);
is(decompose($precomp x 10), $combseq x 10);
is(decompose($precomp x 20), $combseq x 20);

my $hangsyl = hexU("AC00 B098 B2E4 B77C B9C8");
my $jamoseq = hexU("1100 1161 1102 1161 1103 1161 1105 1161 1106 1161");
is(decompose($hangsyl x 5), $jamoseq x 5);
is(decompose($hangsyl x 10), $jamoseq x 10);
is(decompose($hangsyl x 20), $jamoseq x 20);

my $notcomp = hexU("304B 304D 304F 3051 3053");
is(decompose($precomp . $notcomp),     $combseq . $notcomp);
is(decompose($precomp . $notcomp x 5), $combseq . $notcomp x 5);
is(decompose($precomp . $notcomp x10), $combseq . $notcomp x10);


