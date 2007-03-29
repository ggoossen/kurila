BEGIN {
    if ($ENV{'PERL_CORE'}){
        chdir 't';
        @INC = '../lib';
    }
    require Config; Config->import;
    if ($Config{'extensions'} !~ /\bEncode\b/) {
      print "1..0 # Skip: Encode was not built\n";
      exit 0;
    }
    if (ord("A") == 193) {
        print "1..0 # Skip: EBCDIC\n";
        exit 0;
    }
    unless (PerlIO::Layer->find('perlio')){
        print "1..0 # Skip: PerlIO required\n";
        exit 0;
    }
    if ($ENV{PERL_CORE_MINITEST}) {
        print "1..0 # Skip: no dynamic loading on miniperl, no Encode\n";
        exit 0;
    }
    $| = 1;
    require './test.pl';
}

plan tests => 5;

use encoding "greek"; # iso 8859-7
use utf8;

# U+0391, \x[C1], \301, GREEK CAPITAL LETTER ALPHA
# U+03B1, \x[E1], \341, GREEK SMALL LETTER ALPHA

ok("\xC1"    eq chr(0xC1),  '\xXX and ord(0xXX) the same');
ok("\x{C1}"  eq chr(0xC1),  '\xXX and ord(0xXX) the same');
is( eval qq|use encoding 'greek'; "\x[C1]"|, "\x{391}", "source is decoded" );

# U+00C1, \x[C1], \301, LATIN CAPITAL LETTER A WITH ACUTE
# U+0102, \x[C3], \402, LATIN CAPITAL LETTER A WITH BREVE
is( eval qq|use encoding 'latin2'; "\x[C1]"|, "\x{C1}", "source is decoded" );
is( eval qq|use encoding 'latin2'; "\x[C3]"|, "\x{102}", "source is decoded" );
