BEGIN {
    unless ("A" eq pack('U', 0x41)) {
	print "1..0 # Unicode::Collate " .
	    "cannot stringify a Unicode code point\n";
	exit 0;
    }
    if (%ENV{PERL_CORE}) {
	chdir('t') if -d 't';
	@INC = @( $^O eq 'MacOS' ? qw(::lib) : qw(../lib) );
    }
}

BEGIN {
    try { require Unicode::Normalize; };
    if ($@) {
	print "1..0 # skipped: Unicode::Normalize needed for this test\n";
	print $@;
	exit;
    }
}
use Test::More;
BEGIN { plan tests => 100 };

use strict;
use warnings;
use Unicode::Collate;

our $Aring = pack('U', 0xC5);
our $aring = pack('U', 0xE5);

our $entry = <<'ENTRIES';
030A; [.0000.030A.0002] # COMBINING RING ABOVE
212B; [.002B.0020.0008] # ANGSTROM SIGN
0061; [.0A41.0020.0002] # LATIN SMALL LETTER A
0041; [.0A41.0020.0008] # LATIN CAPITAL LETTER A
007A; [.0A5A.0020.0002] # LATIN SMALL LETTER Z
005A; [.0A5A.0020.0008] # LATIN CAPITAL LETTER Z
FF41; [.0A87.0020.0002] # LATIN SMALL LETTER A
FF21; [.0A87.0020.0008] # LATIN CAPITAL LETTER A
00E5; [.0AC5.0020.0002] # LATIN SMALL LETTER A WITH RING ABOVE
00C5; [.0AC5.0020.0008] # LATIN CAPITAL LETTER A WITH RING ABOVE
ENTRIES

# Aong < A+ring < Z < fullA+ring < A-ring

#########################

our $noN = Unicode::Collate->new(
    level => 1,
    table => undef,
    normalization => undef,
    entry => $entry,
);

our $nfc = Unicode::Collate->new(
  level => 1,
  table => undef,
  normalization => 'NFC',
  entry => $entry,
);

our $nfd = Unicode::Collate->new(
  level => 1,
  table => undef,
  normalization => 'NFD',
  entry => $entry,
);

our $nfkc = Unicode::Collate->new(
  level => 1,
  table => undef,
  normalization => 'NFKC',
  entry => $entry,
);

our $nfkd = Unicode::Collate->new(
  level => 1,
  table => undef,
  normalization => 'NFKD',
  entry => $entry,
);

is($noN->cmp("\x{212B}", "A"), -1);
is($noN->cmp("\x{212B}", $Aring), -1);
is($noN->cmp("A\x{30A}", $Aring), -1);
is($noN->cmp("A",       "\x{FF21}"), -1);
is($noN->cmp("Z",       "\x{FF21}"), -1);
is($noN->cmp("Z",        $Aring), -1);
is($noN->cmp("\x{212B}", $aring), -1);
is($noN->cmp("A\x{30A}", $aring), -1);
is($noN->cmp("Z",        $aring), -1);
is($noN->cmp("a\x{30A}", "Z"), -1);

ok($nfd->eq("\x{212B}", "A"));
ok($nfd->eq("\x{212B}", $Aring));
ok($nfd->eq("A\x{30A}", $Aring));
is($nfd->cmp("A",       "\x{FF21}"), -1);
is($nfd->cmp("Z",       "\x{FF21}"), -1);
is($nfd->cmp("Z",        $Aring), 1);
ok($nfd->eq("\x{212B}", $aring));
ok($nfd->eq("A\x{30A}", $aring));
is($nfd->cmp("Z",        $aring), 1);
is($nfd->cmp("a\x{30A}", "Z"), -1);

is($nfc->cmp("\x{212B}", "A"), 1);
ok($nfc->eq("\x{212B}", $Aring));
ok($nfc->eq("A\x{30A}", $Aring));
is($nfc->cmp("A",       "\x{FF21}"), -1);
is($nfc->cmp("Z",       "\x{FF21}"), -1);
is($nfc->cmp("Z",        $Aring), -1);
ok($nfc->eq("\x{212B}", $aring));
ok($nfc->eq("A\x{30A}", $aring));
is($nfc->cmp("Z",        $aring), -1);
is($nfc->cmp("a\x{30A}", "Z"), 1);

