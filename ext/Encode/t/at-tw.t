BEGIN {
    if (! -d 'blib' and -d 't'){ chdir 't' };
    unshift @INC,  '../lib';
    require Config; Config->import;
    if ($Config{'extensions'} !~ m/\bEncode\b/) {
      print "1..0 # Skip: Encode was not built\n";
      exit 0;
    }
    unless (PerlIO::Layer->find( 'perlio')) {
    print "1..0 # Skip: PerlIO was not built\n";
    exit 0;
    }
    if (ord("A") == 193) {
    print "1..0 # Skip: EBCDIC\n";
    exit 0;
    }
    $| = 1;
}

use strict;
use Test::More tests => 17;
use Encode;

no utf8; # we have raw Chinese encodings here

use_ok('Encode::TW');

# Since JP.t already tests basic file IO, we will just focus on
# internal encode / decode test here. Unfortunately, to test
# against all the UniHan characters will take a huge disk space,
# not to mention the time it will take, and the fact that Perl
# did not bundle UniHan.txt anyway.

# So, here we just test a typical snippet spanning multiple Unicode
# blocks, and hope it can point out obvious errors.

run_tests('Basic Big5 range', {
    'utf'	=> (
"\x{5e1d}\x{9ad8}\x{967d}\x{4e4b}\x{82d7}\x{88d4}\x{516e}\x{ff0c}".
"\x{6715}\x{7687}\x{8003}\x{66f0}\x{4f2f}\x{5eb8}\x{fe54}".
"\x{651d}\x{63d0}\x{8c9e}\x{4e8e}\x{5b5f}\x{966c}\x{516e}\x{ff0c}".
"\x{60df}\x{5e9a}\x{5bc5}\x{543e}\x{4ee5}\x{964d}\x{fe54}"
    ),

    'big5'	=> (join('',
'«Ò°ª¶§¤§­]¸Ç¤¼¡A®Ó¬Ó¦Ò¤ê§B±e¡Q',
'Äá´£­s¤_©s³µ¤¼¡A±©©°±G§^¥H­°¡Q',
    )),

    'big5-hkscs'=> (join('',
'«Ò°ª¶§¤§­]¸Ç¤¼¡A®Ó¬Ó¦Ò¤ê§B±e¡Q',
'Äá´£­s¤_©s³µ¤¼¡A±©©°±G§^¥H­°¡Q',
    )),

    'cp950'	=> (join('',
'«Ò°ª¶§¤§­]¸Ç¤¼¡A®Ó¬Ó¦Ò¤ê§B±e¡Q',
'Äá´£­s¤_©s³µ¤¼¡A±©©°±G§^¥H­°¡Q',
    )),
});

run_tests('Hong Kong Extensions', {
    'utf'	=> (
"\x{611f}\x{8b1d}\x{6240}\x{6709}\x{4f7f}\x{7528}\x{20}\x{50}\x{65}\x{72}\x{6c}\x{20}".
"\x{5605}\x{670b}\x{53cb}\x{ff0c}\x{7d66}\x{6211}\x{54cb}\x{5605}".
"\x{652f}\x{6301}\x{3001}\x{610f}\x{898b}\x{548c}\x{9f13}\x{52f5}".
"\x{5982}\x{679c}\x{7de8}\x{78bc}\x{6709}\x{4efb}\x{4f55}\x{932f}\x{6f0f}".
"\x{ff0c}\x{8acb}\x{544a}\x{8a34}\x{6211}\x{54cb}\x{3002}"
    ),

    'big5-hkscs'	=> join('',
'·PÁÂ©Ò¦³¨Ï¥Î Perl ïªB¤Í¡Aµ¹§Ú’]ï¤ä«ù¡B·N¨£©M¹ªÀy',
'¦pªG½s½X¦³¥ô¦ó¿ùº|¡A½Ð§i¶D§Ú’]¡C'
    ),
});

sub run_tests {
    my ($title, $tests) = @_;
    my $utf = delete $tests->{'utf'};

    # $enc = encoding, $str = content
    foreach my $enc (sort keys %{$tests}) {
    my $str = $tests->{$enc};

    is(Encode::decode($enc, $str), $utf, "[$enc] decode - $title");
    is(Encode::encode($enc, $utf), $str, "[$enc] encode - $title");

    my $str2 = $str;
    my $utf8 = Encode::encode('utf-8', $utf);

    Encode::from_to($str2, $enc, 'utf-8');
    is($str2, $utf8, "[$enc] from_to => utf8 - $title");

    Encode::from_to($utf8, 'utf-8', $enc); # convert $utf8 as $enc
    is($utf8, $str,  "[$enc] utf8 => from_to - $title");
    }
}
