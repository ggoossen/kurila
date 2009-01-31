
BEGIN {
    if (env::var('PERL_CORE')) {
        chdir('t') if -d 't';
        $^INCLUDE_PATH = @( $^OS_NAME eq 'MacOS' ?? < qw(::lib) !! < qw(../lib) );
    }
}

#########################

use warnings;

use Unicode::Normalize < qw(:all);
use Test::More;

plan tests => 24;

ok 1;

# if $_ is not NULL-terminated, test may fail.

$_ = compose('abc');
like($_, qr/c$/);

$_ = decompose('abc');
like($_, qr/c$/);

$_ = reorder('abc');
like($_, qr/c$/);

$_ = NFD('abc');
like($_, qr/c$/);

$_ = NFC('abc');
like($_, qr/c$/);

$_ = NFKD('abc');
like($_, qr/c$/);

$_ = NFKC('abc');
like($_, qr/c$/);

$_ = FCC('abc');
like($_, qr/c$/);

$_ = decompose("\x{304C}abc");
like($_, qr/c$/);

$_ = decompose("\x{304B}\x{3099}abc");
like($_, qr/c$/);

$_ = reorder("\x{304C}abc");
like($_, qr/c$/);

$_ = reorder("\x{304B}\x{3099}abc");
like($_, qr/c$/);

$_ = compose("\x{304C}abc");
like($_, qr/c$/);

$_ = compose("\x{304B}\x{3099}abc");
like($_, qr/c$/);

$_ = NFD("\x{304C}abc");
like($_, qr/c$/);

$_ = NFC("\x{304C}abc");
like($_, qr/c$/);

$_ = NFKD("\x{304C}abc");
like($_, qr/c$/);

$_ = NFKC("\x{304C}abc");
like($_, qr/c$/);

$_ = FCC("\x{304C}abc");
like($_, qr/c$/);

$_ = getCanon(0x100);
ok($_ =~ s/.$//);

$_ = getCompat(0x100);
ok($_ =~ s/.$//);

$_ = getCanon(0xAC00);
ok($_ =~ s/.$//);

$_ = getCompat(0xAC00);
ok($_ =~ s/.$//);

