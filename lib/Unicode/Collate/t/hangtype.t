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
BEGIN { plan tests => 33 };

use warnings;
use Unicode::Collate;

ok(1);

#########################

is(Unicode::Collate::getHST(0x0000), '');
is(Unicode::Collate::getHST(0x0100), '');
is(Unicode::Collate::getHST(0x1000), '');
is(Unicode::Collate::getHST(0x10FF), '');
is(Unicode::Collate::getHST(0x1100), 'L');
is(Unicode::Collate::getHST(0x1101), 'L');
is(Unicode::Collate::getHST(0x1159), 'L');
is(Unicode::Collate::getHST(0x115A), '');
is(Unicode::Collate::getHST(0x115E), '');
is(Unicode::Collate::getHST(0x115F), 'L');
is(Unicode::Collate::getHST(0x1160), 'V');
is(Unicode::Collate::getHST(0x1161), 'V');
is(Unicode::Collate::getHST(0x11A0), 'V');
is(Unicode::Collate::getHST(0x11A2), 'V');
is(Unicode::Collate::getHST(0x11A3), '');
is(Unicode::Collate::getHST(0x11A7), '');
is(Unicode::Collate::getHST(0x11A8), 'T');
is(Unicode::Collate::getHST(0x11AF), 'T');
is(Unicode::Collate::getHST(0x11E0), 'T');
is(Unicode::Collate::getHST(0x11F9), 'T');
is(Unicode::Collate::getHST(0x11FA), '');
is(Unicode::Collate::getHST(0x11FF), '');
is(Unicode::Collate::getHST(0x3011), '');
is(Unicode::Collate::getHST(0x11A7), '');
is(Unicode::Collate::getHST(0xABFF), '');
is(Unicode::Collate::getHST(0xAC00), 'LV');
is(Unicode::Collate::getHST(0xAC01), 'LVT');
is(Unicode::Collate::getHST(0xAC1B), 'LVT');
is(Unicode::Collate::getHST(0xAC1C), 'LV');
is(Unicode::Collate::getHST(0xD7A3), 'LVT');
is(Unicode::Collate::getHST(0xD7A4), '');
is(Unicode::Collate::getHST(0xFFFF), '');

