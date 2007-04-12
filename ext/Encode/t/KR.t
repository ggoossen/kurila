BEGIN {
    if ($ENV{'PERL_CORE'}){
        chdir 't';
        unshift @INC, '../lib';
    }
    require Config; import Config;
    if ($Config{'extensions'} !~ /\bEncode\b/) {
      print "1..0 # Skip: Encode was not built\n";
      exit 0;
    }
    unless (find PerlIO::Layer 'perlio') {
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
use Test::More tests => 15;
#use Test::More qw(no_plan);
use Encode;
use File::Basename;
use File::Spec;
use File::Compare;
require_ok "Encode::KR";

my ($src, $uni, $dst, $txt, $euc, $utf, $ref, $rnd);

ok(defined(my $enc = find_encoding('euc-kr')));
ok($enc->isa('Encode::XS'));
is($enc->name,'euc-kr');
my $dir = dirname(__FILE__);

my @subcodings = qw(ksc5601);

for my $subcoding (@subcodings){
    $euc = File::Spec->catfile($dir,"$subcoding.euc");
    $utf = File::Spec->catfile($dir,"$$.utf8");
    $ref = File::Spec->catfile($dir,"$subcoding.ref");
    $rnd = File::Spec->catfile($dir,"$$.rnd");
    print "# Basic decode test\n";
    open($src,"<",$euc) || die "Cannot open $euc:$!";
    binmode($src);
    ok(defined($src) && fileno($src));
    $txt = join('',<$src>);
    open($dst,">:utf8",$utf) || die "Cannot open $utf:$!";
    binmode($dst);
    ok(defined($dst) && fileno($dst));
    eval{ $uni = $enc->decode($txt,1) };
    $@ and print $@;
    ok(defined($uni));
    is(length($txt),0);
    print $dst $uni;
    close($dst);
    close($src);
    ok(compare($utf,$ref) == 0);
}

print "# Basic encode test\n";
open($src,"<:utf8",$ref) || die "Cannot open $ref:$!";
binmode($src);
ok(defined($src) && fileno($src));
$uni = join('',<$src>);
open($dst,">",$rnd) || die "Cannot open $rnd:$!";
binmode($dst);
ok(defined($dst) && fileno($dst));
$txt = $enc->encode($uni,1);
ok(defined($txt));
is(length($uni),0);
print $dst $txt;
close($dst);
close($src);
ok(compare($euc,$rnd) == 0);

is($enc->name,'euc-kr');

END {
 1 while unlink($utf,$rnd);
}
