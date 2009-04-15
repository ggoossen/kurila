
BEGIN {
    unless ("A" eq pack('U', 0x41)) {
	print $^STDOUT, "1..0 # Unicode::Normalize " .
	    "cannot stringify a Unicode code point\n";
	exit 0;
    }
}

#########################

use Test::More;

use warnings;
BEGIN { plan tests => 70 };
use Unicode::Normalize < qw(:all);
ok(1); # If we made it this far, we're ok.

sub _pack_U { Unicode::Normalize::pack_U(< @_) }
sub hexU { _pack_U < map { hex }, split ' ', shift }
sub answer { defined @_[0] ?? @_[0] ?? "YES" !! "NO" !! "MAYBE" }

#########################

is(FCD(''), "");
is(FCC(''), "");
is(FCD('A'), "A");
is(FCC('A'), "A");

is(normalize('FCD', ""), "");
is(normalize('FCC', ""), "");
is(normalize('FCC', "A"), "A");
is(normalize('FCD', "A"), "A");

# if checkFCD is YES, the return value from FCD should be same as the original
is(FCD(hexU("00C5")),		hexU("00C5"));		# A with ring above
is(FCD(hexU("0041 030A")),	hexU("0041 030A"));	# A+ring
is(FCD(hexU("0041 0327 030A")), hexU("0041 0327 030A")); # A+cedilla+ring
is(FCD(hexU("AC01 1100 1161")), hexU("AC01 1100 1161")); # hangul
is(FCD(hexU("212B F900")),	hexU("212B F900"));	# compat

is(normalize('FCD', hexU("00C5")),		hexU("00C5"));
is(normalize('FCD', hexU("0041 030A")),		hexU("0041 030A"));
is(normalize('FCD', hexU("0041 0327 030A")),	hexU("0041 0327 030A"));
is(normalize('FCD', hexU("AC01 1100 1161")),	hexU("AC01 1100 1161"));
is(normalize('FCD', hexU("212B F900")),		hexU("212B F900"));

# if checkFCD is MAYBE or NO, FCD returns NFD (this behavior isn't documented)
is(FCD(hexU("00C5 0327")),	hexU("0041 0327 030A"));
is(FCD(hexU("0041 030A 0327")),	hexU("0041 0327 030A"));
is(FCD(hexU("00C5 0327")),	NFD(hexU("00C5 0327")));
is(FCD(hexU("0041 030A 0327")),	NFD(hexU("0041 030A 0327")));

is(normalize('FCD', hexU("00C5 0327")),		hexU("0041 0327 030A"));
is(normalize('FCD', hexU("0041 030A 0327")),	hexU("0041 0327 030A"));
is(normalize('FCD', hexU("00C5 0327")),		NFD(hexU("00C5 0327")));
is(normalize('FCD', hexU("0041 030A 0327")),	NFD(hexU("0041 030A 0327")));

is(answer(checkFCD('')), 'YES');
is(answer(checkFCD('A')), 'YES');
is(answer(checkFCD("\x{030A}")), 'YES');  # 030A;COMBINING RING ABOVE
is(answer(checkFCD("\x{0327}")), 'YES');  # 0327;COMBINING CEDILLA
is(answer(checkFCD(_pack_U(0x00C5))), 'YES'); # A with ring above
is(answer(checkFCD(hexU("0041 030A"))), 'YES'); # A+ring
is(answer(checkFCD(hexU("0041 0327 030A"))), 'YES'); # A+cedilla+ring
is(answer(checkFCD(hexU("0041 030A 0327"))), 'NO');  # A+ring+cedilla
is(answer(checkFCD(hexU("00C5 0327"))), 'NO');    # A-ring+cedilla
is(answer(checkNFC(hexU("00C5 0327"))), 'MAYBE'); # NFC: A-ring+cedilla
is(answer(check("FCD", hexU("00C5 0327"))), 'NO');
is(answer(check("NFC", hexU("00C5 0327"))), 'MAYBE');
is(answer(checkFCD("\x{AC01}\x{1100}\x{1161}")), 'YES'); # hangul
is(answer(checkFCD("\x{212B}\x{F900}")), 'YES'); # compat

is(answer(checkFCD(hexU("1EA7 05AE 0315 0062"))), "NO");
is(answer(checkFCC(hexU("1EA7 05AE 0315 0062"))), "NO");
is(answer(check('FCD', hexU("1EA7 05AE 0315 0062"))), "NO");
is(answer(check('FCC', hexU("1EA7 05AE 0315 0062"))), "NO");

is(FCC(hexU("00C5 0327")), hexU("0041 0327 030A"));
is(FCC(hexU("0045 0304 0300")), "\x{1E14}");
is(FCC("\x{1100}\x{1161}\x{1100}\x{1173}\x{11AF}"), "\x{AC00}\x{AE00}");
is(normalize('FCC', hexU("00C5 0327")), hexU("0041 0327 030A"));
is(normalize('FCC', hexU("0045 0304 0300")), "\x{1E14}");
is(normalize('FCC', hexU("1100 1161 1100 1173 11AF")), "\x{AC00}\x{AE00}");

is(FCC("\x{0B47}\x{0300}\x{0B3E}"), "\x{0B47}\x{0300}\x{0B3E}");
is(FCC("\x{1100}\x{0300}\x{1161}"), "\x{1100}\x{0300}\x{1161}");
is(FCC("\x{0B47}\x{0B3E}\x{0300}"), "\x{0B4B}\x{0300}");
is(FCC("\x{1100}\x{1161}\x{0300}"), "\x{AC00}\x{0300}");
is(FCC("\x{0B47}\x{300}\x{0B3E}\x{327}"), "\x{0B47}\x{300}\x{0B3E}\x{327}");
is(FCC("\x{1100}\x{300}\x{1161}\x{327}"), "\x{1100}\x{300}\x{1161}\x{327}");

is(answer(checkFCC('')), 'YES');
is(answer(checkFCC('A')), 'YES');
is(answer(checkFCC("\x{030A}")), 'MAYBE');  # 030A;COMBINING RING ABOVE
is(answer(checkFCC("\x{0327}")), 'MAYBE'); # 0327;COMBINING CEDILLA
is(answer(checkFCC(hexU("00C5"))), 'YES'); # A with ring above
is(answer(checkFCC(hexU("0041 030A"))), 'MAYBE'); # A+ring
is(answer(checkFCC(hexU("0041 0327 030A"))), 'MAYBE'); # A+cedilla+ring
is(answer(checkFCC(hexU("0041 030A 0327"))), 'NO');    # A+ring+cedilla
is(answer(checkFCC(hexU("00C5 0327"))), 'NO'); # A-ring+cedilla
is(answer(checkFCC("\x{AC01}\x{1100}\x{1161}")), 'MAYBE'); # hangul
is(answer(checkFCC("\x{212B}\x{F900}")), 'NO'); # compat
is(answer(checkFCC("\x{212B}\x{0327}")), 'NO'); # compat
is(answer(checkFCC("\x{0327}\x{212B}")), 'NO'); # compat

