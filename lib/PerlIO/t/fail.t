#!./perl

BEGIN {
    require "../t/test.pl";
    skip_all("No perlio") unless (PerlIO::Layer->find( 'perlio'));
    plan (15);
}

use warnings 'layer';
my $warn;
my $file = "fail$^PID";
$^WARN_HOOK = sub { $warn = shift->{?description} };

END { 1 while unlink($file) }

ok(open(FH,">",$file),"Create works");
close(FH);
ok(open(FH,"<",$file),"Normal open works");

$warn = ''; $^OS_ERROR = 0;
ok(!binmode(FH,":-)"),"All punctuation fails binmode");
print "# $^OS_ERROR\n";
isnt($^OS_ERROR,0,"Got errno");
like($warn,qr/in PerlIO layer/,"Got warning");

$warn = ''; $^OS_ERROR = 0;
ok(!binmode(FH,":nonesuch"),"Bad package fails binmode");
print "# $^OS_ERROR\n";
isnt($^OS_ERROR,0,"Got errno");
like($warn,qr/nonesuch/,"Got warning");
close(FH);

$warn = ''; $^OS_ERROR = 0;
ok(!open(FH,"<:-)",$file),"All punctuation fails open");
print "# $^OS_ERROR\n";
isnt($^OS_ERROR,"","Got errno");
like($warn,qr/in PerlIO layer/,"Got warning");

$warn = ''; $^OS_ERROR = 0;
ok(!open(FH,"<:nonesuch",$file),"Bad package fails open");
print "# $^OS_ERROR\n";
isnt($^OS_ERROR,0,"Got errno");
like($warn,qr/nonesuch/,"Got warning");

ok(open(FH,"<",$file),"Normal open (still) works");
close(FH);
