#!./perl

require './test.pl';
plan( tests => 15 );

our (@oops, @ops, %files, $not, @glops, $x);

@oops = @ops = glob("op/*");

if ($^O eq 'MSWin32') {
  map { $files{lc($_)}++ } glob("op/*");
  map { delete $files{"op/$_"} } split m/[\s\n]/, `dir /b /l op & dir /b /l /ah op 2>nul`,
}
elsif ($^O eq 'VMS') {
  map { $files{lc($_)}++ } glob("[.op]*");
  map { s/;.*$//; delete $files{lc($_)}; } split m/[\n]/, `directory/noheading/notrailing/versions=1 [.op]`,
}
elsif ($^O eq 'MacOS') {
  @oops = @ops = glob(":op:*");
  map { $files{$_}++ } glob(":op:*");
  map { delete $files{$_} } split m/[\s\n]/, `echo :op:\x[c5]`;
}
else {
  map { $files{$_}++ } glob("op/*");
  map { delete $files{$_} } split m/[\s\n]/, `echo op/*`;
}
ok( !(keys(%files)),'leftover op/* files' ) or diag(join(' ',sort keys %files));

cmp_ok($/,'eq',"\n",'sane input record separator');

$not = '';
if ($^O eq 'MacOS') {
    while (glob("jskdfjskdfj* :op:* jskdjfjkosvk*")) {
	$not = "not " unless $_ eq shift @ops;
	$not = "not at all " if $/ eq "\0";
    }
} else {
    while (glob("jskdfjskdfj* op/* jskdjfjkosvk*")) {
	$not = "not " unless $_ eq shift @ops;
	$not = "not at all " if $/ eq "\0";
    }
}
ok(!$not,"glob amid garbage [$not]");

cmp_ok($/,'eq',"\n",'input record separator still sane');

$_ = $^O eq 'MacOS' ? ":op:*" : "op/*";
@glops = glob $_;
cmp_ok("@glops",'eq',"@oops",'glob operator 1');

@glops = glob;
cmp_ok("@glops",'eq',"@oops",'glob operator 2');

# glob should still work even after the File::Glob stash has gone away
# (this used to dump core)
my $i = 0;
for (1..2) {
    eval "glob('.')";
    ok(!length($@),"eval'ed a glob $_");
    undef %{Symbol::stash('File::Glob')};
    ++$i;
}
cmp_ok($i,'==',2,'remore File::Glob stash');

# ... while ($var = glob(...)) should test definedness not truth

SKIP: {
    skip('no File::Glob to emulate Unix-ism', 1)
	unless $INC{'File/Glob.pm'};
    my $ok = 0;
    $ok = 1 while my $var = glob("0");
    ok($ok,'define versus truth');
}

# The formerly-broken test for the situation above would accidentally
# test definedness for an assignment with a LOGOP on the right:
{
    my $f = 0;
    my $ok = 1;
    $ok = 0, undef $f while $x = $f||$f;
    ok($ok,'test definedness with LOGOP');
}

cmp_ok(scalar(@oops),'+>',0,'glob globbed something');

*aieee = 4;
pass('Can assign integers to typeglobs');
*aieee = 3.14;
pass('Can assign floats to typeglobs');
*aieee = 'pi';
pass('Can assign strings to typeglobs');
