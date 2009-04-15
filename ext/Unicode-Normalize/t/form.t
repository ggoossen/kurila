
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
BEGIN { plan tests => 37 };
use Unicode::Normalize < qw(:all);
ok(1); # If we made it this far, we're ok.

sub answer { defined @_[0] ?? @_[0] ?? "YES" !! "NO" !! "MAYBE" }

#########################

is(NFD ("\x{304C}\x{FF76}"), "\x{304B}\x{3099}\x{FF76}");
is(NFC ("\x{304C}\x{FF76}"), "\x{304C}\x{FF76}");
is(NFKD("\x{304C}\x{FF76}"), "\x{304B}\x{3099}\x{30AB}");
is(NFKC("\x{304C}\x{FF76}"), "\x{304C}\x{30AB}");

is(answer(checkNFD ("\x{304C}")), "NO");
is(answer(checkNFC ("\x{304C}")), "YES");
is(answer(checkNFKD("\x{304C}")), "NO");
is(answer(checkNFKC("\x{304C}")), "YES");
is(answer(checkNFD ("\x{FF76}")), "YES");
is(answer(checkNFC ("\x{FF76}")), "YES");
is(answer(checkNFKD("\x{FF76}")), "NO");
is(answer(checkNFKC("\x{FF76}")), "NO");

is(normalize('D', "\x{304C}\x{FF76}"), "\x{304B}\x{3099}\x{FF76}");
is(normalize('C', "\x{304C}\x{FF76}"), "\x{304C}\x{FF76}");
is(normalize('KD',"\x{304C}\x{FF76}"), "\x{304B}\x{3099}\x{30AB}");
is(normalize('KC',"\x{304C}\x{FF76}"), "\x{304C}\x{30AB}");

is(answer(check('D', "\x{304C}")), "NO");
is(answer(check('C', "\x{304C}")), "YES");
is(answer(check('KD',"\x{304C}")), "NO");
is(answer(check('KC',"\x{304C}")), "YES");
is(answer(check('D' ,"\x{FF76}")), "YES");
is(answer(check('C' ,"\x{FF76}")), "YES");
is(answer(check('KD',"\x{FF76}")), "NO");
is(answer(check('KC',"\x{FF76}")), "NO");

is(normalize('NFD', "\x{304C}\x{FF76}"), "\x{304B}\x{3099}\x{FF76}");
is(normalize('NFC', "\x{304C}\x{FF76}"), "\x{304C}\x{FF76}");
is(normalize('NFKD',"\x{304C}\x{FF76}"), "\x{304B}\x{3099}\x{30AB}");
is(normalize('NFKC',"\x{304C}\x{FF76}"), "\x{304C}\x{30AB}");

is(answer(check('NFD', "\x{304C}")), "NO");
is(answer(check('NFC', "\x{304C}")), "YES");
is(answer(check('NFKD',"\x{304C}")), "NO");
is(answer(check('NFKC',"\x{304C}")), "YES");
is(answer(check('NFD' ,"\x{FF76}")), "YES");
is(answer(check('NFC' ,"\x{FF76}")), "YES");
is(answer(check('NFKD',"\x{FF76}")), "NO");
is(answer(check('NFKC',"\x{FF76}")), "NO");

