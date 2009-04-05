
BEGIN {
    if (env::var('PERL_CORE')) {
        chdir('t') if -d 't';
        $^INCLUDE_PATH = @( $^OS_NAME eq 'MacOS' ?? < qw(::lib) !! < qw(../lib) );
    }
}

#########################

use Unicode::Normalize < qw(:all);

use Test::More;

use warnings;

use utf8;

BEGIN { plan tests => 112 };

#########################

no warnings < qw(utf8);
# To avoid warning in Test.pm, EXPR in ok(EXPR) must be boolean.

for my $u (@(0xD800, 0xDFFF, 0xFDD0, 0xFDEF, 0xFEFF, 0xFFFE, 0xFFFF,
	   0x1FFFF, 0x10FFFF, 0x110000, 0x7FFFFFFF))
{
    my $c = chr $u;
    ok($c eq NFD($c));  # 1
    ok($c eq NFC($c));  # 2
    ok($c eq NFKD($c)); # 3
    ok($c eq NFKC($c)); # 4
    ok($c eq FCD($c));  # 5
    ok($c eq FCC($c));  # 6
    ok($c eq decompose($c));   # 7
    ok($c eq decompose($c,1)); # 8
    ok($c eq reorder($c));     # 9
    ok($c eq compose($c));     # 10
}

our $proc;    # before the last starter
our $unproc;  # the last starter and after

sub _pack_U   { Unicode::Normalize::pack_U(< @_) }

@($proc, $unproc) = splitOnLastStarter(_pack_U(0x41, 0x300, 0x327, 0xFFFF));
ok($proc   eq _pack_U(0x41, 0x300, 0x327));
ok($unproc eq "\x{FFFF}");

