# $Id: enc_data.t,v 2.1 2006/05/03 18:24:10 dankogai Exp $

BEGIN {
    require Config; Config->import();
    if ($Config{'extensions'} !~ /\bEncode\b/) {
      print "1..0 # Skip: Encode was not built\n";
      exit 0;
    }
    unless (PerlIO::Layer->find('perlio')) {
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
use utf8;
use encoding 'euc-jp';
use Encode;
use Test::More tests => 5;

my @a;

{
local $TODO = "decode of data section";
is <DATA>, "これはDATAファイルハンドルのテストです。"."\n";
}

while (<DATA>) {
  $_ = Encode::decode('euc-jp', $_);
  chomp;
  tr/ぁ-んァ-ン/ァ-ンぁ-ん/;
  push @a, $_;
}

is(scalar @a, 3);
is($a[0], "コレハDATAふぁいるはんどるノてすとデス。");
is($a[1], "日本語ガチャント変換デキルカ");
is($a[2], "ドウカノてすとヲシテイマス。");

__DATA__
これはDATAファイルハンドルのテストです。
これはDATAファイルハンドルのテストです。
日本語がちゃんと変換できるか
どうかのテストをしています。
