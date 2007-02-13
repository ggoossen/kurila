# $Id: enc_data.t,v 2.1 2006/05/03 18:24:10 dankogai Exp $

BEGIN {
    require Config; Config->import;
    if ($Config{'extensions'} !~ /\bEncode\b/) {
      print "1..0 # Skip: Encode was not built\n";
      exit 0;
    }
    unless (find PerlIO::Layer 'perlio') {
    print "1..0 # Skip: PerlIO was not built\n";
    exit 0;
    }
    if (ord("A") == 193) {
    print "1..0 # encoding pragma does not support EBCDIC platforms\n";
    exit(0);
    }
    if ($] <= 5.008 and !$Config{perl_patchlevel}){
    print "1..0 # Skip: Perl 5.8.1 or later required\n";
    exit 0;
    }
}


use strict;
use encoding 'euc-jp';
use Test::More tests => 4;

my @a;

while (<DATA>) {
  chomp;
  tr/¤Â¡-¤ó¥¡-¥Âó/¥Â¡-¥ó¤¡-¤Âó/;
  push @a, $_;
}

is(scalar @a, 3);
is($a[0], "¥³¥ì¥ÏDATA¤Õ¤¡¤¤¤ë¤Ï¤ó¤É¤ë¥Î¤Æ¤¹Â¤È¥Ç¥¹¡£");
is($a[1], "ÆüËÜ¸ì¥¬¥Á¥ã¥ó¥ÈÂÊÑ´¹Â¥Ç¥­¥ë¥Â«");
is($a[2], "¥É¥¦¥«¥Î¤Æ¤¹Â¤È¥ò¥·¥Æ¥¤Â¥Þ¥¹¡£");

__DATA__
¤³¤ì¤ÏDATA¥Õ¥¡¥¤¥ë¥Ï¥ó¥É¥ë¤Î¥Æ¥¹Â¥È¤Ç¤¹¡£
ÆüËÜ¸ì¤¬¤Á¤ã¤ó¤ÈÂÊÑ´¹Â¤Ç¤­¤ë¤Â«
¤É¤¦¤«¤Î¥Æ¥¹Â¥È¤ò¤·¤Æ¤¤Â¤Þ¤¹¡£