ok($nfkd->eq("\x{212B}", "A"));
ok($nfkd->eq("\x{212B}", $Aring));
ok($nfkd->eq("A\x{30A}", $Aring));
ok($nfkd->eq("A",       "\x{FF21}"));
is($nfkd->cmp("Z",       "\x{FF21}"), 1);
is($nfkd->cmp("Z",        $Aring), 1);
ok($nfkd->eq("\x{212B}", $aring));
ok($nfkd->eq("A\x{30A}", $aring));
is($nfkd->cmp("Z",        $aring), 1);
is($nfkd->cmp("a\x{30A}", "Z"), -1);

is($nfkc->cmp("\x{212B}", "A"), 1);
ok($nfkc->eq("\x{212B}", $Aring));
ok($nfkc->eq("A\x{30A}", $Aring));
ok($nfkc->eq("A",       "\x{FF21}"));
is($nfkc->cmp("Z",       "\x{FF21}"), 1);
is($nfkc->cmp("Z",        $Aring), -1);
ok($nfkc->eq("\x{212B}", $aring));
ok($nfkc->eq("A\x{30A}", $aring));
is($nfkc->cmp("Z",        $aring), -1);
is($nfkc->cmp("a\x{30A}", "Z"), 1);

$nfd->change(normalization => undef);

is($nfd->cmp("\x{212B}", "A"), -1);
is($nfd->cmp("\x{212B}", $Aring), -1);
is($nfd->cmp("A\x{30A}", $Aring), -1);
is($nfd->cmp("A",       "\x{FF21}"), -1);
is($nfd->cmp("Z",       "\x{FF21}"), -1);
is($nfd->cmp("Z",        $Aring), -1);
is($nfd->cmp("\x{212B}", $aring), -1);
is($nfd->cmp("A\x{30A}", $aring), -1);
is($nfd->cmp("Z",        $aring), -1);
is($nfd->cmp("a\x{30A}", "Z"), -1);

$nfd->change(normalization => 'C');

is($nfd->cmp("\x{212B}", "A"), 1);
ok($nfd->eq("\x{212B}", $Aring));
ok($nfd->eq("A\x{30A}", $Aring));
is($nfd->cmp("A",       "\x{FF21}"), -1);
is($nfd->cmp("Z",       "\x{FF21}"), -1);
is($nfd->cmp("Z",        $Aring), -1);
ok($nfd->eq("\x{212B}", $aring));
ok($nfd->eq("A\x{30A}", $aring));
is($nfd->cmp("Z",        $aring), -1);
is($nfd->cmp("a\x{30A}", "Z"), 1);

$nfd->change(normalization => 'D');

ok($nfd->eq("\x{212B}", "A"));
ok($nfd->eq("\x{212B}", $Aring));
ok($nfd->eq("A\x{30A}", $Aring));
is($nfd->cmp("A",       "\x{FF21}"), -1);
is($nfd->cmp("Z",       "\x{FF21}"), -1);
is($nfd->cmp("Z",        $Aring), 1);
ok($nfd->eq("\x{212B}", $aring));
ok($nfd->eq("A\x{30A}", $aring));
is($nfd->cmp("Z",        $aring), 1);
is($nfd->cmp("a\x{30A}", "Z"), -1);

$nfd->change(normalization => 'KD');

ok($nfd->eq("\x{212B}", "A"));
ok($nfd->eq("\x{212B}", $Aring));
ok($nfd->eq("A\x{30A}", $Aring));
ok($nfd->eq("A",       "\x{FF21}"));
is($nfd->cmp("Z",       "\x{FF21}"), 1);
is($nfd->cmp("Z",        $Aring), 1);
ok($nfd->eq("\x{212B}", $aring));
ok($nfd->eq("A\x{30A}", $aring));
is($nfd->cmp("Z",        $aring), 1);
is($nfd->cmp("a\x{30A}", "Z"), -1);

$nfd->change(normalization => 'KC');

is($nfd->cmp("\x{212B}", "A"), 1);
ok($nfd->eq("\x{212B}", $Aring));
ok($nfd->eq("A\x{30A}", $Aring));
ok($nfd->eq("A",       "\x{FF21}"));
is($nfd->cmp("Z",       "\x{FF21}"), 1);
is($nfd->cmp("Z",        $Aring), -1);
ok($nfd->eq("\x{212B}", $aring));
ok($nfd->eq("A\x{30A}", $aring));
is($nfd->cmp("Z",        $aring), -1);
is($nfd->cmp("a\x{30A}", "Z"), 1);

