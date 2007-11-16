BEGIN {
    if ($ENV{'PERL_CORE'}){
        chdir 't';
    unshift @INC, '../lib';
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
    $| = 1;
}

use strict;
use Test::More tests => 29;
use Encode;

no utf8; # we have raw Chinese encodings here

use_ok('Encode::CN');

# Since JP.t already tests basic file IO, we will just focus on
# internal encode / decode test here. Unfortunately, to test
# against all the UniHan characters will take a huge disk space,
# not to mention the time it will take, and the fact that Perl
# did not bundle UniHan.txt anyway.

# So, here we just test a typical snippet spanning multiple Unicode
# blocks, and hope it can point out obvious errors.

run_tests('Simplified Chinese only', {
    'utf'	=> (
"\x{300a}\x{6613}\x{7ecf}\x{300b}\x{7b2c}\x{4e00}\x{5366}".
"\x{5f56}\x{66f0}\x{ff1a}".
"\x{5927}\x{54c9}\x{4e7e}\x{5143}\x{ff0c}\x{4e07}\x{7269}\x{8d44}\x{59cb}\x{ff0c}".
"\x{4e43}\x{7edf}\x{5929}\x{3002}".
"\x{4e91}\x{884c}\x{96e8}\x{65bd}\x{ff0c}\x{54c1}\x{7269}\x{6d41}\x{5f62}\x{3002}".
"\x{5927}\x{660e}\x{59cb}\x{7ec8}\x{ff0c}\x{516d}\x{4f4d}\x{65f6}\x{6210}\x{ff0c}".
"\x{65f6}\x{4e58}\x{516d}\x{9f99}\x{4ee5}\x{5fa1}\x{5929}\x{3002}".
"\x{4e7e}\x{9053}\x{53d8}\x{5316}\x{ff0c}\x{5404}\x{6b63}\x{6027}\x{547d}\x{ff0c}".
"\x{4fdd}\x{5408}\x{5927}\x{548c}\x{ff0c}\x{4e43}\x{5229}\x{8d1e}\x{3002}".
"\x{9996}\x{51fa}\x{5eb6}\x{7269}\x{ff0c}\x{4e07}\x{56fd}\x{54b8}\x{5b81}\x{3002}"
    ),

    'euc-cn'	=> join('',
'《易经》第一卦',
'彖曰：',
'大哉乾元，万物资始，',
'乃统天。',
'云行雨施，品物流形。',
'大明始终，六位时成，',
'时乘六龙以御天。',
'乾道变化，各正性命，',
'保合大和，乃利贞。',
'首出庶物，万国咸宁。',
    ),

    'gb2312-raw'	=> join('',
'!6RW>-!75ZR;XT',
'ehT;#:',
'4sTUG,T*#,MrNoWJJ<#,',
'DKM3Ll!#',
'TFPPSjJ)#,F7NoAwPN!#',
'4sCwJ<VU#,AyN;J13I#,',
'J13KAyAzRTSyLl!#',
'G,5@1d;/#,8wU}PTC|#,',
'1#:O4s:M#,DK@{Uj!#',
'JW3vJ|No#,Mr9zOLD~!#'
    ), 

    'iso-ir-165'=> join('',
'!6RW>-!75ZR;XT',
'ehT;#:',
'4sTUG,T*#,MrNoWJJ<#,',
'DKM3Ll!#',
'TFPPSjJ)#,F7NoAwPN!#',
'4sCwJ<VU#,AyN;J13I#,',
'J13KAyAzRTSyLl!#',
'G,5@1d;/#,8wU}PTC|#,',
'1#:O4s:M#,DK@{Uj!#',
'JW3vJ|No#,Mr9zOLD~!#'
    ), 
});

run_tests('Simplified Chinese + ASCII', {
    'utf'	=> (
"\x{8c61}\x{66f0}\x{ff1a}\x{a}".
"\x{5929}\x{884c}\x{5065}\x{ff0c}\x{541b}\x{5b50}\x{4ee5}\x{81ea}\x{5f3a}\x{4e0d}\x{606f}\x{3002}\x{a}".
"\x{6f5c}\x{9f99}\x{52ff}\x{7528}\x{ff0c}\x{9633}\x{5728}\x{4e0b}\x{4e5f}\x{3002}\x{20}".
"\x{89c1}\x{9f99}\x{5728}\x{7530}\x{ff0c}\x{5fb7}\x{65bd}\x{666e}\x{4e5f}\x{3002}\x{20}".
"\x{7ec8}\x{65e5}\x{4e7e}\x{4e7e}\x{ff0c}\x{53cd}\x{590d}\x{9053}\x{4e5f}\x{3002}\x{a}".
"\x{6216}\x{8dc3}\x{5728}\x{6e0a}\x{ff0c}\x{8fdb}\x{65e0}\x{548e}\x{4e5f}\x{3002}\x{98de}".
"\x{9f99}\x{5728}\x{5929}\x{ff0c}\x{5927}\x{4eba}\x{9020}\x{4e5f}\x{3002}\x{20}".
"\x{4ea2}\x{9f99}\x{6709}\x{6094}\x{ff0c}\x{76c8}\x{4e0d}\x{53ef}\x{4e45}\x{4e5f}\x{3002}\x{a}".
"\x{7528}\x{4e5d}\x{ff0c}\x{5929}\x{5fb7}\x{4e0d}\x{53ef}\x{4e3a}\x{9996}\x{4e5f}\x{3002}"
    ),

    'cp936'	=> join(chr(10),
'象曰：',
'天行健，君子以自强不息。',
'潜龙勿用，阳在下也。 见龙在田，德施普也。 终日乾乾，反复道也。',
'或跃在渊，进无咎也。飞龙在天，大人造也。 亢龙有悔，盈不可久也。',
'用九，天德不可为首也。',
    ),

    'hz'	=> join(chr(10),
'~{OsT;#:~}',
'~{LlPP=!#,>}WSRTWTG?2;O"!#~}',
'~{G1AzNpSC#,QtTZOBR2!#~} ~{<{AzTZLo#,5BJ)FUR2!#~} ~{VUHUG,G,#,74845@R2!#~}',
'~{;rT>TZT(#,=xN^>LR2!#7IAzTZLl#,4sHKTlR2!#~} ~{?:AzSP;Z#,S/2;?I>CR2!#~}',
'~{SC>E#,Ll5B2;?IN*JWR2!#~}',
    ),
});

run_tests('Traditional Chinese', {
    'utf',	=> "\x{4e7e}\x{ff1a}\x{5143}\x{3001}\x{4ea8}\x{3001}\x{5229}\x{3001}\x{8c9e}",
    'gb12345-raw'	=> 'G,#:T*!":`!"@{!"Uj',
    'gbk'	=> '乾：元、亨、利、貞',
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
